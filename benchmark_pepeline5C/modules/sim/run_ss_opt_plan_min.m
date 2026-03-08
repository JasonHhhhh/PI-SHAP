function out = run_ss_opt_plan_min(mid_stage_counts, make_plots)
if nargin < 1 || isempty(mid_stage_counts)
    mid_stage_counts = [3 7 13];
end
if nargin < 2 || isempty(make_plots)
    make_plots = true;
end

mid_stage_counts = unique(round(mid_stage_counts(:)'), 'stable');
if any(mid_stage_counts < 1)
    error('mid_stage_counts must be positive integers.');
end

sim_dir = fileparts(mfilename('fullpath'));
addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

try
    opengl('software');
catch
end

tr_root = fullfile('shap_src_min', 'tr');
main_dir = fullfile(tr_root, 'ss_opt');
main_plot_dir = fullfile(main_dir, 'plots');

ensure_dir_min(tr_root);
ensure_dir_min(main_dir);
reset_dir_contents_min(main_dir, {'ref-old'});
ensure_dir_min(main_plot_dir);

cfg = case_config_sim();
if exist(cfg.baseline_mat, 'file') ~= 2
    error('Baseline MAT not found: %s', cfg.baseline_mat);
end

S = load(cfg.baseline_mat, 'par');
if ~isfield(S, 'par')
    error('Variable ''par'' not found in %s', cfg.baseline_mat);
end
par_base = S.par;

node_plan = build_ss_node_plan_min();

fprintf('Building SS plan with legacy ss-opt pattern: 24 transient intervals (%d action points).\n', node_plan.n_actions);
fprintf('Stage mid-point counts: %s\n', mat2str(mid_stage_counts));

[ss_pointwise, par_eval] = build_legacy_ss_pattern_min(par_base, node_plan);
writetable(ss_pointwise.node_table, fullfile(main_dir, 'ss_pointwise_nodes.csv'));

sim_cfg = default_sim_cfg_min();

n_plan = 1 + numel(mid_stage_counts);
full_source_idx = 1:size(ss_pointwise.cc_full, 1);
plan_seed = init_plan_struct_min("ss_opt", main_dir, ss_pointwise.cc_full, full_source_idx, ss_pointwise.node_ids, node_plan.n_mid_points);
plans = repmat(plan_seed, n_plan, 1);
plans(1) = plan_seed;

for i = 1:numel(mid_stage_counts)
    n_mid_keep = mid_stage_counts(i);
    [cc_stage, source_idx] = build_stage_policy_min(ss_pointwise.cc_full, n_mid_keep);
    stage_name = sprintf('ss-%dstage', n_mid_keep);
    stage_dir = fullfile(tr_root, stage_name);
    plans(i+1) = init_plan_struct_min(string(stage_name), stage_dir, cc_stage, source_idx, ss_pointwise.node_ids, n_mid_keep);
end

summary_rows = cell(n_plan, 1);

for i = 1:n_plan
    plan = plans(i);

    if plan.name ~= "ss_opt"
        ensure_dir_min(plan.stage_dir);
        reset_dir_contents_min(plan.stage_dir);
    end
    plot_dir = fullfile(plan.stage_dir, 'plots');
    ensure_dir_min(plot_dir);

    t_action_hr = linspace(0, 24, size(plan.cc_policy, 1))';
    sim_eval = run_transient_eval_min(par_eval, plan.cc_policy, sim_cfg);

    start_gap = max(abs(plan.cc_policy(1,:) - ss_pointwise.cc_start));
    end_gap = max(abs(plan.cc_policy(end,:) - ss_pointwise.cc_end));
    max_step = max(max(abs(diff(plan.cc_policy, 1, 1))));

    plan.t_action_hr = t_action_hr;
    plan.sim_eval = sim_eval;
    plan.start_gap = start_gap;
    plan.end_gap = end_gap;
    plan.max_step = max_step;
    plans(i) = plan;

    [summary_one, action_tbl, map_tbl, anchor_tbl] = build_plan_tables_min(plan);
    summary_rows{i} = summary_one;

    writetable(action_tbl, fullfile(plan.stage_dir, 'action_sequence.csv'));
    writetable(map_tbl, fullfile(plan.stage_dir, 'action_source_map.csv'));
    writetable(anchor_tbl, fullfile(plan.stage_dir, 'stage_sampling.csv'));
    writetable(summary_one, fullfile(plan.stage_dir, 'summary.csv'));

    save(fullfile(plan.stage_dir, 'results.mat'), 'plan', 'summary_one', 'ss_pointwise', '-v7.3');

    plan_plots_ok = false;
    if make_plots
        try
            plot_action_single_min(plan, plot_dir);
            plot_transient_single_min(plan, plot_dir);
            plot_metrics_single_min(plan, plot_dir);
            plan_plots_ok = true;
        catch ME
            warning('Plot generation failed for %s: %s', char(plan.name), ME.message);
        end
    end

    write_plan_summary_md_min(plan, summary_one, plan.stage_dir, plan_plots_ok);

    fprintf('[%s] Jcost=%.6e, Jsupp=%.6e, Jvar=%.6e, max_step=%.3e\n', ...
        char(plan.name), sim_eval.Jcost, sim_eval.Jsupp, sim_eval.Jvar, max_step);
end

summary_tbl = vertcat(summary_rows{:});
summary_tbl = sortrows(summary_tbl, 'PlanOrder');

writetable(summary_tbl, fullfile(main_dir, 'summary.csv'));
save(fullfile(main_dir, 'results.mat'), 'plans', 'summary_tbl', 'ss_pointwise', 'node_plan', 'mid_stage_counts', '-v7.3');

compare_plots_ok = false;
if make_plots
    try
        plot_action_compare_min(plans, main_plot_dir);
        plot_transient_compare_min(plans, main_plot_dir);
        plot_metrics_compare_min(summary_tbl, main_plot_dir);
        compare_plots_ok = true;
    catch ME
        warning('Compare-plot generation failed: %s', ME.message);
    end
end

write_main_summary_md_min(main_dir, summary_tbl, ss_pointwise, node_plan, mid_stage_counts, compare_plots_ok);

out = struct();
out.stage_root = tr_root;
out.main_dir = main_dir;
out.summary_tbl = summary_tbl;
out.pointwise = ss_pointwise;
out.plans = plans;

disp(summary_tbl(:, {'PlanName', 'StageMidPoints', 'Jcost', 'Jsupp', 'Jvar', 'MaxStep'}));
end

function node_plan = build_ss_node_plan_min()
all_nodes = 2:4:101;
mid_nodes = all_nodes(2:end-1);

node_plan = struct();
node_plan.start_node = 1;
node_plan.mid_nodes = mid_nodes(:)';
node_plan.terminal_node = 101;
node_plan.n_mid_points = numel(mid_nodes);
node_plan.n_actions = node_plan.n_mid_points + 2;
node_plan.n_intervals = node_plan.n_actions - 1;
end

function [ss_pointwise, par_eval] = build_legacy_ss_pattern_min(par_base, node_plan)
if ~isfield(par_base, 'tr') || ~isfield(par_base.tr, 'cc0')
    error('Baseline par does not contain tr.cc0.');
end

cc_tropt = par_base.tr.cc0';
n_actions = node_plan.n_actions;
n_comp = size(cc_tropt, 2);

cc_ss_legacy = [];
source_mode = "baseline_legacy";
source_file = "shap_src/par_baseline_opt.mat";

candidate_ss_file = fullfile('shap_src', 'par_ss_opt.mat');
if exist(candidate_ss_file, 'file') == 2
    try
        S = load(candidate_ss_file, 'par');
        if isfield(S, 'par')
            cc_candidate = build_ss_sequence_from_par_min(S.par, node_plan, n_comp);
            if size(cc_candidate, 1) == n_actions
                cc_ss_legacy = cc_candidate;
                source_mode = "par_ss_opt_aligned";
                source_file = string(candidate_ss_file);
            end
        end
    catch
    end
end

if isempty(cc_ss_legacy)
    cc_ss_legacy = build_ss_policy_min(par_base);
end

if size(cc_ss_legacy, 1) ~= node_plan.n_actions
    error('Legacy ss-opt action count mismatch: expected %d, got %d.', node_plan.n_actions, size(cc_ss_legacy, 1));
end

cc_ss_legacy(1, :) = cc_tropt(1, :);
cc_ss_legacy(end, :) = cc_tropt(end, :);

node_ids = [node_plan.start_node, node_plan.mid_nodes, node_plan.terminal_node];
seq_idx = (1:node_plan.n_actions)';
role_col = repmat("mid", node_plan.n_actions, 1);
role_col(1) = "start";
role_col(end) = "terminal";

node_table = table(seq_idx, role_col, node_ids(:), repmat(source_mode, node_plan.n_actions, 1), ...
    false(node_plan.n_actions, 1), ...
    'VariableNames', {'SeqIndex', 'Role', 'NodeID', 'SourceMode', 'ResolvedInCurrentRun'});

ss_pointwise = struct();
ss_pointwise.node_ids = node_ids;
ss_pointwise.cc_start = cc_tropt(1, :);
ss_pointwise.cc_end = cc_tropt(end, :);
ss_pointwise.cc_full = cc_ss_legacy;
ss_pointwise.node_table = node_table;
ss_pointwise.total_solve_sec = 0;
ss_pointwise.converged_count = node_plan.n_actions;
ss_pointwise.mode = 'legacy_ss_opt_pattern_with_tr_endpoints';
ss_pointwise.source_mode = char(source_mode);
ss_pointwise.source_file = char(source_file);

par_eval = par_base;
end

function cc_seq = build_ss_sequence_from_par_min(par_ss, node_plan, n_comp)
if ~isstruct(par_ss)
    error('Invalid ss struct.');
end
if ~isfield(par_ss, 'ss_start') || ~isfield(par_ss, 'ss_terminal')
    error('Missing ss_start/ss_terminal in candidate ss struct.');
end

cc_seq = nan(node_plan.n_actions, n_comp);
cc_seq(1, :) = row_cc_from_ss_min(par_ss.ss_start, n_comp);

for i = 1:node_plan.n_mid_points
    fn = sprintf('ss_%d', node_plan.mid_nodes(i));
    if ~isfield(par_ss, fn)
        error('Missing field in candidate ss struct: %s', fn);
    end
    cc_seq(i + 1, :) = row_cc_from_ss_min(par_ss.(fn), n_comp);
end

cc_seq(end, :) = row_cc_from_ss_min(par_ss.ss_terminal, n_comp);
end

function cc_row = row_cc_from_ss_min(ss_node, n_comp)
if ~isfield(ss_node, 'cc0')
    error('Missing cc0 in ss node.');
end
cc_row = ss_node.cc0(:,2)';
if numel(cc_row) ~= n_comp
    error('Compressor count mismatch: expected %d, got %d.', n_comp, numel(cc_row));
end
end

function [ss_pointwise, par_eval] = solve_ss_pointwise_min(par_base, node_plan, log_dir)
if ~isfield(par_base, 'ss')
    error('Baseline par does not contain field ''ss''.');
end

ss_base = par_base.ss;
mid_nodes = node_plan.mid_nodes;
n_mid = numel(mid_nodes);

cc_start = [];
cc_mid = [];
cc_end = [];

ss_mid = cell(n_mid, 1);

seq_idx = (1:(n_mid + 2))';
role_col = strings(n_mid + 2, 1);
node_col = nan(n_mid + 2, 1);
solve_col = nan(n_mid + 2, 1);
status_col = nan(n_mid + 2, 1);
iter_col = nan(n_mid + 2, 1);

solve_slot = 1;

[ss_start, solve_sec, status, iter] = solve_one_ss_node_min(ss_base, node_plan.start_node, log_dir, 'start');
cc_start = ss_start.cc0(:,2)';
role_col(solve_slot) = "start";
node_col(solve_slot) = node_plan.start_node;
solve_col(solve_slot) = solve_sec;
status_col(solve_slot) = status;
iter_col(solve_slot) = iter;
solve_slot = solve_slot + 1;

for i = 1:n_mid
    node_id = mid_nodes(i);
    [ss_mid{i}, solve_sec, status, iter] = solve_one_ss_node_min(ss_base, node_id, log_dir, sprintf('mid_%03d', i));

    if isempty(cc_mid)
        n_comp = numel(ss_mid{i}.cc0(:,2));
        cc_mid = nan(n_mid, n_comp);
    end
    cc_mid(i,:) = ss_mid{i}.cc0(:,2)';

    role_col(solve_slot) = "mid";
    node_col(solve_slot) = node_id;
    solve_col(solve_slot) = solve_sec;
    status_col(solve_slot) = status;
    iter_col(solve_slot) = iter;
    solve_slot = solve_slot + 1;
end

[ss_terminal, solve_sec, status, iter] = solve_one_ss_node_min(ss_base, node_plan.terminal_node, log_dir, 'terminal');
cc_end = ss_terminal.cc0(:,2)';

role_col(solve_slot) = "terminal";
node_col(solve_slot) = node_plan.terminal_node;
solve_col(solve_slot) = solve_sec;
status_col(solve_slot) = status;
iter_col(solve_slot) = iter;

cc_full = [cc_start; cc_mid; cc_end];
node_ids = [node_plan.start_node, mid_nodes, node_plan.terminal_node];

node_table = table(seq_idx, role_col, node_col, solve_col, status_col, iter_col, status_col >= 0, ...
    'VariableNames', {'SeqIndex', 'Role', 'NodeID', 'SolveSec', 'IpoptStatus', 'IpoptIter', 'IsConverged'});

par_eval = par_base;
par_eval.ss_start = ss_start;
par_eval.ss_terminal = ss_terminal;
if isfield(par_eval, 'tr')
    par_eval.tr.ss_start = ss_start;
    par_eval.tr.ss_terminal = ss_terminal;
end

for i = 1:n_mid
    field_name = sprintf('ss_%d', mid_nodes(i));
    par_eval.(field_name) = ss_mid{i};
end

ss_pointwise = struct();
ss_pointwise.ss_start = ss_start;
ss_pointwise.ss_terminal = ss_terminal;
ss_pointwise.ss_mid = ss_mid;
ss_pointwise.mid_nodes = mid_nodes;
ss_pointwise.node_ids = node_ids;
ss_pointwise.cc_start = cc_start;
ss_pointwise.cc_end = cc_end;
ss_pointwise.cc_full = cc_full;
ss_pointwise.node_table = node_table;
ss_pointwise.total_solve_sec = sum(solve_col, 'omitnan');
ss_pointwise.converged_count = sum(status_col >= 0);
end

function [ss_out, solve_sec, status, iter] = solve_one_ss_node_min(ss_base, node_id, log_dir, tag)
ss_work = ss_base;
ss_work.output_file = fullfile(log_dir, sprintf('ss_node_%03d_%s_ipopt.out', node_id, tag));

t0 = tic;
ss_out = static_opt_base_ends(ss_work, node_id);
solve_sec = toc(t0);

status = nan;
iter = nan;
if isfield(ss_out, 'ip_info')
    if isfield(ss_out.ip_info, 'status')
        status = ss_out.ip_info.status;
    end
    if isfield(ss_out.ip_info, 'iter')
        iter = ss_out.ip_info.iter;
    end
end
end

function plan = init_plan_struct_min(plan_name, stage_dir, cc_policy, source_idx, full_node_ids, n_mid_stage)
source_idx = round(source_idx(:)');
n_actions = numel(source_idx);

anchor_action_idx = unique([1, find(diff(source_idx) ~= 0) + 1, n_actions], 'stable');
anchor_src_idx = source_idx(anchor_action_idx);

plan = struct();
plan.name = string(plan_name);
plan.stage_dir = stage_dir;
plan.cc_policy = cc_policy;
plan.source_idx = source_idx;
plan.node_ids = full_node_ids(:)';
plan.anchor_action_idx = anchor_action_idx(:)';
plan.anchor_src_idx = anchor_src_idx(:)';
plan.stage_mid_points = n_mid_stage;
plan.t_action_hr = [];
plan.sim_eval = struct();
plan.start_gap = nan;
plan.end_gap = nan;
plan.max_step = nan;
end

function [cc_stage, source_idx] = build_stage_policy_min(cc_full, n_mid_keep)
n_actions = size(cc_full, 1);
mid_idx = 2:(n_actions - 1);

if n_mid_keep >= numel(mid_idx)
    source_idx = 1:n_actions;
    cc_stage = cc_full;
    return;
end

seed = linspace(mid_idx(1), mid_idx(end), n_mid_keep + 2);
mid_anchor = round(seed(2:end-1));
mid_anchor = unique(mid_anchor, 'stable');

if numel(mid_anchor) < n_mid_keep
    cand = setdiff(mid_idx, mid_anchor, 'stable');
    fill_idx = round(linspace(1, numel(cand), n_mid_keep - numel(mid_anchor)));
    mid_anchor = sort(unique([mid_anchor, cand(fill_idx)]));
end
if numel(mid_anchor) > n_mid_keep
    keep_idx = round(linspace(1, numel(mid_anchor), n_mid_keep));
    mid_anchor = mid_anchor(keep_idx);
end

anchor_src_idx = [1, mid_anchor, n_actions];

source_idx = zeros(1, n_actions);
for i = 1:(numel(anchor_src_idx) - 1)
    source_idx(anchor_src_idx(i):anchor_src_idx(i+1)) = anchor_src_idx(i);
end
source_idx(end) = n_actions;

cc_stage = cc_full(source_idx, :);
end

function [summary_one, action_tbl, map_tbl, anchor_tbl] = build_plan_tables_min(plan)
n_actions = size(plan.cc_policy, 1);
n_comp = size(plan.cc_policy, 2);

comp_names = arrayfun(@(j) sprintf('cc_%d', j), 1:n_comp, 'UniformOutput', false);
action_tbl = array2table([plan.t_action_hr, plan.cc_policy], ...
    'VariableNames', [{'Time_hr'}, comp_names]);

idx = (1:n_actions)';
src_idx = plan.source_idx(:);
src_node = plan.node_ids(src_idx);
is_anchor = ismember(idx, plan.anchor_action_idx(:));
map_tbl = table(idx, plan.node_ids(:), src_idx, src_node(:), is_anchor, ...
    'VariableNames', {'ActionIndex', 'NodeID', 'SourceActionIndex', 'SourceNodeID', 'IsAnchor'});

anchor_action = plan.anchor_action_idx(:);
anchor_src = plan.anchor_src_idx(:);
anchor_node = plan.node_ids(anchor_src(:))';
anchor_time = plan.t_action_hr(anchor_action);
anchor_tbl = table(anchor_action, anchor_time, anchor_src, anchor_node(:), ...
    'VariableNames', {'AnchorActionIndex', 'AnchorTime_hr', 'SourceActionIndex', 'SourceNodeID'});

summary_one = table();
summary_one.PlanName = plan.name;
summary_one.PlanOrder = plan_order_min(plan.name);
summary_one.StageMidPoints = plan.stage_mid_points;
summary_one.NActions = n_actions;
summary_one.NAnchors = numel(plan.anchor_action_idx);
summary_one.StartGapToSS = plan.start_gap;
summary_one.EndGapToSS = plan.end_gap;
summary_one.MaxStep = plan.max_step;
summary_one.Jcost = plan.sim_eval.Jcost;
summary_one.Jsupp = plan.sim_eval.Jsupp;
summary_one.Jvar = plan.sim_eval.Jvar;
summary_one.MeanSupply = mean(plan.sim_eval.m_supp);
summary_one.MeanPowerGW = mean(plan.sim_eval.m_cost / 1e9);
end

function ord = plan_order_min(plan_name)
if plan_name == "ss_opt"
    ord = 0;
    return;
end

name_char = char(plan_name);
tok = regexp(name_char, 'ss-(\d+)stage', 'tokens', 'once');
if isempty(tok)
    ord = 999;
else
    ord = str2double(tok{1});
end
end

function plot_action_single_min(plan, plot_dir)
n_comp = size(plan.cc_policy, 2);
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1500 900]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for comp = 1:n_comp
    nexttile;
    y = plan.cc_policy(:, comp);
    plot(plan.t_action_hr, y, 'b-o', 'LineWidth', 1.8, 'MarkerSize', 4); hold on;
    scatter(plan.t_action_hr(plan.anchor_action_idx), y(plan.anchor_action_idx), 58, ...
        'MarkerEdgeColor', [0.80 0.10 0.10], 'MarkerFaceColor', 'w', 'LineWidth', 1.4);
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('%s compressor %d', upper(char(plan.name)), comp), 'Interpreter', 'none');
    xlim([0 24.2]);
    grid on;
end

nexttile;
y_mean = mean(plan.cc_policy, 2);
plot(plan.t_action_hr, y_mean, 'k-o', 'LineWidth', 1.9, 'MarkerSize', 4); hold on;
scatter(plan.t_action_hr(plan.anchor_action_idx), y_mean(plan.anchor_action_idx), 58, ...
    'MarkerEdgeColor', [0.80 0.10 0.10], 'MarkerFaceColor', 'w', 'LineWidth', 1.4);
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean action profile');
xlim([0 24.2]);
grid on;

sgtitle(sprintf('%s action sequence', upper(char(plan.name))), 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
save_plot_png_min(f, fullfile(plot_dir, 'action.png'), 260);
close(f);
end

function plot_transient_single_min(plan, plot_dir)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1400 430]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(plan.sim_eval.t_hr, plan.sim_eval.m_cc_mean, 'LineWidth', 1.9, 'Color', [0.00 0.45 0.74]);
xlabel('Time (h)');
ylabel('Mean cc');
title('Compressor ratio trajectory');
grid on;

nexttile;
plot(plan.sim_eval.t_hr, plan.sim_eval.m_cost / 1e9, 'LineWidth', 1.9, 'Color', [0.85 0.33 0.10]);
xlabel('Time (h)');
ylabel('Power (GW)');
title('Transient compressor power');
grid on;

nexttile;
plot(plan.sim_eval.t_hr, plan.sim_eval.m_supp, 'LineWidth', 1.9, 'Color', [0.47 0.67 0.19]);
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;

sgtitle(sprintf('%s transient process', upper(char(plan.name))), 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
save_plot_png_min(f, fullfile(plot_dir, 'transient.png'), 260);
close(f);
end

function plot_metrics_single_min(plan, plot_dir)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1100 680]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
bar(plan.sim_eval.Jcost, 0.6);
ylabel('Jcost');
title('Jcost');
grid on;
xticks(1); xticklabels({'this plan'});

nexttile;
bar(plan.sim_eval.Jsupp, 0.6);
ylabel('Jsupp');
title('Jsupp (higher is better)');
grid on;
xticks(1); xticklabels({'this plan'});

nexttile;
bar(plan.sim_eval.Jvar, 0.6);
ylabel('Jvar');
title('Jvar');
grid on;
xticks(1); xticklabels({'this plan'});

nexttile;
yyaxis left;
bar(plan.max_step, 0.55);
ylabel('Max |Delta cc|');
yyaxis right;
plot(1, plan.end_gap, 'ko', 'MarkerSize', 7, 'LineWidth', 1.5);
ylabel('End gap to SS');
title('Control movement and terminal gap');
grid on;
xticks(1); xticklabels({'this plan'});

sgtitle(sprintf('%s metrics', upper(char(plan.name))), 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
save_plot_png_min(f, fullfile(plot_dir, 'metrics.png'), 260);
close(f);
end

function plot_action_compare_min(plans, plot_dir)
n_plan = numel(plans);
n_comp = size(plans(1).cc_policy, 2);
cmap = lines(n_plan);
leg_text = arrayfun(@(p) char(p.name), plans, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1600 930]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for comp = 1:n_comp
    nexttile;
    hold on;
    for i = 1:n_plan
        plot(plans(i).t_action_hr, plans(i).cc_policy(:,comp), 'LineWidth', 1.8, 'Color', cmap(i,:));
    end
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('Compressor %d', comp));
    xlim([0 24.2]);
    grid on;
end

nexttile;
hold on;
for i = 1:n_plan
    plot(plans(i).t_action_hr, mean(plans(i).cc_policy, 2), 'LineWidth', 1.9, 'Color', cmap(i,:));
end
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean action profile');
xlim([0 24.2]);
grid on;
legend(leg_text, 'Location', 'best', 'Interpreter', 'none');

sgtitle('SS plan action sequence comparison', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'action_compare.png'), 260);
close(f);
end

