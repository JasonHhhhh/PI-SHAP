function out = run_benchmark_hvac2zone_seqtree()
cfg = default_cfg_hvac2zone();
rng(cfg.seed, 'twister');

root_dir = fileparts(mfilename('fullpath'));
out_dir = fullfile(root_dir, 'outputs');
fig_dir = fullfile(out_dir, 'figures');
tbl_dir = fullfile(out_dir, 'tables');

ensure_dir_hvac(out_dir);
ensure_dir_hvac(fig_dir);
ensure_dir_hvac(tbl_dir);

fprintf('\n[HVAC-2Zone] 1/9 build base scenario + DOE...\n');
base = build_base_scenario_hvac(cfg);
[doe_tbl, doe_scenarios] = build_doe_scenarios_hvac(cfg, base);
writetable(doe_tbl, fullfile(tbl_dir, 'doe_scenarios.csv'));

plot_scenario_profiles_hvac(cfg, base, doe_scenarios, ...
    fullfile(fig_dir, 'figure_01_scenario_profiles.png'), ...
    fullfile(fig_dir, 'figure_01_scenario_profiles.svg'));

fprintf('[HVAC-2Zone] 2/9 evaluate discrete policy pool...\n');
[block_tbl, metrics_tbl, opt_idx] = evaluate_candidate_pool_hvac(cfg, base);
writetable(metrics_tbl, fullfile(tbl_dir, 'candidate_metrics.csv'));

fprintf('[HVAC-2Zone] 3/9 single-objective comparison...\n');
[single_tbl, single_runs] = build_single_comparison_hvac(cfg, base, block_tbl, metrics_tbl, opt_idx);
writetable(single_tbl, fullfile(tbl_dir, 'single_objective_comparison.csv'));

fprintf('[HVAC-2Zone] 4/9 multi-objective Pareto analysis...\n');
[pareto_tbl, selected_tbl] = build_multi_objective_hvac(cfg, block_tbl, metrics_tbl, opt_idx);
writetable(pareto_tbl, fullfile(tbl_dir, 'multi_objective_pareto_points.csv'));
writetable(selected_tbl, fullfile(tbl_dir, 'multi_objective_selected_plans.csv'));

fprintf('[HVAC-2Zone] 5/9 write planning schedules...\n');
schedule_tbl = build_schedule_table_hvac(cfg, single_runs, selected_tbl, block_tbl);
writetable(schedule_tbl, fullfile(tbl_dir, 'planning_schedule_blocks.csv'));

fprintf('[HVAC-2Zone] 6/9 generate trajectory + Pareto figures...\n');
plot_single_trajectories_hvac(cfg, base, single_runs, selected_tbl, block_tbl, ...
    fullfile(fig_dir, 'figure_02_single_objective_trajectories.png'), ...
    fullfile(fig_dir, 'figure_02_single_objective_trajectories.svg'));

plot_pareto_hvac(metrics_tbl, pareto_tbl, selected_tbl, ...
    fullfile(fig_dir, 'figure_03_multi_objective_pareto.png'), ...
    fullfile(fig_dir, 'figure_03_multi_objective_pareto.svg'));

fprintf('[HVAC-2Zone] 7/9 DOE robustness evaluation...\n');
[robust_long_tbl, robust_summary_tbl] = evaluate_robustness_hvac(cfg, doe_scenarios, single_runs, selected_tbl, block_tbl);
writetable(robust_long_tbl, fullfile(tbl_dir, 'robustness_long.csv'));
writetable(robust_summary_tbl, fullfile(tbl_dir, 'robustness_summary.csv'));

plot_robustness_hvac(robust_summary_tbl, ...
    fullfile(fig_dir, 'figure_04_doe_robustness.png'), ...
    fullfile(fig_dir, 'figure_04_doe_robustness.svg'));

fprintf('[HVAC-2Zone] 8/9 SHAP train/test analysis (single + multi)...\n');
shap_out = run_shap_analysis_hvac(cfg, block_tbl, metrics_tbl, tbl_dir, fig_dir);

fprintf('[HVAC-2Zone] 9/9 write summary + workspace...\n');
summary_file = fullfile(out_dir, 'SUMMARY.md');
write_summary_hvac(summary_file, cfg, single_tbl, selected_tbl, robust_summary_tbl, metrics_tbl, pareto_tbl, shap_out);

save(fullfile(out_dir, 'workspace.mat'), ...
    'cfg', 'base', 'doe_tbl', 'single_tbl', 'pareto_tbl', 'selected_tbl', ...
    'robust_summary_tbl', 'metrics_tbl', 'block_tbl', 'shap_out', '-v7.3');

out = struct();
out.root_dir = root_dir;
out.output_dir = out_dir;
out.table_dir = tbl_dir;
out.figure_dir = fig_dir;
out.summary_file = summary_file;
out.single_table = fullfile(tbl_dir, 'single_objective_comparison.csv');
out.multi_table = fullfile(tbl_dir, 'multi_objective_selected_plans.csv');
out.robust_table = fullfile(tbl_dir, 'robustness_summary.csv');
out.shap_single_table = fullfile(tbl_dir, 'shap_schedule_compare_single.csv');
out.shap_multi_table = fullfile(tbl_dir, 'shap_schedule_compare_multi.csv');

fprintf('HVAC 2-zone benchmark done: %s\n', summary_file);
end

function cfg = default_cfg_hvac2zone()
cfg = struct();
cfg.seed = 20260309;

cfg.horizon = 24;
cfg.dt_hr = 1.0;
cfg.n_zones = 2;

cfg.n_blocks = 4;
cfg.block_hours = cfg.horizon / cfg.n_blocks;
cfg.action_levels = [0.00, 0.35, 0.70, 1.00];

cfg.setpoint = 24.0;
cfg.deadband = 1.0;
cfg.temp_floor = 16.0;
cfg.temp_ceil = 38.0;

cfg.k_out = [0.16, 0.14];
cfg.k_cross = 0.05;
cfg.k_solar = [0.55, 0.40];
cfg.k_occ = [0.70, 0.55];
cfg.k_cool = [2.80, 2.30];

cfg.cooling_kw_max = [7.5, 6.5];

cfg.w_discomfort = 2.20;
cfg.w_smooth = 0.40;
cfg.terminal_weight = 1.50;
cfg.u_prev0 = [0.25, 0.25];

cfg.peak_hours = 16:21;
cfg.peak_idx = cfg.peak_hours + 1;

cfg.n_doe = 48;
cfg.progress_every = 5000;

cfg.shap_n_train = 2400;
cfg.shap_n_test = 800;
cfg.shap_mc_draws = 30;
cfg.shap_cond_k = 80;
cfg.shap_ridge_lambda = 1e-3;
end

function ensure_dir_hvac(path_dir)
if exist(path_dir, 'dir') ~= 7
    mkdir(path_dir);
end
end

function s = build_base_scenario_hvac(cfg)
t = (0:(cfg.horizon - 1))';

tout = 29 + 5.5 * sin(2 * pi * (t - 8) / 24) + 1.2 * sin(4 * pi * (t - 14) / 24);
solar = max(0, sin(pi * (t - 6) / 12)) .^ 1.35;

occ1 = zeros(cfg.horizon, 1);
occ2 = 0.05 * ones(cfg.horizon, 1);

occ1(8:18) = 1.00;
occ1(7) = 0.35;
occ1(19) = 0.25;

occ2(8:19) = 0.75;
occ2(7) = 0.25;
occ2(20) = 0.20;

