#!/usr/bin/env python3
import csv
import re
from pathlib import Path


ROOT = Path('/home/projects/Gas_Line_case/shap_src_min')


def parse_path_points(d):
    vals = [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?', d)]
    return list(zip(vals[0::2], vals[1::2]))


def fmt_path(points):
    out = [f'M{points[0][0]:.4f} {points[0][1]:.4f}']
    out.extend(f'L{x:.4f} {y:.4f}' for (x, y) in points[1:])
    return ' '.join(out)


def linear_fit(xv, yv):
    n = min(len(xv), len(yv))
    x = xv[:n]
    y = yv[:n]
    mx = sum(x) / n
    my = sum(y) / n
    v = sum((u - mx) ** 2 for u in x)
    if v == 0:
        return 0.0, my
    c = sum((x[i] - mx) * (y[i] - my) for i in range(n))
    a = c / v
    b = my - a * mx
    return a, b


def gradient_uniform(vals, dt):
    n = len(vals)
    if n < 2:
        return [0.0] * n
    g = [0.0] * n
    g[0] = (vals[1] - vals[0]) / dt
    g[-1] = (vals[-1] - vals[-2]) / dt
    for i in range(1, n - 1):
        g[i] = (vals[i + 1] - vals[i - 1]) / (2.0 * dt)
    return g


def load_ss_opt():
    rows = []
    p = ROOT / 'tr/ss_opt/action_sequence.csv'
    with p.open(newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            rows.append([float(row[f'cc_{i}']) for i in range(1, 6)])
    return rows


def load_increment_row(seed, sample_id):
    p = ROOT / f'doe/try1/seed_{seed:03d}/dataset_dt_1p0/increment_signed_per_hour_design.csv'
    with p.open() as f:
        for i, line in enumerate(f, 1):
            if i == sample_id:
                return [float(x) for x in line.strip().split(',') if x]
    raise RuntimeError(f'Cannot find sample {sample_id} in {p}')


def reconstruct_cc(seed, sample_id, cc_start, cc_end):
    vals = load_increment_row(seed, sample_id)
    n_actions = 25
    n_comp = 5
    c_min, c_max = 1.0, 1.6
    delta_cap_per_h = 0.08

    sel_idx = list(range(0, n_actions, 2))
    if sel_idx[-1] != n_actions - 1:
        sel_idx.append(n_actions - 1)
    free_idx = sel_idx[1:-1]
    n_free = len(free_idx)
    if len(vals) != n_free * n_comp:
        raise RuntimeError(f'Unexpected design length: {len(vals)}')
    u_signed_per_h = [vals[i * n_comp:(i + 1) * n_comp] for i in range(n_free)]

    sel_vals = [[0.0] * n_comp for _ in range(len(sel_idx))]
    sel_vals[0] = cc_start[:]

    for k in range(1, len(sel_idx) - 1):
        prev = sel_vals[k - 1]
        dth = float(sel_idx[k] - sel_idx[k - 1])
        cap = delta_cap_per_h * dth
        dc = [u_signed_per_h[k - 1][j] * dth for j in range(n_comp)]
        cand = [prev[j] + dc[j] for j in range(n_comp)]
        for j in range(n_comp):
            if cand[j] < c_min or cand[j] > c_max:
                cand[j] = prev[j]

        rem_cap = delta_cap_per_h * float(sel_idx[-1] - sel_idx[k])
        lo = [max(c_min, prev[j] - cap, cc_end[j] - rem_cap) for j in range(n_comp)]
        hi = [min(c_max, prev[j] + cap, cc_end[j] + rem_cap) for j in range(n_comp)]
        for j in range(n_comp):
            if lo[j] > hi[j] + 1e-12:
                mid = 0.5 * (lo[j] + hi[j])
                lo[j] = mid
                hi[j] = mid
            if cand[j] < lo[j]:
                cand[j] = lo[j]
            if cand[j] > hi[j]:
                cand[j] = hi[j]
        sel_vals[k] = cand

    sel_vals[-1] = cc_end[:]

    cc = [[0.0] * n_comp for _ in range(n_actions)]
    for j in range(n_comp):
        for a in range(len(sel_idx) - 1):
            t0 = sel_idx[a]
            t1 = sel_idx[a + 1]
            y0 = sel_vals[a][j]
            y1 = sel_vals[a + 1][j]
            for t in range(t0, t1 + 1):
                frac = 0.0 if t1 == t0 else (t - t0) / float(t1 - t0)
                y = y0 + frac * (y1 - y0)
                if y < c_min:
                    y = c_min
                if y > c_max:
                    y = c_max
                cc[t][j] = y
        cc[0][j] = cc_start[j]
        cc[-1][j] = cc_end[j]
    return cc


def extract_path_groups(svg_text):
    pat = re.compile(r'(<g style="[^"]*stroke-width:3\.2;[^"]*"\s*>)(.*?)(</g\s*>)', re.S)
    groups = []
    for m in pat.finditer(svg_text):
        head, body, tail = m.group(1), m.group(2), m.group(3)
        ds = re.findall(r'<path d="([^"]+)"', body)
        groups.append({'start': m.start(), 'end': m.end(), 'head': head, 'body': body, 'tail': tail, 'paths': ds})
    return groups


def replace_group_paths(group_block, new_paths):
    body = group_block['body']
    i = 0

    def repl(m):
        nonlocal i
        if i >= len(new_paths):
            return m.group(0)
        s = m.group(0)
        s = re.sub(r'd="[^"]+"', f'd="{new_paths[i]}"', s, count=1)
        i += 1
        return s

    body_new = re.sub(r'<path d="[^"]+"[^>]*/>', repl, body)
    return group_block['head'] + body_new + group_block['tail']


def main():
    in_svg = ROOT / 'tr/ss_opt/ref-old/old_2x5.svg'
    out_svg = ROOT / 'tr/ss_opt/ref-old/old_2x5_pi.svg'
    svg = in_svg.read_text()

    ss = load_ss_opt()
    cc_start = ss[0][:]
    cc_end = ss[-1][:]

    # Requested PI-SHAP weight trajectories.
    pi_w02 = reconstruct_cc(seed=23, sample_id=143, cc_start=cc_start, cc_end=cc_end)
    pi_w05 = reconstruct_cc(seed=23, sample_id=394, cc_start=cc_start, cc_end=cc_end)
    pi_w08 = reconstruct_cc(seed=37, sample_id=167, cc_start=cc_start, cc_end=cc_end)
    pi_all = [pi_w02, pi_w05, pi_w08]

    groups = extract_path_groups(svg)
    if len(groups) < 20:
        raise RuntimeError('Unexpected old_2x5.svg structure')

    t = [float(i) for i in range(25)]

    # Build edited blocks for dashed groups only: indices 1,3,...,19.
    replacements = {}
    dashed_idxs = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
    for gidx in dashed_idxs:
        if gidx < 10:
            panel = (gidx - 1) // 2
            solid = groups[gidx - 1]
            ss_pts = parse_path_points(solid['paths'][1])
            xpix = [p[0] for p in ss_pts]
            ypix = [p[1] for p in ss_pts]
            a_x, b_x = linear_fit(t, xpix)
            ss_vals = [ss[k][panel] for k in range(25)]
            a_y, b_y = linear_fit(ss_vals, ypix)

            new_ds = []
            for pi in pi_all:
                pts = []
                for k in range(25):
                    xp = a_x * t[k] + b_x
                    yp = a_y * pi[k][panel] + b_y
                    pts.append((xp, yp))
                new_ds.append(fmt_path(pts))
            replacements[gidx] = replace_group_paths(groups[gidx], new_ds)
        else:
            panel = (gidx - 11) // 2
            solid = groups[gidx - 1]
            ss_pts = parse_path_points(solid['paths'][1])
            ss_r = [ss[k][panel] for k in range(25)]
            ss_d = gradient_uniform(ss_r, 3600.0)
            xpix = [p[0] for p in ss_pts]
            ypix = [p[1] for p in ss_pts]
            a_x, b_x = linear_fit(ss_r, xpix)
            a_y, b_y = linear_fit(ss_d, ypix)

            new_ds = []
            for pi in pi_all:
                r = [pi[k][panel] for k in range(25)]
                d = gradient_uniform(r, 3600.0)
                pts = []
                for k in range(25):
                    xp = a_x * r[k] + b_x
                    yp = a_y * d[k] + b_y
                    pts.append((xp, yp))
                new_ds.append(fmt_path(pts))
            replacements[gidx] = replace_group_paths(groups[gidx], new_ds)

    # Rebuild SVG with updated dashed groups.
    out = []
    last = 0
    for i, g in enumerate(groups):
        out.append(svg[last:g['start']])
        out.append(replacements.get(i, svg[g['start']:g['end']]))
        last = g['end']
    out.append(svg[last:])
    svg_new = ''.join(out)

    # Overlay a compact legend header text without disturbing original geometry.
    legend_overlay = (
        '<g style="stroke:none; fill:white;">'
        '<rect x="640" y="6" width="920" height="52"/></g>'
        '<g style="stroke:none; fill:rgb(38,38,38); font-size:30px; font-family:\'Times New Roman\';">'
        '<text x="660" y="40">tr-opt</text>'
        '<text x="820" y="40">ss-opt</text>'
        '<text x="990" y="40">PI-SHAP (w=0.2)</text>'
        '<text x="1220" y="40">PI-SHAP (w=0.5)</text>'
        '<text x="1450" y="40">PI-SHAP (w=0.8)</text>'
        '</g>'
    )
    svg_new = svg_new.replace('</svg>', legend_overlay + '</svg>')

    out_svg.write_text(svg_new)
    print(f'Wrote {out_svg}')


if __name__ == '__main__':
    main()
