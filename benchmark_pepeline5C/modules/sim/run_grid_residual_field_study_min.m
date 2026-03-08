function out = run_grid_residual_field_study_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_residual_field_min(cfg);

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(fileparts(mfilename('fullpath')));

try
    opengl('software');
catch
end

if exist(cfg.policy_case_file, 'file') ~= 2
    error('Policy case file not found: %s', cfg.policy_case_file);
end

ensure_dir_residual_field_min(cfg.stage_dir);
reset_dir_contents_residual_field_min(cfg.stage_dir);
ensure_dir_residual_field_min(cfg.plot_dir);
ensure_dir_residual_field_min(cfg.run_dir);

S_case = load(cfg.policy_case_file, 'cc_policy', 'par_case', 'dt_hr');
if ~isfield(S_case, 'cc_policy') || ~isfield(S_case, 'par_case')
    error('Missing cc_policy or par_case in %s', cfg.policy_case_file);
end
cc_policy = S_case.cc_policy;

if isfield(S_case, 'dt_hr') && abs(S_case.dt_hr - 0.5) > 1e-9
    warning('Policy is not reported as 0.5h control grid.');
end

defs = make_run_defs_residual_field_min(cfg.solsteps_list);
n_run = numel(defs);
use_parallel_actual = try_setup_parallel_residual_field_min(cfg, n_run);

results = repmat(empty_result_residual_field_min(), n_run, 1);
if use_parallel_actual
    fprintf('Residual-field study runs: %d (parallel mode)\n', n_run);
    parfor i = 1:n_run
        results(i) = run_one_solsteps_residual_field_min(defs(i), cfg, cc_policy, S_case.par_case);
    end
else
    fprintf('Residual-field study runs: %d (serial mode)\n', n_run);
    for i = 1:n_run
        results(i) = run_one_solsteps_residual_field_min(defs(i), cfg, cc_policy, S_case.par_case);
    end
end

results = sort_results_by_solsteps_min(results);
summary_tbl = build_summary_table_residual_field_min(results);

ok = summary_tbl.Status == "ok";
if ~all(ok)
    bad = summary_tbl(~ok, :);
    warning('Some runs failed in residual-field study.\n%s', evalc('disp(bad(:,{''RunID'',''Status'',''Message''}))'));
end

fine_idx = find(summary_tbl.Status == "ok", 1, 'last');
if isempty(fine_idx)
    error('No successful run in residual-field study.');
end

summary_tbl.IsReference = false(height(summary_tbl), 1);
summary_tbl.IsReference(fine_idx) = true;

[summary_tbl, curve_diff_tbl] = add_field_diff_vs_fine_residual_field_min(summary_tbl, results, fine_idx);

for i = 1:numel(results)
    if results(i).Status ~= "ok"
        continue;
    end
    run_tag = sprintf('run_sol%03d', results(i).Solsteps);
    run_result = results(i); %#ok<NASGU>
    save(fullfile(cfg.run_dir, [run_tag '.mat']), 'run_result', '-v7.3');
    writetable(results(i).ResidualTs, fullfile(cfg.run_dir, [run_tag '_residual_timeseries.csv']));
end

writetable(summary_tbl, fullfile(cfg.stage_dir, 'run_summary.csv'));
writetable(curve_diff_tbl, fullfile(cfg.stage_dir, 'field_diff_vs_reference.csv'));

plot_residual_convergence_residual_field_min(summary_tbl, cfg);
plot_field_maps_residual_field_min(results, summary_tbl, cfg);
plot_field_differences_residual_field_min(results, summary_tbl, fine_idx, cfg);
plot_residual_timeseries_residual_field_min(results, summary_tbl, cfg);

write_summary_md_residual_field_min(cfg, summary_tbl, fine_idx);

out = struct();
out.stage_dir = cfg.stage_dir;
out.summary_csv = fullfile(cfg.stage_dir, 'run_summary.csv');
out.field_diff_csv = fullfile(cfg.stage_dir, 'field_diff_vs_reference.csv');
out.summary_md = fullfile(cfg.stage_dir, 'SUMMARY.md');
out.reference_run = summary_tbl.RunID(fine_idx);

disp(summary_tbl(:, {'RunID','Solsteps','NodeCount','EqMassAbsP95','EqMomentumAbsMedian','FieldPressureRelL2','FieldFlowRelL2'}));
end

function cfg = fill_cfg_defaults_residual_field_min(cfg)
if ~isfield(cfg, 'policy_case_file') || isempty(cfg.policy_case_file)
    cfg.policy_case_file = fullfile('shap_src_min', 'tr', 'cost', 'case_cost_dt_0p50.mat');
end

if ~isfield(cfg, 'stage_dir') || isempty(cfg.stage_dir)
    cfg.stage_dir = fullfile('shap_src_min', 'sim', 'grid_residual_field_study');
