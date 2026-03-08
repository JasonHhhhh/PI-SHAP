function out = run_tr_opt_1_compare_singleobj()
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
case_dir = fullfile(tr_root, 'tr_opt_1');
plot_dir = fullfile(case_dir, 'plots');
log_dir = fullfile(case_dir, 'logs');
ss_sync_dir = fullfile('shap_src_min', 'ss');

ensure_dir_min(tr_root);
ensure_dir_min(case_dir);
ensure_dir_min(plot_dir);
ensure_dir_min(log_dir);
ensure_dir_min(ss_sync_dir);

reset_dir_contents_min(case_dir);
ensure_dir_min(plot_dir);
ensure_dir_min(log_dir);

reset_dir_contents_min(ss_sync_dir);

copyfile(fullfile('shap_src', 'par_ss_opt.mat'), fullfile(ss_sync_dir, 'par_ss_opt_old.mat'));

S = load(fullfile('shap_src', 'res_baseline.mat'), 'par_tropt');
par_old = S.par_tropt;

ss_ref = load_ss_reference_min();
par_ss_old = ss_ref.par;

save(fullfile(ss_sync_dir, 'par_ss_opt_synced.mat'), 'par_ss_old', '-v7.3');
write_ss_sync_summary_min(par_ss_old, ss_ref.source, ss_sync_dir);

par_new = par_old;
par_new.ss_start = par_ss_old.ss_start;
par_new.ss_terminal = par_ss_old.ss_terminal;
par_new.tr.ss_start = par_ss_old.ss_start;
par_new.tr.ss_terminal = par_ss_old.ss_terminal;
par_new.tr.m.use_init_state = 1;
par_new.tr.m.extension = 0;
par_new.tr.optintervals = 24;
par_new.tr.Nvec = [4 8 23];
par_new.tr.m.econweight = 0;

[par_new, solve_meta] = solve_tr_with_retries_1h_min(par_new, log_dir);

cc_old_raw = par_old.tr.cc0';
cc_new_raw = par_new.tr.cc0';

cc_start = par_ss_old.ss_start.cc0(:,2)';
cc_end = par_ss_old.ss_terminal.cc0(:,2)';

% No hard step-rate constraint in this run.
cc_old = cc_old_raw;
cc_new = cc_new_raw;

sim_cfg = default_sim_cfg_min();
sim_old = run_transient_eval_min(par_old, cc_old, sim_cfg);
sim_new = run_transient_eval_min(par_new, cc_new, sim_cfg);

n_comp = size(cc_new, 2);
comp_id = (1:n_comp)';
max_step_old = max(abs(diff(cc_old, 1, 1)), [], 1)';
max_step_new = max(abs(diff(cc_new, 1, 1)), [], 1)';
rmse_raw = sqrt(mean((cc_new_raw - cc_old_raw).^2, 1))';

cmp_tbl = table( ...
    comp_id, ...
    cc_start(:), ...
    cc_end(:), ...
    max_step_old, ...
    max_step_new, ...
    rmse_raw, ...
    'VariableNames', { ...
        'CompID', 'CCStart', 'CCEnd', ...
        'MaxStepOld', 'MaxStepNew', 'RMSEOldVsNew'});

summary_tbl = table( ...
    ["old_raw"; "new_raw"], ...
    [sim_old.Jcost; sim_new.Jcost], ...
    [sim_old.Jsupp; sim_new.Jsupp], ...
    [sim_old.Jvar; sim_new.Jvar], ...
    [max(max_step_old); max(max_step_new)], ...
    [max(abs(cc_old(2,:) - cc_old(1,:))); max(abs(cc_new(2,:) - cc_new(1,:)))], ...
    [max(abs(cc_old(end,:) - cc_old(end-1,:))); max(abs(cc_new(end,:) - cc_new(end-1,:)))], ...
    'VariableNames', {'Policy', 'Jcost', 'Jsupp', 'Jvar', 'MaxStep', 'BoundarySlopeStart', 'BoundarySlopeEnd'});

writetable(cmp_tbl, fullfile(case_dir, 'policy_compare_by_comp.csv'));
writetable(summary_tbl, fullfile(case_dir, 'policy_compare_summary.csv'));