function plot_transient_compare_min(plans, plot_dir)
n_plan = numel(plans);
cmap = lines(n_plan);
leg_text = arrayfun(@(p) char(p.name), plans, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1450 430]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
hold on;
for i = 1:n_plan
    plot(plans(i).sim_eval.t_hr, plans(i).sim_eval.m_cc_mean, 'LineWidth', 1.9, 'Color', cmap(i,:));
end
xlabel('Time (h)');
ylabel('Mean cc');
title('Compressor ratio trajectory');
grid on;

nexttile;
hold on;
for i = 1:n_plan
    plot(plans(i).sim_eval.t_hr, plans(i).sim_eval.m_cost / 1e9, 'LineWidth', 1.9, 'Color', cmap(i,:));
end
xlabel('Time (h)');
ylabel('Power (GW)');
title('Transient compressor power');
grid on;

nexttile;
hold on;
for i = 1:n_plan
    plot(plans(i).sim_eval.t_hr, plans(i).sim_eval.m_supp, 'LineWidth', 1.9, 'Color', cmap(i,:));
end
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
legend(leg_text, 'Location', 'best', 'Interpreter', 'none');

sgtitle('SS plan transient comparison', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'transient_compare.png'), 260);
close(f);
end

function plot_metrics_compare_min(summary_tbl, plot_dir)
summary_tbl = sortrows(summary_tbl, 'PlanOrder');
labels = cellstr(summary_tbl.PlanName);
x = 1:height(summary_tbl);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1250 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
yyaxis left;
plot(x, summary_tbl.Jcost, 'o-', 'LineWidth', 1.6);
ylabel('Jcost');
yyaxis right;
plot(x, summary_tbl.Jsupp, 's-', 'LineWidth', 1.6);
ylabel('Jsupp');
xticks(x);
xticklabels(labels);
xtickangle(15);
title('Jcost / Jsupp');
grid on;

