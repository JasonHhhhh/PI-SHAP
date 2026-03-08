function out = run_tr_sim_grid_independence_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_grid_indep_min(cfg);

sim_dir = fileparts(mfilename('fullpath'));
addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

try
    opengl('software');
catch
end

if exist(cfg.policy_case_file, 'file') ~= 2
    error('Policy case file not found: %s', cfg.policy_case_file);
end

ensure_dir_grid_indep_min(cfg.stage_dir);
reset_dir_contents_grid_indep_min(cfg.stage_dir);
ensure_dir_grid_indep_min(cfg.plot_dir);

S_case = load(cfg.policy_case_file, 'cc_policy', 'dt_hr', 'par_case');
if ~isfield(S_case, 'cc_policy')
    error('cc_policy is missing in file: %s', cfg.policy_case_file);
end
cc_policy = S_case.cc_policy;

if ~isfield(S_case, 'par_case')
    error('par_case is missing in file: %s', cfg.policy_case_file);
end

if ~isfield(cfg, 'model_folder') || isempty(cfg.model_folder)
    cfg.model_folder = S_case.par_case.mfolder;
end

if ~isfield(S_case, 'dt_hr') || abs(S_case.dt_hr - 0.5) > 1e-9
    warning('Selected policy does not report dt_hr=0.5h. Continue anyway.');
end

if isempty(cfg.lmax_list)
    base_lmax = S_case.par_case.tr.lmax;
    cfg.lmax_list = base_lmax * [2.0, 1.5, 1.0, 0.75, 0.5];
end

