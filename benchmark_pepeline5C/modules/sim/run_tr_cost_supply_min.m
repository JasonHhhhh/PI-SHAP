function out = run_tr_cost_supply_min(supply_weights, action_dt_hr, use_parallel, cfg)
if nargin < 4 || isempty(cfg)
    cfg = struct();
end
cfg = fill_cfg_defaults_min(cfg);

if nargin < 1 || isempty(supply_weights)
    supply_weights = cfg.supply_weights;
end
if nargin < 2 || isempty(action_dt_hr)
    action_dt_hr = 1.0;
end
if nargin < 3 || isempty(use_parallel)
    use_parallel = true;
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

stage_root = fullfile('shap_src_min', 'tr', 'cost_supply');
if isempty(cfg.try_name)
    stage_dir = stage_root;
else
    stage_dir = fullfile(stage_root, cfg.try_name);
end
plot_dir = fullfile(stage_dir, 'plots');
log_dir = fullfile(stage_dir, 'logs');
ensure_dir_min(stage_root);
ensure_dir_min(stage_dir);
if cfg.clear_stage_dir
    reset_dir_contents_min(stage_dir);
end
ensure_dir_min(plot_dir);
ensure_dir_min(log_dir);

baseline_file = fullfile('shap_src', 'res_baseline.mat');
if exist(baseline_file, 'file') ~= 2
    error('Missing required file: shap_src/res_baseline.mat');
end

ss_ref = load_ss_reference_min();

sim_cfg = default_sim_cfg_min();

optintervals_exact = 24 / action_dt_hr;
optintervals = round(optintervals_exact);
if abs(optintervals_exact - optintervals) > 1e-10
    error('24 h horizon is not divisible by action_dt_hr=%.6g h.', action_dt_hr);
end