nexttile;
plot(x, summary_tbl.Jvar, 'd-', 'LineWidth', 1.6);
xticks(x);
xticklabels(labels);
xtickangle(15);
ylabel('Jvar');
title('Jvar');
grid on;

nexttile;
bar(x, summary_tbl.MaxStep, 0.65);
xticks(x);
xticklabels(labels);
xtickangle(15);
ylabel('Max |Delta cc|');
title('Control movement');
grid on;

nexttile;
plot(x, summary_tbl.EndGapToSS, 'ko-', 'LineWidth', 1.5);
xticks(x);
xticklabels(labels);
xtickangle(15);
ylabel('End gap to SS');
title('Terminal gap');
grid on;

sgtitle('SS plan metrics comparison', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'metrics_compare.png'), 260);
close(f);
end

function write_plan_summary_md_min(plan, summary_one, stage_dir, plots_ok)
md_file = fullfile(stage_dir, 'summary.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write markdown summary: %s', md_file);
end

fprintf(fid, '# %s plan results\n\n', upper(char(plan.name)));
fprintf(fid, '- stage mid-point count: `%d`\n', plan.stage_mid_points);
fprintf(fid, '- action points: `%d`\n', summary_one.NActions);
fprintf(fid, '- anchors used: `%d`\n', summary_one.NAnchors);
fprintf(fid, '- Jcost: `%.10g`\n', summary_one.Jcost);
fprintf(fid, '- Jsupp: `%.10g` (higher is better)\n', summary_one.Jsupp);
fprintf(fid, '- Jvar: `%.10g`\n', summary_one.Jvar);
fprintf(fid, '- max |Delta cc|: `%.10g`\n', summary_one.MaxStep);
fprintf(fid, '- end gap to SS: `%.10g`\n\n', summary_one.EndGapToSS);

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `action_sequence.csv`\n');
fprintf(fid, '- `action_source_map.csv`\n');
fprintf(fid, '- `stage_sampling.csv`\n');
fprintf(fid, '- `summary.csv`\n');
fprintf(fid, '- `results.mat`\n');
if plots_ok
    fprintf(fid, '- `plots/action.png`\n');
    fprintf(fid, '- `plots/transient.png`\n');
    fprintf(fid, '- `plots/metrics.png`\n');
