function out = run_tr_opt_granularity_min(action_hours)
if nargin < 1
    action_hours = [0.25 0.5 1.0 1.5 2.0];
end

sim_dir = fileparts(mfilename('fullpath'));
stage_dir = fullfile('shap_src_min', 'sim', 'tr_opt_granularity');
plot_dir = fullfile(stage_dir, 'plots');

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

if exist(stage_dir, 'dir') ~= 7
    mkdir(stage_dir);
end
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end

try
    opengl('software');
catch
end

par_base = load_base_for_tr_min();
if ~isfield(par_base, 'ss_start') || ~isfield(par_base, 'ss_terminal')
    par_base = run_case_ss_opt();
end

cc_start_ref = par_base.ss_start.cc0(:,2)';
cc_end_ref = par_base.ss_terminal.cc0(:,2)';

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

n_case = numel(action_hours);
cases = repmat(struct(), n_case, 1);

dt_col = nan(n_case, 1);
opt_col = nan(n_case, 1);
na_col = nan(n_case, 1);
solve_col = nan(n_case, 1);
status_col = nan(n_case, 1);
maxiter_col = nan(n_case, 1);
tol_col = nan(n_case, 1);
attempt_col = nan(n_case, 1);
slack_col = nan(n_case, 1);
start_raw_col = nan(n_case, 1);
end_raw_col = nan(n_case, 1);
start_col = nan(n_case, 1);
end_col = nan(n_case, 1);
jcost_col = nan(n_case, 1);
jsupp_col = nan(n_case, 1);
jvar_col = nan(n_case, 1);

for i = 1:n_case
    dt_hr = action_hours(i);
    optintervals_exact = 24 / dt_hr;
    optintervals = round(optintervals_exact);

    if abs(optintervals_exact - optintervals) > 1e-10
        error('24 h horizon is not divisible by dt=%.6g h.', dt_hr);
    end

    fprintf('\n=== TR case dt = %.2f h (optintervals=%d) ===\n', dt_hr, optintervals);

    par_case = par_base;
    par_case.tr.optintervals = optintervals;
    par_case.tr.m.extension = 0;
    par_case.tr.Nvec = build_nvec_from_opt_min(optintervals);
    par_case.tr.m.use_init_state = 1;
    par_case.tr.ss_start = par_base.ss_start;
    par_case.tr.ss_terminal = par_base.ss_terminal;

    [par_case, solve_meta] = solve_tr_with_retries_min(par_case, stage_dir, dt_hr);
    solve_sec = solve_meta.solve_sec;
    status = solve_meta.status;

    cc_policy_raw = par_case.tr.cc0';
    cc_policy = cc_policy_raw;
    cc_policy(1,:) = cc_start_ref;
    cc_policy(end,:) = cc_end_ref;

    t_action_hr = linspace(0, 24, size(cc_policy, 1))';
    start_err_raw = max(abs(cc_policy_raw(1,:) - cc_start_ref));
    end_err_raw = max(abs(cc_policy_raw(end,:) - cc_end_ref));
    start_err = max(abs(cc_policy(1,:) - cc_start_ref));
    end_err = max(abs(cc_policy(end,:) - cc_end_ref));

    sim_eval = run_transient_eval_min(par_case, cc_policy, sim_cfg);

    dt_tag = dt_tag_min(dt_hr);
    save(fullfile(stage_dir, ['case_dt_' dt_tag '.mat']), ...
        'dt_hr', 'optintervals', 'par_case', 'cc_policy_raw', 'cc_policy', 't_action_hr', ...
        'sim_eval', 'solve_sec', 'status', 'start_err_raw', 'end_err_raw', 'start_err', 'end_err', '-v7.3');

    cases(i).dt_hr = dt_hr;
    cases(i).optintervals = optintervals;
    cases(i).n_actions = size(cc_policy, 1);
    cases(i).nvec = par_case.tr.Nvec;
    cases(i).solve_sec = solve_sec;
    cases(i).status = status;
    cases(i).maxiter_used = solve_meta.maxiter_used;
    cases(i).opt_tol_used = solve_meta.opt_tol_used;
    cases(i).attempt_count = solve_meta.attempt_count;
    cases(i).slack_warn_count = solve_meta.slack_warn_count;
    cases(i).start_err_raw = start_err_raw;
    cases(i).end_err_raw = end_err_raw;
    cases(i).start_err = start_err;
    cases(i).end_err = end_err;
    cases(i).t_action_hr = t_action_hr;
    cases(i).cc_policy_raw = cc_policy_raw;
    cases(i).cc_policy = cc_policy;
    cases(i).sim_eval = sim_eval;

    dt_col(i) = dt_hr;
    opt_col(i) = optintervals;
    na_col(i) = size(cc_policy, 1);
    solve_col(i) = solve_sec;
    status_col(i) = status;
    maxiter_col(i) = solve_meta.maxiter_used;
    tol_col(i) = solve_meta.opt_tol_used;
    attempt_col(i) = solve_meta.attempt_count;
    slack_col(i) = solve_meta.slack_warn_count;
    start_raw_col(i) = start_err_raw;
    end_raw_col(i) = end_err_raw;
    start_col(i) = start_err;
    end_col(i) = end_err;
    jcost_col(i) = sim_eval.Jcost;
    jsupp_col(i) = sim_eval.Jsupp;
    jvar_col(i) = sim_eval.Jvar;

    fprintf('status=%g, solve=%.2fs, maxiter=%g, tol=%g, attempts=%g, raw_end_err=%.3e\n', ...
        status, solve_sec, solve_meta.maxiter_used, solve_meta.opt_tol_used, solve_meta.attempt_count, end_err_raw);
    fprintf('Jcost=%.6e, Jsupp=%.6e, Jvar=%.6e\n', ...
        sim_eval.Jcost, sim_eval.Jsupp, sim_eval.Jvar);
