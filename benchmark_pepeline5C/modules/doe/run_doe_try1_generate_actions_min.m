function out = run_doe_try1_generate_actions_min()
addpath('shap_src_min');

cfg = struct();
cfg.try_name = 'try1';
cfg.seeds = [11 23 37];
cfg.dt_list = [0.5 1.0 1.5 2.0];
cfg.n_comp = 5;
cfg.c_min = 1.0;
cfg.c_max = 1.6;
cfg.delta_cap_per_hour = 0.08;
cfg.show_per_dt = 24;

root_dir = fullfile('shap_src_min', 'doe', cfg.try_name);
ensure_dir_min(root_dir);
reset_dir_contents_min(root_dir, { ...
    'doe_try1_sim_config_min.m', ...
    'run_doe_try1_sim_batch_min.m', ...
    'reconstruct_case_from_saved_min.m', ...
    'run_doe_try1_preflight_test_min.m', ...
    'replot_try1_overview_all_seeds_min.m', ...
    'plot_try1_summary_stats_min.m', ...
    'DOE_TRY1_SIM_PLAN.md', ...
    'DOE_TRY1_SAVED_VARIABLES.md', ...
    'sim_outputs'});

ss_ref = load_ss_reference_min();
cc_start = ss_ref.cc_start(1:cfg.n_comp);
cc_end = ss_ref.cc_end(1:cfg.n_comp);

meta_rows = repmat(struct( ...
    'Seed', nan, 'ActionDt_hr', nan, 'NActions', nan, ...
    'NSelectedPoints', nan, 'NFreeSelectedPoints', nan, ...
    'NVar', nan, 'NSamples', nan, ...
    'MaxP95IncPerHour', nan, 'MedianP95IncPerHour', nan, 'MinP95IncPerHour', nan), 0, 1);

for si = 1:numel(cfg.seeds)
    seed = cfg.seeds(si);
    seed_dir = fullfile(root_dir, sprintf('seed_%03d', seed));
    ensure_dir_min(seed_dir);

    seed_plot_data = cell(numel(cfg.dt_list), 1);

    for di = 1:numel(cfg.dt_list)
        dt_hr = cfg.dt_list(di);
        [dataset_info, plot_info] = build_one_dataset_min(seed, dt_hr, cfg, cc_start, cc_end, seed_dir);
        seed_plot_data{di} = plot_info;

        r = struct();
        r.Seed = seed;
        r.ActionDt_hr = dt_hr;
        r.NActions = dataset_info.n_actions;
        r.NSelectedPoints = dataset_info.n_selected;
        r.NFreeSelectedPoints = dataset_info.n_free;
        r.NVar = dataset_info.n_var;
        r.NSamples = dataset_info.n_samples;
        r.MaxP95IncPerHour = dataset_info.max_p95_inc_per_h;
        r.MedianP95IncPerHour = dataset_info.median_p95_inc_per_h;
        r.MinP95IncPerHour = dataset_info.min_p95_inc_per_h;
        meta_rows(end+1,1) = r; %#ok<AGROW>
    end

    plot_seed_overview_min(seed_plot_data, seed_dir, seed);
    write_seed_summary_md_min(seed_dir, seed, seed_plot_data);
end

plot_all_seeds_overview_min(root_dir, cfg);

meta_tbl = struct2table(meta_rows);
meta_tbl = sortrows(meta_tbl, {'Seed', 'ActionDt_hr'});
writetable(meta_tbl, fullfile(root_dir, 'try1_dataset_index.csv'));

write_try_summary_md_min(root_dir, cfg, ss_ref, meta_tbl);

out = struct();
out.root_dir = root_dir;
out.meta_tbl = meta_tbl;

disp(meta_tbl);
fprintf('Generated action-only DOE try at: %s\n', root_dir);
end

function [dataset_info, plot_info] = build_one_dataset_min(seed, dt_hr, cfg, cc_start, cc_end, seed_dir)
n_actions = round(24 / dt_hr) + 1;
t_hr = linspace(0, 24, n_actions)';