else
    fprintf(fid, '- plots skipped or failed\n');
end

fclose(fid);
end

function write_main_summary_md_min(main_dir, summary_tbl, ss_pointwise, node_plan, mid_stage_counts, plots_ok)
md_file = fullfile(main_dir, 'summary.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write markdown summary: %s', md_file);
end

fprintf(fid, '# SS stage plan\n\n');
fprintf(fid, '- optimization mode: legacy ss-opt trajectory pattern (prefer `shap_src/par_ss_opt.mat`, fallback `build_ss_policy_min(par_baseline_opt)`)\n');
fprintf(fid, '- endpoint rule: force-align to transient optimization start/end actions\n');
fprintf(fid, '- transient intervals: `%d`\n', node_plan.n_intervals);
fprintf(fid, '- action points: `%d`\n', node_plan.n_actions);
fprintf(fid, '- middle points for pattern shaping: `%d`\n', node_plan.n_mid_points);
fprintf(fid, '- stage middle-point settings: `%s`\n', mat2str(mid_stage_counts));
fprintf(fid, '- source mode: `%s`\n\n', ss_pointwise.mode);
fprintf(fid, '- sequence source: `%s`\n', ss_pointwise.source_file);
fprintf(fid, '- sequence source mode: `%s`\n\n', ss_pointwise.source_mode);

