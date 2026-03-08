function out = run_doe_1h_pilot_confirm_min()
addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath('shap_src_min/sim');

out_dir = fullfile('shap_src_min', 'doe', 'pilot_1h_confirm');
plot_dir = fullfile(out_dir, 'plots');

ensure_dir_min(out_dir);
reset_dir_contents_min(out_dir);
ensure_dir_min(plot_dir);

dt_hr = 1.0;
n_actions = round(24 / dt_hr) + 1;
comp_count = 5;

c_min = 1.0;
c_max = 1.6;

delta_caps = [0.10 0.15 0.20 0.25 0.30];
n_rep = 12;

S = load(fullfile('shap_src', 'res_baseline.mat'), 'par_tropt');
par_base = S.par_tropt;
ss_ref = load_ss_reference_min();

par_base.ss_start = ss_ref.ss_start;
par_base.ss_terminal = ss_ref.ss_terminal;
par_base.tr.ss_start = ss_ref.ss_start;
par_base.tr.ss_terminal = ss_ref.ss_terminal;

sim_cfg = default_sim_cfg_min();

single_seed = 260226;
single_cap = 0.20;
[cc_one, one_meta] = build_incremental_sample_min(ss_ref.cc_start, n_actions, comp_count, c_min, c_max, single_cap, dt_hr, single_seed);
[sim_one, sim_sec_one] = run_transient_eval_min(par_base, cc_one, sim_cfg);

one_tbl = table(single_seed, single_cap, sim_sec_one, one_meta.max_step, one_meta.boundary_hit_rate, ...
    sim_one.Jcost, sim_one.Jsupp, sim_one.Jvar, ...
    'VariableNames', {'Seed', 'DeltaCapPerHour', 'SimSec', 'MaxStep', 'BoundaryHitRate', 'Jcost', 'Jsupp', 'Jvar'});
writetable(one_tbl, fullfile(out_dir, 'single_sample_summary.csv'));
writematrix(cc_one, fullfile(out_dir, 'single_sample_cc_profile.csv'));

plot_single_profile_min(cc_one, plot_dir);

n_total = numel(delta_caps) * n_rep;
sample_seed = nan(n_total, 1);
sample_cap = nan(n_total, 1);
sample_id = nan(n_total, 1);
sample_sim_sec = nan(n_total, 1);
sample_max_step = nan(n_total, 1);
sample_boundary_hit = nan(n_total, 1);
sample_traj_std = nan(n_total, 1);
sample_jcost = nan(n_total, 1);
sample_jsupp = nan(n_total, 1);
sample_jvar = nan(n_total, 1);
sample_ok = false(n_total, 1);

row = 0;
for i = 1:numel(delta_caps)
    cap = delta_caps(i);
    for r = 1:n_rep
        row = row + 1;
        seed = 1000 * i + r;

        [cc, meta] = build_incremental_sample_min(ss_ref.cc_start, n_actions, comp_count, c_min, c_max, cap, dt_hr, seed);
        [sim_eval, sim_sec] = run_transient_eval_min(par_base, cc, sim_cfg);

        sample_seed(row) = seed;
        sample_cap(row) = cap;
        sample_id(row) = r;
        sample_sim_sec(row) = sim_sec;
        sample_max_step(row) = meta.max_step;
        sample_boundary_hit(row) = meta.boundary_hit_rate;
        sample_traj_std(row) = mean(std(cc, 0, 1));
        sample_jcost(row) = sim_eval.Jcost;
        sample_jsupp(row) = sim_eval.Jsupp;
        sample_jvar(row) = sim_eval.Jvar;
        sample_ok(row) = sim_eval.ok;
    end
end

sample_tbl = table(sample_seed, sample_cap, sample_id, sample_ok, sample_sim_sec, sample_max_step, sample_boundary_hit, sample_traj_std, ...
    sample_jcost, sample_jsupp, sample_jvar, ...
    'VariableNames', {'Seed', 'DeltaCapPerHour', 'SampleID', 'OK', 'SimSec', 'MaxStep', 'BoundaryHitRate', 'TrajectoryStd', 'Jcost', 'Jsupp', 'Jvar'});
writetable(sample_tbl, fullfile(out_dir, 'delta_cap_samples.csv'));