end

summary_tbl = table( ...
    dt_col, ...
    opt_col, ...
    na_col, ...
    solve_col, ...
    status_col, ...
    maxiter_col, ...
    tol_col, ...
    attempt_col, ...
    slack_col, ...
    start_raw_col, ...
    end_raw_col, ...
    start_col, ...
    end_col, ...
    jcost_col, ...
    jsupp_col, ...
    jvar_col, ...
    'VariableNames', { ...
        'ActionDt_hr', 'OptIntervals', 'NActions', 'SolveSec', 'IpoptStatus', ...
        'MaxIterUsed', 'OptTolUsed', 'AttemptCount', 'SlackWarnCount', ...
        'StartErrRaw', 'EndErrRaw', 'StartErr', 'EndErr', 'Jcost', 'Jsupp', 'Jvar'});

writetable(summary_tbl, fullfile(stage_dir, 'tr_opt_granularity_summary.csv'));
save(fullfile(stage_dir, 'tr_opt_granularity_results.mat'), 'cases', 'summary_tbl', 'action_hours', '-v7.3');

plot_action_profiles_min(cases, plot_dir);
plot_transient_process_min(cases, plot_dir);
plot_metrics_min(summary_tbl, plot_dir);

out = struct();
out.stage_dir = stage_dir;
out.plot_dir = plot_dir;
out.summary_tbl = summary_tbl;

disp(summary_tbl);
end

function par_base = load_base_for_tr_min()
stage_mat = fullfile('shap_src_min', 'sim', 'ss_opt_stage', 'par_ss_opt_stage.mat');
if exist(stage_mat, 'file') == 2
    S = load(stage_mat, 'par');
    par_base = S.par;
    return;
end

baseline_mat = fullfile('shap_src', 'par_baseline_opt.mat');
if exist(baseline_mat, 'file') == 2
    S = load(baseline_mat, 'par');
    par_base = S.par;
    return;
end

par_base = run_case_ss_opt();
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

function status = get_ipopt_status_min(tr)
status = nan;
if isfield(tr, 'ip_info') && isfield(tr.ip_info, 'status')
    status = tr.ip_info.status;
end
end

function [par_case, meta] = solve_tr_with_retries_min(par_case, stage_dir, dt_hr)
dt_tag = dt_tag_min(dt_hr);
log_dir = fullfile(stage_dir, 'logs');
if exist(log_dir, 'dir') ~= 7
    mkdir(log_dir);
end

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

    t0 = tic;
    txt = evalc('par_try.tr = tran_opt_base_shap(par_try.tr);');
    solve_sec_total = solve_sec_total + toc(t0);

    status = get_ipopt_status_min(par_try.tr);
    iter = par_try.tr.ip_info.iter;
    nslack = numel(strfind(txt, 'Slack too small')); %#ok<STREMP>

    log_file = fullfile(log_dir, sprintf('dt_%s_attempt_%d.log', dt_tag, k));
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