cfg.solsteps_list = unique(round(cfg.solsteps_list(:)'),'stable');
cfg.lmax_list = unique(cfg.lmax_list(:)');
cfg.lmax_list = sort(cfg.lmax_list, 'descend');

n_s = numel(cfg.solsteps_list);
n_l = numel(cfg.lmax_list);
n_run = n_s * n_l;

run_defs = repmat(struct(), n_run, 1);
k = 0;
for il = 1:n_l
    for is = 1:n_s
        k = k + 1;
        run_defs(k).solsteps = cfg.solsteps_list(is);
        run_defs(k).lmax_km = cfg.lmax_list(il);
        run_defs(k).run_id = sprintf('sol%03d_lmax_%s', cfg.solsteps_list(is), num_tag_grid_indep_min(cfg.lmax_list(il)));
    end
end

grid_tbl = table( ...
    reshape(repmat(cfg.solsteps_list, n_l, 1), [], 1), ...
    reshape(repmat(cfg.lmax_list(:), 1, n_s), [], 1), ...
    'VariableNames', {'Solsteps', 'Lmax_km'});
writetable(grid_tbl, fullfile(cfg.stage_dir, 'grid_definition.csv'));

use_parallel_actual = try_setup_parallel_grid_indep_min(cfg, n_run);

results = repmat(empty_result_grid_indep_min(), n_run, 1);
if use_parallel_actual
    fprintf('Grid independence runs: %d (parallel mode)\n', n_run);
    parfor i = 1:n_run
        results(i) = run_one_setting_grid_indep_min(run_defs(i), cfg, cc_policy);
    end
else
    fprintf('Grid independence runs: %d (serial mode)\n', n_run);
    for i = 1:n_run
        results(i) = run_one_setting_grid_indep_min(run_defs(i), cfg, cc_policy);
    end
end

summary_tbl = make_summary_table_grid_indep_min(results);

[ref_idx, ref_key] = pick_reference_idx_grid_indep_min(summary_tbl, cfg);
summary_tbl.IsReference = false(height(summary_tbl), 1);
if ~isnan(ref_idx)
    summary_tbl.IsReference(ref_idx) = true;
end

[summary_tbl, curve_tbl] = add_relative_errors_grid_indep_min(summary_tbl, results, ref_idx);

writetable(summary_tbl, fullfile(cfg.stage_dir, 'run_summary.csv'));
writetable(curve_tbl, fullfile(cfg.stage_dir, 'curve_series_long.csv'));

save(fullfile(cfg.stage_dir, 'results.mat'), ...
    'cfg', 'results', 'summary_tbl', 'curve_tbl', 'ref_idx', 'ref_key', '-v7.3');

plot_heatmaps_grid_indep_min(summary_tbl, cfg);
plot_curve_sweeps_grid_indep_min(summary_tbl, results, cfg);

write_summary_md_grid_indep_min(cfg, summary_tbl, ref_idx, ref_key, cc_policy);

out = struct();
out.stage_dir = cfg.stage_dir;
out.plot_dir = cfg.plot_dir;
out.summary_csv = fullfile(cfg.stage_dir, 'run_summary.csv');
out.curve_csv = fullfile(cfg.stage_dir, 'curve_series_long.csv');
out.summary_md = fullfile(cfg.stage_dir, 'SUMMARY.md');
out.reference = ref_key;

disp(summary_tbl(:, {'RunID','Solsteps','Lmax_km','NodeCount','RuntimeSec','RelErrJcost','RelErrJsupp','RelErrJvar'}));
end

function cfg = fill_cfg_defaults_grid_indep_min(cfg)
sim_dir = fileparts(mfilename('fullpath'));

if ~isfield(cfg, 'policy_case_file') || isempty(cfg.policy_case_file)
    cfg.policy_case_file = fullfile('shap_src_min', 'tr', 'cost', 'case_cost_dt_0p50.mat');
end

if ~isfield(cfg, 'stage_dir') || isempty(cfg.stage_dir)
    cfg.stage_dir = fullfile('shap_src_min', 'sim', 'grid_independence');
end

if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.stage_dir, 'plots');
end

if ~isfield(cfg, 'solsteps_list') || isempty(cfg.solsteps_list)
    cfg.solsteps_list = [96, 144, 192, 240, 288];
end

if ~isfield(cfg, 'lmax_list')
    cfg.lmax_list = [];
end

if ~isfield(cfg, 'model_folder')
    cfg.model_folder = '';
end

if ~isfield(cfg, 'startup') || isempty(cfg.startup)
    cfg.startup = 1/8;
end
if ~isfield(cfg, 'nperiods') || isempty(cfg.nperiods)
    cfg.nperiods = 2;
end

if ~isfield(cfg, 'rtol0') || isempty(cfg.rtol0)
    cfg.rtol0 = 1e-2;
end
if ~isfield(cfg, 'atol0') || isempty(cfg.atol0)
    cfg.atol0 = 1e-1;
end
if ~isfield(cfg, 'rtol1') || isempty(cfg.rtol1)
    cfg.rtol1 = 1e-3;
end
if ~isfield(cfg, 'atol1') || isempty(cfg.atol1)
    cfg.atol1 = 1e-2;
end
if ~isfield(cfg, 'rtol') || isempty(cfg.rtol)
    cfg.rtol = 1e-5;
end
if ~isfield(cfg, 'atol') || isempty(cfg.atol)
    cfg.atol = 1e-3;
end

if ~isfield(cfg, 'use_parallel') || isempty(cfg.use_parallel)
    cfg.use_parallel = true;
end
if ~isfield(cfg, 'max_workers') || isempty(cfg.max_workers)
    cfg.max_workers = 8;
end

if ~isfield(cfg, 'sim_dir') || isempty(cfg.sim_dir)
    cfg.sim_dir = sim_dir;
end
end

function yes = try_setup_parallel_grid_indep_min(cfg, n_run)
yes = false;
if ~cfg.use_parallel
    return;
end

try
    has_dct = license('test', 'Distrib_Computing_Toolbox');
catch
    has_dct = false;
end

if ~has_dct
    return;
end

try
    pool = gcp('nocreate');
    if isempty(pool)
        n_workers = min([cfg.max_workers, n_run]);
        parpool(n_workers);
    end
    yes = true;
catch
    yes = false;
end
end

function res = empty_result_grid_indep_min()
res = struct();
res.RunID = "";
res.Solsteps = nan;
res.Lmax_km = nan;
res.NodeCount = nan;
res.EdgeCount = nan;
res.RuntimeSec = nan;
res.SetupSec = nan;
res.Jcost = nan;
res.Jsupp = nan;
res.Jvar = nan;
res.CostPeak = nan;
res.SuppMean = nan;
res.VarPeak = nan;
res.PressureMean = nan;
res.Status = "fail";
res.Message = "";
res.t_hr = [];
res.curve_cc_mean = [];
res.curve_pnod_mean = [];
res.curve_cost_total = [];
res.curve_supp = [];
end

function res = run_one_setting_grid_indep_min(def, cfg, cc_policy)
res = empty_result_grid_indep_min();
res.RunID = string(def.run_id);
res.Solsteps = def.solsteps;
res.Lmax_km = def.lmax_km;

try
    S_case = load(cfg.policy_case_file, 'par_case');
    par = S_case.par_case;

    par = rebuild_par_for_lmax_grid_indep_min(par, def.lmax_km, cfg.model_folder);
    par.sim = prepare_sim_for_grid_indep_min(par.ss, cfg, def.solsteps);

    t_setup = tic;
    par = tran_sim_setup_0_min(par, cc_policy');
    setup_sec = toc(t_setup);

    t_run = tic;
    par.sim = tran_sim_base_flat_noextd(par.sim);
    run_sec = toc(t_run);

    ev = evaluate_sim_curves_grid_indep_min(par.sim);

    res.NodeCount = par.tr.n.nv;
    res.EdgeCount = par.tr.n.ne;
    res.RuntimeSec = run_sec;
    res.SetupSec = setup_sec;
    res.Jcost = ev.Jcost;
    res.Jsupp = ev.Jsupp;
    res.Jvar = ev.Jvar;
    res.CostPeak = ev.CostPeak;
    res.SuppMean = ev.SuppMean;
    res.VarPeak = ev.VarPeak;
    res.PressureMean = ev.PressureMean;
    res.Status = "ok";
    res.Message = "";
    res.t_hr = ev.t_hr;
    res.curve_cc_mean = ev.curve_cc_mean;
    res.curve_pnod_mean = ev.curve_pnod_mean;
    res.curve_cost_total = ev.curve_cost_total;
    res.curve_supp = ev.curve_supp;
catch ME
    res.Status = "fail";
    res.Message = string(ME.message);
end
end

function par = rebuild_par_for_lmax_grid_indep_min(par, lmax_km, model_folder)
if nargin < 3 || isempty(model_folder)
    model_folder = par.mfolder;
end

n0 = gas_model_reader_new(model_folder);

par.tr.lmax = lmax_km;
par.tr.n0 = n0;
par.tr.n = gas_model_reconstruct_new(par.tr.n0, lmax_km, 0);
par.tr = model_spec(par.tr);
par.tr = econ_spec(par.tr, model_folder);

par.ss.lmax = lmax_km;
par.ss.n0 = n0;
par.ss.n = gas_model_reconstruct_new(par.ss.n0, lmax_km, 1);
par.ss = model_spec(par.ss);
par.ss = econ_spec(par.ss, model_folder);

% Provide a consistent initial state for startup DAE solve.
par.ss.m.ppp0 = par.ss.m.p_min_nd(par.ss.n.nonslack_nodes);
par.ss.m.qqq0 = zeros(par.ss.n.ne, 1);
par.ss.m.ccc0 = par.ss.n.c_max;

if isfield(par, 'out')
    par.out.dosim = 1;
end
end

function sim = prepare_sim_for_grid_indep_min(ss, cfg, solsteps)
sim = ss;
sim.rtol0 = cfg.rtol0;
sim.atol0 = cfg.atol0;
sim.rtol1 = cfg.rtol1;
sim.atol1 = cfg.atol1;
sim.rtol = cfg.rtol;
sim.atol = cfg.atol;
sim.startup = cfg.startup;
sim.nperiods = cfg.nperiods;
sim.solsteps = solsteps;
sim.fromss = 1;
end

function ev = evaluate_sim_curves_grid_indep_min(sim)
idx = find(sim.tt >= -1e-12);
if isempty(idx)
    idx = (numel(sim.tt)-sim.solsteps):numel(sim.tt);
    idx = idx(idx >= 1);
end

if numel(idx) > sim.solsteps + 1
    idx = idx(end-sim.solsteps:end);
end

t_sec = sim.tt(idx);
t_hr = t_sec / 3600;

cc = sim.cc(idx, :);
qq = sim.qq(idx, :);

c_edges = sim.m.comp_pos(:, 2);
qcomp = qq(:, c_edges);
cpow_each = abs(qcomp) .* (cc .^ sim.m.mpow - 1) * sim.m.Wc;
cost_total = sum(cpow_each, 2);

if isempty(sim.m.spos)
    supp_curve = mean(qq, 2);
else
    s_edges = sim.m.comp_pos(sim.m.spos, 2);
    supp_curve = mean(qq(:, s_edges), 2);
end

var_curve = abs(supp_curve - mean(supp_curve));

ev = struct();
ev.t_hr = t_hr(:);
ev.curve_cc_mean = mean(cc, 2);
ev.curve_pnod_mean = mean(sim.pnodout(idx, :), 2);
ev.curve_cost_total = cost_total(:);
ev.curve_supp = supp_curve(:);

ev.Jcost = trapz(t_sec, cost_total);
ev.Jsupp = trapz(t_sec, supp_curve);
ev.Jvar = trapz(t_sec, var_curve);
ev.CostPeak = max(cost_total);
ev.SuppMean = mean(supp_curve);
ev.VarPeak = max(var_curve);
ev.PressureMean = mean(ev.curve_pnod_mean);
end

function summary_tbl = make_summary_table_grid_indep_min(results)
n = numel(results);

run_id = strings(n, 1);
solsteps = nan(n, 1);
lmax = nan(n, 1);
node_count = nan(n, 1);
edge_count = nan(n, 1);
runtime_sec = nan(n, 1);
setup_sec = nan(n, 1);
jcost = nan(n, 1);
jsupp = nan(n, 1);
jvar = nan(n, 1);
cost_peak = nan(n, 1);
supp_mean = nan(n, 1);
var_peak = nan(n, 1);
press_mean = nan(n, 1);
status = strings(n, 1);
message = strings(n, 1);

for i = 1:n
    run_id(i) = string(results(i).RunID);
    solsteps(i) = results(i).Solsteps;
    lmax(i) = results(i).Lmax_km;
    node_count(i) = results(i).NodeCount;
    edge_count(i) = results(i).EdgeCount;
    runtime_sec(i) = results(i).RuntimeSec;
    setup_sec(i) = results(i).SetupSec;
    jcost(i) = results(i).Jcost;
    jsupp(i) = results(i).Jsupp;
    jvar(i) = results(i).Jvar;
    cost_peak(i) = results(i).CostPeak;
    supp_mean(i) = results(i).SuppMean;
    var_peak(i) = results(i).VarPeak;
    press_mean(i) = results(i).PressureMean;
    status(i) = string(results(i).Status);
    message(i) = string(results(i).Message);
end

summary_tbl = table( ...
    run_id, solsteps, lmax, node_count, edge_count, runtime_sec, setup_sec, ...
    jcost, jsupp, jvar, cost_peak, supp_mean, var_peak, press_mean, status, message, ...
    'VariableNames', { ...
    'RunID', 'Solsteps', 'Lmax_km', 'NodeCount', 'EdgeCount', 'RuntimeSec', 'SetupSec', ...
    'Jcost', 'Jsupp', 'Jvar', 'CostPeak', 'SuppMean', 'VarPeak', 'PressureMean', 'Status', 'Message'});
end

function [ref_idx, ref_key] = pick_reference_idx_grid_indep_min(summary_tbl, cfg)
ref_idx = nan;
ref_key = struct('Solsteps', nan, 'Lmax_km', nan, 'RunID', "");

ok = summary_tbl.Status == "ok";
if ~any(ok)
    return;
end

fine_sol = max(cfg.solsteps_list);
fine_lmax = min(cfg.lmax_list);

cand = find(ok & abs(summary_tbl.Solsteps - fine_sol) < 1e-12 & abs(summary_tbl.Lmax_km - fine_lmax) < 1e-12, 1, 'first');
if isempty(cand)
    cand = find(ok, 1, 'first');
end

ref_idx = cand;
ref_key.Solsteps = summary_tbl.Solsteps(ref_idx);
ref_key.Lmax_km = summary_tbl.Lmax_km(ref_idx);
ref_key.RunID = summary_tbl.RunID(ref_idx);
end

function [summary_tbl, curve_tbl] = add_relative_errors_grid_indep_min(summary_tbl, results, ref_idx)
n = height(summary_tbl);
rel_jcost = nan(n, 1);
rel_jsupp = nan(n, 1);
rel_jvar = nan(n, 1);
curve_err_cc = nan(n, 1);
curve_err_cost = nan(n, 1);
curve_err_supp = nan(n, 1);

curve_run = strings(0,1);
curve_sol = nan(0,1);
curve_lmax = nan(0,1);
curve_t = nan(0,1);
curve_cc = nan(0,1);
curve_p = nan(0,1);
curve_cost = nan(0,1);
curve_supp = nan(0,1);

if isnan(ref_idx)
    summary_tbl.RelErrJcost = rel_jcost;
    summary_tbl.RelErrJsupp = rel_jsupp;
    summary_tbl.RelErrJvar = rel_jvar;
    summary_tbl.CurveErrPnodMean = curve_err_cc;
    summary_tbl.CurveErrCost = curve_err_cost;
    summary_tbl.CurveErrSupp = curve_err_supp;
    curve_tbl = table(curve_run, curve_sol, curve_lmax, curve_t, curve_cc, curve_p, curve_cost, curve_supp, ...
        'VariableNames', {'RunID','Solsteps','Lmax_km','Time_hr','CcMean','PnodMean','CostTotal','SuppFlow'});
    return;
end

res_ref = results(ref_idx);
ref_t = res_ref.t_hr(:);
ref_cc = res_ref.curve_cc_mean(:);
ref_p = res_ref.curve_pnod_mean(:);
ref_cost = res_ref.curve_cost_total(:);
ref_supp = res_ref.curve_supp(:);

for i = 1:n
    if summary_tbl.Status(i) ~= "ok"
        continue;
    end

rel_jcost(i) = rel_abs_grid_indep_min(summary_tbl.Jcost(i), summary_tbl.Jcost(ref_idx));
rel_jsupp(i) = rel_abs_grid_indep_min(summary_tbl.Jsupp(i), summary_tbl.Jsupp(ref_idx));
rel_jvar(i) = rel_abs_grid_indep_min(summary_tbl.Jvar(i), summary_tbl.Jvar(ref_idx));

    ti = results(i).t_hr(:);
    cci = results(i).curve_cc_mean(:);
    pi = results(i).curve_pnod_mean(:);
costi = results(i).curve_cost_total(:);
    suppi = results(i).curve_supp(:);

    cc_interp = interp1(ti, cci, ref_t, 'linear', 'extrap');
    p_interp = interp1(ti, pi, ref_t, 'linear', 'extrap');
    cost_interp = interp1(ti, costi, ref_t, 'linear', 'extrap');
    supp_interp = interp1(ti, suppi, ref_t, 'linear', 'extrap');

    curve_err_cc(i) = rel_l2_grid_indep_min(p_interp, ref_p);
    curve_err_cost(i) = rel_l2_grid_indep_min(cost_interp, ref_cost);
    curve_err_supp(i) = rel_l2_grid_indep_min(supp_interp, ref_supp);

nn = numel(ref_t);
curve_run = [curve_run; repmat(summary_tbl.RunID(i), nn, 1)]; %#ok<AGROW>
curve_sol = [curve_sol; repmat(summary_tbl.Solsteps(i), nn, 1)]; %#ok<AGROW>
    curve_lmax = [curve_lmax; repmat(summary_tbl.Lmax_km(i), nn, 1)]; %#ok<AGROW>
    curve_t = [curve_t; ref_t]; %#ok<AGROW>
    curve_cc = [curve_cc; cc_interp]; %#ok<AGROW>
    curve_p = [curve_p; p_interp]; %#ok<AGROW>
    curve_cost = [curve_cost; cost_interp]; %#ok<AGROW>
    curve_supp = [curve_supp; supp_interp]; %#ok<AGROW>
end

summary_tbl.RelErrJcost = rel_jcost;
summary_tbl.RelErrJsupp = rel_jsupp;
summary_tbl.RelErrJvar = rel_jvar;
summary_tbl.CurveErrPnodMean = curve_err_cc;
summary_tbl.CurveErrCost = curve_err_cost;
summary_tbl.CurveErrSupp = curve_err_supp;

curve_tbl = table(curve_run, curve_sol, curve_lmax, curve_t, curve_cc, curve_p, curve_cost, curve_supp, ...
    'VariableNames', {'RunID','Solsteps','Lmax_km','Time_hr','CcMean','PnodMean','CostTotal','SuppFlow'});
end

function v = rel_abs_grid_indep_min(x, x_ref)
v = abs(x - x_ref) / max(abs(x_ref), eps);
end

function v = rel_l2_grid_indep_min(x, x_ref)
v = norm(x - x_ref, 2) / max(norm(x_ref, 2), eps);
end

function plot_heatmaps_grid_indep_min(summary_tbl, cfg)
lvals = sort(unique(summary_tbl.Lmax_km), 'descend');
svals = sort(unique(summary_tbl.Solsteps), 'ascend');

M1 = metric_matrix_grid_indep_min(summary_tbl, 'RelErrJcost', lvals, svals);
M2 = metric_matrix_grid_indep_min(summary_tbl, 'RelErrJsupp', lvals, svals);
M3 = metric_matrix_grid_indep_min(summary_tbl, 'RelErrJvar', lvals, svals);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1450 450], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

plot_one_heatmap_grid_indep_min(nexttile, M1, lvals, svals, 'Rel error vs ref: Cost integral');
plot_one_heatmap_grid_indep_min(nexttile, M2, lvals, svals, 'Rel error vs ref: Supply integral');
plot_one_heatmap_grid_indep_min(nexttile, M3, lvals, svals, 'Rel error vs ref: Variability integral');

sgtitle('Grid independence (5x5): integral metrics relative to finest reference', 'FontSize', 13, 'FontWeight', 'bold');
print(f, fullfile(cfg.plot_dir, 'grid_rel_error_heatmaps.png'), '-dpng', '-r260');
close(f);

C1 = metric_matrix_grid_indep_min(summary_tbl, 'CurveErrPnodMean', lvals, svals);
C2 = metric_matrix_grid_indep_min(summary_tbl, 'CurveErrCost', lvals, svals);
C3 = metric_matrix_grid_indep_min(summary_tbl, 'CurveErrSupp', lvals, svals);

f2 = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1450 450], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

plot_one_heatmap_grid_indep_min(nexttile, C1, lvals, svals, 'Curve L2 rel error: mean nodal pressure');
plot_one_heatmap_grid_indep_min(nexttile, C2, lvals, svals, 'Curve L2 rel error: total compressor power');
plot_one_heatmap_grid_indep_min(nexttile, C3, lvals, svals, 'Curve L2 rel error: supply flow');

sgtitle('Grid independence (5x5): key-curve errors relative to finest reference', 'FontSize', 13, 'FontWeight', 'bold');
print(f2, fullfile(cfg.plot_dir, 'grid_curve_error_heatmaps.png'), '-dpng', '-r260');
close(f2);
end

function M = metric_matrix_grid_indep_min(summary_tbl, var_name, lvals, svals)
M = nan(numel(lvals), numel(svals));
for i = 1:height(summary_tbl)
    if summary_tbl.Status(i) ~= "ok"
        continue;
    end
    il = find(abs(lvals - summary_tbl.Lmax_km(i)) < 1e-12, 1, 'first');
    is = find(abs(svals - summary_tbl.Solsteps(i)) < 1e-12, 1, 'first');
    if isempty(il) || isempty(is)
        continue;
    end
    M(il, is) = summary_tbl.(var_name)(i);
end
end

function plot_one_heatmap_grid_indep_min(ax, M, lvals, svals, ttl)
imagesc(ax, M);
set(ax, 'YDir', 'normal', 'FontSize', 10, 'LineWidth', 1.0);
xticks(ax, 1:numel(svals));
xticklabels(ax, arrayfun(@(x) sprintf('%d', x), svals, 'UniformOutput', false));
yticks(ax, 1:numel(lvals));
yticklabels(ax, arrayfun(@(x) sprintf('%.2f', x), lvals, 'UniformOutput', false));
xlabel(ax, 'Internal time grid (solsteps / 24h)');
ylabel(ax, 'Internal space grid (l_{max}, km)');
title(ax, ttl);
colorbar(ax);
grid(ax, 'on');
end

function plot_curve_sweeps_grid_indep_min(summary_tbl, results, cfg)
ok = summary_tbl.Status == "ok";
if ~any(ok)
    return;
end

fine_l = min(summary_tbl.Lmax_km(ok));
fine_s = max(summary_tbl.Solsteps(ok));

idx_time = find(ok & abs(summary_tbl.Lmax_km - fine_l) < 1e-12);
idx_space = find(ok & abs(summary_tbl.Solsteps - fine_s) < 1e-12);

if ~isempty(idx_time)
    [~, ord] = sort(summary_tbl.Solsteps(idx_time), 'ascend');
    idx_time = idx_time(ord);
    f1 = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1400 460], 'Renderer', 'painters');
    tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    plot_sweep_set_grid_indep_min(nexttile, results, summary_tbl, idx_time, 'curve_pnod_mean', 'Mean nodal pressure (Pa)', 'Temporal sweep at finest space');
    plot_sweep_set_grid_indep_min(nexttile, results, summary_tbl, idx_time, 'curve_cost_total', 'Total compressor power (W)', 'Temporal sweep at finest space');
    plot_sweep_set_grid_indep_min(nexttile, results, summary_tbl, idx_time, 'curve_supp', 'Supply flow', 'Temporal sweep at finest space');
    sgtitle(sprintf('Key curves vs internal time grid (l_{max}=%.2f km)', fine_l), 'FontSize', 13, 'FontWeight', 'bold');
    print(f1, fullfile(cfg.plot_dir, 'curves_temporal_sweep_fine_space.png'), '-dpng', '-r260');
    close(f1);
