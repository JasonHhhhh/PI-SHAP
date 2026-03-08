function out = run_tr_opt_granularity_singleobj_min(action_hours)
if nargin < 1
    action_hours = [0.5 1.5 2.0];
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

stage_dir = fullfile('shap_src_min', 'tr', 'tr_opt_singleobj_granularity');
plot_dir = fullfile(stage_dir, 'plots');
log_dir = fullfile(stage_dir, 'logs');

ensure_dir_min(stage_dir);
reset_dir_contents_min(stage_dir);
ensure_dir_min(plot_dir);
ensure_dir_min(log_dir);

if exist(fullfile('shap_src', 'res_baseline.mat'), 'file') ~= 2
    error('Missing required file: shap_src/res_baseline.mat');
end

S = load(fullfile('shap_src', 'res_baseline.mat'), 'par_tropt');
par_base = S.par_tropt;
ss_ref = load_ss_reference_min();

par_base.ss_start = ss_ref.ss_start;
par_base.ss_terminal = ss_ref.ss_terminal;
par_base.tr.ss_start = ss_ref.ss_start;
par_base.tr.ss_terminal = ss_ref.ss_terminal;
par_base.tr.m.use_init_state = 1;
par_base.tr.m.extension = 0;
par_base.tr.m.econweight = 0;

sim_cfg = default_sim_cfg_min();

action_hours = action_hours(:)';
action_hours = unique(action_hours, 'stable');
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
start_gap_col = nan(n_case, 1);
end_gap_col = nan(n_case, 1);
max_step_col = nan(n_case, 1);
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

    fprintf('\n=== Single-objective TR case dt = %.2f h (optintervals=%d) ===\n', dt_hr, optintervals);

    par_case = par_base;
    par_case.tr.optintervals = optintervals;
    par_case.tr.Nvec = build_nvec_from_opt_min(optintervals);
    par_case.tr.m.econweight = 0;
    par_case.tr.m.use_init_state = 1;
    par_case.tr.m.extension = 0;
    par_case.tr.ss_start = ss_ref.ss_start;
    par_case.tr.ss_terminal = ss_ref.ss_terminal;

    [par_case, solve_meta] = solve_tr_with_retries_min(par_case, log_dir, dt_hr);

    cc_policy = par_case.tr.cc0';
    t_action_hr = linspace(0, 24, size(cc_policy, 1))';

    start_gap = max(abs(cc_policy(1,:) - ss_ref.cc_start));
    end_gap = max(abs(cc_policy(end,:) - ss_ref.cc_end));
    max_step = max(max(abs(diff(cc_policy, 1, 1))));

    sim_eval = run_transient_eval_min(par_case, cc_policy, sim_cfg);

    dt_tag = dt_tag_min(dt_hr);
    save(fullfile(stage_dir, ['case_dt_' dt_tag '.mat']), ...
        'dt_hr', 'optintervals', 'par_case', 'cc_policy', 't_action_hr', ...
        'sim_eval', 'solve_meta', 'start_gap', 'end_gap', 'max_step', ...
        'ss_ref', '-v7.3');

    cases(i).dt_hr = dt_hr;
    cases(i).optintervals = optintervals;
    cases(i).n_actions = size(cc_policy, 1);
    cases(i).nvec = par_case.tr.Nvec;
    cases(i).solve_sec = solve_meta.solve_sec;
    cases(i).status = solve_meta.status;
    cases(i).maxiter_used = solve_meta.maxiter_used;
    cases(i).opt_tol_used = solve_meta.opt_tol_used;
    cases(i).attempt_count = solve_meta.attempt_count;
    cases(i).slack_warn_count = solve_meta.slack_warn_count;
    cases(i).start_gap = start_gap;
    cases(i).end_gap = end_gap;
    cases(i).max_step = max_step;
    cases(i).t_action_hr = t_action_hr;
    cases(i).cc_policy = cc_policy;
    cases(i).sim_eval = sim_eval;

    dt_col(i) = dt_hr;
    opt_col(i) = optintervals;
    na_col(i) = size(cc_policy, 1);
    solve_col(i) = solve_meta.solve_sec;
    status_col(i) = solve_meta.status;
    maxiter_col(i) = solve_meta.maxiter_used;
    tol_col(i) = solve_meta.opt_tol_used;
    attempt_col(i) = solve_meta.attempt_count;
    slack_col(i) = solve_meta.slack_warn_count;
    start_gap_col(i) = start_gap;
    end_gap_col(i) = end_gap;
    max_step_col(i) = max_step;
    jcost_col(i) = sim_eval.Jcost;
    jsupp_col(i) = sim_eval.Jsupp;
    jvar_col(i) = sim_eval.Jvar;

    fprintf('status=%g, solve=%.2fs, nvec=%s\n', solve_meta.status, solve_meta.solve_sec, mat2str(par_case.tr.Nvec));
    fprintf('start_gap=%.3e, end_gap=%.3e, max_step=%.3e\n', start_gap, end_gap, max_step);
    fprintf('Jcost=%.6e, Jsupp=%.6e, Jvar=%.6e\n', sim_eval.Jcost, sim_eval.Jsupp, sim_eval.Jvar);
