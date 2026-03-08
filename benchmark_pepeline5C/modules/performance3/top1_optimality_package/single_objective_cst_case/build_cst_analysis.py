#!/usr/bin/env python3
from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RUNS_DIR = ROOT / "runs"
ROB_TABLES = ROOT / "robustness_validation" / "tables"
ROB_PLOTS = ROOT / "robustness_validation" / "plots"
PAR_TABLES = ROOT / "parameter_analysis" / "tables"
PAR_PLOTS = ROOT / "parameter_analysis" / "plots"

TOPK_LIST = [1, 3, 5, 10, 20, 50, 100]
METHODS = [
    ("PI-SHAP", "PIScoreJcost", "tab:blue"),
    ("Ori-SHAP", "OriScoreJcost", "tab:orange"),
    ("Cond-SHAP", "CondScoreJcost", "tab:green"),
]

SVG_COLORS = {
    "tab:blue": "#1f77b4",
    "tab:orange": "#ff7f0e",
    "tab:green": "#2ca02c",
}


@dataclass(frozen=True)
class RunMeta:
    run_id: str
    group: str
    value: str
    note: str


def classify_run(run_id: str) -> RunMeta:
    if run_id == "seed_train23_test11_37_dt1p0":
        return RunMeta(run_id, "seed_variation", "seed_split_A", "reference split")
    if run_id == "seed_train37_test11_23_dt1p0":
        return RunMeta(run_id, "seed_variation", "seed_split_B", "swapped train/test seeds")
    if run_id.startswith("dt0p5"):
        return RunMeta(run_id, "temporal_granularity", "dt=0.5h", "finer time step")
    if run_id.startswith("dt2p0"):
        return RunMeta(run_id, "temporal_granularity", "dt=2.0h", "coarser time step")
    if run_id.startswith("k120"):
        return RunMeta(run_id, "train_sample_k", "k=120", "smaller train subset")
    if run_id.startswith("k240"):
        return RunMeta(run_id, "train_sample_k", "k=240", "larger train subset")
    if run_id.startswith("ncl2"):
        return RunMeta(run_id, "label_count", "Ncl=2", "fewer labels")
    if run_id.startswith("ncl4"):
        return RunMeta(run_id, "label_count", "Ncl=4", "more labels")
    if run_id.startswith("ncl6"):
        return RunMeta(run_id, "label_count", "Ncl=6", "finer labels")
    if run_id.startswith("ncl8"):
        return RunMeta(run_id, "label_count", "Ncl=8", "finest labels")
    return RunMeta(run_id, "other", "unknown", "")


def ensure_dirs() -> None:
    for d in [ROB_TABLES, ROB_PLOTS, PAR_TABLES, PAR_PLOTS]:
        d.mkdir(parents=True, exist_ok=True)


def _read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def load_runs() -> dict[str, list[dict[str, str]]]:
    out: dict[str, list[dict[str, str]]] = {}
    for run_dir in sorted(RUNS_DIR.iterdir()):
        table = run_dir / "tables" / "holdout_case_scores.csv"
        if table.exists():
            out[run_dir.name] = _read_csv_rows(table)
    return out


def _to_float(v: str) -> float:
    try:
        return float(v)
    except Exception:
        return float("nan")


def _sort_by_score(rows: list[dict[str, str]], score_col: str) -> list[dict[str, str]]:
    return sorted(rows, key=lambda r: _to_float(r[score_col]))