end

if ~isempty(idx_space)
    [~, ord] = sort(summary_tbl.Lmax_km(idx_space), 'descend');
    idx_space = idx_space(ord);
    f2 = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1400 460], 'Renderer', 'painters');
    tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    plot_sweep_set_grid_indep_min(nexttile, results, summary_tbl, idx_space, 'curve_pnod_mean', 'Mean nodal pressure (Pa)', 'Spatial sweep at finest time');
    plot_sweep_set_grid_indep_min(nexttile, results, summary_tbl, idx_space, 'curve_cost_total', 'Total compressor power (W)', 'Spatial sweep at finest time');
    plot_sweep_set_grid_indep_min(nexttile, results, summary_tbl, idx_space, 'curve_supp', 'Supply flow', 'Spatial sweep at finest time');
    sgtitle(sprintf('Key curves vs internal space grid (solsteps=%d)', fine_s), 'FontSize', 13, 'FontWeight', 'bold');
    print(f2, fullfile(cfg.plot_dir, 'curves_spatial_sweep_fine_time.png'), '-dpng', '-r260');
    close(f2);
end
end

function plot_sweep_set_grid_indep_min(ax, results, summary_tbl, idx_list, curve_field, ylab, ttl)
hold(ax, 'on');
cmap = lines(numel(idx_list));
labels = strings(numel(idx_list), 1);