plot_action_compare_min(cc_old, cc_new, cc_start, cc_end, fullfile(plot_dir, 'tr_opt_1_action_compare.png'));
plot_transient_compare_min(sim_old, sim_new, fullfile(plot_dir, 'tr_opt_1_transient_compare.png'));
write_case_summary_md_min(case_dir, solve_meta, summary_tbl, cmp_tbl);

save(fullfile(case_dir, 'tr_opt_1_compare.mat'), ...
    'par_old', 'par_new', 'par_ss_old', ...
    'cc_old_raw', 'cc_new_raw', 'cc_old', 'cc_new', ...
    'cmp_tbl', 'summary_tbl', ...
    'sim_old', 'sim_new', 'solve_meta', '-v7.3');

out = struct();
out.case_dir = case_dir;
out.ss_sync_dir = ss_sync_dir;
out.compare_table = cmp_tbl;
out.summary_table = summary_tbl;
out.solve_meta = solve_meta;

disp(summary_tbl);
disp(cmp_tbl);
disp(['Saved TR 1h comparison artifacts to: ' case_dir]);
disp(['Synced old SS artifacts to: ' ss_sync_dir]);
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

function write_ss_sync_summary_min(par_ss_old, ss_source, ss_sync_dir)
cc_start = par_ss_old.ss_start.cc0(:,2);
cc_end = par_ss_old.ss_terminal.cc0(:,2);
abs_diff = abs(cc_end - cc_start);

tbl = table((1:numel(cc_start))', cc_start, cc_end, abs_diff, ...
    'VariableNames', {'CompID', 'CCStart', 'CCEnd', 'AbsDiff'});
writetable(tbl, fullfile(ss_sync_dir, 'ss_start_end_old.csv'));

fid = fopen(fullfile(ss_sync_dir, 'ss_sync_summary.md'), 'w');
if fid < 0
    error('Cannot write SS sync summary markdown.');
end

fprintf(fid, '# Synced Old SS Result\n\n');
fprintf(fid, '- source: `%s`\n', ss_source);
fprintf(fid, '- synced folder: `shap_src_min/ss`\n\n');
fprintf(fid, '| CompID | Start | End | AbsDiff |\n');
fprintf(fid, '|---:|---:|---:|---:|\n');
for i = 1:height(tbl)
    fprintf(fid, '| %d | %.10g | %.10g | %.10g |\n', ...
        tbl.CompID(i), tbl.CCStart(i), tbl.CCEnd(i), tbl.AbsDiff(i));
end

fclose(fid);
end

function [par_case, meta] = solve_tr_with_retries_1h_min(par_case, log_dir)
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
    par_try.tr.output_file = fullfile(log_dir, sprintf('ipopt_attempt_%d.out', k));

    t0 = tic;
    txt = evalc('par_try.tr = tran_opt_base_shap(par_try.tr);');
    solve_sec_total = solve_sec_total + toc(t0);

    status = get_ipopt_status_min(par_try.tr);
    iter = par_try.tr.ip_info.iter;
    nslack = numel(strfind(txt, 'Slack too small')); %#ok<STREMP>

    log_file = fullfile(log_dir, sprintf('attempt_%d.log', k));
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

log_file = fullfile(log_dir, 'best_fallback.log');
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