def _write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def build_topk_tables(run_data: dict[str, list[dict[str, str]]]) -> tuple[list[dict], list[dict]]:
    rows_topk: list[dict] = []
    rows_top1: list[dict] = []

    for run_id, rows in run_data.items():
        meta = classify_run(run_id)
        jcost_vals = [_to_float(r["Jcost"]) for r in rows]
        global_best = min(jcost_vals)

        for method_name, score_col, _ in METHODS:
            ranked = _sort_by_score(rows, score_col)
            top1_jcost = _to_float(ranked[0]["Jcost"])
            top1_regret_pct = (top1_jcost / global_best - 1.0) * 100.0
            rows_top1.append(
                {
                    "RunID": run_id,
                    "Group": meta.group,
                    "GroupValue": meta.value,
                    "Method": method_name,
                    "N": int(len(rows)),
                    "GlobalBestJcost": global_best,
                    "Top1Jcost": top1_jcost,
                    "Top1RegretPct": top1_regret_pct,
                }
            )

            for k in TOPK_LIST:
                if k > len(rows):
                    continue
                block = ranked[:k]
                best_topk = min(_to_float(r["Jcost"]) for r in block)
                regret_pct = (best_topk / global_best - 1.0) * 100.0
                hit_best = int(any(abs(_to_float(r["Jcost"]) - global_best) <= 1e-9 for r in block))
                rows_topk.append(
                    {
                        "RunID": run_id,
                        "Group": meta.group,
                        "GroupValue": meta.value,
                        "Method": method_name,
                        "K": int(k),
                        "BestJcostInTopK": best_topk,
                        "GlobalBestJcost": global_best,
                        "RegretPct": regret_pct,
                        "HitGlobalBest": hit_best,
                    }
                )

    return rows_topk, rows_top1


def _filter(rows: list[dict], key: str, value: str) -> list[dict]:
    return [r for r in rows if r.get(key) == value]


def save_group_tables(top1_rows: list[dict], topk_rows: list[dict]) -> None:
    _write_csv(ROB_TABLES / "topk_seed_variation.csv", _filter(topk_rows, "Group", "seed_variation"))
    _write_csv(ROB_TABLES / "topk_temporal_granularity.csv", _filter(topk_rows, "Group", "temporal_granularity"))

    _write_csv(ROB_TABLES / "top1_seed_variation.csv", _filter(top1_rows, "Group", "seed_variation"))
    _write_csv(
        ROB_TABLES / "top1_temporal_granularity.csv",
        _filter(top1_rows, "Group", "temporal_granularity"),
    )

    _write_csv(PAR_TABLES / "topk_train_sample_k.csv", _filter(topk_rows, "Group", "train_sample_k"))
    _write_csv(PAR_TABLES / "topk_label_count.csv", _filter(topk_rows, "Group", "label_count"))

    _write_csv(PAR_TABLES / "top1_train_sample_k.csv", _filter(top1_rows, "Group", "train_sample_k"))
    _write_csv(PAR_TABLES / "top1_label_count.csv", _filter(top1_rows, "Group", "label_count"))