for j = 1:numel(idx_list)
    i = idx_list(j);
    rr = results(i);
    y = rr.(curve_field);
    if strcmp(curve_field, 'curve_cost_total')
        y = y / 1e9;
        ylab = 'Total compressor power (GW)';
    end
    plot(ax, rr.t_hr, y, 'LineWidth', 1.8, 'Color', cmap(j,:));
    labels(j) = sprintf('sol=%d, lmax=%.2f', summary_tbl.Solsteps(i), summary_tbl.Lmax_km(i));
end

xlabel(ax, 'Time (h)');
ylabel(ax, ylab);
title(ax, ttl);
grid(ax, 'on');
legend(ax, labels, 'Location', 'best', 'Box', 'on');
set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

function write_summary_md_grid_indep_min(cfg, summary_tbl, ref_idx, ref_key, cc_policy)
md_file = fullfile(cfg.stage_dir, 'SUMMARY.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write markdown file: %s', md_file);
end

ok = summary_tbl.Status == "ok";
n_ok = sum(ok);

fprintf(fid, '# Simulation Grid Independence (Internal Time/Space Grids)\n\n');
fprintf(fid, '## Scope\n\n');
fprintf(fid, '- Fixed control policy source: `%s`\n', cfg.policy_case_file);
fprintf(fid, '- Control policy horizon/action points: `%d x %d` (49 action points at 0.5h control granularity).\n', size(cc_policy,1), size(cc_policy,2));
fprintf(fid, '- This study varies **internal simulation grids only** (ODE solver time grid and pipeline spatial reconstruction), not control action granularity.\n');
fprintf(fid, '- Internal time-grid candidates (solsteps / 24h): `%s`\n', mat2str(cfg.solsteps_list));
fprintf(fid, '- Internal space-grid candidates (lmax km): `%s`\n', mat2str(cfg.lmax_list, 4));
fprintf(fid, '- Total combinations: `%d` (successful: `%d`).\n\n', numel(cfg.solsteps_list) * numel(cfg.lmax_list), n_ok);