price = 0.18 * ones(cfg.horizon, 1);
price(1:6) = 0.12;
price(cfg.peak_idx) = 0.34;
price(23:24) = 0.16;

s = struct();
s.Hour = t;
s.Tout = tout;
s.Solar = solar;
s.Occ = [occ1, occ2];
s.Price = price;
s.T0 = [26.6, 26.1];
s.Name = 'base_reference_day';
end

function [tbl, scenarios] = build_doe_scenarios_hvac(cfg, base)
n = cfg.n_doe;
d = 9;
X = lhs_unit_hvac(n, d, cfg.seed + 101);

temp_shift = scale_linear_hvac(X(:, 1), -2.0, 4.0);
temp_amp = scale_linear_hvac(X(:, 2), 0.85, 1.20);
solar_mult = scale_linear_hvac(X(:, 3), 0.75, 1.25);
occ1_mult = scale_linear_hvac(X(:, 4), 0.70, 1.30);
occ2_mult = scale_linear_hvac(X(:, 5), 0.70, 1.25);
peak_mult = scale_linear_hvac(X(:, 6), 0.80, 1.45);
base_price_mult = scale_linear_hvac(X(:, 7), 0.90, 1.15);
t0_off1 = scale_linear_hvac(X(:, 8), -1.20, 1.20);
t0_off2 = scale_linear_hvac(X(:, 9), -1.20, 1.20);

scenarios = repmat(struct('Hour', [], 'Tout', [], 'Solar', [], 'Occ', [], 'Price', [], 'T0', [], 'Name', ''), n, 1);

scenario_id = (1:n)';
mean_tout = zeros(n, 1);
max_tout = zeros(n, 1);
peak_price = zeros(n, 1);
mean_occ = zeros(n, 1);

for i = 1:n
    tout_center = mean(base.Tout);
    tout = tout_center + temp_shift(i) + temp_amp(i) * (base.Tout - tout_center);
    tout = tout + 0.30 * sin(2 * pi * (base.Hour + i / n) / 24);

    solar = clamp_hvac(base.Solar * solar_mult(i), 0, 1.40);

    occ1 = clamp_hvac(base.Occ(:, 1) * occ1_mult(i), 0, 1.20);
    occ2 = clamp_hvac(base.Occ(:, 2) * occ2_mult(i), 0, 1.20);

    price = clamp_hvac(base.Price * base_price_mult(i), 0.08, 0.55);
    price(cfg.peak_idx) = clamp_hvac(price(cfg.peak_idx) * peak_mult(i), 0.10, 0.65);

    s = struct();
    s.Hour = base.Hour;
    s.Tout = tout;
    s.Solar = solar;
    s.Occ = [occ1, occ2];
    s.Price = price;
    s.T0 = base.T0 + [t0_off1(i), t0_off2(i)];
    s.Name = sprintf('doe_%03d', i);

    scenarios(i) = s;

    mean_tout(i) = mean(tout);
    max_tout(i) = max(tout);
    peak_price(i) = max(price);
    mean_occ(i) = mean((occ1 + occ2) / 2);
end

tbl = table(scenario_id, temp_shift, temp_amp, solar_mult, occ1_mult, occ2_mult, ...
    peak_mult, base_price_mult, t0_off1, t0_off2, mean_tout, max_tout, peak_price, mean_occ, ...
    'VariableNames', {'ScenarioID', 'TempShift', 'TempAmp', 'SolarMult', 'Occ1Mult', 'Occ2Mult', ...
    'PeakPriceMult', 'BasePriceMult', 'T0OffsetZone1', 'T0OffsetZone2', ...
    'MeanTout', 'MaxTout', 'PeakPrice', 'MeanOcc'});
end

function X = lhs_unit_hvac(n, d, seed)
rng(seed, 'twister');
X = zeros(n, d);
edges = linspace(0, 1, n + 1);
for j = 1:d
    u = edges(1:n)' + rand(n, 1) / n;
    X(:, j) = u(randperm(n));
end
end

function y = scale_linear_hvac(x, lo, hi)
y = lo + (hi - lo) .* x;
end

function v = clamp_hvac(v, lo, hi)
v = min(max(v, lo), hi);
end

function plot_scenario_profiles_hvac(cfg, base, scenarios, png_file, svg_file)
n = numel(scenarios);
idx = unique(max(1, min(n, [1, round(n / 2), n])));

fig = figure('Color', 'w', 'Position', [120, 80, 1200, 820]);

subplot(4, 1, 1);
plot(base.Hour, base.Tout, 'k-', 'LineWidth', 1.8); hold on;
for i = 1:numel(idx)
    plot(scenarios(idx(i)).Hour, scenarios(idx(i)).Tout, '--', 'LineWidth', 1.1);
end
grid on;
ylabel('Tout (degC)');
title('HVAC 2-zone benchmark: base day and DOE profile examples');
lg = [{'Base'}, arrayfun(@(x) sprintf('DOE-%03d', x), idx, 'UniformOutput', false)];
legend(lg, 'Location', 'northwest');

subplot(4, 1, 2);
plot(base.Hour, base.Solar, 'Color', [0.85, 0.45, 0.05], 'LineWidth', 1.8);
grid on;
ylabel('Solar (-)');

subplot(4, 1, 3);
plot(base.Hour, base.Occ(:, 1), 'b-', 'LineWidth', 1.5); hold on;
plot(base.Hour, base.Occ(:, 2), 'g-', 'LineWidth', 1.5);
grid on;
ylabel('Occupancy (-)');
legend({'Zone1', 'Zone2'}, 'Location', 'northwest');

subplot(4, 1, 4);
plot(base.Hour, base.Price, 'm-', 'LineWidth', 1.8);
grid on;
xlabel('Hour');
ylabel('Price ($/kWh)');
xlim([0, cfg.horizon - 1]);

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function [block_tbl, metrics_tbl, opt_idx] = evaluate_candidate_pool_hvac(cfg, scenario)
[block_tbl, block_mat] = build_candidate_blocks_hvac(cfg);
n = size(block_mat, 1);

cost = zeros(n, 1);
discomfort = zeros(n, 1);
smooth = zeros(n, 1);
energy = zeros(n, 1);
jsingle = zeros(n, 1);
tmax = zeros(n, 1);
tmin = zeros(n, 1);
viol_hours = zeros(n, 1);

for i = 1:n
    blocks = row_to_blocks_hvac(block_mat(i, :), cfg);
    res = simulate_blocks_hvac(blocks, scenario, cfg, false);

    cost(i) = res.Cost;
    discomfort(i) = res.Discomfort;
    smooth(i) = res.Smoothness;
    energy(i) = res.EnergyKWh;
    jsingle(i) = res.Jsingle;
    tmax(i) = res.Tmax;
    tmin(i) = res.Tmin;
    viol_hours(i) = res.ComfortViolationHours;

    if mod(i, cfg.progress_every) == 0
        fprintf('  evaluated %d / %d candidates\n', i, n);
    end
end

[~, opt_idx] = min(jsingle);

metrics_tbl = table(block_tbl.CandidateID, cost, discomfort, smooth, energy, jsingle, tmax, tmin, viol_hours, ...
    'VariableNames', {'CandidateID', 'Cost', 'Discomfort', 'Smoothness', 'EnergyKWh', ...
    'Jsingle', 'Tmax', 'Tmin', 'ComfortViolationHours'});
end

function [block_tbl, block_mat] = build_candidate_blocks_hvac(cfg)
n_levels = numel(cfg.action_levels);
n_dec = 2 * cfg.n_blocks;
n_total = n_levels ^ n_dec;

