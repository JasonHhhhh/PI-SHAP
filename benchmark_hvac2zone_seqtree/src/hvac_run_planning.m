function planning = hvac_run_planning(cfg, base, doe_scenarios, dirs)
[block_tbl, metrics_tbl, opt_idx] = evaluate_candidate_pool_hvac(cfg, base);
writetable(metrics_tbl, fullfile(dirs.table_dir, 'candidate_metrics.csv'));

[single_tbl, single_runs] = build_single_comparison_hvac(cfg, base, block_tbl, metrics_tbl, opt_idx);
writetable(single_tbl, fullfile(dirs.table_dir, 'single_objective_comparison.csv'));

[pareto_tbl, selected_tbl] = build_multi_objective_hvac(cfg, block_tbl, metrics_tbl, opt_idx);
writetable(pareto_tbl, fullfile(dirs.table_dir, 'multi_objective_pareto_points.csv'));
writetable(selected_tbl, fullfile(dirs.table_dir, 'multi_objective_selected_plans.csv'));

schedule_tbl = build_schedule_table_hvac(cfg, single_runs, selected_tbl, block_tbl);
writetable(schedule_tbl, fullfile(dirs.table_dir, 'planning_schedule_blocks.csv'));

plot_single_trajectories_hvac(cfg, base, single_runs, selected_tbl, block_tbl, ...
    fullfile(dirs.figure_dir, 'figure_02_single_objective_trajectories.png'), ...
    fullfile(dirs.figure_dir, 'figure_02_single_objective_trajectories.svg'));

plot_pareto_hvac(metrics_tbl, pareto_tbl, selected_tbl, ...
    fullfile(dirs.figure_dir, 'figure_03_multi_objective_pareto.png'), ...
    fullfile(dirs.figure_dir, 'figure_03_multi_objective_pareto.svg'));

[robust_long_tbl, robust_summary_tbl] = evaluate_robustness_hvac(cfg, doe_scenarios, single_runs, selected_tbl, block_tbl);
writetable(robust_long_tbl, fullfile(dirs.table_dir, 'robustness_long.csv'));
writetable(robust_summary_tbl, fullfile(dirs.table_dir, 'robustness_summary.csv'));

plot_robustness_hvac(robust_summary_tbl, ...
    fullfile(dirs.figure_dir, 'figure_04_doe_robustness.png'), ...
    fullfile(dirs.figure_dir, 'figure_04_doe_robustness.svg'));

planning = struct();
planning.block_tbl = block_tbl;
planning.metrics_tbl = metrics_tbl;
planning.opt_idx = opt_idx;
planning.single_tbl = single_tbl;
planning.single_runs = single_runs;
planning.pareto_tbl = pareto_tbl;
planning.selected_tbl = selected_tbl;
planning.schedule_tbl = schedule_tbl;
planning.robust_long_tbl = robust_long_tbl;
planning.robust_summary_tbl = robust_summary_tbl;
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

function v = clamp_hvac(v, lo, hi)
v = min(max(v, lo), hi);
end