sel_idx = 1:2:n_actions;
if sel_idx(end) ~= n_actions
    sel_idx(end+1) = n_actions;
end
sel_idx = unique(sel_idx, 'stable');
sel_t = t_hr(sel_idx);

free_idx = sel_idx(2:end-1);
n_free = numel(free_idx);
n_var = n_free * cfg.n_comp;
n_samples = 10 * n_var;

dt_tag = dt_tag_min(dt_hr);
ds_dir = fullfile(seed_dir, ['dataset_dt_' dt_tag]);
ensure_dir_min(ds_dir);

fprintf('seed=%d dt=%.2fh n_var=%d n_samples=%d\n', seed, dt_hr, n_var, n_samples);

rng(seed * 1000 + round(dt_hr * 100), 'twister');
inc_abs_per_h_u = lhsdesign(n_samples, n_var) * cfg.delta_cap_per_hour;
inc_sign_u = lhsdesign(n_samples, n_var);
inc_signed_per_h_u = (2 * (inc_sign_u >= 0.5) - 1) .* inc_abs_per_h_u;

cc_samples = zeros(n_actions, cfg.n_comp, n_samples);
max_inc_no_h = nan(n_samples, 1);
p95_inc_no_h = nan(n_samples, 1);
median_inc_no_h = nan(n_samples, 1);
mean_inc_no_h = nan(n_samples, 1);
mean_signed_inc_no_h = nan(n_samples, 1);
pos_inc_rate_no_h = nan(n_samples, 1);
max_inc_term_h = nan(n_samples, 1);
boundary_hit_rate = nan(n_samples, 1);

for s = 1:n_samples
    u_signed_per_h = reshape(inc_signed_per_h_u(s, :), [n_free, cfg.n_comp]);

    sel_vals = zeros(numel(sel_idx), cfg.n_comp);
    sel_vals(1, :) = cc_start;

    for k = 2:(numel(sel_idx)-1)
        prev = sel_vals(k-1, :);
        dth = sel_t(k) - sel_t(k-1);
        cap = cfg.delta_cap_per_hour * dth;

        dc = u_signed_per_h(k-1, :) * dth;

        cand = prev + dc;
        out_bound = cand < cfg.c_min | cand > cfg.c_max;
        cand(out_bound) = prev(out_bound);

        rem_cap = cfg.delta_cap_per_hour * (sel_t(end) - sel_t(k));
        lo = max([cfg.c_min * ones(1, cfg.n_comp); prev - cap; cc_end - rem_cap], [], 1);
        hi = min([cfg.c_max * ones(1, cfg.n_comp); prev + cap; cc_end + rem_cap], [], 1);
        bad = lo > (hi + 1e-12);
        if any(bad)
            mid = 0.5 * (lo + hi);
            lo(bad) = mid(bad);
            hi(bad) = mid(bad);
        end
        cand = min(max(cand, lo), hi);
        sel_vals(k, :) = cand;
    end
    sel_vals(end, :) = cc_end;

    cc = zeros(n_actions, cfg.n_comp);
    for j = 1:cfg.n_comp
        y = interp1(sel_t, sel_vals(:, j), t_hr, 'linear');
        y = min(max(y, cfg.c_min), cfg.c_max);
        y(1) = cc_start(j);
        y(end) = cc_end(j);
        cc(:, j) = y;
    end

    cc_samples(:, :, s) = cc;

    d = diff(cc, 1, 1);
    d_no = d;
    if size(d_no, 1) >= 2
        d_no = d_no(1:end-1, :);
    else
        d_no = zeros(0, cfg.n_comp);
    end

    if isempty(d_no)
        max_inc_no_h(s) = nan;
        p95_inc_no_h(s) = nan;
        mean_inc_no_h(s) = nan;
    else
        x = abs(d_no(:)) / dt_hr;
        sx = d_no(:) / dt_hr;
        max_inc_no_h(s) = max(x);
        p95_inc_no_h(s) = prctile(x, 95);
        median_inc_no_h(s) = median(x);
        mean_inc_no_h(s) = mean(x);
        mean_signed_inc_no_h(s) = mean(sx);
        pos_inc_rate_no_h(s) = mean(sx > 0);
    end

    max_inc_term_h(s) = max(abs(d(end, :)) / dt_hr);
    boundary_hit_rate(s) = mean(abs(cc(:) - cfg.c_min) < 1e-9 | abs(cc(:) - cfg.c_max) < 1e-9);