digits = zeros(n_total, n_dec);
tmp = (0:(n_total - 1))';
for k = 1:n_dec
    digits(:, k) = mod(tmp, n_levels);
    tmp = floor(tmp / n_levels);
end

block_mat = cfg.action_levels(digits + 1);

candidate_id = (1:n_total)';
block_tbl = table(candidate_id, 'VariableNames', {'CandidateID'});

for b = 1:cfg.n_blocks
    var_name = sprintf('B%d_Z1', b);
    block_tbl.(var_name) = block_mat(:, b);
end
for b = 1:cfg.n_blocks
    var_name = sprintf('B%d_Z2', b);
    block_tbl.(var_name) = block_mat(:, cfg.n_blocks + b);
end
end

function blocks = row_to_blocks_hvac(row_vec, cfg)
z1 = row_vec(1:cfg.n_blocks);
z2 = row_vec((cfg.n_blocks + 1):(2 * cfg.n_blocks));
blocks = [z1(:), z2(:)];
end

function u_hourly = blocks_to_hourly_hvac(blocks, cfg)
u_hourly = zeros(cfg.horizon, cfg.n_zones);
for b = 1:cfg.n_blocks
    i1 = (b - 1) * cfg.block_hours + 1;
    i2 = b * cfg.block_hours;
    u_hourly(i1:i2, :) = repmat(blocks(b, :), cfg.block_hours, 1);
end
end

function res = simulate_blocks_hvac(blocks, scenario, cfg, need_traj)
u_hourly = blocks_to_hourly_hvac(blocks, cfg);
res = simulate_hourly_hvac(u_hourly, scenario, cfg, need_traj);
res.Blocks = blocks;
end

function res = simulate_hourly_hvac(u_hourly, scenario, cfg, need_traj)
if nargin < 4
    need_traj = false;
end

h = cfg.horizon;
t_hist = zeros(h + 1, cfg.n_zones);
t_hist(1, :) = scenario.T0;

cost = 0;
discomfort = 0;
smooth = 0;
energy = 0;
viol_hours = 0;

u_prev = cfg.u_prev0;

for t = 1:h
    T1 = t_hist(t, 1);
    T2 = t_hist(t, 2);

u = u_hourly(t, :);
u = clamp_hvac(u, 0, 1);

err = abs([T1, T2] - cfg.setpoint) - cfg.deadband;
exceed = max(err, 0);
discomfort = discomfort + sum(exceed .^ 2);
viol_hours = viol_hours + sum(exceed > 0);

cooling_kw = cfg.cooling_kw_max .* u;
energy = energy + sum(cooling_kw) * cfg.dt_hr;
cost = cost + scenario.Price(t) * sum(cooling_kw) * cfg.dt_hr;

du = u - u_prev;
smooth = smooth + sum(du .^ 2);
u_prev = u;

dt1 = cfg.k_out(1) * (scenario.Tout(t) - T1) ...
    + cfg.k_cross * (T2 - T1) ...
    + cfg.k_solar(1) * scenario.Solar(t) ...
    + cfg.k_occ(1) * scenario.Occ(t, 1) ...
    - cfg.k_cool(1) * u(1);

dt2 = cfg.k_out(2) * (scenario.Tout(t) - T2) ...
    + cfg.k_cross * (T1 - T2) ...
    + cfg.k_solar(2) * scenario.Solar(t) ...
    + cfg.k_occ(2) * scenario.Occ(t, 2) ...
    - cfg.k_cool(2) * u(2);

next_t = [T1, T2] + cfg.dt_hr * [dt1, dt2];
next_t = clamp_hvac(next_t, cfg.temp_floor, cfg.temp_ceil);
    t_hist(t + 1, :) = next_t;
end

end_err = abs(t_hist(end, :) - cfg.setpoint) - cfg.deadband;
end_exceed = max(end_err, 0);
discomfort = discomfort + cfg.terminal_weight * sum(end_exceed .^ 2);

jsingle = cost + cfg.w_discomfort * discomfort + cfg.w_smooth * smooth;

res = struct();
res.Cost = cost;
res.Discomfort = discomfort;
res.Smoothness = smooth;
res.EnergyKWh = energy;
res.Jsingle = jsingle;
res.Tmax = max(t_hist(:));
res.Tmin = min(t_hist(:));
res.ComfortViolationHours = viol_hours;

if need_traj
    res.TrajT = t_hist;
    res.TrajU = u_hourly;
else
    res.TrajT = [];
    res.TrajU = [];
end
end

function [single_tbl, runs] = build_single_comparison_hvac(cfg, base, block_tbl, metrics_tbl, opt_idx)
opt_blocks = candidate_id_to_blocks_hvac(block_tbl, metrics_tbl.CandidateID(opt_idx), cfg);

rule_price = baseline_blocks_hvac('Rule-PriceAware', cfg);
rule_comfort = baseline_blocks_hvac('Rule-ComfortFirst', cfg);
rule_eco = baseline_blocks_hvac('Rule-EcoNight', cfg);

runs = repmat(struct('Method', '', 'Blocks', [], 'Result', []), 4, 1);

runs(1).Method = 'Opt-Exhaustive';
runs(1).Blocks = opt_blocks;
runs(1).Result = simulate_blocks_hvac(opt_blocks, base, cfg, true);

runs(2).Method = 'Rule-PriceAware';
runs(2).Blocks = rule_price;
runs(2).Result = simulate_blocks_hvac(rule_price, base, cfg, true);

runs(3).Method = 'Rule-ComfortFirst';
runs(3).Blocks = rule_comfort;
runs(3).Result = simulate_blocks_hvac(rule_comfort, base, cfg, true);

runs(4).Method = 'Rule-EcoNight';
runs(4).Blocks = rule_eco;
runs(4).Result = simulate_blocks_hvac(rule_eco, base, cfg, true);

method = cell(numel(runs), 1);
source = cell(numel(runs), 1);
cost = zeros(numel(runs), 1);
discomfort = zeros(numel(runs), 1);
smooth = zeros(numel(runs), 1);
energy = zeros(numel(runs), 1);
jsingle = zeros(numel(runs), 1);
viol_hours = zeros(numel(runs), 1);
tmax = zeros(numel(runs), 1);
tmin = zeros(numel(runs), 1);

for i = 1:numel(runs)
    method{i} = runs(i).Method;
    if strcmp(runs(i).Method, 'Opt-Exhaustive')
        source{i} = 'discrete_global_search';
    else
        source{i} = 'handcrafted_rule';
    end
    cost(i) = runs(i).Result.Cost;
    discomfort(i) = runs(i).Result.Discomfort;
    smooth(i) = runs(i).Result.Smoothness;
    energy(i) = runs(i).Result.EnergyKWh;
    jsingle(i) = runs(i).Result.Jsingle;
    viol_hours(i) = runs(i).Result.ComfortViolationHours;
    tmax(i) = runs(i).Result.Tmax;
    tmin(i) = runs(i).Result.Tmin;
end

opt_j = runs(1).Result.Jsingle;
regret_pct = (jsingle / opt_j - 1) * 100;

single_tbl = table(method, source, cost, discomfort, smooth, energy, jsingle, regret_pct, viol_hours, tmax, tmin, ...
    'VariableNames', {'Method', 'Source', 'Cost', 'Discomfort', 'Smoothness', 'EnergyKWh', ...
    'Jsingle', 'RegretVsOptPct', 'ComfortViolationHours', 'Tmax', 'Tmin'});