fprintf(fid, '## Reference run\n\n');
if isnan(ref_idx)
    fprintf(fid, '- No successful run, reference is unavailable.\n\n');
else
    fprintf(fid, '- RunID: `%s`\n', ref_key.RunID);
    fprintf(fid, '- solsteps: `%d`\n', ref_key.Solsteps);
    fprintf(fid, '- lmax_km: `%.6g`\n\n', ref_key.Lmax_km);
end

fprintf(fid, '## Relative-error summary (vs reference)\n\n');
if n_ok > 0 && ~isnan(ref_idx)
    max_e_cost = max(summary_tbl.RelErrJcost(ok));
    max_e_supp = max(summary_tbl.RelErrJsupp(ok));
    max_e_var = max(summary_tbl.RelErrJvar(ok));
    max_c_cc = max(summary_tbl.CurveErrPnodMean(ok));
    max_c_cost = max(summary_tbl.CurveErrCost(ok));
    max_c_supp = max(summary_tbl.CurveErrSupp(ok));

    fprintf(fid, '- Max relative error of integral cost metric: `%.4e`\n', max_e_cost);
    fprintf(fid, '- Max relative error of integral supply metric: `%.4e`\n', max_e_supp);
    fprintf(fid, '- Max relative error of integral variability metric: `%.4e`\n', max_e_var);
    fprintf(fid, '- Max relative L2 error of mean-nodal-pressure curve: `%.4e`\n', max_c_cc);
    fprintf(fid, '- Max relative L2 error of total-power curve: `%.4e`\n', max_c_cost);
    fprintf(fid, '- Max relative L2 error of supply-flow curve: `%.4e`\n\n', max_c_supp);
else
    fprintf(fid, '- Relative-error statistics unavailable.\n\n');
end

fprintf(fid, '## Figures\n\n');
fprintf(fid, '![Grid rel error heatmaps](plots/grid_rel_error_heatmaps.png)\n\n');
fprintf(fid, '![Grid curve error heatmaps](plots/grid_curve_error_heatmaps.png)\n\n');
fprintf(fid, '![Temporal sweep at finest space](plots/curves_temporal_sweep_fine_space.png)\n\n');
fprintf(fid, '![Spatial sweep at finest time](plots/curves_spatial_sweep_fine_time.png)\n\n');

fprintf(fid, '## Core files\n\n');
fprintf(fid, '- `grid_definition.csv`\n');
fprintf(fid, '- `run_summary.csv`\n');
fprintf(fid, '- `curve_series_long.csv`\n');
fprintf(fid, '- `results.mat`\n');

fclose(fid);
end

function ensure_dir_grid_indep_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_grid_indep_min(path_str)
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

function s = num_tag_grid_indep_min(x)
s = strrep(sprintf('%.2f', x), '.', 'p');
end