supply_weights = unique(supply_weights(:)', 'stable');
if any(supply_weights < 0 | supply_weights > 1)
    error('All supply_weights must be in [0,1].');
end

weights_tbl = table((1:numel(supply_weights))', supply_weights(:), (1 - supply_weights(:)), ...
    'VariableNames', {'CaseIndex', 'WSupply', 'WCost'});
writetable(weights_tbl, fullfile(stage_dir, 'weights.csv'));

obj_setup = struct();
obj_setup.supp_obj_sign = cfg.supp_obj_sign;
obj_setup.cost_scale = cfg.cost_scale;
obj_setup.supp_scale = cfg.supp_scale;

anchor_tbl = table();
if cfg.auto_scale_from_extremes
    anchor_weights = unique([0 1], 'stable');
    anchor_cell = cell(numel(anchor_weights), 1);
    for ai = 1:numel(anchor_weights)
        anchor_cell{ai} = run_single_case_min(anchor_weights(ai), action_dt_hr, optintervals, ss_ref, sim_cfg, log_dir, stage_dir, baseline_file, obj_setup, true, 0, 0);
    end
    anchor_cases = vertcat(anchor_cell{:});

    anchor_jc = arrayfun(@(x) x.sim_eval.Jcost, anchor_cases);
    anchor_js = arrayfun(@(x) x.sim_eval.Jsupp, anchor_cases);
    obj_setup.cost_scale = max(max(anchor_jc), eps);
    obj_setup.supp_scale = max(max(anchor_js), eps);

    anchor_tbl = table(anchor_weights(:), (1-anchor_weights(:)), anchor_jc(:), anchor_js(:), ...
        'VariableNames', {'WSupply', 'WCost', 'Jcost', 'Jsupp'});
    writetable(anchor_tbl, fullfile(stage_dir, 'anchors.csv'));
end

n_case = numel(supply_weights);
cases_cell = cell(n_case, 1);

parallel_used = false;
n_workers = 1;
n_cpu = detect_num_cores_min();
target_workers = max(1, floor(n_cpu * cfg.parallel_worker_ratio));
if use_parallel && can_use_parallel_min() && n_case > 1
    try
        p = gcp('nocreate');
        if isempty(p)
            p = parpool('local', target_workers);
        elseif cfg.force_pool_size && p.NumWorkers ~= target_workers
            delete(p);
            p = parpool('local', target_workers);
        end
        parallel_used = true;
        n_workers = p.NumWorkers;
    catch
        parallel_used = false;
        n_workers = 1;
    end
end

if parallel_used
    fprintf('Running cost+supply sweep in parallel (%d workers, target=%d, cpu=%d).\n', n_workers, target_workers, n_cpu);
    parfor i = 1:n_case
        cases_cell{i} = run_single_case_min(supply_weights(i), action_dt_hr, optintervals, ss_ref, sim_cfg, log_dir, stage_dir, baseline_file, obj_setup, false, i, n_case);
    end
else
    fprintf('Running cost+supply sweep in serial mode.\n');
    for i = 1:n_case
        cases_cell{i} = run_single_case_min(supply_weights(i), action_dt_hr, optintervals, ss_ref, sim_cfg, log_dir, stage_dir, baseline_file, obj_setup, false, i, n_case);
    end
end

cases = vertcat(cases_cell{:});
n_case_eff = numel(cases);

w_s_col = nan(n_case_eff, 1);
w_c_col = nan(n_case_eff, 1);
solve_col = nan(n_case_eff, 1);
status_col = nan(n_case_eff, 1);
iter_col = nan(n_case_eff, 1);
maxiter_col = nan(n_case_eff, 1);
tol_col = nan(n_case_eff, 1);
attempt_col = nan(n_case_eff, 1);
slack_col = nan(n_case_eff, 1);
start_gap_col = nan(n_case_eff, 1);
end_gap_col = nan(n_case_eff, 1);
max_step_col = nan(n_case_eff, 1);
jcost_col = nan(n_case_eff, 1);
jsupp_col = nan(n_case_eff, 1);
jvar_col = nan(n_case_eff, 1);

for i = 1:n_case_eff
    c = cases(i);
    w_s_col(i) = c.w_supply;
    w_c_col(i) = c.w_cost;
    solve_col(i) = c.solve_sec;
    status_col(i) = c.status;
    iter_col(i) = c.iter;
    maxiter_col(i) = c.maxiter_used;
    tol_col(i) = c.opt_tol_used;
    attempt_col(i) = c.attempt_count;
    slack_col(i) = c.slack_warn_count;
    start_gap_col(i) = c.start_gap;
    end_gap_col(i) = c.end_gap;
    max_step_col(i) = c.max_step;
    jcost_col(i) = c.sim_eval.Jcost;
    jsupp_col(i) = c.sim_eval.Jsupp;
    jvar_col(i) = c.sim_eval.Jvar;
end

summary_tbl = table( ...
    w_s_col, w_c_col, ...
    repmat(action_dt_hr, n_case_eff, 1), repmat(optintervals, n_case_eff, 1), ...
    repmat(optintervals+1, n_case_eff, 1), ...
    solve_col, status_col, iter_col, maxiter_col, tol_col, attempt_col, slack_col, ...
    start_gap_col, end_gap_col, max_step_col, ...
    jcost_col, jsupp_col, jvar_col, ...
    'VariableNames', { ...
        'WSupply', 'WCost', 'ActionDt_hr', 'OptIntervals', 'NActions', ...
        'SolveSec', 'IpoptStatus', 'IpoptIter', 'MaxIterUsed', 'OptTolUsed', 'AttemptCount', 'SlackWarnCount', ...
        'StartGapToSS', 'EndGapToSS', 'MaxStep', ...
        'Jcost', 'Jsupp', 'Jvar'});

summary_tbl = sortrows(summary_tbl, 'WSupply');

valid = isfinite(summary_tbl.Jcost) & isfinite(summary_tbl.Jsupp);
jc = summary_tbl.Jcost(valid);
js = summary_tbl.Jsupp(valid);
if isempty(jc)
    jc_min = 0; jc_max = 1;
    js_min = 0; js_max = 1;
else
    jc_min = min(jc); jc_max = max(jc);
    js_min = min(js); js_max = max(js);
end

den_c = max(jc_max - jc_min, eps);
den_s = max(js_max - js_min, eps);

summary_tbl.JcostNorm = (summary_tbl.Jcost - jc_min) / den_c;
summary_tbl.JsuppNorm = (summary_tbl.Jsupp - js_min) / den_s;
summary_tbl.WeightedNormScore = summary_tbl.WCost .* summary_tbl.JcostNorm + summary_tbl.WSupply .* (1 - summary_tbl.JsuppNorm);
summary_tbl.IsConverged = summary_tbl.IpoptStatus >= 0;
summary_tbl.IsPareto = false(height(summary_tbl), 1);

conv_idx = find(summary_tbl.IsConverged);
if isempty(conv_idx)
    pareto_tbl = summary_tbl([],:);
else
    pareto_mask = pareto_front_costmin_suppmax_min(summary_tbl.Jcost(conv_idx), summary_tbl.Jsupp(conv_idx));
    summary_tbl.IsPareto(conv_idx(pareto_mask)) = true;
    pareto_tbl = summary_tbl(summary_tbl.IsPareto, :);
end

writetable(summary_tbl, fullfile(stage_dir, 'summary.csv'));
writetable(pareto_tbl, fullfile(stage_dir, 'pareto.csv'));
save(fullfile(stage_dir, 'results.mat'), 'cases', 'summary_tbl', 'pareto_tbl', 'ss_ref', 'supply_weights', 'action_dt_hr', 'cfg', 'obj_setup', 'anchor_tbl', '-v7.3');

plots_ok = false;
if cfg.make_plots
    try
        plot_action_profiles_min(cases, plot_dir);
        plot_transient_process_min(cases, plot_dir);
        plot_metrics_min(summary_tbl, plot_dir);
        plot_pareto_min(summary_tbl, pareto_tbl, plot_dir);
        plots_ok = true;
    catch ME
        warning('Plot generation failed for %s: %s', stage_dir, ME.message);
    end
end
write_summary_md_min(stage_dir, summary_tbl, pareto_tbl, ss_ref, action_dt_hr, cfg, obj_setup, anchor_tbl, n_cpu, target_workers, n_workers, plots_ok);

out = struct();
out.stage_dir = stage_dir;
out.plot_dir = plot_dir;
out.summary_tbl = summary_tbl;
out.pareto_tbl = pareto_tbl;
out.ss_ref = ss_ref;
out.parallel_used = parallel_used;
out.parallel_workers = n_workers;
out.n_cpu = n_cpu;
out.target_workers = target_workers;
out.obj_setup = obj_setup;
out.anchor_tbl = anchor_tbl;

disp(summary_tbl);
if ~isempty(pareto_tbl)
    disp('Pareto points:');
    disp(pareto_tbl(:, {'WSupply','WCost','Jcost','Jsupp','IpoptStatus'}));
end
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

function Nvec = build_nvec_from_opt_min(optintervals)
N_final = optintervals - 1;
if N_final < 1
    Nvec = 0;
    return;
end

if N_final <= 3
    Nvec = N_final;
    return;
end

max_pow = floor(log2(N_final / 2));
if max_pow < 2
    Nvec = [4 N_final];
else
    Nvec = [2.^(2:max_pow) N_final];
end

Nvec = unique(Nvec, 'stable');
end

function tf = can_use_parallel_min()
tf = false;
try
    tf = ~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox');
catch
    tf = false;
end
end

function case_out = run_single_case_min(w_s, action_dt_hr, optintervals, ss_ref, sim_cfg, log_dir, stage_dir, baseline_file, obj_setup, anchor_only, case_idx, n_case)
w_c = 1 - w_s;
if anchor_only
    fprintf('\n=== TR anchor case w_supply=%.3f (w_cost=%.3f), dt=%.2fh ===\n', w_s, w_c, action_dt_hr);
else
    fprintf('\n=== TR cost+supply case w_supply=%.3f (w_cost=%.3f), dt=%.2fh ===\n', w_s, w_c, action_dt_hr);
end

S = load(baseline_file, 'par_tropt');
par_case = S.par_tropt;
par_case.ss_start = ss_ref.ss_start;
par_case.ss_terminal = ss_ref.ss_terminal;
par_case.tr.ss_start = ss_ref.ss_start;
par_case.tr.ss_terminal = ss_ref.ss_terminal;
par_case.tr.optintervals = optintervals;
par_case.tr.Nvec = build_nvec_from_opt_min(optintervals);
par_case.tr.m.econweight = w_s;
par_case.tr.m.supp_obj_sign = obj_setup.supp_obj_sign;
par_case.tr.m.multi_cost_scale = obj_setup.cost_scale;
par_case.tr.m.multi_supp_scale = obj_setup.supp_scale;
par_case.tr.m.use_init_state = 1;
par_case.tr.m.extension = 0;

[par_case, solve_meta] = solve_tr_with_retries_min(par_case, log_dir, action_dt_hr, w_s, obj_setup, anchor_only, case_idx);

cc_policy = par_case.tr.cc0';
t_action_hr = linspace(0, 24, size(cc_policy, 1))';

start_gap = max(abs(cc_policy(1,:) - ss_ref.cc_start));
end_gap = max(abs(cc_policy(end,:) - ss_ref.cc_end));
max_step = max(max(abs(diff(cc_policy, 1, 1))));

sim_eval = run_transient_eval_min(par_case, cc_policy, sim_cfg);

w_tag = w_tag_min(w_s);
if ~anchor_only
    save(fullfile(stage_dir, sprintf('case_%04dof%04d_w%s.mat', case_idx, n_case, w_tag)), ...
        'w_s', 'w_c', 'action_dt_hr', 'optintervals', 'par_case', 'cc_policy', 't_action_hr', ...
        'sim_eval', 'solve_meta', 'start_gap', 'end_gap', 'max_step', 'ss_ref', 'obj_setup', '-v7.3');
end

case_out = struct();
case_out.w_supply = w_s;
case_out.w_cost = w_c;
case_out.dt_hr = action_dt_hr;
case_out.optintervals = optintervals;
case_out.n_actions = size(cc_policy, 1);
case_out.nvec = par_case.tr.Nvec;
case_out.solve_sec = solve_meta.solve_sec;
case_out.status = solve_meta.status;
case_out.iter = solve_meta.iter;
case_out.maxiter_used = solve_meta.maxiter_used;
case_out.opt_tol_used = solve_meta.opt_tol_used;
case_out.attempt_count = solve_meta.attempt_count;
case_out.slack_warn_count = solve_meta.slack_warn_count;
case_out.start_gap = start_gap;
case_out.end_gap = end_gap;
case_out.max_step = max_step;
case_out.t_action_hr = t_action_hr;
case_out.cc_policy = cc_policy;
case_out.sim_eval = sim_eval;

fprintf('status=%g, iter=%g, solve=%.2fs, nvec=%s\n', ...
    solve_meta.status, solve_meta.iter, solve_meta.solve_sec, mat2str(par_case.tr.Nvec));
fprintf('start_gap=%.3e, end_gap=%.3e, max_step=%.3e\n', start_gap, end_gap, max_step);
fprintf('Jcost=%.6e, Jsupp=%.6e, Jvar=%.6e\n', sim_eval.Jcost, sim_eval.Jsupp, sim_eval.Jvar);
end

function [par_case, meta] = solve_tr_with_retries_min(par_case, log_dir, dt_hr, w_supply, obj_setup, anchor_only, case_idx)
dt_tag = dt_tag_min(dt_hr);
w_tag = w_tag_min(w_supply);
case_tag = case_tag_min(case_idx);
retry_plan = [ ...
    400, 1e-6; ...
    800, 1e-4; ...
    1200, 1e-3];

par_best = par_case;
best_status = -999;
best_iter = inf;
best_txt = '';
solve_sec_total = 0;

last_maxiter = retry_plan(end,1);
last_tol = retry_plan(end,2);
last_slack = nan;

for k = 1:size(retry_plan, 1)
    par_try = par_case;
    par_try.tr.m.maxiter = retry_plan(k,1);
    par_try.tr.m.opt_tol = retry_plan(k,2);
    par_try.tr.m.econweight = w_supply;
    par_try.tr.m.supp_obj_sign = obj_setup.supp_obj_sign;
    par_try.tr.m.multi_cost_scale = obj_setup.cost_scale;
    par_try.tr.m.multi_supp_scale = obj_setup.supp_scale;
    if anchor_only
        par_try.tr.output_file = fullfile(log_dir, sprintf('anchor_ws%s_dt_%s_attempt_%d_ipopt.out', w_tag, dt_tag, k));
    else
        par_try.tr.output_file = fullfile(log_dir, sprintf('ws%s_%s_dt_%s_attempt_%d_ipopt.out', w_tag, case_tag, dt_tag, k));
    end

    t0 = tic;
    txt = evalc('par_try.tr = tran_opt_base_shap(par_try.tr);');
    solve_sec_total = solve_sec_total + toc(t0);

    status = get_ipopt_status_min(par_try.tr);
    iter = par_try.tr.ip_info.iter;
    nslack = numel(strfind(txt, 'Slack too small')); %#ok<STREMP>

    if anchor_only
        log_file = fullfile(log_dir, sprintf('anchor_ws%s_dt_%s_attempt_%d.log', w_tag, dt_tag, k));
    else
        log_file = fullfile(log_dir, sprintf('ws%s_%s_dt_%s_attempt_%d.log', w_tag, case_tag, dt_tag, k));
    end
    fid = fopen(log_file, 'w');
    if fid > 0
        fprintf(fid, '%s', txt);
        fclose(fid);
    end

    if status > best_status || (status == best_status && iter < best_iter)
        par_best = par_try;
        best_status = status;
        best_iter = iter;
        best_txt = txt;
    end

    last_maxiter = par_try.tr.m.maxiter;
    last_tol = par_try.tr.m.opt_tol;
    last_slack = nslack;

    if status >= 0
        par_case = par_try;
        meta = struct();
        meta.status = status;
        meta.solve_sec = solve_sec_total;
        meta.maxiter_used = par_try.tr.m.maxiter;
        meta.opt_tol_used = par_try.tr.m.opt_tol;
        meta.attempt_count = k;
        meta.slack_warn_count = nslack;
        meta.iter = iter;
        return;
    end
end

par_case = par_best;
meta = struct();
meta.status = get_ipopt_status_min(par_case.tr);
meta.solve_sec = solve_sec_total;
meta.maxiter_used = last_maxiter;
meta.opt_tol_used = last_tol;
meta.attempt_count = size(retry_plan, 1);
meta.slack_warn_count = last_slack;
meta.iter = par_case.tr.ip_info.iter;

if anchor_only
    log_file = fullfile(log_dir, sprintf('anchor_ws%s_dt_%s_best_fallback.log', w_tag, dt_tag));
else
    log_file = fullfile(log_dir, sprintf('ws%s_%s_dt_%s_best_fallback.log', w_tag, case_tag, dt_tag));
end
fid = fopen(log_file, 'w');
if fid > 0
    fprintf(fid, '%s', best_txt);
    fclose(fid);
end
end

function status = get_ipopt_status_min(tr)
status = nan;
if isfield(tr, 'ip_info') && isfield(tr.ip_info, 'status')
    status = tr.ip_info.status;
end
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

function keep = pareto_front_costmin_suppmax_min(jcost, jsupp)
n = numel(jcost);
keep = true(n,1);
for i = 1:n
    for j = 1:n
        if i == j
            continue;
        end
        if (jcost(j) <= jcost(i) && jsupp(j) >= jsupp(i)) && ...
                (jcost(j) < jcost(i) || jsupp(j) > jsupp(i))
            keep(i) = false;
            break;
        end
    end
end
end

function plot_action_profiles_min(cases, plot_dir)
[~, idx] = sort([cases.w_supply]);
cases = cases(idx);

n_case = numel(cases);
n_comp = size(cases(1).cc_policy, 2);
cmap = turbo(n_case);
markers = {'o','s','d','^','v','>','<','p','h','x','+'};

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1800 920]);
t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