[~, ord] = sort(single_tbl.Jsingle, 'ascend');
single_tbl = single_tbl(ord, :);
single_tbl.Rank = (1:height(single_tbl))';
single_tbl = movevars(single_tbl, 'Rank', 'Before', 1);
end

function blocks = baseline_blocks_hvac(name, cfg)
switch name
    case 'Rule-PriceAware'
        z1 = [0.35; 0.70; 0.35; 0.35];
        z2 = [0.35; 0.70; 0.35; 0.35];
    case 'Rule-ComfortFirst'
        z1 = [0.70; 1.00; 1.00; 0.70];
        z2 = [0.70; 1.00; 1.00; 0.70];
    case 'Rule-EcoNight'
        z1 = [0.35; 0.35; 0.35; 0.00];
        z2 = [0.35; 0.35; 0.35; 0.00];
    otherwise
        error('Unknown baseline policy: %s', name);
end

blocks = [z1(1:cfg.n_blocks), z2(1:cfg.n_blocks)];
end

function [pareto_tbl, selected_tbl] = build_multi_objective_hvac(cfg, block_tbl, metrics_tbl, opt_idx)
cost = metrics_tbl.Cost;
disc = metrics_tbl.Discomfort;

[~, ord] = sort(cost, 'ascend');
best_disc = inf;
is_pareto = false(height(metrics_tbl), 1);

for k = 1:numel(ord)
    idx = ord(k);
    if disc(idx) < best_disc - 1e-10
        is_pareto(idx) = true;
        best_disc = disc(idx);
    end
end

pareto_idx = find(is_pareto);
pareto_tbl = [metrics_tbl(pareto_idx, :), block_tbl(pareto_idx, 2:end)];
pareto_tbl = sortrows(pareto_tbl, 'Cost', 'ascend');

[~, i_min_cost] = min(pareto_tbl.Cost);
[~, i_min_disc] = min(pareto_tbl.Discomfort);

nc = normalize01_hvac(pareto_tbl.Cost);
nd = normalize01_hvac(pareto_tbl.Discomfort);
dist_utopia = sqrt(nc .^ 2 + nd .^ 2);
[~, i_knee] = min(dist_utopia);

selected_name = {'Pareto_MinCost'; 'Pareto_Knee'; 'Pareto_MinDiscomfort'; 'SingleObj_Opt'};
selected_idx = [pareto_tbl.CandidateID(i_min_cost); ...
    pareto_tbl.CandidateID(i_knee); ...
    pareto_tbl.CandidateID(i_min_disc); ...
    metrics_tbl.CandidateID(opt_idx)];

sel_cost = zeros(numel(selected_idx), 1);
sel_disc = zeros(numel(selected_idx), 1);
sel_smooth = zeros(numel(selected_idx), 1);
sel_energy = zeros(numel(selected_idx), 1);
sel_jsingle = zeros(numel(selected_idx), 1);

for i = 1:numel(selected_idx)
    rid = find(metrics_tbl.CandidateID == selected_idx(i), 1, 'first');
    sel_cost(i) = metrics_tbl.Cost(rid);
    sel_disc(i) = metrics_tbl.Discomfort(rid);
    sel_smooth(i) = metrics_tbl.Smoothness(rid);
    sel_energy(i) = metrics_tbl.EnergyKWh(rid);
    sel_jsingle(i) = metrics_tbl.Jsingle(rid);
end

opt_j = metrics_tbl.Jsingle(opt_idx);
regret = (sel_jsingle / opt_j - 1) * 100;

selected_tbl = table(selected_name, selected_idx, sel_cost, sel_disc, sel_smooth, sel_energy, sel_jsingle, regret, ...
    'VariableNames', {'Selection', 'CandidateID', 'Cost', 'Discomfort', 'Smoothness', 'EnergyKWh', 'Jsingle', 'RegretVsSingleOptPct'});

for b = 1:cfg.n_blocks
    vn = sprintf('B%d_Z1', b);
    selected_tbl.(vn) = zeros(height(selected_tbl), 1);
end
for b = 1:cfg.n_blocks
    vn = sprintf('B%d_Z2', b);
    selected_tbl.(vn) = zeros(height(selected_tbl), 1);
end

for i = 1:height(selected_tbl)
    blocks = candidate_id_to_blocks_hvac(block_tbl, selected_tbl.CandidateID(i), cfg);
    for b = 1:cfg.n_blocks
        selected_tbl.(sprintf('B%d_Z1', b))(i) = blocks(b, 1);
        selected_tbl.(sprintf('B%d_Z2', b))(i) = blocks(b, 2);
    end
end
end

function x = normalize01_hvac(x)
lo = min(x);
hi = max(x);
if hi - lo < 1e-12
    x = zeros(size(x));
else
    x = (x - lo) / (hi - lo);
end
end

function blocks = candidate_id_to_blocks_hvac(block_tbl, candidate_id, cfg)
rid = find(block_tbl.CandidateID == candidate_id, 1, 'first');
if isempty(rid)
    error('CandidateID %d not found', candidate_id);
end

blocks = zeros(cfg.n_blocks, 2);
for b = 1:cfg.n_blocks
    blocks(b, 1) = block_tbl.(sprintf('B%d_Z1', b))(rid);
    blocks(b, 2) = block_tbl.(sprintf('B%d_Z2', b))(rid);
end
end

function schedule_tbl = build_schedule_table_hvac(cfg, single_runs, selected_tbl, block_tbl)
names = {};
source = {};
all_blocks = [];

for i = 1:numel(single_runs)
    names{end + 1, 1} = single_runs(i).Method; %#ok<AGROW>
    source{end + 1, 1} = 'single_comparison'; %#ok<AGROW>
    all_blocks = [all_blocks; reshape(single_runs(i).Blocks, 1, [])]; %#ok<AGROW>
end

for i = 1:height(selected_tbl)
    names{end + 1, 1} = selected_tbl.Selection{i}; %#ok<AGROW>
    source{end + 1, 1} = 'multi_objective_selection'; %#ok<AGROW>
    b = candidate_id_to_blocks_hvac(block_tbl, selected_tbl.CandidateID(i), cfg);
    all_blocks = [all_blocks; reshape(b, 1, [])]; %#ok<AGROW>
end

schedule_tbl = table(names, source, 'VariableNames', {'PlanLabel', 'PlanSource'});

for b = 1:cfg.n_blocks
    schedule_tbl.(sprintf('B%d_Z1', b)) = all_blocks(:, (b - 1) * 2 + 1);
    schedule_tbl.(sprintf('B%d_Z2', b)) = all_blocks(:, (b - 1) * 2 + 2);
end
end

function plot_single_trajectories_hvac(cfg, base, single_runs, selected_tbl, block_tbl, png_file, svg_file)
knee_row = find(strcmp(selected_tbl.Selection, 'Pareto_Knee'), 1, 'first');
if isempty(knee_row)
    knee_row = 1;
end
knee_blocks = candidate_id_to_blocks_hvac(block_tbl, selected_tbl.CandidateID(knee_row), cfg);
knee_run = simulate_blocks_hvac(knee_blocks, base, cfg, true);

plot_runs = repmat(struct('Name', '', 'Res', []), 4, 1);
plot_runs(1).Name = 'Opt-Exhaustive';
plot_runs(1).Res = find_run_hvac(single_runs, 'Opt-Exhaustive').Result;
plot_runs(2).Name = 'Pareto-Knee';
plot_runs(2).Res = knee_run;
plot_runs(3).Name = 'Rule-PriceAware';
plot_runs(3).Res = find_run_hvac(single_runs, 'Rule-PriceAware').Result;
plot_runs(4).Name = 'Rule-ComfortFirst';
plot_runs(4).Res = find_run_hvac(single_runs, 'Rule-ComfortFirst').Result;