summary_cap = table();
summary_cap.DeltaCapPerHour = delta_caps(:);
summary_cap.SuccessRate = nan(numel(delta_caps), 1);
summary_cap.MeanSimSec = nan(numel(delta_caps), 1);
summary_cap.MedianJcost = nan(numel(delta_caps), 1);
summary_cap.MedianJsupp = nan(numel(delta_caps), 1);
summary_cap.MedianJvar = nan(numel(delta_caps), 1);
summary_cap.MeanMaxStep = nan(numel(delta_caps), 1);
summary_cap.P95MaxStep = nan(numel(delta_caps), 1);
summary_cap.MeanBoundaryHitRate = nan(numel(delta_caps), 1);
summary_cap.MeanTrajectoryStd = nan(numel(delta_caps), 1);

for i = 1:numel(delta_caps)
    cap = delta_caps(i);
    idx = sample_tbl.DeltaCapPerHour == cap;
    ok_idx = idx & sample_tbl.OK;

    summary_cap.SuccessRate(i) = mean(sample_tbl.OK(idx));
    summary_cap.MeanSimSec(i) = mean(sample_tbl.SimSec(ok_idx));
    summary_cap.MedianJcost(i) = median(sample_tbl.Jcost(ok_idx));
    summary_cap.MedianJsupp(i) = median(sample_tbl.Jsupp(ok_idx));
    summary_cap.MedianJvar(i) = median(sample_tbl.Jvar(ok_idx));
    summary_cap.MeanMaxStep(i) = mean(sample_tbl.MaxStep(idx));
    summary_cap.P95MaxStep(i) = prctile(sample_tbl.MaxStep(idx), 95);
    summary_cap.MeanBoundaryHitRate(i) = mean(sample_tbl.BoundaryHitRate(idx));
    summary_cap.MeanTrajectoryStd(i) = mean(sample_tbl.TrajectoryStd(idx));
end

step_n = normalize_safe_min(summary_cap.MeanMaxStep);
hit_n = normalize_safe_min(summary_cap.MeanBoundaryHitRate);
std_n = normalize_safe_min(summary_cap.MeanTrajectoryStd);

summary_cap.CompositeScore = 0.45 * step_n + 0.35 * hit_n + 0.20 * (1 - std_n);

[~, best_idx] = min(summary_cap.CompositeScore);
recommended_cap = summary_cap.DeltaCapPerHour(best_idx);

summary_cap.IsRecommended = false(height(summary_cap), 1);
summary_cap.IsRecommended(best_idx) = true;

writetable(summary_cap, fullfile(out_dir, 'delta_cap_summary.csv'));

plot_delta_cap_summary_min(summary_cap, plot_dir);

write_pilot_md_min(out_dir, one_tbl, summary_cap, recommended_cap, c_min, c_max, dt_hr, n_actions, n_rep);

out = struct();
out.out_dir = out_dir;
out.plot_dir = plot_dir;
out.recommended_cap = recommended_cap;
out.single_sample_sec = sim_sec_one;
out.summary_cap = summary_cap;
out.single_sample = one_tbl;

disp(one_tbl);
disp(summary_cap);
fprintf('Recommended delta cap per hour (1h case): %.2f\n', recommended_cap);
end

function [cc, meta] = build_incremental_sample_min(start_cc, n_actions, n_comp, c_min, c_max, delta_cap_per_hr, dt_hr, seed)
rng(seed, 'twister');

cc = zeros(n_actions, n_comp);
cc(1, :) = min(max(start_cc(1:n_comp), c_min), c_max);

delta_cap = delta_cap_per_hr * dt_hr;
for k = 2:n_actions
    dc = (2 * rand(1, n_comp) - 1) * delta_cap;
    cc(k, :) = cc(k-1, :) + dc;
    cc(k, :) = min(max(cc(k, :), c_min), c_max);
end

meta = struct();
meta.max_step = max(max(abs(diff(cc, 1, 1))));
meta.boundary_hit_rate = mean((abs(cc(:) - c_min) < 1e-9) | (abs(cc(:) - c_max) < 1e-9));
end

function [sim_eval, sim_sec] = run_transient_eval_min(par_case, cc_policy, sim_cfg)
sim_eval = struct();
sim_eval.ok = false;
sim_eval.Jcost = nan;
sim_eval.Jsupp = nan;
sim_eval.Jvar = nan;
sim_eval.t_hr = [];
sim_eval.m_cc_mean = [];
sim_eval.m_cost = [];
sim_eval.m_supp = [];

