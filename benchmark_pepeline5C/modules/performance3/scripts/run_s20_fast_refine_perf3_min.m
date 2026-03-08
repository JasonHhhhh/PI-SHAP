function out = run_s20_fast_refine_perf3_min(cfg)
% Fast S=20 refinement with small config variants.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end
cfg = fill_cfg_defaults_s20_fast(cfg);

ensure_dir_s20_fast(cfg.run_root);
ensure_dir_s20_fast(cfg.table_dir);

pool_info = ensure_parallel_pool_s20_fast(cfg);
if pool_info.enabled
    fprintf('[S20-fast] parallel pool workers=%d\n', pool_info.n_workers);
else
    fprintf('[S20-fast] parallel pool disabled.\n');
end

baseline = read_run_metrics_s20_fast(cfg.baseline_tables_dir);
cands = build_candidates_s20_fast(cfg);

rows = table();
for i = 1:numel(cands)
    c = cands(i);
    run_dir = fullfile(cfg.run_root, c.name);
    ensure_dir_s20_fast(run_dir);

    run_cfg = struct();
    run_cfg.work_dir = run_dir;

    sc = struct();
    sc.repo_dir = cfg.repo_dir;
    sc.eval_seed_list = cfg.eval_seed_list;
    sc.eval_dt_hr = cfg.eval_dt_hr;
    sc.split_mode = 'seed';
    sc.train_seed_list = cfg.train_seed_list;
    sc.test_seed_list = cfg.test_seed_list;
    sc.filter_use_train_only = true;
    sc.tree_refit_all = false;
    sc.tree_max_splits = cfg.S;
    sc.rule_prior_blend = 1.0;
    sc.label_class_levels = cfg.label_class_levels;
    sc.label_level_quantiles = cfg.label_level_quantiles;
    sc.use_map_cache = true;
    sc.map_cache_file = cfg.map_cache_file;
    sc.shap_use_parallel = true;
    sc.score_use_multilevel_match = true;
    sc.score_reliability_use_threshold = false;
    sc.score_multilevel_sign_weight = 0.70;

    fns = fieldnames(c.override);
    for k = 1:numel(fns)
        sc.(fns{k}) = c.override.(fns{k});
    end
    run_cfg.score_cfg = sc;

    run_cfg.review_cfg = struct();
    if isfield(cfg, 'review_cfg') && isstruct(cfg.review_cfg)
        run_cfg.review_cfg = cfg.review_cfg;
    end

    save_run_cfg_s20_fast(run_dir, run_cfg, c);

    fprintf('[S20-fast] (%d/%d) running %s\n', i, numel(cands), c.name);
    run_reviewer_single_multi_perf3_min(run_cfg);

    met = read_run_metrics_s20_fast(fullfile(run_dir, 'reviewer_outputs', 'tables'));
    row = build_summary_row_s20_fast(c.name, baseline, met);
    rows = [rows; row]; %#ok<AGROW>
end

summary_csv = fullfile(cfg.table_dir, 's20_fast_refine_summary.csv');
writetable(rows, summary_csv);

report_md = fullfile(cfg.run_root, 'S20_FAST_REFINE_REPORT.md');
write_report_s20_fast(report_md, rows, cfg, summary_csv);

out = struct();
out.summary_csv = summary_csv;
out.report_md = report_md;
out.run_root = cfg.run_root;

fprintf('[S20-fast] done: %s\n', report_md);
end

function row = build_summary_row_s20_fast(name, b, m)
row = table(string(name), ...
    m.pi.jcost, m.pi.jsupp, m.pi.jvar, ...
    m.pi.hv, m.pi.igd, m.pi.eps, m.pi.md, m.pi.p90, ...
    pct_change_s20_fast(m.pi.jcost, b.pi.jcost, 'min'), ...
    pct_change_s20_fast(m.pi.jsupp, b.pi.jsupp, 'max'), ...
    pct_change_s20_fast(m.pi.jvar, b.pi.jvar, 'min'), ...
    pct_change_s20_fast(m.pi.hv, b.pi.hv, 'max'), ...
    pct_change_s20_fast(m.pi.igd, b.pi.igd, 'min'), ...
    pct_change_s20_fast(m.pi.eps, b.pi.eps, 'min'), ...
    int32(m.pi.jcost < m.ori.jcost), int32(m.pi.jcost < m.cond.jcost), ...
    int32(m.pi.jsupp > m.ori.jsupp), int32(m.pi.jsupp > m.cond.jsupp), ...
    int32(m.pi.jvar < m.ori.jvar), int32(m.pi.jvar < m.cond.jvar), ...
    'VariableNames', { ...
    'Variant', ...
    'PI_Jcost', 'PI_Jsupp', 'PI_Jvar', ...
    'PI_HVRelToRef', 'PI_IGD', 'PI_EpsilonAdd', 'PI_MeanFrontDist', 'PI_P90FrontDist', ...
    'DeltaPct_PI_Jcost_vsBase', 'DeltaPct_PI_Jsupp_vsBase', 'DeltaPct_PI_Jvar_vsBase', ...
    'DeltaPct_PI_HV_vsBase', 'DeltaPct_PI_IGD_vsBase', 'DeltaPct_PI_Eps_vsBase', ...
    'PI_beats_Ori_Jcost', 'PI_beats_Cond_Jcost', ...
    'PI_beats_Ori_Jsupp', 'PI_beats_Cond_Jsupp', ...
    'PI_beats_Ori_Jvar', 'PI_beats_Cond_Jvar'});