colors = lines(4);
t_state = 0:cfg.horizon;
t_ctrl = 0:(cfg.horizon - 1);

fig = figure('Color', 'w', 'Position', [80, 80, 1280, 840]);

subplot(2, 2, 1);
hold on;
for i = 1:numel(plot_runs)
    plot(t_state, plot_runs(i).Res.TrajT(:, 1), 'LineWidth', 1.6, 'Color', colors(i, :));
end
yline(cfg.setpoint - cfg.deadband, 'k--', 'LineWidth', 1.0);
yline(cfg.setpoint + cfg.deadband, 'k--', 'LineWidth', 1.0);
grid on;
xlim([0, cfg.horizon]);
xlabel('Hour');
ylabel('Zone1 Temp (degC)');
title('Zone 1 trajectory');
legend({plot_runs.Name, 'Comfort lower', 'Comfort upper'}, 'Location', 'best');

subplot(2, 2, 2);
hold on;
for i = 1:numel(plot_runs)
    plot(t_state, plot_runs(i).Res.TrajT(:, 2), 'LineWidth', 1.6, 'Color', colors(i, :));
end
yline(cfg.setpoint - cfg.deadband, 'k--', 'LineWidth', 1.0);
yline(cfg.setpoint + cfg.deadband, 'k--', 'LineWidth', 1.0);
grid on;
xlim([0, cfg.horizon]);
xlabel('Hour');
ylabel('Zone2 Temp (degC)');
title('Zone 2 trajectory');

subplot(2, 2, 3);
hold on;
for i = 1:numel(plot_runs)
    stairs(t_ctrl, plot_runs(i).Res.TrajU(:, 1), 'LineWidth', 1.6, 'Color', colors(i, :));
end
grid on;
xlim([0, cfg.horizon - 1]);
ylim([0, 1.05]);
xlabel('Hour');
ylabel('u_{zone1}');
title('Zone 1 control schedule');

subplot(2, 2, 4);
yyaxis left;
hold on;
for i = 1:numel(plot_runs)
    stairs(t_ctrl, plot_runs(i).Res.TrajU(:, 2), 'LineWidth', 1.6, 'Color', colors(i, :));
end
ylabel('u_{zone2}');
ylim([0, 1.05]);

yyaxis right;
plot(t_ctrl, base.Price, 'k-.', 'LineWidth', 1.4);
ylabel('Price ($/kWh)');

grid on;
xlim([0, cfg.horizon - 1]);
xlabel('Hour');
title('Zone 2 control and price');

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function run_item = find_run_hvac(single_runs, name)
idx = find(strcmp({single_runs.Method}, name), 1, 'first');
if isempty(idx)
    error('Method not found in single runs: %s', name);
end
run_item = single_runs(idx);
end

function plot_pareto_hvac(metrics_tbl, pareto_tbl, selected_tbl, png_file, svg_file)
n = height(metrics_tbl);
step = max(1, ceil(n / 12000));
idx = 1:step:n;

fig = figure('Color', 'w', 'Position', [120, 100, 980, 700]);
scatter(metrics_tbl.Cost(idx), metrics_tbl.Discomfort(idx), 10, [0.78, 0.78, 0.78], 'filled'); hold on;
plot(pareto_tbl.Cost, pareto_tbl.Discomfort, 'r-', 'LineWidth', 1.8);

markers = {'o', 'd', '^', 's'};
colors = lines(height(selected_tbl));
for i = 1:height(selected_tbl)
    scatter(selected_tbl.Cost(i), selected_tbl.Discomfort(i), 90, colors(i, :), markers{i}, 'filled', 'MarkerEdgeColor', 'k');
    text(selected_tbl.Cost(i) + 0.2, selected_tbl.Discomfort(i), selected_tbl.Selection{i}, 'FontSize', 9);
end

grid on;
xlabel('Energy cost ($/day)');
ylabel('Discomfort penalty (sum of squared exceedance)');
title('Multi-objective trade-off: cost vs discomfort');
legend({'Candidate sample', 'Pareto front', 'Selected plans'}, 'Location', 'northeast');

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function [long_tbl, summary_tbl] = evaluate_robustness_hvac(cfg, scenarios, single_runs, selected_tbl, block_tbl)
method_names = {'Opt-Exhaustive', 'Pareto-Knee', 'Pareto-MinCost', 'Rule-PriceAware', 'Rule-ComfortFirst'};
method_blocks = cell(size(method_names));

method_blocks{1} = find_run_hvac(single_runs, 'Opt-Exhaustive').Blocks;

idx_knee = find(strcmp(selected_tbl.Selection, 'Pareto_Knee'), 1, 'first');
idx_minc = find(strcmp(selected_tbl.Selection, 'Pareto_MinCost'), 1, 'first');
if isempty(idx_knee)
    idx_knee = 1;
end
if isempty(idx_minc)
    idx_minc = idx_knee;
end

method_blocks{2} = candidate_id_to_blocks_hvac(block_tbl, selected_tbl.CandidateID(idx_knee), cfg);
method_blocks{3} = candidate_id_to_blocks_hvac(block_tbl, selected_tbl.CandidateID(idx_minc), cfg);
method_blocks{4} = find_run_hvac(single_runs, 'Rule-PriceAware').Blocks;
method_blocks{5} = find_run_hvac(single_runs, 'Rule-ComfortFirst').Blocks;

n_s = numel(scenarios);
n_m = numel(method_names);
n_rows = n_s * n_m;

scenario_id = zeros(n_rows, 1);
method = cell(n_rows, 1);
cost = zeros(n_rows, 1);
discomfort = zeros(n_rows, 1);
smooth = zeros(n_rows, 1);
energy = zeros(n_rows, 1);
jsingle = zeros(n_rows, 1);
viol = zeros(n_rows, 1);

rid = 0;
for s = 1:n_s
    for m = 1:n_m
        rid = rid + 1;
        res = simulate_blocks_hvac(method_blocks{m}, scenarios(s), cfg, false);
        scenario_id(rid) = s;
        method{rid} = method_names{m};
        cost(rid) = res.Cost;
        discomfort(rid) = res.Discomfort;
        smooth(rid) = res.Smoothness;
        energy(rid) = res.EnergyKWh;
        jsingle(rid) = res.Jsingle;
        viol(rid) = res.ComfortViolationHours;
    end
end

long_tbl = table(scenario_id, method, cost, discomfort, smooth, energy, jsingle, viol, ...
    'VariableNames', {'ScenarioID', 'Method', 'Cost', 'Discomfort', 'Smoothness', ...
    'EnergyKWh', 'Jsingle', 'ComfortViolationHours'});

mean_cost = zeros(n_m, 1);
std_cost = zeros(n_m, 1);
mean_disc = zeros(n_m, 1);
std_disc = zeros(n_m, 1);
mean_js = zeros(n_m, 1);
std_js = zeros(n_m, 1);

for m = 1:n_m
    idx = strcmp(long_tbl.Method, method_names{m});
    mean_cost(m) = mean(long_tbl.Cost(idx));
    std_cost(m) = std(long_tbl.Cost(idx));
    mean_disc(m) = mean(long_tbl.Discomfort(idx));
    std_disc(m) = std(long_tbl.Discomfort(idx));
    mean_js(m) = mean(long_tbl.Jsingle(idx));
    std_js(m) = std(long_tbl.Jsingle(idx));
end