end

summary_tbl = table( ...
    dt_col, opt_col, na_col, solve_col, status_col, maxiter_col, tol_col, attempt_col, slack_col, ...
    start_gap_col, end_gap_col, max_step_col, jcost_col, jsupp_col, jvar_col, ...
    'VariableNames', { ...
        'ActionDt_hr', 'OptIntervals', 'NActions', 'SolveSec', 'IpoptStatus', ...
        'MaxIterUsed', 'OptTolUsed', 'AttemptCount', 'SlackWarnCount', ...
        'StartGapToSS', 'EndGapToSS', 'MaxStep', 'Jcost', 'Jsupp', 'Jvar'});

writetable(summary_tbl, fullfile(stage_dir, 'singleobj_tr_opt_granularity_summary.csv'));
save(fullfile(stage_dir, 'singleobj_tr_opt_granularity_results.mat'), ...
    'cases', 'summary_tbl', 'action_hours', 'ss_ref', '-v7.3');

plot_action_profiles_min(cases, plot_dir);
plot_transient_process_min(cases, plot_dir);
plot_metrics_min(summary_tbl, plot_dir);
write_summary_md_min(stage_dir, summary_tbl, ss_ref);

out = struct();
out.stage_dir = stage_dir;
out.plot_dir = plot_dir;
out.summary_tbl = summary_tbl;
out.ss_ref = ss_ref;

disp(summary_tbl);
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

function [par_case, meta] = solve_tr_with_retries_min(par_case, log_dir, dt_hr)
dt_tag = dt_tag_min(dt_hr);
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
    par_try.tr.m.econweight = 0;
    par_try.tr.output_file = fullfile(log_dir, sprintf('dt_%s_attempt_%d_ipopt.out', dt_tag, k));

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

function plot_action_profiles_min(cases, plot_dir)
n_case = numel(cases);
n_comp = size(cases(1).cc_policy, 2);
cmap = lines(n_case);
markers = {'o','s','d','^','v','>','<','p','h'};

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1500 900]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

legend_text = arrayfun(@(x) sprintf('dt=%.2fh', x.dt_hr), cases, 'UniformOutput', false);

for comp = 1:n_comp
    ax = nexttile;
    hold on;
    for i = 1:n_case
        mk = markers{mod(i-1, numel(markers))+1};
        plot(cases(i).t_action_hr, cases(i).cc_policy(:,comp), '-', ...
            'Color', cmap(i,:), 'LineWidth', 1.8, 'Marker', mk, 'MarkerSize', 4);
    end
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('Compressor %d action profile', comp));
    grid on;
    legend(legend_text, 'Location', 'best');
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
hold on;
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    plot(cases(i).t_action_hr, mean(cases(i).cc_policy, 2), '-', ...
        'Color', cmap(i,:), 'LineWidth', 1.9, 'Marker', mk, 'MarkerSize', 4);