end

mean_cc = squeeze(mean(cc_samples, 2));

sample_tbl = table((1:n_samples)', max_inc_no_h, p95_inc_no_h, median_inc_no_h, mean_inc_no_h, mean_signed_inc_no_h, pos_inc_rate_no_h, max_inc_term_h, boundary_hit_rate, ...
    'VariableNames', {'SampleID', 'MaxAbsIncNoTerminalPerHour', 'P95AbsIncNoTerminalPerHour', 'MedianAbsIncNoTerminalPerHour', 'MeanAbsIncNoTerminalPerHour', 'MeanSignedIncNoTerminalPerHour', 'PositiveIncRateNoTerminal', 'MaxAbsIncTerminalPerHour', 'BoundaryHitRate'});
writetable(sample_tbl, fullfile(ds_dir, 'sample_stats.csv'));

writematrix(inc_abs_per_h_u, fullfile(ds_dir, 'lhs_design.csv'));
writematrix(inc_signed_per_h_u, fullfile(ds_dir, 'increment_signed_per_hour_design.csv'));
save(fullfile(ds_dir, 'actions.mat'), ...
    'seed', 'dt_hr', 'n_actions', 't_hr', 'sel_idx', 'free_idx', ...
    'inc_abs_per_h_u', 'inc_sign_u', 'inc_signed_per_h_u', 'cc_samples', 'mean_cc', 'sample_tbl', ...
    'cc_start', 'cc_end', '-v7.3');

write_dataset_md_min(ds_dir, seed, dt_hr, n_actions, numel(sel_idx), n_free, n_var, n_samples, cfg.delta_cap_per_hour, sample_tbl);

q10_cc = prctile(cc_samples, 10, 3);
q90_cc = prctile(cc_samples, 90, 3);
mean_cc_curve = mean(cc_samples, 3);

show_n = min(cfg.show_per_dt, n_samples);
pick = randperm(n_samples, show_n);
pick_cc = cc_samples(:, :, pick);

mean_samples = squeeze(mean(cc_samples, 2));
if isvector(mean_samples)
    mean_samples = mean_samples(:);
end
q10_mean = prctile(mean_samples, 10, 2);
q90_mean = prctile(mean_samples, 90, 2);
mean_mean = mean(mean_samples, 2);

pick_mean = squeeze(mean(pick_cc, 2));
if isvector(pick_mean)
    pick_mean = pick_mean(:);
end

dataset_info = struct();
dataset_info.n_actions = n_actions;
dataset_info.n_selected = numel(sel_idx);
dataset_info.n_free = n_free;
dataset_info.n_var = n_var;
dataset_info.n_samples = n_samples;
dataset_info.max_p95_inc_per_h = max(p95_inc_no_h);
dataset_info.median_p95_inc_per_h = median(p95_inc_no_h);
dataset_info.min_p95_inc_per_h = min(p95_inc_no_h);

plot_info = struct();
plot_info.dt_hr = dt_hr;
plot_info.t_hr = t_hr;
plot_info.n_comp = cfg.n_comp;
plot_info.pick_cc = pick_cc;
plot_info.pick_mean = pick_mean;
plot_info.mean_cc_curve = mean_cc_curve;
plot_info.q10_cc = q10_cc;
plot_info.q90_cc = q90_cc;
plot_info.mean_mean = mean_mean;
plot_info.q10_mean = q10_mean;
plot_info.q90_mean = q90_mean;
plot_info.n_samples = n_samples;
plot_info.n_show = show_n;
end