summary_tbl = table(method_names', mean_cost, std_cost, mean_disc, std_disc, mean_js, std_js, ...
    'VariableNames', {'Method', 'MeanCost', 'StdCost', 'MeanDiscomfort', 'StdDiscomfort', 'MeanJsingle', 'StdJsingle'});

[~, ord] = sort(summary_tbl.MeanJsingle, 'ascend');
summary_tbl = summary_tbl(ord, :);
summary_tbl.RankByMeanJsingle = (1:height(summary_tbl))';
summary_tbl = movevars(summary_tbl, 'RankByMeanJsingle', 'Before', 1);
end

function plot_robustness_hvac(summary_tbl, png_file, svg_file)
fig = figure('Color', 'w', 'Position', [180, 140, 1080, 520]);

methods = summary_tbl.Method;
x = 1:numel(methods);

subplot(1, 2, 1);
bar(x, summary_tbl.MeanCost, 0.7, 'FaceColor', [0.30, 0.55, 0.85]); hold on;
errorbar(x, summary_tbl.MeanCost, summary_tbl.StdCost, 'k.', 'LineWidth', 1.2);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Cost ($/day)');
title('DOE robustness: mean cost +/- 1 std');
grid on;

subplot(1, 2, 2);
bar(x, summary_tbl.MeanDiscomfort, 0.7, 'FaceColor', [0.85, 0.48, 0.20]); hold on;
errorbar(x, summary_tbl.MeanDiscomfort, summary_tbl.StdDiscomfort, 'k.', 'LineWidth', 1.2);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Discomfort penalty');
title('DOE robustness: mean discomfort +/- 1 std');
grid on;

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function out = run_shap_analysis_hvac(cfg, block_tbl, metrics_tbl, tbl_dir, fig_dir)
feature_names = block_tbl.Properties.VariableNames(2:end);
method_names = {'Ori-SHAP', 'Cond-SHAP', 'PI-SHAP'};

X_all = table2array(block_tbl(:, 2:end));
candidate_all = block_tbl.CandidateID;

y_single = metrics_tbl.Jsingle;
y_multi = build_balanced_multi_target_hvac(metrics_tbl);

n = size(X_all, 1);
rng(cfg.seed + 701, 'twister');
perm = randperm(n);

n_train = min(cfg.shap_n_train, n - 1000);
n_test = min(cfg.shap_n_test, n - n_train);

train_idx = perm(1:n_train);
test_idx = perm((n_train + 1):(n_train + n_test));

X_train = X_all(train_idx, :);
X_test = X_all(test_idx, :);
cid_train = candidate_all(train_idx);
cid_test = candidate_all(test_idx);

y_single_train = y_single(train_idx);
y_single_test = y_single(test_idx);
y_multi_train = y_multi(train_idx);
y_multi_test = y_multi(test_idx);

split_tbl = table([cid_train; cid_test], [repmat({'train'}, n_train, 1); repmat({'test'}, n_test, 1)], ...
    'VariableNames', {'CandidateID', 'Split'});
writetable(split_tbl, fullfile(tbl_dir, 'shap_split_candidates.csv'));

model_single = fit_ridge_model_hvac(X_train, y_single_train, cfg.shap_ridge_lambda);
model_multi = fit_ridge_model_hvac(X_train, y_multi_train, cfg.shap_ridge_lambda);

yhat_single_train = predict_ridge_model_hvac(model_single, X_train);
yhat_single_test = predict_ridge_model_hvac(model_single, X_test);
yhat_multi_train = predict_ridge_model_hvac(model_multi, X_train);
yhat_multi_test = predict_ridge_model_hvac(model_multi, X_test);

fit_tbl = table( ...
    {'single'; 'multi_balanced'}, ...
    [rmse_hvac(y_single_train, yhat_single_train); rmse_hvac(y_multi_train, yhat_multi_train)], ...
    [rmse_hvac(y_single_test, yhat_single_test); rmse_hvac(y_multi_test, yhat_multi_test)], ...
    [r2_hvac(y_single_train, yhat_single_train); r2_hvac(y_multi_train, yhat_multi_train)], ...
    [r2_hvac(y_single_test, yhat_single_test); r2_hvac(y_multi_test, yhat_multi_test)], ...
    'VariableNames', {'Objective', 'TrainRMSE', 'TestRMSE', 'TrainR2', 'TestR2'});
writetable(fit_tbl, fullfile(tbl_dir, 'shap_model_fit_summary.csv'));

contrib_single = cell(numel(method_names), 1);
contrib_multi = cell(numel(method_names), 1);

fprintf('  [SHAP] computing contributions for single-objective...\n');
for m = 1:numel(method_names)
    fprintf('    method: %s\n', method_names{m});
    contrib_single{m} = compute_shap_contrib_hvac(method_names{m}, model_single, X_train, X_test, cfg);
end

fprintf('  [SHAP] computing contributions for multi-objective...\n');
for m = 1:numel(method_names)
    fprintf('    method: %s\n', method_names{m});
    contrib_multi{m} = compute_shap_contrib_hvac(method_names{m}, model_multi, X_train, X_test, cfg);
end

[corr_single_tbl, score_single_map, imp_single_tbl] = analyze_shap_outputs_hvac(method_names, contrib_single, y_single_test, feature_names);
[corr_multi_tbl, score_multi_map, imp_multi_tbl] = analyze_shap_outputs_hvac(method_names, contrib_multi, y_multi_test, feature_names);

writetable(corr_single_tbl, fullfile(tbl_dir, 'shap_correlation_single.csv'));
writetable(corr_multi_tbl, fullfile(tbl_dir, 'shap_correlation_multi.csv'));
writetable(imp_single_tbl, fullfile(tbl_dir, 'shap_feature_importance_single.csv'));
writetable(imp_multi_tbl, fullfile(tbl_dir, 'shap_feature_importance_multi.csv'));

schedule_single_tbl = build_shap_schedule_table_hvac(method_names, score_single_map, -yhat_single_test, y_single_test, cid_test);
schedule_multi_tbl = build_shap_schedule_table_hvac(method_names, score_multi_map, -yhat_multi_test, y_multi_test, cid_test);

writetable(schedule_single_tbl, fullfile(tbl_dir, 'shap_schedule_compare_single.csv'));
writetable(schedule_multi_tbl, fullfile(tbl_dir, 'shap_schedule_compare_multi.csv'));

plot_shap_correlations_hvac(corr_single_tbl, corr_multi_tbl, ...
    fullfile(fig_dir, 'figure_05_shap_correlations.png'), ...
    fullfile(fig_dir, 'figure_05_shap_correlations.svg'));

plot_shap_schedule_compare_hvac(schedule_single_tbl, 'Single-objective scheduling (SHAP score ranking)', ...
    fullfile(fig_dir, 'figure_06_shap_schedule_compare_single.png'), ...
    fullfile(fig_dir, 'figure_06_shap_schedule_compare_single.svg'));

plot_shap_schedule_compare_hvac(schedule_multi_tbl, 'Multi-objective scheduling (balanced score)', ...
    fullfile(fig_dir, 'figure_07_shap_schedule_compare_multi.png'), ...
    fullfile(fig_dir, 'figure_07_shap_schedule_compare_multi.svg'));

plot_shap_importance_hvac(imp_single_tbl, imp_multi_tbl, ...
    fullfile(fig_dir, 'figure_08_shap_feature_importance.png'), ...
    fullfile(fig_dir, 'figure_08_shap_feature_importance.svg'));