end
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean action profile');
grid on;
legend(legend_text, 'Location', 'best');
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Single-objective TR action profiles by time granularity', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'singleobj_action_profile_compare.png'), '-dpng', '-r260');
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
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cc_mean, 'Color', cmap(i,:), 'LineWidth', 1.9);
end
xlabel('Time (h)');
ylabel('Mean cc');
title('Compressor ratio trajectory');
grid on;
legend(legend_text, 'Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cost/1e9, 'Color', cmap(i,:), 'LineWidth', 1.9);
end
xlabel('Time (h)');
ylabel('Power (GW)');
title('Transient compressor power');
grid on;
legend(legend_text, 'Location', 'best');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_supp, 'Color', cmap(i,:), 'LineWidth', 1.9);
end
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
legend(legend_text, 'Location', 'best');
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Single-objective transient process by time granularity', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'singleobj_transient_process_compare.png'), '-dpng', '-r260');
close(f);
end

function plot_metrics_min(summary_tbl, plot_dir)
dt_labels = arrayfun(@(x) sprintf('%.2fh', x), summary_tbl.ActionDt_hr, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1250 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
bar(summary_tbl.Jcost);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jcost');
title('Single-objective metric Jcost');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
yyaxis left;
bar(summary_tbl.MaxStep, 0.7);
ylabel('Max |Delta cc|');
yyaxis right;
plot(1:height(summary_tbl), summary_tbl.EndGapToSS, 'ko-', 'LineWidth', 1.4);
ylabel('End gap to SS');
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
title('Control movement and terminal gap');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
bar(summary_tbl.SolveSec);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Solve time (s)');
title('Solve time');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
yyaxis left;
bar(summary_tbl.Jsupp, 0.65);
ylabel('Jsupp');
yyaxis right;
plot(1:height(summary_tbl), summary_tbl.Jvar, 'ko-', 'LineWidth', 1.4);
ylabel('Jvar');
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
title('Non-optimized metrics tracking');
grid on;
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Single-objective TR metrics vs action granularity', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'singleobj_metrics_vs_granularity.png'), '-dpng', '-r260');
close(f);
end

function write_summary_md_min(stage_dir, summary_tbl, ss_ref)
md_file = fullfile(stage_dir, 'singleobj_tr_opt_granularity_summary.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write summary markdown: %s', md_file);
end

fprintf(fid, '# Single-Objective TR Granularity Study\n\n');
fprintf(fid, '- action granularities: `%s` h\n', mat2str(summary_tbl.ActionDt_hr', 6));
fprintf(fid, '- SS reference source: `%s`\n', ss_ref.source);
fprintf(fid, '- SS start cc: `%s`\n', mat2str(ss_ref.cc_start, 10));
fprintf(fid, '- SS terminal cc: `%s`\n\n', mat2str(ss_ref.cc_end, 10));

fprintf(fid, '| dt(h) | NActions | Nvec-final | IPOPT | SolveSec | StartGapToSS | EndGapToSS | MaxStep | Jcost | Jsupp | Jvar |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary_tbl)
    fprintf(fid, '| %.2f | %d | %d | %g | %.3f | %.4e | %.4e | %.4e | %.10g | %.10g | %.10g |\n', ...
        summary_tbl.ActionDt_hr(i), ...
        summary_tbl.NActions(i), ...
        summary_tbl.NActions(i)-1, ...
        summary_tbl.IpoptStatus(i), ...
        summary_tbl.SolveSec(i), ...
        summary_tbl.StartGapToSS(i), ...
        summary_tbl.EndGapToSS(i), ...
        summary_tbl.MaxStep(i), ...
        summary_tbl.Jcost(i), ...
        summary_tbl.Jsupp(i), ...
        summary_tbl.Jvar(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- `singleobj_tr_opt_granularity_summary.csv`\n');
fprintf(fid, '- `singleobj_tr_opt_granularity_results.mat`\n');
fprintf(fid, '- `plots/singleobj_action_profile_compare.png`\n');
fprintf(fid, '- `plots/singleobj_transient_process_compare.png`\n');
fprintf(fid, '- `plots/singleobj_metrics_vs_granularity.png`\n');

fclose(fid);
end

function s = dt_tag_min(dt_hr)
s = strrep(sprintf('%.2f', dt_hr), '.', 'p');
end