t0 = tic;
try
    par_sim = par_case;
    par_sim.sim = par_sim.ss;
    par_sim.sim.rtol0 = sim_cfg.rtol0;
    par_sim.sim.atol0 = sim_cfg.atol0;
    par_sim.sim.rtol1 = sim_cfg.rtol1;
    par_sim.sim.atol1 = sim_cfg.atol1;
    par_sim.sim.rtol = sim_cfg.rtol;
    par_sim.sim.atol = sim_cfg.atol;
    par_sim.sim.startup = sim_cfg.startup;
    par_sim.sim.nperiods = sim_cfg.nperiods;
    par_sim.sim.solsteps = sim_cfg.solsteps;
    par_sim.sim.fromss = 1;

    par_sim = tran_sim_setup_0_min(par_sim, cc_policy');
    par_sim.sim = tran_sim_base_flat_noextd(par_sim.sim);
    par_sim = process_output_tr_nofd_sim(par_sim);

    n_t = size(par_sim.tr.m_cc, 1);
    sim_eval.t_hr = linspace(0, 24, n_t)';
    sim_eval.m_cc_mean = mean(par_sim.tr.m_cc, 2);
    sim_eval.m_cost = par_sim.tr.m_cost;
    sim_eval.m_supp = par_sim.tr.m_supp;
    sim_eval.Jcost = sum(par_sim.tr.shap.ori_Jcost);
    sim_eval.Jsupp = par_sim.tr.shap.ori_Jsupp;
    sim_eval.Jvar = par_sim.tr.shap.ori_Jvar;
    sim_eval.ok = true;
catch
end

sim_sec = toc(t0);
end

function sim_cfg = default_sim_cfg_min()
sim_cfg = struct();
sim_cfg.rtol0 = 1e-2;
sim_cfg.atol0 = 1e-1;
sim_cfg.rtol1 = 1e-3;
sim_cfg.atol1 = 1e-2;
sim_cfg.rtol = 1e-5;
sim_cfg.atol = 1e-3;
sim_cfg.startup = 1/8;
sim_cfg.nperiods = 2;
sim_cfg.solsteps = 24 * 6 * 2;
end

function y = normalize_safe_min(x)
x = x(:);
xmin = min(x);
xmax = max(x);
if xmax - xmin < eps
    y = zeros(size(x));
else
    y = (x - xmin) / (xmax - xmin);
end
end

function plot_single_profile_min(cc, plot_dir)
n_comp = size(cc, 2);
t_hr = linspace(0, 24, size(cc, 1))';

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1450 820]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:n_comp
    ax = nexttile;
    plot(t_hr, cc(:, j), '-o', 'LineWidth', 1.6, 'MarkerSize', 3); hold on;
    scatter(t_hr(end), cc(end, j), 52, 'wo', 'LineWidth', 1.2);
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', j));
    title(sprintf('Compressor %d', j));
    xlim([0 24.2]);
    ylim([1.0 1.6]);
    grid on;
    legend({'sample', 'final point'}, 'Location', 'best');
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
y = mean(cc, 2);
plot(t_hr, y, '-o', 'LineWidth', 1.6, 'MarkerSize', 3); hold on;
scatter(t_hr(end), y(end), 52, 'wo', 'LineWidth', 1.2);
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean trajectory (includes final point)');
xlim([0 24.2]);
ylim([1.0 1.6]);
grid on;
legend({'sample', 'final point'}, 'Location', 'best');
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('1h pilot single-sample profile (incremental sampling)', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'single_sample_profile.png'), '-dpng', '-r260');
close(f);
end

function plot_delta_cap_summary_min(summary_cap, plot_dir)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1300 740]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

x = summary_cap.DeltaCapPerHour;

ax1 = nexttile;
yyaxis left;
plot(x, summary_cap.MedianJcost, 'o-', 'LineWidth', 1.6);
ylabel('Median Jcost');
yyaxis right;
plot(x, summary_cap.MedianJsupp, 's-', 'LineWidth', 1.6);
ylabel('Median Jsupp');
xlabel('Delta cap per hour');
title('Objective medians vs delta cap');
grid on;
legend({'Median Jcost', 'Median Jsupp'}, 'Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
plot(x, summary_cap.MeanMaxStep, 'o-', 'LineWidth', 1.6); hold on;
plot(x, summary_cap.P95MaxStep, 's-', 'LineWidth', 1.6);
xlabel('Delta cap per hour');
ylabel('Step magnitude');
title('Step-size diagnostics');
grid on;
legend({'Mean max step', 'P95 max step'}, 'Location', 'best');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
yyaxis left;
bar(x, summary_cap.MeanBoundaryHitRate, 0.7);
ylabel('Mean boundary hit rate');
yyaxis right;
plot(x, summary_cap.MeanTrajectoryStd, 'ko-', 'LineWidth', 1.4);
ylabel('Mean trajectory std');
xlabel('Delta cap per hour');
title('Boundary hits and trajectory spread');
grid on;
legend({'Boundary hit rate', 'Trajectory std'}, 'Location', 'best');
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
plot(x, summary_cap.CompositeScore, 'o-', 'LineWidth', 1.8); hold on;
rec = summary_cap.IsRecommended;
scatter(x(rec), summary_cap.CompositeScore(rec), 90, 'rp', 'filled');
xlabel('Delta cap per hour');
ylabel('Composite score (lower better)');
title('Recommended delta-cap selection');
grid on;
legend({'Composite score', 'Recommended'}, 'Location', 'best');
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('1h pilot: delta-cap confirmation in [0.10, 0.30]', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'delta_cap_summary.png'), '-dpng', '-r260');
close(f);
end