log_file = fullfile(log_dir, sprintf('dt_%s_best_fallback.log', dt_tag));
fid = fopen(log_file, 'w');
if fid > 0
    fprintf(fid, '%s', best_txt);
    fclose(fid);
end
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
sim_eval.m_cc = par_sim.tr.m_cc;
sim_eval.m_cc_mean = mean(par_sim.tr.m_cc, 2);
sim_eval.m_cost = par_sim.tr.m_cost;
sim_eval.m_supp = par_sim.tr.m_supp;
sim_eval.m_mass = par_sim.tr.m_mass;
sim_eval.Jcost = sum(par_sim.tr.shap.ori_Jcost);
sim_eval.Jsupp = par_sim.tr.shap.ori_Jsupp;
sim_eval.Jvar = par_sim.tr.shap.ori_Jvar;
end

function plot_action_profiles_min(cases, plot_dir)
n_case = numel(cases);
n_comp = size(cases(1).cc_policy, 2);
cmap = lines(n_case);
markers = {'o','s','d','^','v','>','<','p','h'};

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1500 900]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

legend_text = arrayfun(@(x) sprintf('dt=%.2fh', x.dt_hr), cases, 'UniformOutput', false);

for comp = 1:n_comp
    ax = nexttile;
    hold on;
    for i = 1:n_case
        mk = markers{mod(i-1, numel(markers))+1};
        plot(cases(i).t_action_hr, cases(i).cc_policy(:,comp), '-', ...
            'Color', cmap(i,:), 'LineWidth', 1.6, 'Marker', mk, 'MarkerSize', 4);
    end
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('Compressor %d action profile', comp));
    grid on;
    legend(legend_text, 'Location', 'best', 'Box', 'on');
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
hold on;
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    plot(cases(i).t_action_hr, mean(cases(i).cc_policy, 2), '-', ...
        'Color', cmap(i,:), 'LineWidth', 1.8, 'Marker', mk, 'MarkerSize', 4);
end
xlabel('Time (h)');
ylabel('Mean cc');
title('Mean action profile');
grid on;
legend(legend_text, 'Location', 'best');
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR optimization actions under different time granularities', ...
    'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'action_profile_compare.png'), '-dpng', '-r260');
close(f);
end

function plot_transient_process_min(cases, plot_dir)
n_case = numel(cases);
cmap = lines(n_case);
legend_text = arrayfun(@(x) sprintf('dt=%.2fh', x.dt_hr), cases, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1400 430]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cc_mean, ...
        'Color', cmap(i,:), 'LineWidth', 1.9);
end
xlabel('Time (h)');
ylabel('Mean cc (sim)');
title('Compressor ratio trajectory');
grid on;
legend(legend_text, 'Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cost/1e9, ...
        'Color', cmap(i,:), 'LineWidth', 1.9);
end
xlabel('Time (h)');
ylabel('Mean power (GW)');
title('Transient compressor power');
grid on;
legend(legend_text, 'Location', 'best', 'Box', 'on');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_supp, ...
        'Color', cmap(i,:), 'LineWidth', 1.9);
end
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
legend(legend_text, 'Location', 'best', 'Box', 'on');
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Transient process comparison by action granularity', ...
    'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'transient_process_compare.png'), '-dpng', '-r260');
close(f);
end

function plot_metrics_min(summary_tbl, plot_dir)
dt_labels = arrayfun(@(x) sprintf('%.2fh', x), summary_tbl.ActionDt_hr, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1200 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
bar(summary_tbl.Jcost);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jcost');
title('Total energy metric Jcost');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
bar(summary_tbl.Jsupp);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jsupp');
title('Supply metric Jsupp');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
bar(summary_tbl.Jvar);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jvar');
title('Variation metric Jvar');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
yyaxis left;
bar(summary_tbl.SolveSec, 0.65);
ylabel('Solve time (s)');
yyaxis right;
plot(1:height(summary_tbl), summary_tbl.IpoptStatus, 'ko-', 'LineWidth', 1.4);
ylabel('IPOPT status');
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
title('Solve effort and status');
grid on;
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Performance vs action time granularity', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'metrics_vs_granularity.png'), '-dpng', '-r260');
close(f);
end

function s = dt_tag_min(dt_hr)
s = strrep(sprintf('%.2f', dt_hr), '.', 'p');
end