summary_tbl = sortrows(summary_tbl, 'PlanOrder');
fprintf(fid, '| Plan | MidPoints | Anchors | Jcost | Jsupp | Jvar | MaxStep | EndGapToSS |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary_tbl)
    fprintf(fid, '| %s | %d | %d | %.10g | %.10g | %.10g | %.10g | %.10g |\n', ...
        char(summary_tbl.PlanName(i)), ...
        summary_tbl.StageMidPoints(i), ...
        summary_tbl.NAnchors(i), ...
        summary_tbl.Jcost(i), ...
        summary_tbl.Jsupp(i), ...
        summary_tbl.Jvar(i), ...
        summary_tbl.MaxStep(i), ...
        summary_tbl.EndGapToSS(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- `ss_pointwise_nodes.csv`\n');
fprintf(fid, '- `summary.csv`\n');
fprintf(fid, '- `results.mat`\n');
if plots_ok
    fprintf(fid, '- `plots/action_compare.png`\n');
    fprintf(fid, '- `plots/transient_compare.png`\n');
    fprintf(fid, '- `plots/metrics_compare.png`\n');
end

fclose(fid);
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

function sim_eval = run_transient_eval_min(par_case, cc_policy, sim_cfg)
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
t_hr = linspace(0, 24, n_t)';

sim_eval = struct();
sim_eval.t_hr = t_hr;
sim_eval.m_cc_mean = mean(par_sim.tr.m_cc, 2);
sim_eval.m_cost = par_sim.tr.m_cost;
sim_eval.m_supp = par_sim.tr.m_supp;
sim_eval.Jcost = sum(par_sim.tr.shap.ori_Jcost);
sim_eval.Jsupp = par_sim.tr.shap.ori_Jsupp;
sim_eval.Jvar = par_sim.tr.shap.ori_Jvar;
end

function save_plot_png_min(fig_handle, out_file, dpi)
if nargin < 3 || isempty(dpi)
    dpi = 260;
end
set(fig_handle, 'Renderer', 'painters');
set(fig_handle, 'InvertHardcopy', 'off');
drawnow('nocallbacks');
print(fig_handle, out_file, '-dpng', sprintf('-r%d', dpi), '-painters');
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_min(path_str, keep_names)
if nargin < 2
    keep_names = {};
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
    if any(strcmp(name, keep_names))
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