function plot_action_compare_min(cc_old, cc_new, cc_start, cc_end, out_png)
n_comp = size(cc_new, 2);
t_hr = linspace(0, 24, size(cc_new, 1))';

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1450 820]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:n_comp
    ax = nexttile;
    plot(t_hr, cc_old(:,j), '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.9); hold on;
    plot(t_hr, cc_new(:,j), '-', 'Color', [0.85 0.25 0.1], 'LineWidth', 2.0);
    yline(cc_start(j), '-.', 'Color', [0.0 0.45 0.74], 'LineWidth', 1.0);
    yline(cc_end(j), '-.', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.0);
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', j));
    title(sprintf('Compressor %d', j));
    grid on;
    if j == 1
        legend({'old', 'new', 'start', 'end'}, 'Location', 'best');
    end
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
plot(t_hr, mean(cc_old, 2), '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.9); hold on;
plot(t_hr, mean(cc_new, 2), '-', 'Color', [0.85 0.25 0.1], 'LineWidth', 2.0);
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean compressor ratio');
grid on;
legend({'old', 'new'}, 'Location', 'best');
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR 1h single-objective policy comparison (old vs new)', 'FontSize', 14, 'FontWeight', 'bold');
print(f, out_png, '-dpng', '-r260');
close(f);
end

function plot_transient_compare_min(sim_old, sim_new, out_png)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1350 430]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot(sim_old.t_hr, sim_old.m_cc_mean, '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 2.0); hold on;
plot(sim_new.t_hr, sim_new.m_cc_mean, '-', 'Color', [0.85 0.25 0.1], 'LineWidth', 2.0);
xlabel('Time (h)');
ylabel('Mean cc');
title('Compressor ratio trajectory');
grid on;
legend({'old', 'new'}, 'Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
plot(sim_old.t_hr, sim_old.m_cost / 1e9, '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 2.0); hold on;
plot(sim_new.t_hr, sim_new.m_cost / 1e9, '-', 'Color', [0.85 0.25 0.1], 'LineWidth', 2.0);
xlabel('Time (h)');
ylabel('Power (GW)');
title('Transient compressor power');
grid on;
legend({'old', 'new'}, 'Location', 'best');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
plot(sim_old.t_hr, sim_old.m_supp, '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 2.0); hold on;
plot(sim_new.t_hr, sim_new.m_supp, '-', 'Color', [0.85 0.25 0.1], 'LineWidth', 2.0);
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
legend({'old', 'new'}, 'Location', 'best');
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR 1h transient process comparison', 'FontSize', 14, 'FontWeight', 'bold');
print(f, out_png, '-dpng', '-r260');
close(f);
end

function write_case_summary_md_min(case_dir, solve_meta, summary_tbl, cmp_tbl)
md_file = fullfile(case_dir, 'tr_opt_1_summary.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write TR opt 1 summary markdown.');
end

fprintf(fid, '# TR 1h Single-Objective New vs Old\n\n');
fprintf(fid, '## Solve meta\n\n');
fprintf(fid, '- IPOPT status: `%g`\n', solve_meta.status);
fprintf(fid, '- iter: `%g`\n', solve_meta.iter);
fprintf(fid, '- solve sec: `%.3f`\n', solve_meta.solve_sec);
fprintf(fid, '- attempts: `%g`\n', solve_meta.attempt_count);
fprintf(fid, '- maxiter used: `%g`\n', solve_meta.maxiter_used);
fprintf(fid, '- opt_tol used: `%g`\n', solve_meta.opt_tol_used);
fprintf(fid, '- slack warning count: `%g`\n\n', solve_meta.slack_warn_count);
fprintf(fid, '- hard step-rate constraint: `off`\n\n');

fprintf(fid, '## Policy summary\n\n');
fprintf(fid, '| Policy | Jcost | Jsupp | Jvar | MaxStep | BoundarySlopeStart | BoundarySlopeEnd |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary_tbl)
    fprintf(fid, '| %s | %.10g | %.10g | %.10g | %.10g | %.10g | %.10g |\n', ...
        summary_tbl.Policy(i), ...
        summary_tbl.Jcost(i), ...
        summary_tbl.Jsupp(i), ...
        summary_tbl.Jvar(i), ...
        summary_tbl.MaxStep(i), ...
        summary_tbl.BoundarySlopeStart(i), ...
        summary_tbl.BoundarySlopeEnd(i));
end

fprintf(fid, '\n## Compressor-level comparison\n\n');
fprintf(fid, '| CompID | MaxStepOld | MaxStepNew | RMSEOldVsNew |\n');
fprintf(fid, '|---:|---:|---:|---:|\n');
for i = 1:height(cmp_tbl)
    fprintf(fid, '| %d | %.10g | %.10g | %.10g |\n', ...
        cmp_tbl.CompID(i), ...
        cmp_tbl.MaxStepOld(i), ...
        cmp_tbl.MaxStepNew(i), ...
        cmp_tbl.RMSEOldVsNew(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- `tr_opt_1_compare.mat`\n');
fprintf(fid, '- `policy_compare_summary.csv`\n');
fprintf(fid, '- `policy_compare_by_comp.csv`\n');
fprintf(fid, '- `plots/tr_opt_1_action_compare.png`\n');
fprintf(fid, '- `plots/tr_opt_1_transient_compare.png`\n');

fclose(fid);
end