legend_text = arrayfun(@(x) sprintf('w_s=%.2f (status=%g)', x.w_supply, x.status), cases, 'UniformOutput', false);
h_legend = [];

for comp = 1:n_comp
    ax = nexttile;
    hold on;
    h = gobjects(n_case,1);
    for i = 1:n_case
        mk = markers{mod(i-1, numel(markers))+1};
        h(i) = plot(cases(i).t_action_hr, cases(i).cc_policy(:,comp), '-', ...
            'Color', cmap(i,:), 'LineWidth', 1.8, 'Marker', mk, 'MarkerSize', 4);
        scatter(cases(i).t_action_hr(end), cases(i).cc_policy(end,comp), 48, ...
            'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor', 'w', 'LineWidth', 1.2, ...
            'HandleVisibility', 'off');
    end
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('Compressor %d action profile', comp));
    xlim([0 24.2]);
    grid on;
    if comp == 1
        h_legend = h;
    end
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
hold on;
h = gobjects(n_case,1);
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    y = mean(cases(i).cc_policy, 2);
    h(i) = plot(cases(i).t_action_hr, y, '-', ...
        'Color', cmap(i,:), 'LineWidth', 1.9, 'Marker', mk, 'MarkerSize', 4);
    scatter(cases(i).t_action_hr(end), y(end), 48, ...
        'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor', 'w', 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
end
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean action profile (includes final point)');
xlim([0 24.2]);
grid on;
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

if ~isempty(h_legend)
    lgd = legend(h_legend, legend_text, 'Location', 'eastoutside');
    lgd.Layout.Tile = 'east';
end

sgtitle('TR COST+SUPPLY action profiles (weight sweep)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'action.png'), 260);
close(f);
end

function plot_transient_process_min(cases, plot_dir)
[~, idx] = sort([cases.w_supply]);
cases = cases(idx);

n_case = numel(cases);
cmap = turbo(n_case);
legend_text = arrayfun(@(x) sprintf('w_s=%.2f (status=%g)', x.w_supply, x.status), cases, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1600 500]);
t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold on;
h1 = gobjects(n_case,1);
for i = 1:n_case
    h1(i) = plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cc_mean, 'Color', cmap(i,:), 'LineWidth', 1.9);
    scatter(cases(i).sim_eval.t_hr(end), cases(i).sim_eval.m_cc_mean(end), 42, ...
        'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor', 'w', 'LineWidth', 1.1, 'HandleVisibility', 'off');