function plot_seed_overview_min(seed_plot_data, seed_dir, seed)
nrow = numel(seed_plot_data);
ncol = 6;
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [30 30 2450 max(920, 360 * nrow)]);
tiledlayout(nrow, ncol, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(seed_plot_data)
    d = seed_plot_data{i};
    for j = 1:6
        ax = nexttile((i-1) * 6 + j);
        hold on;

        if j <= d.n_comp
            rand_mat = squeeze(d.pick_cc(:, j, :));
            if isvector(rand_mat)
                rand_mat = rand_mat(:);
            end
            q10 = d.q10_cc(:, j);
            q90 = d.q90_cc(:, j);
            y_mean = d.mean_cc_curve(:, j);
            ylab = sprintf('cc_%d', j);
            ttl = sprintf('dt=%.2fh | cc_%d', d.dt_hr, j);
        else
            rand_mat = d.pick_mean;
            if isvector(rand_mat)
                rand_mat = rand_mat(:);
            end
            q10 = d.q10_mean;
            q90 = d.q90_mean;
            y_mean = d.mean_mean;
            ylab = 'mean(cc)';
            ttl = sprintf('dt=%.2fh | mean', d.dt_hr);
        end

        h_rand = gobjects(1, 1);
        for k = 1:size(rand_mat, 2)
            if k == 1
                h_rand = plot(d.t_hr, rand_mat(:, k), '-', 'Color', [0.62 0.72 0.92], 'LineWidth', 0.8);
            else
                plot(d.t_hr, rand_mat(:, k), '-', 'Color', [0.62 0.72 0.92], 'LineWidth', 0.8, 'HandleVisibility', 'off');
            end
        end
        h10 = plot(d.t_hr, q10, '--', 'Color', [0.05 0.35 0.75], 'LineWidth', 1.2);
        h90 = plot(d.t_hr, q90, '--', 'Color', [0.05 0.35 0.75], 'LineWidth', 1.2);
        h_mean = plot(d.t_hr, y_mean, '-', 'Color', [0.82 0.12 0.08], 'LineWidth', 1.8);

        xlabel('Time (h)');
        ylabel(ylab);
        title(ttl);
        xlim([0 24.2]);
        ylim([1.0 1.6]);
        grid on;
        set(ax, 'FontSize', 9, 'LineWidth', 0.9);

        if i == 1 && j == 1
            legend([h_rand h_mean h10 h90], {'random samples', 'mean', 'q10 contour', 'q90 contour'}, 'Location', 'best');
        end
    end
end

sgtitle(sprintf('DOE try1 seed %03d overview (%dx%d: dt rows, cc1..cc5 + mean cols)', seed, nrow, ncol), ...
    'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(f, fullfile(seed_dir, sprintf('seed_%03d_overview_6x%d.png', seed, nrow)), 'Resolution', 230, 'BackgroundColor', 'white');
close(f);
end

function plot_all_seeds_overview_min(root_dir, cfg)
n_seed = numel(cfg.seeds);
all_plot_data = cell(numel(cfg.dt_list), 1);

for di = 1:numel(cfg.dt_list)
    dt_hr = cfg.dt_list(di);
    dt_tag = dt_tag_min(dt_hr);

    t_ref = [];

    q10_cc = [];
    q90_cc = [];
    mean_cc_curve = [];
    q10_mean = [];
    q90_mean = [];
    mean_mean = [];

    for si = 1:numel(cfg.seeds)
        seed = cfg.seeds(si);
        fp = fullfile(root_dir, sprintf('seed_%03d', seed), ['dataset_dt_' dt_tag], 'actions.mat');
        S = load(fp, 'cc_samples', 't_hr');

        if isempty(t_ref)
            t_ref = S.t_hr;
        elseif numel(t_ref) ~= numel(S.t_hr)
            error('Inconsistent t_hr length in pooled overview for dt=%.2f.', dt_hr);
        end

        cc_seed = S.cc_samples;
        q10_cc(:, :, si) = prctile(cc_seed, 10, 3); %#ok<AGROW>
        q90_cc(:, :, si) = prctile(cc_seed, 90, 3); %#ok<AGROW>
        mean_cc_curve(:, :, si) = mean(cc_seed, 3); %#ok<AGROW>

        mean_samples = squeeze(mean(cc_seed, 2));
        if isvector(mean_samples)
            mean_samples = mean_samples(:);
        end
        q10_mean(:, si) = prctile(mean_samples, 10, 2); %#ok<AGROW>
        q90_mean(:, si) = prctile(mean_samples, 90, 2); %#ok<AGROW>
        mean_mean(:, si) = mean(mean_samples, 2); %#ok<AGROW>
    end

    d = struct();
    d.dt_hr = dt_hr;
    d.t_hr = t_ref;
    d.n_comp = cfg.n_comp;
    d.n_seed = n_seed;
    d.seeds = cfg.seeds;
    d.mean_cc_curve = mean_cc_curve;
    d.q10_cc = q10_cc;
    d.q90_cc = q90_cc;
    d.mean_mean = mean_mean;
    d.q10_mean = q10_mean;
    d.q90_mean = q90_mean;

    all_plot_data{di} = d;
end

mean_palette = [
    0.85 0.10 0.10;
    0.08 0.62 0.12;
    0.10 0.10 0.10;
    0.18 0.55 0.20;
    0.60 0.28 0.02];
band_palette = [
    0.05 0.35 0.85;
    0.00 0.62 0.62;
    0.46 0.16 0.78;
    0.00 0.40 0.42;
    0.12 0.18 0.36];
if n_seed <= size(mean_palette, 1)
    mean_cols = mean_palette(1:n_seed, :);
    band_cols = band_palette(1:n_seed, :);
else
    mean_cols = lines(n_seed);
    band_cols = 0.55 * mean_cols + 0.45 * [0 0.2 0.7];
end

nrow = numel(all_plot_data);
ncol = 6;
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [30 30 2450 max(920, 360 * nrow)]);
tiledlayout(nrow, ncol, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(all_plot_data)
    d = all_plot_data{i};
    for j = 1:6
        ax = nexttile((i-1) * 6 + j);
        hold on;

        if j <= d.n_comp
            ylab = sprintf('cc_%d', j);
            ttl = sprintf('dt=%.2fh | cc_%d', d.dt_hr, j);
        else
            ylab = 'mean(cc)';
            ttl = sprintf('dt=%.2fh | mean', d.dt_hr);
        end

        h_leg = gobjects(2 * d.n_seed, 1);
        leg_txt = cell(2 * d.n_seed, 1);
        for si = 1:d.n_seed
            if j <= d.n_comp
                q10 = d.q10_cc(:, j, si);
                q90 = d.q90_cc(:, j, si);
                y_mean = d.mean_cc_curve(:, j, si);
            else
                q10 = d.q10_mean(:, si);
                q90 = d.q90_mean(:, si);
                y_mean = d.mean_mean(:, si);
            end

            h10 = plot(d.t_hr, q10, '--', 'Color', band_cols(si, :), 'LineWidth', 1.1);
            plot(d.t_hr, q90, '--', 'Color', band_cols(si, :), 'LineWidth', 1.1, 'HandleVisibility', 'off');
            h_mean = plot(d.t_hr, y_mean, '-', 'Color', mean_cols(si, :), 'LineWidth', 1.7);

            if i == 1 && j == 1
                h_leg(2*si - 1) = h_mean;
                h_leg(2*si) = h10;
                leg_txt{2*si - 1} = sprintf('seed%03d mean', d.seeds(si));
                leg_txt{2*si} = sprintf('seed%03d q10/q90', d.seeds(si));
            end
        end

        xlabel('Time (h)');
        ylabel(ylab);
        title(ttl);
        xlim([0 24.2]);
        ylim([1.0 1.6]);
        grid on;
        set(ax, 'FontSize', 9, 'LineWidth', 0.9);

        if i == 1 && j == 1
            legend(h_leg, leg_txt, 'Location', 'best');
        end
    end
end

sgtitle(sprintf('DOE try1 seed-comparison overview across seeds %s (%dx%d)', mat2str(cfg.seeds), nrow, ncol), ...
    'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(f, fullfile(root_dir, sprintf('try1_overview_all_seeds_6x%d.png', nrow)), 'Resolution', 230, 'BackgroundColor', 'white');
close(f);
end

function write_dataset_md_min(ds_dir, seed, dt_hr, n_actions, n_selected, n_free, n_var, n_samples, delta_cap_per_hour, sample_tbl)
md = fullfile(ds_dir, 'DATASET.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write dataset markdown: %s', md);
end

fprintf(fid, '# try1 dataset summary\n\n');
fprintf(fid, '- seed: `%d`\n', seed);
fprintf(fid, '- dt: `%.2f h`\n', dt_hr);
fprintf(fid, '- action points per day: `%d`\n', n_actions);
fprintf(fid, '- selected points (step=2): `%d`\n', n_selected);
fprintf(fid, '- free selected points: `%d`\n', n_free);
fprintf(fid, '- variable count (`Nvar`): `%d`\n', n_var);
fprintf(fid, '- sample count (`10*Nvar`): `%d`\n', n_samples);
fprintf(fid, '- bounds: `cc in [1.0, 1.6]`\n');
fprintf(fid, '- incremental cap per hour: `|Delta c|/h <= %.4f`\n', delta_cap_per_hour);
fprintf(fid, '- terminal point is fixed to unified SS end.\n\n');

fprintf(fid, '## Sample statistics\n\n');
fprintf(fid, '- increment design variable in `lhs_design.csv`: `|Delta c|/h in [0, %.4f]`\n', delta_cap_per_hour);
fprintf(fid, '- median P95 |Delta c|/h (NoTerminal): `%.6f`\n', median(sample_tbl.P95AbsIncNoTerminalPerHour));
fprintf(fid, '- max P95 |Delta c|/h (NoTerminal): `%.6f`\n', max(sample_tbl.P95AbsIncNoTerminalPerHour));
fprintf(fid, '- median Median |Delta c|/h (NoTerminal): `%.6f`\n', median(sample_tbl.MedianAbsIncNoTerminalPerHour));
fprintf(fid, '- median positive-inc rate (NoTerminal): `%.6f`\n', median(sample_tbl.PositiveIncRateNoTerminal));
fprintf(fid, '- median boundary-hit rate: `%.6f`\n\n', median(sample_tbl.BoundaryHitRate));

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `lhs_design.csv`\n');
fprintf(fid, '- `increment_signed_per_hour_design.csv`\n');
fprintf(fid, '- `sample_stats.csv`\n');
fprintf(fid, '- `actions.mat`\n');

fclose(fid);
end

function write_seed_summary_md_min(seed_dir, seed, seed_plot_data)
md = fullfile(seed_dir, sprintf('seed_%03d_summary.md', seed));
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write seed summary markdown.');
end

fprintf(fid, '# seed %03d summary\n\n', seed);
nrow = numel(seed_plot_data);
fprintf(fid, '- This seed contains %d datasets.\n', nrow);
fprintf(fid, '- Overview plot: `seed_%03d_overview_6x%d.png` (%d rows x 6 columns).\n', seed, nrow, nrow);
fprintf(fid, '- Row mapping: dt schemes; column mapping: `cc_1..cc_5` and `mean(cc)`.\n');
fprintf(fid, '- Plot uses random sampled trajectories (light blue) + mean (red solid) + q10/q90 contour (blue dashed).\n');
fprintf(fid, '- This stage is action-sampling only, no transient simulation.\n\n');

fprintf(fid, '| dt(h) | samples used in stats |\n');
fprintf(fid, '|---:|---:|\n');
for i = 1:numel(seed_plot_data)
    d = seed_plot_data{i};
    fprintf(fid, '| %.2f | %d |\n', d.dt_hr, d.n_samples);
end

fclose(fid);
end

function write_try_summary_md_min(root_dir, cfg, ss_ref, meta_tbl)
md = fullfile(root_dir, 'TRY1_SUMMARY.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write TRY1 summary markdown.');
end

fprintf(fid, '# DOE try1 action sampling summary\n\n');
fprintf(fid, '- stage: action sampling only (no simulation)\n');
fprintf(fid, '- seeds: `%s`\n', mat2str(cfg.seeds));
fprintf(fid, '- dt schemes: `%s` h\n', mat2str(cfg.dt_list));
fprintf(fid, '- bounds: `cc in [%.1f, %.1f]`\n', cfg.c_min, cfg.c_max);
fprintf(fid, '- incremental cap per hour: `|Delta c|/h <= %.4f`\n', cfg.delta_cap_per_hour);
fprintf(fid, '- increment design variable: `|Delta c|/h in [0, %.4f]` with sampled sign\n', cfg.delta_cap_per_hour);
fprintf(fid, '- selected-point rule: every other action point (`step=2`)\n');
fprintf(fid, '- bound handling: if sampled increment crosses bound, keep previous value\n');
fprintf(fid, '- endpoint source: `%s`\n\n', ss_ref.source);

fprintf(fid, '## Dataset index\n\n');
fprintf(fid, '| seed | dt(h) | Nvar | Nsamp | median P95 |Delta c|/h | max P95 |Delta c|/h |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(meta_tbl)
    fprintf(fid, '| %d | %.2f | %d | %d | %.6f | %.6f |\n', ...
        meta_tbl.Seed(i), meta_tbl.ActionDt_hr(i), meta_tbl.NVar(i), meta_tbl.NSamples(i), ...
        meta_tbl.MedianP95IncPerHour(i), meta_tbl.MaxP95IncPerHour(i));
end

fprintf(fid, '\nTotal sampled action trajectories: `%d`\n\n', sum(meta_tbl.NSamples));

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `try1_dataset_index.csv`\n');
fprintf(fid, '- `seed_*/seed_*_overview_6x*.png`\n');
fprintf(fid, '- `try1_overview_all_seeds_6x*.png` (seed comparison: no light-blue random lines)\n');
fprintf(fid, '- `seed_*/dataset_dt_*/{lhs_design.csv,increment_signed_per_hour_design.csv,sample_stats.csv,actions.mat,DATASET.md}`\n');
fprintf(fid, '- `doe_try1_sim_config_min.m`\n');
fprintf(fid, '- `run_doe_try1_sim_batch_min.m`\n');
fprintf(fid, '- `reconstruct_case_from_saved_min.m`\n');
fprintf(fid, '- `run_doe_try1_preflight_test_min.m`\n');
fprintf(fid, '- `replot_try1_overview_all_seeds_min.m`\n');
fprintf(fid, '- `DOE_TRY1_SIM_PLAN.md`\n');
fprintf(fid, '- `DOE_TRY1_SAVED_VARIABLES.md`\n');

fclose(fid);
end

function s = dt_tag_min(dt_hr)
s = strrep(sprintf('%.1f', dt_hr), '.', 'p');
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_min(path_str, preserve_names)
if nargin < 2 || isempty(preserve_names)
    preserve_names = {};
end

if exist(path_str, 'dir') ~= 7
    return;
end

items = dir(path_str);
for i = 1:numel(items)
    name = items(i).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue;
    end
    if any(strcmp(name, preserve_names))
        continue;
    end
    fp = fullfile(path_str, name);
    if items(i).isdir
        rmdir(fp, 's');
    else
        delete(fp);
    end
end
end