end

function d = pct_change_s20_fast(v, v0, sense)
if ~isfinite(v0) || abs(v0) <= eps
    d = NaN;
    return;
end
if strcmpi(sense, 'max')
    d = 100 * (v - v0) / abs(v0);
else
    d = 100 * (v0 - v) / abs(v0);
end
end

function m = read_run_metrics_s20_fast(tdir)
jc = readtable(fullfile(tdir, 'single_target_metric_single_jcost.csv'));
js = readtable(fullfile(tdir, 'single_target_metric_single_jsupp.csv'));
jv = readtable(fullfile(tdir, 'single_target_metric_single_jvar.csv'));
mo = readtable(fullfile(tdir, 'multi_mo_metrics.csv'));

m = struct();
m.pi = struct('jcost', pick_metric_s20_fast(jc, 'PI-SHAP'), 'jsupp', pick_metric_s20_fast(js, 'PI-SHAP'), 'jvar', pick_metric_s20_fast(jv, 'PI-SHAP'), ...
    'hv', pick_mo_s20_fast(mo, 'PI-SHAP', 'HVRelToRef'), 'igd', pick_mo_s20_fast(mo, 'PI-SHAP', 'IGD'), ...
    'eps', pick_mo_s20_fast(mo, 'PI-SHAP', 'EpsilonAdd'), 'md', pick_mo_s20_fast(mo, 'PI-SHAP', 'MeanFrontDist'), ...
    'p90', pick_mo_s20_fast(mo, 'PI-SHAP', 'P90FrontDist'));
m.ori = struct('jcost', pick_metric_s20_fast(jc, 'Ori-SHAP'), 'jsupp', pick_metric_s20_fast(js, 'Ori-SHAP'), 'jvar', pick_metric_s20_fast(jv, 'Ori-SHAP'));
m.cond = struct('jcost', pick_metric_s20_fast(jc, 'Cond-SHAP'), 'jsupp', pick_metric_s20_fast(js, 'Cond-SHAP'), 'jvar', pick_metric_s20_fast(jv, 'Cond-SHAP'));
end

function v = pick_metric_s20_fast(T, method)
v = T.TargetMetricFinalAbs(string(T.Method) == string(method));
if isempty(v)
    v = NaN;
else
    v = v(1);
end
end

function v = pick_mo_s20_fast(T, method, field)
v = T.(field)(string(T.Method) == string(method));
if isempty(v)
    v = NaN;
else
    v = v(1);
end
end

function cands = build_candidates_s20_fast(cfg)
cands = repmat(struct('name', '', 'override', struct()), 1, 3);

cands(1).name = 'C1_costGuard_thr035_noFill_bal';
cands(1).override = struct( ...
    'label_fill_from_dv', false, ...
    'tree_use_class_balance_weights', true, ...
    'tree_class_weight_cap', 6.0, ...
    'score_use_multilevel_by_objective', [0, 1, 1], ...
    'score_multilevel_sign_weight_by_objective', [0.70, 0.65, 0.45], ...
    'score_reliability_use_threshold', true, ...
    'score_reliability_baseline', 0.35);

cands(2).name = 'C2_costGuard_thr035_fill_bal';
cands(2).override = struct( ...
    'label_fill_from_dv', true, ...
    'tree_use_class_balance_weights', true, ...
    'tree_class_weight_cap', 6.0, ...
    'score_use_multilevel_by_objective', [0, 1, 1], ...
    'score_multilevel_sign_weight_by_objective', [0.70, 0.60, 0.40], ...
    'score_reliability_use_threshold', true, ...
    'score_reliability_baseline', 0.35);

cands(3).name = 'C3_costGuard_thr040_noFill_nobal';
cands(3).override = struct( ...
    'label_fill_from_dv', false, ...
    'tree_use_class_balance_weights', false, ...
    'score_use_multilevel_by_objective', [0, 1, 1], ...
    'score_multilevel_sign_weight_by_objective', [0.70, 0.55, 0.35], ...
    'score_reliability_use_threshold', true, ...
    'score_reliability_baseline', 0.40);

if isfield(cfg, 'extra_candidates') && ~isempty(cfg.extra_candidates)
    cands = [cands, cfg.extra_candidates];
end
end

function save_run_cfg_s20_fast(run_dir, run_cfg, cand)
save(fullfile(run_dir, 'RUN_CFG.mat'), 'run_cfg', 'cand', '-v7.3');