def _svg_line_plot(rows: list[dict], out_path: Path, title: str) -> None:
    if not rows:
        return

    width = 920
    height = 560
    left = 80
    right = 30
    top = 60
    bottom = 80
    plot_w = width - left - right
    plot_h = height - top - bottom

    ks = sorted({int(r["K"]) for r in rows})
    yvals = [float(r["RegretPct"]) for r in rows if r.get("RegretPct") is not None]
    ymin = min(0.0, min(yvals))
    ymax = max(yvals)
    if abs(ymax - ymin) < 1e-9:
        ymax = ymin + 1.0

    def x_map(k: int) -> float:
        lx = np_log10(k)
        lx0 = np_log10(min(ks))
        lx1 = np_log10(max(ks))
        if abs(lx1 - lx0) < 1e-9:
            return left
        return left + plot_w * (lx - lx0) / (lx1 - lx0)

    def y_map(v: float) -> float:
        return top + plot_h * (1.0 - (v - ymin) / (ymax - ymin))

    grouped: dict[str, list[dict]] = {}
    for r in rows:
        key = f"{r['Method']} | {r['GroupValue']}"
        grouped.setdefault(key, []).append(r)

    lines: list[str] = []
    lines.append(f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}'>")
    lines.append("<rect width='100%' height='100%' fill='white' />")
    lines.append(f"<text x='{width/2:.1f}' y='28' font-size='18' text-anchor='middle' font-family='Arial'>{title}</text>")

    lines.append(f"<line x1='{left}' y1='{top+plot_h}' x2='{left+plot_w}' y2='{top+plot_h}' stroke='black' />")
    lines.append(f"<line x1='{left}' y1='{top}' x2='{left}' y2='{top+plot_h}' stroke='black' />")

    for k in ks:
        x = x_map(k)
        lines.append(f"<line x1='{x:.1f}' y1='{top+plot_h}' x2='{x:.1f}' y2='{top+plot_h+6}' stroke='black' />")
        lines.append(
            f"<text x='{x:.1f}' y='{top+plot_h+22}' font-size='12' text-anchor='middle' font-family='Arial'>{k}</text>"
        )

    for t in range(6):
        yv = ymin + (ymax - ymin) * t / 5.0
        y = y_map(yv)
        lines.append(f"<line x1='{left-6}' y1='{y:.1f}' x2='{left}' y2='{y:.1f}' stroke='black' />")
        lines.append(
            f"<text x='{left-10}' y='{y+4:.1f}' font-size='12' text-anchor='end' font-family='Arial'>{yv:.2f}</text>"
        )
        lines.append(
            f"<line x1='{left}' y1='{y:.1f}' x2='{left+plot_w}' y2='{y:.1f}' stroke='#dddddd' stroke-dasharray='3,3' />"
        )

    legend_x = left + 10
    legend_y = top + 10
    li = 0
    for label in sorted(grouped.keys()):
        srows = sorted(grouped[label], key=lambda r: int(r["K"]))
        method = srows[0]["Method"]
        method_color_key = [m[2] for m in METHODS if m[0] == method][0]
        color = SVG_COLORS[method_color_key]
        pts = " ".join(f"{x_map(int(r['K'])):.1f},{y_map(float(r['RegretPct'])):.1f}" for r in srows)
        lines.append(f"<polyline points='{pts}' fill='none' stroke='{color}' stroke-width='2' />")
        for r in srows:
            x = x_map(int(r["K"]))
            y = y_map(float(r["RegretPct"]))
            lines.append(f"<circle cx='{x:.1f}' cy='{y:.1f}' r='2.8' fill='{color}' />")

        ly = legend_y + 18 * li
        lines.append(f"<line x1='{legend_x}' y1='{ly}' x2='{legend_x+18}' y2='{ly}' stroke='{color}' stroke-width='2' />")
        lines.append(
            f"<text x='{legend_x+24}' y='{ly+4}' font-size='11' font-family='Arial'>{label}</text>"
        )
        li += 1

    lines.append(
        f"<text x='{left + plot_w/2:.1f}' y='{height-22}' font-size='13' text-anchor='middle' font-family='Arial'>Top-K candidates (log scale)</text>"
    )
    lines.append(
        f"<text transform='translate(20,{top + plot_h/2:.1f}) rotate(-90)' font-size='13' text-anchor='middle' font-family='Arial'>Regret vs global best (%)</text>"
    )
    lines.append("</svg>")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def np_log10(v: int) -> float:
    # Local helper to avoid non-stdlib dependencies.
    import math

    return math.log10(float(v))


def _plot_group(topk_rows: list[dict], group: str, out_path: Path, title: str) -> None:
    subset = [r for r in topk_rows if r["Group"] == group]
    if not subset:
        return
    _svg_line_plot(subset, out_path, title)


def make_plots(topk_rows: list[dict]) -> None:
    _plot_group(
        topk_rows,
        "seed_variation",
        ROB_PLOTS / "topk_regret_seed_variation.svg",
        "Seed Variation Robustness (Jcost)",
    )
    _plot_group(
        topk_rows,
        "temporal_granularity",
        ROB_PLOTS / "topk_regret_temporal_granularity.svg",
        "Temporal Granularity Robustness (Jcost)",
    )
    _plot_group(
        topk_rows,
        "train_sample_k",
        PAR_PLOTS / "topk_regret_train_sample_k.svg",
        "Train Sample Number Sensitivity (Jcost)",
    )
    _plot_group(
        topk_rows,
        "label_count",
        PAR_PLOTS / "topk_regret_label_count.svg",
        "Label Count Sensitivity (Jcost)",
    )