out = struct();
out.n_train = n_train;
out.n_test = n_test;
out.single_corr_tbl = corr_single_tbl;
out.multi_corr_tbl = corr_multi_tbl;
out.single_schedule_tbl = schedule_single_tbl;
out.multi_schedule_tbl = schedule_multi_tbl;
out.fit_tbl = fit_tbl;
end

function y_multi = build_balanced_multi_target_hvac(metrics_tbl)
cost_n = normalize01_hvac(metrics_tbl.Cost);
disc_n = normalize01_hvac(metrics_tbl.Discomfort);
smooth_n = normalize01_hvac(metrics_tbl.Smoothness);
y_multi = 0.55 * cost_n + 0.40 * disc_n + 0.05 * smooth_n;
end

function model = fit_ridge_model_hvac(X, y, lambda)
Phi = build_poly_features_hvac(X);
p = size(Phi, 2);
reg = lambda * eye(p);
reg(1, 1) = 0;
beta = (Phi' * Phi + reg) \ (Phi' * y);

model = struct();
model.beta = beta;
model.n_feat = size(X, 2);
end

function yhat = predict_ridge_model_hvac(model, X)
Phi = build_poly_features_hvac(X);
yhat = Phi * model.beta;
end

function Phi = build_poly_features_hvac(X)
n = size(X, 1);
p = size(X, 2);

Phi = [ones(n, 1), X, X .^ 2];
for i = 1:p
    for j = (i + 1):p
        Phi = [Phi, X(:, i) .* X(:, j)]; %#ok<AGROW>
    end
end
end

function contrib = compute_shap_contrib_hvac(method_name, model, X_train, X_test, cfg)
n_test = size(X_test, 1);
n_feat = size(X_test, 2);
n_train = size(X_train, 1);

contrib = zeros(n_test, n_feat);
fx = predict_ridge_model_hvac(model, X_test);

for i = 1:n_test
    x = X_test(i, :);

    for j = 1:n_feat
        switch method_name
            case 'Ori-SHAP'
                ridx = randi(n_train, cfg.shap_mc_draws, 1);
                Xp = repmat(x, cfg.shap_mc_draws, 1);
                Xp(:, j) = X_train(ridx, j);
                fp = mean(predict_ridge_model_hvac(model, Xp));
                contrib(i, j) = fp - fx(i);

            case 'Cond-SHAP'
                mask = true(1, n_feat);
                mask(j) = false;
                d2 = sum((X_train(:, mask) - x(mask)) .^ 2, 2);
                [~, ord] = sort(d2, 'ascend');
                k = min(cfg.shap_cond_k, numel(ord));
                pool = ord(1:k);
                ridx = pool(randi(k, cfg.shap_mc_draws, 1));
                Xp = repmat(x, cfg.shap_mc_draws, 1);
                Xp(:, j) = X_train(ridx, j);
                fp = mean(predict_ridge_model_hvac(model, Xp));
                contrib(i, j) = fp - fx(i);

            case 'PI-SHAP'
                jp = paired_feature_index_hvac(j, cfg.n_blocks);
                ridx = randi(n_train, cfg.shap_mc_draws, 1);
                Xp = repmat(x, cfg.shap_mc_draws, 1);
                Xp(:, [j, jp]) = X_train(ridx, [j, jp]);
                fp = mean(predict_ridge_model_hvac(model, Xp));
                contrib(i, j) = 0.5 * (fp - fx(i));

            otherwise
                error('Unknown SHAP method: %s', method_name);
        end
    end

    if mod(i, 100) == 0
        fprintf('      %s progress: %d / %d\n', method_name, i, n_test);
    end
end
end

function jp = paired_feature_index_hvac(j, n_blocks)
if j <= n_blocks
    jp = j + n_blocks;
else
    jp = j - n_blocks;
end
end

function [corr_tbl, score_map, imp_tbl] = analyze_shap_outputs_hvac(method_names, contrib_cell, y_test, feature_names)
n_m = numel(method_names);
n_feat = numel(feature_names);

score_map = struct();
mean_abs = zeros(n_m, 1);
sp = zeros(n_m, 1);
pe = zeros(n_m, 1);

imp_mat = zeros(n_feat, n_m);

for m = 1:n_m
    C = contrib_cell{m};
    score = sum(C, 2);
    score_map.(valid_field_name_hvac(method_names{m})) = score;

    mean_abs(m) = mean(abs(C(:)));
    sp(m) = spearman_simple_hvac(score, -y_test);
    pe(m) = pearson_simple_hvac(score, -y_test);
    imp_mat(:, m) = mean(abs(C), 1)';
end

corr_tbl = table(method_names(:), sp, pe, mean_abs, ...
    'VariableNames', {'Method', 'SpearmanScoreVsNegMetric', 'PearsonScoreVsNegMetric', 'MeanAbsContribution'});

imp_tbl = table(feature_names(:), 'VariableNames', {'Feature'});
for m = 1:n_m
    vn = strrep(method_names{m}, '-', '_');
    imp_tbl.(vn) = imp_mat(:, m);
end
end

function tbl = build_shap_schedule_table_hvac(method_names, score_map, model_score, y_test, candidate_id)
all_methods = [method_names, {'Model-Pred'}];
n_m = numel(all_methods);

method = cell(n_m, 1);
top1_id = zeros(n_m, 1);
top1_metric = zeros(n_m, 1);
top5_metric = zeros(n_m, 1);
regret1 = zeros(n_m, 1);
regret5 = zeros(n_m, 1);
sp = zeros(n_m, 1);
pe = zeros(n_m, 1);

best_true = min(y_test);

for m = 1:n_m
    method{m} = all_methods{m};
    if strcmp(all_methods{m}, 'Model-Pred')
        score = model_score;
    else
        score = score_map.(valid_field_name_hvac(all_methods{m}));
    end

    [~, ord] = sort(score, 'descend');
    k = min(5, numel(ord));

    top1_id(m) = candidate_id(ord(1));
    top1_metric(m) = y_test(ord(1));
    top5_metric(m) = min(y_test(ord(1:k)));

    regret1(m) = (top1_metric(m) / best_true - 1) * 100;
    regret5(m) = (top5_metric(m) / best_true - 1) * 100;

    sp(m) = spearman_simple_hvac(score, -y_test);
    pe(m) = pearson_simple_hvac(score, -y_test);
end

tbl = table(method, top1_id, top1_metric, top5_metric, regret1, regret5, sp, pe, ...
    'VariableNames', {'Method', 'Top1CandidateID', 'Top1Metric', 'Top5BestMetric', ...
    'RegretTop1Pct', 'RegretTop5Pct', 'SpearmanScoreVsNegMetric', 'PearsonScoreVsNegMetric'});

[~, ord] = sort(tbl.RegretTop1Pct, 'ascend');
tbl = tbl(ord, :);
tbl.RankByTop1Regret = (1:height(tbl))';
tbl = movevars(tbl, 'RankByTop1Regret', 'Before', 1);
end

function v = valid_field_name_hvac(name)
v = strrep(name, '-', '_');
v = strrep(v, ' ', '_');
end

function r = rmse_hvac(y, yhat)
r = sqrt(mean((y - yhat) .^ 2));
end

function r = r2_hvac(y, yhat)
den = sum((y - mean(y)) .^ 2);
if den < 1e-12
    r = NaN;
else
    r = 1 - sum((y - yhat) .^ 2) / den;
end
end

function rho = spearman_simple_hvac(x, y)
rx = tied_rank_hvac(x);
ry = tied_rank_hvac(y);
rho = pearson_simple_hvac(rx, ry);
end