fp = fullfile(run_dir, 'RUN_CFG.json');
txt = jsonencode(run_cfg);
fid = fopen(fp, 'w');
if fid < 0
    return;
end
fprintf(fid, '%s\n', txt);
fclose(fid);
end

function write_report_s20_fast(md_file, T, cfg, summary_csv)
fid = fopen(md_file, 'w');
if fid < 0
    return;
end

fprintf(fid, '# S20 Fast Refinement Report\n\n');
fprintf(fid, '- S fixed: `%d`\n', cfg.S);
fprintf(fid, '- Train seed: `%s`\n', mat2str(cfg.train_seed_list));
fprintf(fid, '- Test seeds: `%s`\n', mat2str(cfg.test_seed_list));
fprintf(fid, '- Labels: `%s`\n', mat2str(cfg.label_class_levels));
fprintf(fid, '- Shared SHAP cache: `%s`\n\n', cfg.map_cache_file);

fprintf(fid, '## Variants\n\n');
fprintf(fid, '| Variant | PI_Jcost | PI_Jsupp | PI_Jvar | dJcost%% | dJsupp%% | dJvar%% | dHV%% | dIGD%% | dEps%% |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(T)
    fprintf(fid, '| %s | %.6g | %.6g | %.6g | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
        string(T.Variant(i)), T.PI_Jcost(i), T.PI_Jsupp(i), T.PI_Jvar(i), ...
        T.DeltaPct_PI_Jcost_vsBase(i), T.DeltaPct_PI_Jsupp_vsBase(i), T.DeltaPct_PI_Jvar_vsBase(i), ...
        T.DeltaPct_PI_HV_vsBase(i), T.DeltaPct_PI_IGD_vsBase(i), T.DeltaPct_PI_Eps_vsBase(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- Summary CSV: `%s`\n', summary_csv);
fprintf(fid, '- Each run has `RUN_CFG.mat` and `RUN_CFG.json` in its own folder.\n');

fclose(fid);
end

function info = ensure_parallel_pool_s20_fast(cfg)
info = struct('enabled', false, 'n_workers', 0);
if ~cfg.use_parallel
    return;
end
if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2
    return;
end

try
    p = gcp('nocreate');
    if isempty(p)
        p = parpool('local', cfg.parallel_workers);
    end
    info.enabled = true;
    info.n_workers = p.NumWorkers;
catch
    info.enabled = false;
end
end

function cfg = fill_cfg_defaults_s20_fast(cfg)
this_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(this_dir)));

if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end
if ~isfield(cfg, 'run_root') || isempty(cfg.run_root)
    cfg.run_root = fullfile(this_dir, 's20_fast_refine');
end
if ~isfield(cfg, 'table_dir') || isempty(cfg.table_dir)
    cfg.table_dir = fullfile(cfg.run_root, 'tables');
end
if ~isfield(cfg, 'baseline_tables_dir') || isempty(cfg.baseline_tables_dir)
    cfg.baseline_tables_dir = fullfile(this_dir, 's_sweep_seedsplit', 'S020', 'reviewer_outputs', 'tables');
end

if ~isfield(cfg, 'S') || isempty(cfg.S)
    cfg.S = 20;
end
if ~isfield(cfg, 'eval_seed_list') || isempty(cfg.eval_seed_list)
    cfg.eval_seed_list = [11, 23, 37];
end
if ~isfield(cfg, 'train_seed_list') || isempty(cfg.train_seed_list)
    cfg.train_seed_list = 11;
end
if ~isfield(cfg, 'test_seed_list') || isempty(cfg.test_seed_list)
    cfg.test_seed_list = [23, 37];
end
if ~isfield(cfg, 'eval_dt_hr') || isempty(cfg.eval_dt_hr)
    cfg.eval_dt_hr = 1.0;
end

if ~isfield(cfg, 'label_class_levels') || isempty(cfg.label_class_levels)
    cfg.label_class_levels = [-4, -3, -2, -1, 1, 2, 3, 4];
end
if ~isfield(cfg, 'label_level_quantiles') || isempty(cfg.label_level_quantiles)
    cfg.label_level_quantiles = [0.25, 0.50, 0.75];
end

if ~isfield(cfg, 'map_cache_file') || isempty(cfg.map_cache_file)
    cfg.map_cache_file = fullfile(this_dir, 's_sweep_seedsplit', 'shared_holdout_shap_maps_cache_seedwise_dt1p0.mat');
end

if ~isfield(cfg, 'use_parallel') || isempty(cfg.use_parallel)
    cfg.use_parallel = true;
end
if ~isfield(cfg, 'parallel_workers') || isempty(cfg.parallel_workers)
    n = 1;
    try
        n = feature('numcores');
    catch
    end
    cfg.parallel_workers = max(1, floor(0.9 * n));
end
end

function ensure_dir_s20_fast(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end