end
xlabel('Time (h)');
ylabel('Mean cc');
title('Compressor ratio trajectory');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
h2 = gobjects(n_case,1);
for i = 1:n_case
    y = cases(i).sim_eval.m_cost/1e9;
    h2(i) = plot(cases(i).sim_eval.t_hr, y, 'Color', cmap(i,:), 'LineWidth', 1.9);
    scatter(cases(i).sim_eval.t_hr(end), y(end), 42, ...
        'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor', 'w', 'LineWidth', 1.1, 'HandleVisibility', 'off');
end
xlabel('Time (h)');
ylabel('Power (GW)');
title('Transient compressor power');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
hold on;
h3 = gobjects(n_case,1);
for i = 1:n_case
    h3(i) = plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_supp, 'Color', cmap(i,:), 'LineWidth', 1.9);
    scatter(cases(i).sim_eval.t_hr(end), cases(i).sim_eval.m_supp(end), 42, ...
        'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor', 'w', 'LineWidth', 1.1, 'HandleVisibility', 'off');
end
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

lgd = legend(h1, legend_text, 'Location', 'eastoutside');
lgd.Layout.Tile = 'east';

sgtitle('TR COST+SUPPLY transient process (weight sweep)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'transient.png'), 260);
close(f);
end

function plot_metrics_min(summary_tbl, plot_dir)
summary_tbl = sortrows(summary_tbl, 'WSupply');
x = 1:height(summary_tbl);
labels = arrayfun(@(v) sprintf('%.2f', v), summary_tbl.WSupply, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1250 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
yyaxis left;
h11 = plot(x, summary_tbl.Jcost, 'o-', 'LineWidth', 1.6);
ylabel('Jcost');
yyaxis right;
h12 = plot(x, summary_tbl.Jsupp, 's-', 'LineWidth', 1.6);
ylabel('Jsupp');
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
title('Raw objectives vs weight');
grid on;
legend([h11 h12], {'Jcost', 'Jsupp'}, 'Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
h21 = plot(x, summary_tbl.JcostNorm, 'o-', 'LineWidth', 1.6); hold on;
h22 = plot(x, 1 - summary_tbl.JsuppNorm, 's-', 'LineWidth', 1.6);
h23 = plot(x, summary_tbl.WeightedNormScore, 'd-', 'LineWidth', 1.8);
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
ylabel('Normalized value');
title('Normalized objective scales');
legend([h21 h22 h23], {'Jcost norm', '1-Jsupp norm', 'weighted score'}, 'Location', 'best');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
h31 = bar(summary_tbl.SolveSec);
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
ylabel('Solve time (s)');
title('Solve time');
grid on;
legend(h31, {'SolveSec'}, 'Location', 'best');
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
yyaxis left;
h41 = bar(summary_tbl.MaxStep, 0.65);
ylabel('Max |Delta cc|');
yyaxis right;
h42 = plot(x, summary_tbl.EndGapToSS, 'ko-', 'LineWidth', 1.4);
ylabel('End gap to SS');
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
title('Control movement and terminal gap');
grid on;
legend([h41 h42], {'MaxStep', 'EndGapToSS'}, 'Location', 'best');
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR COST+SUPPLY metrics by weight', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'metrics.png'), 260);
close(f);
end

function plot_pareto_min(summary_tbl, pareto_tbl, plot_dir)
summary_tbl = sortrows(summary_tbl, 'WSupply');
f = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 860 620]);

hold on;
cmap = turbo(height(summary_tbl));
h_all = gobjects(height(summary_tbl),1);
for i = 1:height(summary_tbl)
    h_all(i) = scatter(summary_tbl.Jcost(i), summary_tbl.Jsupp(i), 70, cmap(i,:), 'filled');
    text(summary_tbl.Jcost(i), summary_tbl.Jsupp(i), sprintf('  w=%.2f', summary_tbl.WSupply(i)), ...
        'FontSize', 9, 'Color', [0.15 0.15 0.15]);
end

if ~isempty(pareto_tbl)
    p = sortrows(pareto_tbl, 'Jcost');
    plot(p.Jcost, p.Jsupp, 'k-', 'LineWidth', 1.8, 'DisplayName', 'Pareto front');
    scatter(p.Jcost, p.Jsupp, 90, 'ko', 'LineWidth', 1.4, 'DisplayName', 'Pareto points');
end

xlabel('Jcost (lower is better)');
ylabel('Jsupp (higher is better)');
title('Cost-Supply Pareto plane (cost min, supply max)');
grid on;

leg_text = arrayfun(@(v) sprintf('w_{s}=%.2f', v), summary_tbl.WSupply, 'UniformOutput', false);
legend(h_all, leg_text, 'Location', 'bestoutside');

save_plot_png_min(f, fullfile(plot_dir, 'pareto.png'), 260);
close(f);
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

function write_summary_md_min(stage_dir, summary_tbl, pareto_tbl, ss_ref, action_dt_hr, cfg, obj_setup, anchor_tbl, n_cpu, target_workers, n_workers, plots_ok)
md_file = fullfile(stage_dir, 'summary.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write summary markdown: %s', md_file);
end

fprintf(fid, '# TR COST+SUPPLY multi-objective results\n\n');
fprintf(fid, '- time granularity (action interval): `%.2f h`\n', action_dt_hr);
fprintf(fid, '- control points per day (including 24h endpoint): `%d`\n', round(24/action_dt_hr)+1);
fprintf(fid, '- supply objective direction: `maximize supply` (Pareto uses cost min + supply max)\n');
fprintf(fid, '- objective sign config: `supp_obj_sign = %.3g`\n', obj_setup.supp_obj_sign);
fprintf(fid, '- normalized optimization scales: `cost_scale=%.10g`, `supp_scale=%.10g`\n', obj_setup.cost_scale, obj_setup.supp_scale);
fprintf(fid, '- auto scale from extreme anchors: `%d`\n', cfg.auto_scale_from_extremes);
fprintf(fid, '- cpu cores detected: `%d`\n', n_cpu);
fprintf(fid, '- target workers (90%% rule): `%d`\n', target_workers);
fprintf(fid, '- actual workers: `%d`\n', n_workers);
fprintf(fid, '- try name: `%s`\n', cfg.try_name);
fprintf(fid, '- SS reference source: `%s`\n', ss_ref.source);
fprintf(fid, '- SS start cc: `%s`\n', mat2str(ss_ref.cc_start, 10));
fprintf(fid, '- SS terminal cc: `%s`\n\n', mat2str(ss_ref.cc_end, 10));

if ~isempty(anchor_tbl)
    fprintf(fid, '## Anchor scaling cases\n\n');
    fprintf(fid, '| w_supply | w_cost | Jcost | Jsupp |\n');
    fprintf(fid, '|---:|---:|---:|---:|\n');
    for i = 1:height(anchor_tbl)
        fprintf(fid, '| %.2f | %.2f | %.10g | %.10g |\n', anchor_tbl.WSupply(i), anchor_tbl.WCost(i), anchor_tbl.Jcost(i), anchor_tbl.Jsupp(i));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '| w_supply | w_cost | IPOPT | SolveSec | EndGapToSS | MaxStep | Jcost | Jsupp | Jvar | Pareto |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary_tbl)
    fprintf(fid, '| %.2f | %.2f | %g | %.3f | %.4e | %.4e | %.10g | %.10g | %.10g | %d |\n', ...
        summary_tbl.WSupply(i), ...
        summary_tbl.WCost(i), ...
        summary_tbl.IpoptStatus(i), ...
        summary_tbl.SolveSec(i), ...
        summary_tbl.EndGapToSS(i), ...
        summary_tbl.MaxStep(i), ...
        summary_tbl.Jcost(i), ...
        summary_tbl.Jsupp(i), ...
        summary_tbl.Jvar(i), ...
        summary_tbl.IsPareto(i));
end

fprintf(fid, '\n## Pareto points\n\n');
if isempty(pareto_tbl)
    fprintf(fid, '- No converged Pareto points under current solve statuses.\n');
else
    fprintf(fid, '| w_supply | w_cost | Jcost | Jsupp | IPOPT |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|\n');
    for i = 1:height(pareto_tbl)
        fprintf(fid, '| %.2f | %.2f | %.10g | %.10g | %g |\n', ...
            pareto_tbl.WSupply(i), pareto_tbl.WCost(i), pareto_tbl.Jcost(i), pareto_tbl.Jsupp(i), pareto_tbl.IpoptStatus(i));
    end
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- `weights.csv`\n');
if ~isempty(anchor_tbl)
    fprintf(fid, '- `anchors.csv`\n');
end
fprintf(fid, '- `summary.csv`\n');
fprintf(fid, '- `pareto.csv`\n');
fprintf(fid, '- `results.mat`\n');
if plots_ok
    fprintf(fid, '- `plots/action.png`\n');
    fprintf(fid, '- `plots/transient.png`\n');
    fprintf(fid, '- `plots/metrics.png`\n');
    fprintf(fid, '- `plots/pareto.png`\n');
else
    fprintf(fid, '- plots skipped (set `cfg.make_plots = false` or plotting failed)\n');
end

fclose(fid);
end

function cfg = fill_cfg_defaults_min(cfg)
if ~isfield(cfg, 'try_name') || isempty(cfg.try_name)
    cfg.try_name = '';
end
if ~isfield(cfg, 'supply_weights') || isempty(cfg.supply_weights)
    cfg.supply_weights = 0:0.1:0.8;
end
if ~isfield(cfg, 'supp_obj_sign') || isempty(cfg.supp_obj_sign)
    cfg.supp_obj_sign = -1;
end
if ~isfield(cfg, 'cost_scale') || isempty(cfg.cost_scale)
    cfg.cost_scale = 1;
end
if ~isfield(cfg, 'supp_scale') || isempty(cfg.supp_scale)
    cfg.supp_scale = 1;
end
if ~isfield(cfg, 'auto_scale_from_extremes') || isempty(cfg.auto_scale_from_extremes)
    cfg.auto_scale_from_extremes = true;
end
if ~isfield(cfg, 'parallel_worker_ratio') || isempty(cfg.parallel_worker_ratio)
    cfg.parallel_worker_ratio = 0.90;
end
cfg.parallel_worker_ratio = min(max(cfg.parallel_worker_ratio, 0.05), 1.0);
if ~isfield(cfg, 'force_pool_size') || isempty(cfg.force_pool_size)
    cfg.force_pool_size = false;
end
if ~isfield(cfg, 'make_plots') || isempty(cfg.make_plots)
    cfg.make_plots = true;
end
if ~isfield(cfg, 'clear_stage_dir') || isempty(cfg.clear_stage_dir)
    cfg.clear_stage_dir = true;
end
end

function n = detect_num_cores_min()
n = 1;
try
    n = feature('numcores');
catch
    n = 1;
end
if isempty(n) || ~isfinite(n) || n < 1
    n = 1;
end
n = floor(n);
end

function s = dt_tag_min(dt_hr)
s = strrep(sprintf('%.2f', dt_hr), '.', 'p');
end

function s = w_tag_min(w)
s = strrep(sprintf('%.5f', w), '.', 'p');
end

function s = case_tag_min(case_idx)
if nargin < 1 || isempty(case_idx) || ~isfinite(case_idx) || case_idx < 1
    s = 'case_anchor';
    return;
end
s = sprintf('case_%04d', floor(case_idx));
end