def _pick(rows: list[dict], run: str, method: str, k: int) -> float:
    row = [r for r in rows if r["RunID"] == run and r["Method"] == method and int(r["K"]) == k]
    if not row:
        return float("nan")
    return float(row[0]["RegretPct"])


def _pick_top1(rows: list[dict], run: str, method: str, field: str) -> float:
    row = [r for r in rows if r["RunID"] == run and r["Method"] == method]
    if not row:
        return float("nan")
    return float(row[0][field])


def write_markdown(topk_rows: list[dict], top1_rows: list[dict]) -> None:
    ref_run = "seed_train23_test11_37_dt1p0"
    seed_swap = "seed_train37_test11_23_dt1p0"

    pi_ref_top1 = _pick_top1(top1_rows, ref_run, "PI-SHAP", "Top1Jcost")
    ori_ref_top1 = _pick_top1(top1_rows, ref_run, "Ori-SHAP", "Top1Jcost")
    cond_ref_top1 = _pick_top1(top1_rows, ref_run, "Cond-SHAP", "Top1Jcost")

    pi_minus_ori = (pi_ref_top1 / ori_ref_top1 - 1.0) * 100.0
    pi_minus_cond = (pi_ref_top1 / cond_ref_top1 - 1.0) * 100.0

    seed_pi_k1_ref = _pick(topk_rows, ref_run, "PI-SHAP", 1)
    seed_pi_k1_swap = _pick(topk_rows, seed_swap, "PI-SHAP", 1)
    seed_pi_k20_ref = _pick(topk_rows, ref_run, "PI-SHAP", 20)
    seed_pi_k20_swap = _pick(topk_rows, seed_swap, "PI-SHAP", 20)

    dt05 = "dt0p5_seed11_test23_37"
    dt20 = "dt2p0_seed11_test23_37"
    dt_pi_k1_05 = _pick(topk_rows, dt05, "PI-SHAP", 1)
    dt_pi_k1_20 = _pick(topk_rows, dt20, "PI-SHAP", 1)

    k120 = "k120_seed11_test23_37"
    k240 = "k240_seed11_test23_37"
    ncl2 = "ncl2_seed11_test23_37"
    ncl4 = "ncl4_seed11_test23_37"
    ncl6 = "ncl6_seed11_test23_37"
    ncl8 = "ncl8_seed11_test23_37"

    k_pi_k1_120 = _pick(topk_rows, k120, "PI-SHAP", 1)
    k_pi_k1_240 = _pick(topk_rows, k240, "PI-SHAP", 1)
    ncl_pi_k1_2 = _pick(topk_rows, ncl2, "PI-SHAP", 1)
    ncl_pi_k1_4 = _pick(topk_rows, ncl4, "PI-SHAP", 1)
    ncl_pi_k1_6 = _pick(topk_rows, ncl6, "PI-SHAP", 1)
    ncl_pi_k1_8 = _pick(topk_rows, ncl8, "PI-SHAP", 1)

    robustness_md = f"""# Robustness Validation for Single-Objective Jcst Case

This section validates the robustness of TOP-K screening behavior under seed perturbation and temporal granularity variation for the Jcst single-objective case. The evaluation metric is the top-K regret, defined as $R_K=(J_{{K}}^{{best}}/J^* - 1)\\times 100\\%$, where $J_{{K}}^{{best}}$ is the minimum true Jcst found inside the method-ranked top-K candidate set and $J^*$ is the global minimum true Jcst over all holdout candidates in the same run.

Under the reference split (`seed_train23_test11_37_dt1p0`), PI-SHAP obtains a top-1 Jcst of {pi_ref_top1:.3e}. The top-1 difference is {pi_minus_ori:+.2f}% versus Ori-SHAP ({ori_ref_top1:.3e}) and {pi_minus_cond:+.2f}% versus Cond-SHAP ({cond_ref_top1:.3e}); negative values indicate PI-SHAP is better. In this run, Cond-SHAP provides the best top-1 retrieval, while PI-SHAP and Ori-SHAP are almost tied. When train/test seeds are swapped, PI-SHAP top-1 regret changes from {seed_pi_k1_ref:.2f}% to {seed_pi_k1_swap:.2f}%, while top-20 regret changes from {seed_pi_k20_ref:.2f}% to {seed_pi_k20_swap:.2f}%.

Temporal-granularity stress tests show non-uniform behavior: at `dt=0.5h` and `dt=2.0h`, PI-SHAP top-1 regrets are {dt_pi_k1_05:.2f}% and {dt_pi_k1_20:.2f}%, respectively. The K-growth curves in `robustness_validation/plots` show monotone regret decay with K for all methods, but the best method at low-K depends on the run condition.

Key data sources are exported in `robustness_validation/tables/topk_seed_variation.csv`, `robustness_validation/tables/topk_temporal_granularity.csv`, `robustness_validation/tables/top1_seed_variation.csv`, and `robustness_validation/tables/top1_temporal_granularity.csv`.
"""

    parameter_md = f"""# Parameter Analysis for Single-Objective Jcst Case

This section reports sensitivity to (i) train sample number $k$ and (ii) class label count $N_{{cl}}$, again measured by top-K regret on true Jcst. For train sub-sampling, PI-SHAP top-1 regret is {k_pi_k1_120:.2f}% at `k=120` and {k_pi_k1_240:.2f}% at `k=240`, showing the practical effect size of train-set reduction under the current protocol.

For label cardinality, PI-SHAP top-1 regret is {ncl_pi_k1_2:.2f}% (`Ncl=2`), {ncl_pi_k1_4:.2f}% (`Ncl=4`), {ncl_pi_k1_6:.2f}% (`Ncl=6`), and {ncl_pi_k1_8:.2f}% (`Ncl=8`). This indicates a non-monotonic sensitivity to class granularity in the current split, rather than a strictly linear trend. Across both parameter sweeps, regret decreases with larger K for all methods, and Cond-SHAP generally shows the strongest low-K retrieval in this dataset.

The complete numeric outputs are provided in `parameter_analysis/tables/topk_train_sample_k.csv`, `parameter_analysis/tables/topk_label_count.csv`, `parameter_analysis/tables/top1_train_sample_k.csv`, and `parameter_analysis/tables/top1_label_count.csv`, with corresponding figures in `parameter_analysis/plots`.
"""

    (ROOT / "robustness_validation" / "ROBUSTNESS_VALIDATION_EN.md").write_text(robustness_md, encoding="utf-8")
    (ROOT / "parameter_analysis" / "PARAMETER_ANALYSIS_EN.md").write_text(parameter_md, encoding="utf-8")