function write_pilot_md_min(out_dir, one_tbl, summary_cap, recommended_cap, c_min, c_max, dt_hr, n_actions, n_rep)
md = fullfile(out_dir, 'PILOT_CONFIRM.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write pilot markdown.');
end

fprintf(fid, '# 1h Pilot Confirmation for DOE Constraints\n\n');
fprintf(fid, '- pressure-ratio bounds: `[%.1f, %.1f]`\n', c_min, c_max);
fprintf(fid, '- case used for confirmation: `dt=%.1f h`\n', dt_hr);
fprintf(fid, '- control points per day (including endpoint): `%d`\n', n_actions);
fprintf(fid, '- incremental rule: `c_k = clip(c_{k-1} + Delta_k, [c_min,c_max])`\n');
fprintf(fid, '- tested per-hour delta caps: `%s`\n', mat2str(summary_cap.DeltaCapPerHour', 3));
fprintf(fid, '- replicates per cap: `%d`\n\n', n_rep);

fprintf(fid, '## Single-sample runtime check\n\n');
fprintf(fid, '- sampled with delta cap `%.2f` on 1h case\n', one_tbl.DeltaCapPerHour(1));
fprintf(fid, '- one-sample simulation wall time: `%.3f s`\n', one_tbl.SimSec(1));
fprintf(fid, '- one-sample metrics: `Jcost=%.10g`, `Jsupp=%.10g`, `Jvar=%.10g`\n\n', ...
    one_tbl.Jcost(1), one_tbl.Jsupp(1), one_tbl.Jvar(1));

fprintf(fid, '## Delta-cap confirmation (1h)\n\n');
fprintf(fid, '| DeltaCapPerHour | SuccessRate | MeanSimSec | MeanMaxStep | P95MaxStep | MeanBoundaryHitRate | MeanTrajectoryStd | CompositeScore | Recommended |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary_cap)
    fprintf(fid, '| %.2f | %.3f | %.3f | %.5f | %.5f | %.5f | %.5f | %.5f | %d |\n', ...
        summary_cap.DeltaCapPerHour(i), ...
        summary_cap.SuccessRate(i), ...
        summary_cap.MeanSimSec(i), ...
        summary_cap.MeanMaxStep(i), ...
        summary_cap.P95MaxStep(i), ...
        summary_cap.MeanBoundaryHitRate(i), ...
        summary_cap.MeanTrajectoryStd(i), ...
        summary_cap.CompositeScore(i), ...
        summary_cap.IsRecommended(i));
end

fprintf(fid, '\nRecommended per-hour delta cap for DOE: `%.2f`\n\n', recommended_cap);
fprintf(fid, 'Scaling rule for other granularities:\n');
fprintf(fid, '- `|Delta c| <= delta_cap_per_hour * dt_hr`\n\n');

fprintf(fid, '## Output files\n\n');
fprintf(fid, '- `single_sample_summary.csv`\n');
fprintf(fid, '- `single_sample_cc_profile.csv`\n');
fprintf(fid, '- `delta_cap_samples.csv`\n');
fprintf(fid, '- `delta_cap_summary.csv`\n');
fprintf(fid, '- `plots/single_sample_profile.png`\n');
fprintf(fid, '- `plots/delta_cap_summary.png`\n');

fclose(fid);
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_min(path_str)
if exist(path_str, 'dir') ~= 7
    return;
end

items = dir(path_str);
for i = 1:numel(items)
    name = items(i).name;
    if strcmp(name, '.') || strcmp(name, '..')
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