end

if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.stage_dir, 'plots');
end

if ~isfield(cfg, 'run_dir') || isempty(cfg.run_dir)
    cfg.run_dir = fullfile(cfg.stage_dir, 'runs');
end

if ~isfield(cfg, 'solsteps_list') || isempty(cfg.solsteps_list)
    cfg.solsteps_list = [192, 240, 288, 336, 384];
end

if ~isfield(cfg, 'lmax_km') || isempty(cfg.lmax_km)
    cfg.lmax_km = 2.0;
end

if ~isfield(cfg, 'original_pipe_id') || isempty(cfg.original_pipe_id)
    cfg.original_pipe_id = 1;
end

if ~isfield(cfg, 'display_solsteps') || isempty(cfg.display_solsteps)
    cfg.display_solsteps = [192, 288, 384];
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
end

function defs = make_run_defs_residual_field_min(solsteps_list)
solsteps_list = unique(round(solsteps_list(:)'));
defs = repmat(struct(), numel(solsteps_list), 1);
for i = 1:numel(solsteps_list)
    defs(i).solsteps = solsteps_list(i);
    defs(i).run_id = sprintf('sol%03d_lmax2p00', solsteps_list(i));
end
end

function yes = try_setup_parallel_residual_field_min(cfg, n_run)
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

function res = empty_result_residual_field_min()
res = struct();
res.RunID = "";
res.Solsteps = nan;
res.Lmax_km = nan;
res.NodeCount = nan;
res.EdgeCount = nan;
res.RuntimeSec = nan;
res.SetupSec = nan;
res.Status = "fail";
res.Message = "";
res.ResidualStats = struct();
res.ResidualTs = table();
res.Field = struct();
end

function res = run_one_solsteps_residual_field_min(def, cfg, cc_policy, par_case_base)
res = empty_result_residual_field_min();
res.RunID = string(def.run_id);
res.Solsteps = def.solsteps;
res.Lmax_km = cfg.lmax_km;

try
    par = par_case_base;
    par = rebuild_par_for_lmax_residual_field_min(par, cfg.lmax_km);
    par.sim = prepare_sim_for_solsteps_residual_field_min(par.ss, cfg, def.solsteps);

    t_setup = tic;
    par = tran_sim_setup_0_min(par, cc_policy');
    setup_sec = toc(t_setup);

    t_run = tic;
    par.sim = tran_sim_base_flat_noextd(par.sim);
    run_sec = toc(t_run);

    [stats, ts_tbl] = compute_pde_residuals_residual_field_min(par.sim);
    field = extract_pipe_field_residual_field_min(par.sim, cfg.original_pipe_id);

    res.NodeCount = par.tr.n.nv;
    res.EdgeCount = par.tr.n.ne;
    res.SetupSec = setup_sec;
    res.RuntimeSec = run_sec;
    res.ResidualStats = stats;
    res.ResidualTs = ts_tbl;
    res.Field = field;
    res.Status = "ok";
catch ME
    res.Status = "fail";
    res.Message = string(ME.message);
end
end

function par = rebuild_par_for_lmax_residual_field_min(par, lmax_km)
n0 = gas_model_reader_new(par.mfolder);

par.tr.lmax = lmax_km;
par.tr.n0 = n0;
par.tr.n = gas_model_reconstruct_new(par.tr.n0, lmax_km, 0);
par.tr = model_spec(par.tr);
par.tr = econ_spec(par.tr, par.mfolder);

par.ss.lmax = lmax_km;
par.ss.n0 = n0;
par.ss.n = gas_model_reconstruct_new(par.ss.n0, lmax_km, 1);
par.ss = model_spec(par.ss);
par.ss = econ_spec(par.ss, par.mfolder);

par.ss.m.ppp0 = par.ss.m.p_min_nd(par.ss.n.nonslack_nodes);
par.ss.m.qqq0 = zeros(par.ss.n.ne, 1);
par.ss.m.ccc0 = par.ss.n.c_max;

if isfield(par, 'out')
    par.out.dosim = 1;
end
end

function sim = prepare_sim_for_solsteps_residual_field_min(ss, cfg, solsteps)
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

function [stats, ts_tbl] = compute_pde_residuals_residual_field_min(sim)
t_mask = sim.tt >= -1e-12 & sim.tt <= sim.c.T + 1e-9;
t_sec = sim.tt(t_mask);
if isempty(t_sec)
    error('No time points in [0, T] for residual evaluation.');
end

tau = t_sec / sim.c.Tsc;
p = sim.ppnd(t_mask, :);
q = sim.qqnd(t_mask, :);

FN = sim.m.FN;
M = sim.m.M;
if size(p,2) ~= FN || size(q,2) ~= (M - FN)
    error('State dimensions mismatch for residual evaluation.');
end

Ad = sim.m.Ad;
Am = sim.m.Am;
Adp = sim.m.Adp;
Amn = sim.m.Amn;
Xs = sim.m.Xs;
ML = sim.m.ML;
Ma = sim.m.Ma;
Dk = sim.m.Dk;
lamk = sim.m.lamk;
R = sim.m.R;
cn = sim.m.comp_pos(:,1);
cl = sim.m.comp_pos(:,2);
dnodes = sim.m.dnodes;
snodes = sim.m.snodes;

C = sim.m.C;
PN = sim.m.PN;

n_t = numel(t_sec);
if n_t < 2
    error('Need at least two time points to compute discrete residuals.');
end

mass_abs = zeros(n_t-1, 1);
mom_abs = zeros(n_t-1, 1);
mass_rel = zeros(n_t-1, 1);
mom_rel = zeros(n_t-1, 1);
t_mid_hr = zeros(n_t-1, 1);

for k = 1:(n_t-1)
    dtau = tau(k+1) - tau(k);
    tmid = 0.5 * (t_sec(k+1) + t_sec(k));
    t_mid_hr(k) = tmid / 3600;

    pk = 0.5 * (p(k, :)' + p(k+1, :)');
    qk = 0.5 * (q(k, :)' + q(k+1, :)');
    dpk = (p(k+1, :)' - p(k, :)') / max(dtau, eps);
    dqk = (q(k+1, :)' - q(k, :)') / max(dtau, eps);

    comps = force_matrix_rows_residual_field_min(sim.m.cfun(tmid), C);
    doutk = force_matrix_rows_residual_field_min(sim.m.dout(tmid), FN);
    sk = force_matrix_rows_residual_field_min(sim.m.sfun(tmid), PN);
    dsk = force_matrix_rows_residual_field_min(sim.m.dsfun(tmid), PN);

    if size(comps, 2) > 1
        comps = comps(:, 1);
    end
    if size(doutk, 2) > 1
        doutk = doutk(:, 1);
    end
    if size(sk, 2) > 1
        sk = sk(:, 1);
    end
    if size(dsk, 2) > 1
        dsk = dsk(:, 1);
    end

    if sim.m.doZ == 1
        sk = p_to_rho_residual_field_min(sk, sim.c.b1, sim.c.b2, sim.c.psc);
    end

    Amj = Am;
    Amj(sub2ind(size(Amj), cn, cl)) = -comps;
    Adj = Amj(dnodes, :);
    Asj = Amj(snodes, :);

    Amnj = Amn;
    Amnj(sub2ind(size(Amnj), cn, cl)) = -comps;
    Adnj = Amnj(dnodes, :);

    if sim.m.doZ == 1
        AsAdp2 = (-rho_to_p_residual_field_min(-Asj' * sk, sim.c.b1, sim.c.b2, sim.c.psc) ...
                 + rho_to_p_residual_field_min(Adp' * pk, sim.c.b1, sim.c.b2, sim.c.psc) ...
                 - rho_to_p_residual_field_min(-Adnj' * pk, sim.c.b1, sim.c.b2, sim.c.psc));
    else
        AsAdp2 = (Asj' * sk + Adj' * pk);
    end

    A = (abs(Ad) * Xs * ML * abs(Adj'));
    rhs_p = Ad * Xs * qk - doutk - abs(Ad) * Xs * ML * abs(Asj') * dsk;
    term_q = abs(Asj') * sk + abs(Adj') * pk;
    fric_q = qk .* abs(qk) .* lamk ./ Dk * R;

    rp = A * (dpk * dtau) - rhs_p * dtau;
    rq = term_q .* (dqk * dtau) - (Ma * (AsAdp2 .* term_q) - fric_q) * dtau;

    mass_abs(k) = norm(rp, 2) / sqrt(numel(rp));
    mom_abs(k) = norm(rq, 2) / sqrt(numel(rq));

    den_p = norm(rhs_p * dtau, 2) / sqrt(numel(rhs_p)) + eps;
    den_q = norm((Ma * (AsAdp2 .* term_q) - fric_q) * dtau, 2) / sqrt(numel(term_q)) + eps;
    mass_rel(k) = mass_abs(k) / den_p;
    mom_rel(k) = mom_abs(k) / den_q;
end

stats = struct();
stats.EqMassAbsMean = mean(mass_abs);
stats.EqMassAbsMedian = median(mass_abs);
stats.EqMassAbsP95 = prctile(mass_abs, 95);
stats.EqMassRelMean = mean(mass_rel);
stats.EqMassRelMedian = median(mass_rel);
stats.EqMassRelP95 = prctile(mass_rel, 95);

stats.EqMomentumAbsMean = mean(mom_abs);
stats.EqMomentumAbsMedian = median(mom_abs);
stats.EqMomentumAbsP95 = prctile(mom_abs, 95);
stats.EqMomentumRelMean = mean(mom_rel);
stats.EqMomentumRelMedian = median(mom_rel);
stats.EqMomentumRelP95 = prctile(mom_rel, 95);

ts_tbl = table( ...
    t_mid_hr, mass_abs, mass_rel, mom_abs, mom_rel, ...
    'VariableNames', {'Time_hr', 'EqMassAbs', 'EqMassRel', 'EqMomentumAbs', 'EqMomentumRel'});
end

function M = force_matrix_rows_residual_field_min(x, nrow)
if isvector(x)
    x = x(:);
end

[r, c] = size(x);
if r == nrow
    M = x;
elseif c == nrow
    M = x';
else
    error('Cannot reshape array to %d-row matrix.', nrow);
end
end

function p = rho_to_p_residual_field_min(rho, b1, b2, psc)
p = (-b1 + sqrt(b1^2 + 4 * b2 * psc .* rho)) ./ (2 * b2 * psc);
end

function rho = p_to_rho_residual_field_min(p, b1, b2, psc)
rho = p .* (b1 + b2 * psc .* p);
end

function field = extract_pipe_field_residual_field_min(sim, orig_edge)
if orig_edge < 1 || orig_edge > size(sim.n.disc_to_edge, 1)
    error('Invalid original edge id: %d', orig_edge);
end

disc_edges = find(sim.n.disc_to_edge(orig_edge, :) > 0);
if isempty(disc_edges)
    error('No discretized edges found for original edge %d', orig_edge);
end

start_node = sim.n0.from_id(orig_edge);
end_node = sim.n0.to_id(orig_edge);

[ordered_edges, ordered_nodes] = order_pipe_chain_residual_field_min(sim.n, disc_edges, start_node, end_node);

dist_nodes = zeros(numel(ordered_nodes), 1);
for i = 2:numel(ordered_nodes)
    e = ordered_edges(i-1);
    dist_nodes(i) = dist_nodes(i-1) + sim.n.pipe_length(e);
end
dist_edges = (dist_nodes(1:end-1) + dist_nodes(2:end)) / 2;

t_mask = sim.tt >= -1e-12 & sim.tt <= sim.c.T + 1e-9;
t_hr = sim.tt(t_mask) / 3600;

field = struct();
field.OriginalEdge = orig_edge;
field.Time_hr = t_hr(:);
field.XNode_km = dist_nodes(:) / 1000;
field.XEdge_km = dist_edges(:) / 1000;
field.Pressure_Pa = sim.pnodin(t_mask, ordered_nodes);
field.Flow = sim.qq(t_mask, ordered_edges);
end

function [ordered_edges, ordered_nodes] = order_pipe_chain_residual_field_min(n, disc_edges, start_node, end_node)
from_vec = n.from_id(disc_edges);
to_vec = n.to_id(disc_edges);

ordered_edges = zeros(numel(disc_edges), 1);
ordered_nodes = zeros(numel(disc_edges) + 1, 1);
ordered_nodes(1) = start_node;

used = false(numel(disc_edges), 1);
cur = start_node;
ok = true;

for k = 1:numel(disc_edges)
    pick = find(~used & from_vec == cur, 1, 'first');
    if isempty(pick)
        ok = false;
        break;
    end
    used(pick) = true;
    e = disc_edges(pick);
    ordered_edges(k) = e;
    cur = n.to_id(e);
    ordered_nodes(k + 1) = cur;
end

if ~ok || cur ~= end_node
    % fallback by x-coordinate order for near-collinear pipes
    node_set = unique([from_vec; to_vec]);
    [~, ord] = sort(n.xcoord(node_set), 'ascend');
    ordered_nodes = node_set(ord);
    ordered_edges = zeros(numel(ordered_nodes)-1, 1);
    for k = 1:numel(ordered_edges)
        e = find(n.from_id == ordered_nodes(k) & n.to_id == ordered_nodes(k+1), 1, 'first');
        if isempty(e)
            e = find(n.to_id == ordered_nodes(k) & n.from_id == ordered_nodes(k+1), 1, 'first');
        end
        if isempty(e)
            error('Cannot reconstruct ordered edge chain.');
        end
        ordered_edges(k) = e;
    end
end

ordered_edges = ordered_edges(ordered_edges > 0);
ordered_nodes = ordered_nodes(1:numel(ordered_edges)+1);
end

function results = sort_results_by_solsteps_min(results)
sol = nan(numel(results), 1);
for i = 1:numel(results)
    sol(i) = results(i).Solsteps;
end
[~, ord] = sort(sol, 'ascend');
results = results(ord);
end

function summary_tbl = build_summary_table_residual_field_min(results)
n = numel(results);

run_id = strings(n, 1);
solsteps = nan(n, 1);
lmax = nan(n, 1);
node_count = nan(n, 1);
edge_count = nan(n, 1);
runtime_sec = nan(n, 1);
setup_sec = nan(n, 1);

eqm_abs_mean = nan(n, 1);
eqm_abs_median = nan(n, 1);
eqm_abs_p95 = nan(n, 1);
eqm_rel_mean = nan(n, 1);
eqm_rel_median = nan(n, 1);
eqm_rel_p95 = nan(n, 1);

eqq_abs_mean = nan(n, 1);
eqq_abs_median = nan(n, 1);
eqq_abs_p95 = nan(n, 1);
eqq_rel_mean = nan(n, 1);
eqq_rel_median = nan(n, 1);
eqq_rel_p95 = nan(n, 1);

status = strings(n, 1);
message = strings(n, 1);

for i = 1:n
    run_id(i) = results(i).RunID;
    solsteps(i) = results(i).Solsteps;
    lmax(i) = results(i).Lmax_km;
    node_count(i) = results(i).NodeCount;
    edge_count(i) = results(i).EdgeCount;
    runtime_sec(i) = results(i).RuntimeSec;
    setup_sec(i) = results(i).SetupSec;
    status(i) = results(i).Status;
    message(i) = results(i).Message;

    if results(i).Status == "ok"
        st = results(i).ResidualStats;
        eqm_abs_mean(i) = st.EqMassAbsMean;
        eqm_abs_median(i) = st.EqMassAbsMedian;
        eqm_abs_p95(i) = st.EqMassAbsP95;
        eqm_rel_mean(i) = st.EqMassRelMean;
        eqm_rel_median(i) = st.EqMassRelMedian;
        eqm_rel_p95(i) = st.EqMassRelP95;
        eqq_abs_mean(i) = st.EqMomentumAbsMean;
        eqq_abs_median(i) = st.EqMomentumAbsMedian;
        eqq_abs_p95(i) = st.EqMomentumAbsP95;
        eqq_rel_mean(i) = st.EqMomentumRelMean;
        eqq_rel_median(i) = st.EqMomentumRelMedian;
        eqq_rel_p95(i) = st.EqMomentumRelP95;
    end
end

summary_tbl = table( ...
    run_id, solsteps, lmax, node_count, edge_count, runtime_sec, setup_sec, ...
    eqm_abs_mean, eqm_abs_median, eqm_abs_p95, eqm_rel_mean, eqm_rel_median, eqm_rel_p95, ...
    eqq_abs_mean, eqq_abs_median, eqq_abs_p95, eqq_rel_mean, eqq_rel_median, eqq_rel_p95, ...
    status, message, ...
    'VariableNames', { ...
    'RunID','Solsteps','Lmax_km','NodeCount','EdgeCount','RuntimeSec','SetupSec', ...
    'EqMassAbsMean','EqMassAbsMedian','EqMassAbsP95','EqMassRelMean','EqMassRelMedian','EqMassRelP95', ...
    'EqMomentumAbsMean','EqMomentumAbsMedian','EqMomentumAbsP95','EqMomentumRelMean','EqMomentumRelMedian','EqMomentumRelP95', ...
    'Status','Message'});
end

function [summary_tbl, diff_tbl] = add_field_diff_vs_fine_residual_field_min(summary_tbl, results, fine_idx)
n = height(summary_tbl);
fp_l2 = nan(n, 1);
ff_l2 = nan(n, 1);
fp_max = nan(n, 1);
ff_max = nan(n, 1);

res_ref = results(fine_idx);
t_ref = res_ref.Field.Time_hr(:);
p_ref = res_ref.Field.Pressure_Pa;
f_ref = res_ref.Field.Flow;

for i = 1:n
    if summary_tbl.Status(i) ~= "ok"
        continue;
    end

    t_i = results(i).Field.Time_hr(:);
    p_i = results(i).Field.Pressure_Pa;
    f_i = results(i).Field.Flow;

    p_interp = interp_field_time_residual_field_min(p_i, t_i, t_ref);
    f_interp = interp_field_time_residual_field_min(f_i, t_i, t_ref);

    dp = p_interp - p_ref;
    df = f_interp - f_ref;

    fp_l2(i) = norm(dp(:), 2) / max(norm(p_ref(:), 2), eps);
    ff_l2(i) = norm(df(:), 2) / max(norm(f_ref(:), 2), eps);

    fp_max(i) = max(abs(dp(:))) / max(max(abs(p_ref(:))), eps);
    ff_max(i) = max(abs(df(:))) / max(max(abs(f_ref(:))), eps);
end

summary_tbl.FieldPressureRelL2 = fp_l2;
summary_tbl.FieldFlowRelL2 = ff_l2;
summary_tbl.FieldPressureRelMax = fp_max;
summary_tbl.FieldFlowRelMax = ff_max;

diff_tbl = summary_tbl(:, {'RunID','Solsteps','FieldPressureRelL2','FieldFlowRelL2','FieldPressureRelMax','FieldFlowRelMax'});
end

function Xq = interp_field_time_residual_field_min(X, t, t_ref)
Xq = zeros(numel(t_ref), size(X, 2));
for j = 1:size(X, 2)
    Xq(:, j) = interp1(t, X(:, j), t_ref, 'linear', 'extrap');
end
end

function plot_residual_convergence_residual_field_min(summary_tbl, cfg)
ok = summary_tbl.Status == "ok";
T = summary_tbl(ok, :);
T = sortrows(T, 'Solsteps', 'ascend');

x = T.Solsteps;
y_mass = T.EqMassAbsP95;
y_mom = T.EqMomentumAbsMedian;
z_p = T.FieldPressureRelL2;
z_f = T.FieldFlowRelL2;

y_mass_env = cummin(y_mass);
y_mom_env = cummin(y_mom);
z_p_env = cummin(z_p);
z_f_env = cummin(z_f);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 470], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
    semilogy(ax1, x, y_mass, 'o-', 'LineWidth', 1.7, 'MarkerSize', 6, 'Color', [0.00 0.45 0.74], 'DisplayName', 'Mass residual (p95, abs)');
hold(ax1, 'on');
semilogy(ax1, x, y_mom, 's-', 'LineWidth', 1.7, 'MarkerSize', 6, 'Color', [0.85 0.33 0.10], 'DisplayName', 'Momentum residual (median, abs)');
semilogy(ax1, x, y_mass_env, '--', 'LineWidth', 2.0, 'Color', [0.00 0.45 0.74], 'DisplayName', 'Mass envelope (cum-min)');
semilogy(ax1, x, y_mom_env, '--', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], 'DisplayName', 'Momentum envelope (cum-min)');
grid(ax1, 'on');
xlabel(ax1, 'Internal time grid (solsteps / 24h)');
ylabel(ax1, 'Absolute residual level');
title(ax1, 'PDE residual convergence at fixed spatial grid');
legend(ax1, 'Location', 'best', 'Box', 'on');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
semilogy(ax2, x, z_p, 'o-', 'LineWidth', 1.7, 'MarkerSize', 6, 'Color', [0.13 0.55 0.13], 'DisplayName', 'Pressure-field rel-L2');
hold(ax2, 'on');
semilogy(ax2, x, z_f, 's-', 'LineWidth', 1.7, 'MarkerSize', 6, 'Color', [0.49 0.18 0.56], 'DisplayName', 'Flow-field rel-L2');
semilogy(ax2, x, z_p_env, '--', 'LineWidth', 2.0, 'Color', [0.13 0.55 0.13], 'DisplayName', 'Pressure envelope (cum-min)');
semilogy(ax2, x, z_f_env, '--', 'LineWidth', 2.0, 'Color', [0.49 0.18 0.56], 'DisplayName', 'Flow envelope (cum-min)');
grid(ax2, 'on');
xlabel(ax2, 'Internal time grid (solsteps / 24h)');
ylabel(ax2, 'Relative field difference to finest run');
title(ax2, 'Field-map convergence at fixed spatial grid');
legend(ax2, 'Location', 'best', 'Box', 'on');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('"Slimming" convergence view: residuals and field differences', 'FontSize', 13, 'FontWeight', 'bold');
print(f, fullfile(cfg.plot_dir, 'residual_and_field_convergence.png'), '-dpng', '-r260');
close(f);
end

function plot_field_maps_residual_field_min(results, summary_tbl, cfg)
sel = cfg.display_solsteps(:)';
idx_list = [];
for s = sel
    i = find(summary_tbl.Solsteps == s & summary_tbl.Status == "ok", 1, 'first');
    if ~isempty(i)
        idx_list(end+1) = i; %#ok<AGROW>
    end
end

if numel(idx_list) < 2
    ok_idx = find(summary_tbl.Status == "ok");
    if numel(ok_idx) >= 2
        idx_list = [ok_idx(1), ok_idx(round(numel(ok_idx)/2)), ok_idx(end)];
        idx_list = unique(idx_list, 'stable');
    else
        return;
    end
end

ncol = numel(idx_list);

pmin = inf; pmax = -inf;
qmin = inf; qmax = -inf;
for ii = idx_list
    p = results(ii).Field.Pressure_Pa / 1e6;
    q = results(ii).Field.Flow;
    pmin = min(pmin, min(p(:))); pmax = max(pmax, max(p(:)));
    qmin = min(qmin, min(q(:))); qmax = max(qmax, max(q(:)));
end

f = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 420*ncol 760], 'Renderer', 'painters');
tiledlayout(2, ncol, 'TileSpacing', 'compact', 'Padding', 'compact');

for c = 1:ncol
    i = idx_list(c);
    fld = results(i).Field;

    ax1 = nexttile(c);
    imagesc(ax1, fld.XNode_km, fld.Time_hr, fld.Pressure_Pa / 1e6);
    axis(ax1, 'xy');
    caxis(ax1, [pmin pmax]);
    xlabel(ax1, 'Distance along pipe (km)');
    ylabel(ax1, 'Time (h)');
    title(ax1, sprintf('Pressure field (sol=%d)', summary_tbl.Solsteps(i)));
    colorbar(ax1);
    set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

    ax2 = nexttile(ncol + c);
    imagesc(ax2, fld.XEdge_km, fld.Time_hr, fld.Flow);
    axis(ax2, 'xy');
    caxis(ax2, [qmin qmax]);
    xlabel(ax2, 'Distance along pipe (km)');
    ylabel(ax2, 'Time (h)');
    title(ax2, sprintf('Flow field (sol=%d)', summary_tbl.Solsteps(i)));
    colorbar(ax2);
    set(ax2, 'FontSize', 10, 'LineWidth', 1.0);
end

sgtitle(sprintf('Field maps across time-grid refinement (fixed l_{max}=%.2f km, pipe %d)', cfg.lmax_km, cfg.original_pipe_id), ...
    'FontSize', 13, 'FontWeight', 'bold');
print(f, fullfile(cfg.plot_dir, 'field_maps_across_time_grids.png'), '-dpng', '-r260');
close(f);
end

function plot_field_differences_residual_field_min(results, summary_tbl, fine_idx, cfg)
ok_idx = find(summary_tbl.Status == "ok");
if numel(ok_idx) < 2
    return;
end

fine = results(fine_idx).Field;
t_ref = fine.Time_hr;
p_ref = fine.Pressure_Pa / 1e6;
q_ref = fine.Flow;

coarse_idx = ok_idx(ok_idx ~= fine_idx);
coarse_idx = coarse_idx(:)';

if numel(coarse_idx) > 3
    coarse_idx = [coarse_idx(1), coarse_idx(round(numel(coarse_idx)/2)), coarse_idx(end)];
    coarse_idx = unique(coarse_idx, 'stable');
end

ncol = numel(coarse_idx);
if ncol == 0
    return;
end

dp_max = 0;
dq_max = 0;
diff_p = cell(ncol,1);
diff_q = cell(ncol,1);

for c = 1:ncol
    i = coarse_idx(c);
    fld = results(i).Field;

    p_i = interp_field_time_residual_field_min(fld.Pressure_Pa / 1e6, fld.Time_hr, t_ref);
    q_i = interp_field_time_residual_field_min(fld.Flow, fld.Time_hr, t_ref);

    diff_p{c} = abs(p_i - p_ref);
    diff_q{c} = abs(q_i - q_ref);

    dp_max = max(dp_max, max(diff_p{c}(:)));
    dq_max = max(dq_max, max(diff_q{c}(:)));
end

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 420*ncol 760], 'Renderer', 'painters');
tiledlayout(2, ncol, 'TileSpacing', 'compact', 'Padding', 'compact');

for c = 1:ncol
    i = coarse_idx(c);

    ax1 = nexttile(c);
    imagesc(ax1, fine.XNode_km, t_ref, diff_p{c});
    axis(ax1, 'xy');
    caxis(ax1, [0 max(dp_max, eps)]);
    xlabel(ax1, 'Distance along pipe (km)');
    ylabel(ax1, 'Time (h)');
    title(ax1, sprintf('|dP| vs sol=%d', summary_tbl.Solsteps(i)));
    colorbar(ax1);
    set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

    ax2 = nexttile(ncol + c);
    imagesc(ax2, fine.XEdge_km, t_ref, diff_q{c});
    axis(ax2, 'xy');
    caxis(ax2, [0 max(dq_max, eps)]);
    xlabel(ax2, 'Distance along pipe (km)');
    ylabel(ax2, 'Time (h)');
    title(ax2, sprintf('|dQ| vs sol=%d', summary_tbl.Solsteps(i)));
    colorbar(ax2);
    set(ax2, 'FontSize', 10, 'LineWidth', 1.0);
end

sgtitle(sprintf('Difference maps to finest run (sol=%d, l_{max}=%.2f km)', summary_tbl.Solsteps(fine_idx), cfg.lmax_km), ...
    'FontSize', 13, 'FontWeight', 'bold');
print(f, fullfile(cfg.plot_dir, 'field_difference_to_finest.png'), '-dpng', '-r260');
close(f);
end

function plot_residual_timeseries_residual_field_min(results, summary_tbl, cfg)
ok_idx = find(summary_tbl.Status == "ok");
if numel(ok_idx) < 2
    return;
end

i_coarse = ok_idx(1);
i_fine = ok_idx(end);

tc = results(i_coarse).ResidualTs;
tf = results(i_fine).ResidualTs;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1200 460], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
    semilogy(ax1, tc.Time_hr, tc.EqMassAbs, '-', 'LineWidth', 1.4, 'Color', [0.85 0.33 0.10], 'DisplayName', sprintf('coarse sol=%d', summary_tbl.Solsteps(i_coarse)));
hold(ax1, 'on');
semilogy(ax1, tf.Time_hr, tf.EqMassAbs, '-', 'LineWidth', 1.4, 'Color', [0 0.45 0.74], 'DisplayName', sprintf('fine sol=%d', summary_tbl.Solsteps(i_fine)));
grid(ax1, 'on');
xlabel(ax1, 'Time (h)');
ylabel(ax1, 'Mass residual (absolute)');
title(ax1, 'Continuity-equation residual over time');
legend(ax1, 'Location', 'best', 'Box', 'on');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
    semilogy(ax2, tc.Time_hr, tc.EqMomentumAbs, '-', 'LineWidth', 1.4, 'Color', [0.85 0.33 0.10], 'DisplayName', sprintf('coarse sol=%d', summary_tbl.Solsteps(i_coarse)));
hold(ax2, 'on');
semilogy(ax2, tf.Time_hr, tf.EqMomentumAbs, '-', 'LineWidth', 1.4, 'Color', [0 0.45 0.74], 'DisplayName', sprintf('fine sol=%d', summary_tbl.Solsteps(i_fine)));
grid(ax2, 'on');
xlabel(ax2, 'Time (h)');
ylabel(ax2, 'Momentum residual (absolute)');
title(ax2, 'Momentum-equation residual over time');
legend(ax2, 'Location', 'best', 'Box', 'on');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('PDE residual time traces: coarse vs fine time grid', 'FontSize', 13, 'FontWeight', 'bold');
print(f, fullfile(cfg.plot_dir, 'residual_timeseries_coarse_vs_fine.png'), '-dpng', '-r260');
close(f);
end

function write_summary_md_residual_field_min(cfg, summary_tbl, fine_idx)
md_file = fullfile(cfg.stage_dir, 'SUMMARY.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write markdown file: %s', md_file);
end

ok = summary_tbl.Status == "ok";
T = summary_tbl(ok, :);

fprintf(fid, '# PDE Residual and Field-Map Grid Study\n\n');
fprintf(fid, '## Scope\n\n');
fprintf(fid, '- Fixed policy: `%s` (0.5h control actions).\n', cfg.policy_case_file);
fprintf(fid, '- Fixed internal space grid: `lmax=%.2f km`.\n', cfg.lmax_km);
fprintf(fid, '- Internal time-grid sweep (solsteps): `%s`.\n\n', mat2str(cfg.solsteps_list));

fprintf(fid, '## Reference run\n\n');
fprintf(fid, '- `%s`\n\n', summary_tbl.RunID(fine_idx));

fprintf(fid, '## Key numeric outcomes\n\n');
fprintf(fid, '- Continuity residual p95 (abs) range: `%.4e -> %.4e`\n', T.EqMassAbsP95(1), T.EqMassAbsP95(end));
fprintf(fid, '- Momentum residual median (abs) range: `%.4e -> %.4e`\n', T.EqMomentumAbsMedian(1), T.EqMomentumAbsMedian(end));
fprintf(fid, '- Worst-case pressure-field rel-L2 to finest: `%.4e`\n', max(T.FieldPressureRelL2));
fprintf(fid, '- Worst-case flow-field rel-L2 to finest: `%.4e`\n\n', max(T.FieldFlowRelL2));

fprintf(fid, '## Figures\n\n');
fprintf(fid, '![Residual and field convergence](plots/residual_and_field_convergence.png)\n\n');
fprintf(fid, '![Field maps across time grids](plots/field_maps_across_time_grids.png)\n\n');
fprintf(fid, '![Field difference to finest](plots/field_difference_to_finest.png)\n\n');
fprintf(fid, '![Residual time traces](plots/residual_timeseries_coarse_vs_fine.png)\n\n');

fprintf(fid, '## Core files\n\n');
fprintf(fid, '- `run_summary.csv`\n');
fprintf(fid, '- `field_diff_vs_reference.csv`\n');
fprintf(fid, '- `runs/run_sol*_residual_timeseries.csv`\n');

fclose(fid);
end

function ensure_dir_residual_field_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_residual_field_min(path_str)
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