def write_manifest(run_data: dict[str, list[dict[str, str]]]) -> None:
    rows = []
    for run_id, rrows in sorted(run_data.items()):
        meta = classify_run(run_id)
        dt_vals = sorted({_to_float(r["DatasetDtHr"]) for r in rrows})
        rows.append(
            {
                "RunID": run_id,
                "Group": meta.group,
                "GroupValue": meta.value,
                "Note": meta.note,
                "Rows": int(len(rrows)),
                "DatasetDtHr_unique": ";".join(f"{v:g}" for v in dt_vals),
            }
        )

    _write_csv(ROOT / "run_manifest.csv", rows)


def main() -> None:
    ensure_dirs()
    run_data = load_runs()
    if not run_data:
        raise SystemExit("No run tables found under runs/*/tables/holdout_case_scores.csv")

    write_manifest(run_data)
    topk_rows, top1_rows = build_topk_tables(run_data)

    topk_rows.sort(key=lambda r: (r["Group"], r["RunID"], r["Method"], int(r["K"])))
    top1_rows.sort(key=lambda r: (r["Group"], r["RunID"], r["Method"]))

    _write_csv(ROOT / "topk_all_runs.csv", topk_rows)
    _write_csv(ROOT / "top1_all_runs.csv", top1_rows)

    save_group_tables(top1_rows, topk_rows)
    make_plots(topk_rows)
    write_markdown(topk_rows, top1_rows)

    print("Generated tables/plots/markdown under single_objective_cst_case.")


if __name__ == "__main__":
    main()