function rho = pearson_simple_hvac(x, y)
x = x(:);
y = y(:);
if std(x) < 1e-12 || std(y) < 1e-12
    rho = NaN;
    return;
end
c = corrcoef(x, y);
rho = c(1, 2);
end

function r = tied_rank_hvac(v)
v = v(:);
n = numel(v);
[sv, ord] = sort(v, 'ascend');
r = zeros(n, 1);

i = 1;
while i <= n
    j = i;
    while j < n && sv(j + 1) == sv(i)
        j = j + 1;
    end
    rk = (i + j) / 2;
    r(ord(i:j)) = rk;
    i = j + 1;
end
end

function plot_shap_correlations_hvac(corr_single_tbl, corr_multi_tbl, png_file, svg_file)
methods = corr_single_tbl.Method;
x = 1:numel(methods);

fig = figure('Color', 'w', 'Position', [160, 110, 980, 480]);

subplot(1, 2, 1);
vals = [corr_single_tbl.SpearmanScoreVsNegMetric, corr_multi_tbl.SpearmanScoreVsNegMetric];
bar(x, vals, 0.75);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Spearman correlation');
title('SHAP score correlation with objective');
legend({'Single objective', 'Multi balanced objective'}, 'Location', 'northwest');
grid on;

subplot(1, 2, 2);
vals2 = [corr_single_tbl.PearsonScoreVsNegMetric, corr_multi_tbl.PearsonScoreVsNegMetric];
bar(x, vals2, 0.75);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Pearson correlation');
title('Linear correlation check');
legend({'Single objective', 'Multi balanced objective'}, 'Location', 'northwest');
grid on;

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function plot_shap_schedule_compare_hvac(schedule_tbl, ttl, png_file, svg_file)
fig = figure('Color', 'w', 'Position', [200, 140, 900, 480]);

methods = schedule_tbl.Method;
x = 1:height(schedule_tbl);
bar(x, schedule_tbl.RegretTop1Pct, 0.70, 'FaceColor', [0.20, 0.58, 0.75]);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Top1 regret (%)');
title(ttl);
grid on;

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function plot_shap_importance_hvac(imp_single_tbl, imp_multi_tbl, png_file, svg_file)
method_cols = imp_single_tbl.Properties.VariableNames(2:end);

A = table2array(imp_single_tbl(:, 2:end));
B = table2array(imp_multi_tbl(:, 2:end));

fig = figure('Color', 'w', 'Position', [100, 100, 1200, 540]);

subplot(1, 2, 1);
imagesc(A);
colorbar;
title('Mean |contribution| (single objective)');
set(gca, 'XTick', 1:numel(method_cols), 'XTickLabel', method_cols, ...
    'YTick', 1:height(imp_single_tbl), 'YTickLabel', imp_single_tbl.Feature, ...
    'XTickLabelRotation', 20);

subplot(1, 2, 2);
imagesc(B);
colorbar;
title('Mean |contribution| (multi balanced objective)');
set(gca, 'XTick', 1:numel(method_cols), 'XTickLabel', method_cols, ...
    'YTick', 1:height(imp_multi_tbl), 'YTickLabel', imp_multi_tbl.Feature, ...
    'XTickLabelRotation', 20);

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function write_summary_hvac(file_path, cfg, single_tbl, selected_tbl, robust_summary_tbl, metrics_tbl, pareto_tbl, shap_out)
fid = fopen(file_path, 'w');
if fid < 0
    error('Cannot write summary file: %s', file_path);
end

fprintf(fid, '# HVAC 2-zone benchmark summary\n\n');
fprintf(fid, '## Configuration\n\n');
fprintf(fid, '- Horizon: `%d` hours (`dt=%.1f h`)\n', cfg.horizon, cfg.dt_hr);
fprintf(fid, '- Controls: `%d` zones\n', cfg.n_zones);
fprintf(fid, '- Blocked control variables: `%d` blocks x 2 zones = `%d` decision variables\n', cfg.n_blocks, 2 * cfg.n_blocks);
fprintf(fid, '- Action levels per variable: `%d` (%s)\n', numel(cfg.action_levels), mat2str(cfg.action_levels));
fprintf(fid, '- Candidate pool size: `%d`\n', height(metrics_tbl));
fprintf(fid, '- DOE scenario count: `%d`\n\n', cfg.n_doe);

fprintf(fid, '## Single-objective result\n\n');
best_row = single_tbl(1, :);
fprintf(fid, '- Best method: `%s`\n', best_row.Method{1});
fprintf(fid, '- Best Jsingle: `%.4f`\n', best_row.Jsingle);
fprintf(fid, '- Cost / Discomfort / Smoothness: `%.4f / %.4f / %.4f`\n', ...
    best_row.Cost, best_row.Discomfort, best_row.Smoothness);
fprintf(fid, '- Comfort violation hours: `%.1f`\n\n', best_row.ComfortViolationHours);

fprintf(fid, '## Multi-objective result\n\n');
fprintf(fid, '- Pareto points found: `%d`\n', height(pareto_tbl));

for i = 1:height(selected_tbl)
    fprintf(fid, '- `%s`: cost `%.4f`, discomfort `%.4f`, Jsingle `%.4f`\n', ...
        selected_tbl.Selection{i}, selected_tbl.Cost(i), selected_tbl.Discomfort(i), selected_tbl.Jsingle(i));
end
fprintf(fid, '\n');

fprintf(fid, '## DOE robustness (mean Jsingle ranking)\n\n');
for i = 1:height(robust_summary_tbl)
    fprintf(fid, '%d. `%s`: mean Jsingle `%.4f` (std `%.4f`), mean cost `%.4f`, mean discomfort `%.4f`\n', ...
        robust_summary_tbl.RankByMeanJsingle(i), robust_summary_tbl.Method{i}, ...
        robust_summary_tbl.MeanJsingle(i), robust_summary_tbl.StdJsingle(i), ...
        robust_summary_tbl.MeanCost(i), robust_summary_tbl.MeanDiscomfort(i));
end

fprintf(fid, '\n## SHAP method comparison (train/test split)\n\n');
fprintf(fid, '- Train/Test candidates: `%d / %d`\n', shap_out.n_train, shap_out.n_test);
fprintf(fid, '- Time granularity for planning and SHAP: `%d` blocks x `%d` hours/block\n\n', cfg.n_blocks, cfg.block_hours);

fprintf(fid, '### Single-objective scheduling\n\n');
for i = 1:height(shap_out.single_schedule_tbl)
    fprintf(fid, '- `%s`: top1 metric `%.4f`, top1 regret `%.4f %%`, Spearman(score,-metric)=`%.4f`\n', ...
        shap_out.single_schedule_tbl.Method{i}, ...
        shap_out.single_schedule_tbl.Top1Metric(i), ...
        shap_out.single_schedule_tbl.RegretTop1Pct(i), ...
        shap_out.single_schedule_tbl.SpearmanScoreVsNegMetric(i));
end

fprintf(fid, '\n### Multi-objective scheduling (balanced score)\n\n');
for i = 1:height(shap_out.multi_schedule_tbl)
    fprintf(fid, '- `%s`: top1 metric `%.4f`, top1 regret `%.4f %%`, Spearman(score,-metric)=`%.4f`\n', ...
        shap_out.multi_schedule_tbl.Method{i}, ...
        shap_out.multi_schedule_tbl.Top1Metric(i), ...
        shap_out.multi_schedule_tbl.RegretTop1Pct(i), ...
        shap_out.multi_schedule_tbl.SpearmanScoreVsNegMetric(i));
end

fclose(fid);
end
