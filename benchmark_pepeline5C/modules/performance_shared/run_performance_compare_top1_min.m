function out = run_performance_compare_top1_min(cfg)
% Performance2: SHAP -> sequential tree rules -> ranking.
% This script keeps output table schema compatible with reviewer plotting.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_perf2(cfg);
ensure_dir_perf2(cfg.work_dir);
ensure_dir_perf2(cfg.plot_dir);
ensure_dir_perf2(cfg.table_dir);
ensure_dir_perf2(cfg.selection_dir);
ensure_dir_perf2(cfg.ranking_dir);
ensure_dir_perf2(cfg.method_runs_dir);
ensure_dir_perf2(cfg.candidate_search_dir);

addpath(fullfile(cfg.repo_dir, 'src'));
addpath(fullfile(cfg.repo_dir, 'shap_src'));
addpath(fullfile(cfg.repo_dir, 'shap_src_min'));
addpath(fullfile(cfg.repo_dir, 'shap_src_min', 'SHAP'));

S = load(cfg.dataset_file, 'X', 'feature_names', 'train_idx', 'val_idx');
M = load(cfg.models_file, 'scalar_models');
models_obj = M.scalar_models(1:3);

fn = string(S.feature_names(:));
idx_cc = find(startsWith(fn, "cc_"));
idx_pin = find(startsWith(fn, "pin_"));
if numel(idx_cc) ~= cfg.n_time_nn * cfg.n_comp
    error('Unexpected cc feature count: %d', numel(idx_cc));
end

pin_template = median(S.X(:, idx_pin), 1);

if cfg.use_val_for_background
    train_use = unique([S.train_idx(:); S.val_idx(:)]);
else
    train_use = S.train_idx(:);
end
n_bg = min(cfg.shap_background_n, numel(train_use));
rng(cfg.rng_seed + 13, 'twister');
bg_pick = train_use(randperm(numel(train_use), n_bg));
Xbg = S.X(bg_pick, :);

D = load_holdout_dataset_perf2(cfg, idx_cc, idx_pin, pin_template, numel(fn));
if D.n_case < cfg.min_cases
    error('Too few valid cases: %d', D.n_case);
end

[mask_keep, zeta, dnorm] = apply_lhs_like_filter_perf2(D.dv, cfg, D.seed);
if sum(mask_keep) < cfg.min_cases
    mask_keep = true(D.n_case, 1);
end

D = subset_dataset_perf2(D, mask_keep);

[idx_train, idx_test] = split_train_test_perf2(D.n_case, cfg, D.seed);
idx_train = maybe_subsample_train_idx_perf2(idx_train, cfg);

[cache_hit, maps_ori, maps_cond, maps_pi] = try_load_map_cache_perf2(cfg, D, idx_train, idx_test);
if ~cache_hit
    [maps_ori, maps_cond] = compute_nn_maps_perf2(models_obj, Xbg, D.Xq, idx_cc, cfg);
    maps_pi = D.pi_maps;

    maps_ori = sanitize_maps_perf2(maps_ori, cfg);
    maps_cond = sanitize_maps_perf2(maps_cond, cfg);
    maps_pi = sanitize_maps_perf2(maps_pi, cfg);

    maps_ori = robust_clip_maps_perf2(maps_ori, cfg.map_clip_pct);
    maps_cond = robust_clip_maps_perf2(maps_cond, cfg.map_clip_pct);
    maps_pi = robust_clip_maps_perf2(maps_pi, cfg.map_clip_pct);

    save_map_cache_perf2(cfg, D, idx_train, idx_test, maps_ori, maps_cond, maps_pi);
else
    fprintf('Loaded SHAP maps from cache: %s\n', cfg.map_cache_file);
end

[tree_pack, tree_tbl] = train_rule_trees_perf2(D, maps_ori, maps_cond, maps_pi, idx_train, idx_test, cfg);

score_ori_raw = score_by_rules_perf2(D, tree_pack.models_ori, tree_pack.weights_ori, tree_pack.reliability_ori, idx_train, cfg);
score_cond_raw = score_by_rules_perf2(D, tree_pack.models_cond, tree_pack.weights_cond, tree_pack.reliability_cond, idx_train, cfg);
score_pi_raw = score_by_rules_perf2(D, tree_pack.models_pi, tree_pack.weights_pi, tree_pack.reliability_pi, idx_train, cfg);

prior_ori = compute_prior_scores_perf2(maps_ori, D.obj, cfg);
prior_cond = compute_prior_scores_perf2(maps_cond, D.obj, cfg);
prior_pi = compute_prior_scores_perf2(maps_pi, D.obj, cfg);

score_ori_mix = blend_rule_prior_scores_perf2(score_ori_raw, prior_ori, idx_train, cfg);
score_cond_mix = blend_rule_prior_scores_perf2(score_cond_raw, prior_cond, idx_train, cfg);
score_pi_mix = blend_rule_prior_scores_perf2(score_pi_raw, prior_pi, idx_train, cfg);

[score_ori, calib_ori] = calibrate_scores_perf2(score_ori_mix, D.obj, idx_train, cfg);
[score_cond, calib_cond] = calibrate_scores_perf2(score_cond_mix, D.obj, idx_train, cfg);
[score_pi, calib_pi] = calibrate_scores_perf2(score_pi_mix, D.obj, idx_train, cfg);

tree_pack.calib_ori = calib_ori;
tree_pack.calib_cond = calib_cond;
tree_pack.calib_pi = calib_pi;

corr_ori = zeros(1, 3);
corr_cond = zeros(1, 3);
corr_pi = zeros(1, 3);
for j = 1:3
    corr_ori(j) = corr(score_ori(:, j), D.obj(:, j), 'Type', 'Pearson', 'Rows', 'complete');
    corr_cond(j) = corr(score_cond(:, j), D.obj(:, j), 'Type', 'Pearson', 'Rows', 'complete');
    corr_pi(j) = corr(score_pi(:, j), D.obj(:, j), 'Type', 'Pearson', 'Rows', 'complete');
end

case_score_tbl = table(D.sample_file(:), D.seed(:), D.raw_case_idx(:), D.case_idx(:), D.dataset_dt_hr(:), D.obj(:, 1), D.obj(:, 2), D.obj(:, 3), ...
    score_ori(:, 1), score_ori(:, 2), score_ori(:, 3), ...
    score_cond(:, 1), score_cond(:, 2), score_cond(:, 3), ...
    score_pi(:, 1), score_pi(:, 2), score_pi(:, 3), ...
    'VariableNames', {'SampleFile', 'Seed', 'RawCaseIndex', 'CaseIndex', 'DatasetDtHr', 'Jcost', 'Jsupp', 'Jvar', ...
    'OriScoreJcost', 'OriScoreJsupp', 'OriScoreJvar', ...
    'CondScoreJcost', 'CondScoreJsupp', 'CondScoreJvar', ...
    'PIScoreJcost', 'PIScoreJsupp', 'PIScoreJvar'});

method_col = ["Ori-SHAP"; "Cond-SHAP"; "PI-SHAP"; "Ori-SHAP"; "Cond-SHAP"; "PI-SHAP"; "Ori-SHAP"; "Cond-SHAP"; "PI-SHAP"];
obj_col = ["Jcost"; "Jcost"; "Jcost"; "Jsupp"; "Jsupp"; "Jsupp"; "Jvar"; "Jvar"; "Jvar"];
corr_val = [corr_ori(1); corr_cond(1); corr_pi(1); corr_ori(2); corr_cond(2); corr_pi(2); corr_ori(3); corr_cond(3); corr_pi(3)];
corr_tbl = table(method_col, obj_col, corr_val, 'VariableNames', {'Method', 'Objective', 'PearsonCorr'});

filter_tbl = table(zeta, mean(dnorm(mask_keep)), mean(dnorm), sum(mask_keep), D.n_case, ...
    'VariableNames', {'Zeta', 'MeanDvNormKept', 'MeanDvNormAll', 'NKept', 'NTotal'});

split_tbl = table((1:D.n_case)', ismember((1:D.n_case)', idx_train), ismember((1:D.n_case)', idx_test), ...
    D.seed(:), D.raw_case_idx(:), D.case_idx(:), D.sample_file(:), ...
    'VariableNames', {'RowID', 'IsTrain', 'IsTest', 'Seed', 'RawCaseIndex', 'CaseIndex', 'SampleFile'});

case_score_csv = fullfile(cfg.table_dir, 'holdout_case_scores.csv');
corr_csv = fullfile(cfg.table_dir, 'holdout_score_correlation.csv');
tree_csv = fullfile(cfg.table_dir, 'tree_training_summary.csv');
filter_csv = fullfile(cfg.table_dir, 'lhs_filter_summary.csv');
split_csv = fullfile(cfg.table_dir, 'train_test_split.csv');

writetable(case_score_tbl, case_score_csv);
writetable(corr_tbl, corr_csv);
writetable(tree_tbl, tree_csv);
writetable(filter_tbl, filter_csv);
writetable(split_tbl, split_csv);

save(fullfile(cfg.method_runs_dir, 'rule_tree_models.mat'), 'tree_pack', 'cfg', '-v7.3');

out = struct();
out.case_score_csv = case_score_csv;
out.corr_csv = corr_csv;
out.tree_csv = tree_csv;
out.filter_csv = filter_csv;
out.split_csv = split_csv;
out.n_case = D.n_case;

fprintf('Performance2 scores saved: %s\n', case_score_csv);
end

function D = load_holdout_dataset_perf2(cfg, idx_cc, idx_pin, pin_template, n_feat)
dt_tag = strrep(sprintf('%.1f', cfg.eval_dt_hr), '.', 'p');
seed_list = resolve_seed_list_perf2(cfg);

[file_paths, file_seed_hint] = collect_holdout_case_files_perf2(cfg.case_root, seed_list, dt_tag);
if isempty(file_paths)
    error('No holdout case files found under %s for dt=%s and seeds=%s', cfg.case_root, dt_tag, mat2str(seed_list));
end

if ~isempty(cfg.max_holdout_cases) && cfg.max_holdout_cases > 0 && numel(file_paths) > cfg.max_holdout_cases
    rng(cfg.rng_seed + 101, 'twister');
    pick = randperm(numel(file_paths), cfg.max_holdout_cases);
    pick = sort(pick);
    file_paths = file_paths(pick);
    file_seed_hint = file_seed_hint(pick);
end

n_file = numel(file_paths);
sample_file = strings(n_file, 1);
seed = nan(n_file, 1);
raw_case_idx = nan(n_file, 1);
case_idx = nan(n_file, 1);
dataset_dt_hr = nan(n_file, 1);
obj = nan(n_file, 3);
Xq = nan(n_file, n_feat);
policy = nan(cfg.n_time_nn, cfg.n_comp, n_file);
dv = nan(cfg.n_time_shap, cfg.n_comp, n_file);
pi_maps = nan(cfg.n_time_shap, cfg.n_comp, 3, n_file);

n_ok = 0;
for i = 1:n_file
    fp = char(file_paths(i));
    [~, fname, ext] = fileparts(fp);
    fname = [fname, ext];

    try
        S = load(fp, 'payload');
        p = S.payload;
    catch
        continue;
    end

    if ~isfield(p, 'inputs') || ~isfield(p.inputs, 'cc_policy') || ...
            ~isfield(p, 'outputs') || ~isfield(p.outputs, 'objective') || ...
            ~isfield(p, 'system') || ~isfield(p.system, 'shap')
        continue;
    end

    shp = p.system.shap;
    req = {'item_shap_cost', 'item_shap_supp', 'item_shap_var'};
    if ~all(isfield(shp, req))
        continue;
    end

    cc = fix_policy_shape_perf2(p.inputs.cc_policy, cfg.n_time_nn, cfg.n_comp);
    dv_i = diff(cc, 1, 1);

    m1 = ensure_map_shape_perf2(shp.item_shap_cost, cfg.n_time_shap, cfg.n_comp);
    m2 = ensure_map_shape_perf2(shp.item_shap_supp, cfg.n_time_shap, cfg.n_comp);
    m3 = ensure_map_shape_perf2(shp.item_shap_var, cfg.n_time_shap, cfg.n_comp);

    y = [p.outputs.objective.Jcost, p.outputs.objective.Jsupp, p.outputs.objective.Jvar];
    if ~all(isfinite(y))
        continue;
    end

    seed_i = parse_seed_perf2(p, fp, file_seed_hint(i));
    raw_idx_i = parse_case_idx_perf2(p, fname);
    uid_i = compose_case_uid_perf2(seed_i, raw_idx_i, i);

    n_ok = n_ok + 1;
    sample_file(n_ok) = string(fp);
    seed(n_ok) = seed_i;
    raw_case_idx(n_ok) = raw_idx_i;
    case_idx(n_ok) = uid_i;
    dataset_dt_hr(n_ok) = cfg.eval_dt_hr;
    obj(n_ok, :) = y;
    policy(:, :, n_ok) = cc;
    dv(:, :, n_ok) = dv_i;
    pi_maps(:, :, 1, n_ok) = m1;
    pi_maps(:, :, 2, n_ok) = m2;
    pi_maps(:, :, 3, n_ok) = m3;

    x = zeros(1, n_feat);
    x(idx_cc) = reshape(cc', 1, []);
    x(idx_pin) = pin_template;
    Xq(n_ok, :) = x;
end

if n_ok < 1
    error('No valid holdout cases loaded for dt=%s and seeds=%s', dt_tag, mat2str(seed_list));
end

sample_file = sample_file(1:n_ok);
seed = seed(1:n_ok);
raw_case_idx = raw_case_idx(1:n_ok);
case_idx = case_idx(1:n_ok);
dataset_dt_hr = dataset_dt_hr(1:n_ok);
obj = obj(1:n_ok, :);
Xq = Xq(1:n_ok, :);
policy = policy(:, :, 1:n_ok);
dv = dv(:, :, 1:n_ok);
pi_maps = pi_maps(:, :, :, 1:n_ok);

D = struct();
D.sample_file = sample_file;
D.seed = seed;
D.raw_case_idx = raw_case_idx;
D.case_idx = case_idx;
D.dataset_dt_hr = dataset_dt_hr;
D.obj = obj;
D.Xq = Xq;
D.policy = policy;
D.dv = dv;
D.pi_maps = pi_maps;
D.n_case = n_ok;
end

function seed_list = resolve_seed_list_perf2(cfg)
if isfield(cfg, 'eval_seed_list') && ~isempty(cfg.eval_seed_list)
    seed_list = cfg.eval_seed_list(:)';
else
    seed_list = cfg.eval_seed;
end
seed_list = round(seed_list(isfinite(seed_list)));
seed_list = unique(seed_list, 'stable');
if isempty(seed_list)
    seed_list = 37;
end
end

function [file_paths, file_seed_hint] = collect_holdout_case_files_perf2(case_root, seed_list, dt_tag)
file_paths = strings(0, 1);
file_seed_hint = zeros(0, 1);

for s = 1:numel(seed_list)
    sd = seed_list(s);
    case_dir = fullfile(case_root, sprintf('seed_%03d', sd), sprintf('dataset_dt_%s', dt_tag));
    if exist(case_dir, 'dir') ~= 7
        warning('Holdout case directory not found (skip): %s', case_dir);
        continue;
    end

    files = dir(fullfile(case_dir, 'sample_*.mat'));
    if isempty(files)
        warning('No holdout sample files in (skip): %s', case_dir);
        continue;
    end

    [~, ord] = sort({files.name});
    files = files(ord);

    n = numel(files);
    p = strings(n, 1);
    for i = 1:n
        p(i) = string(fullfile(files(i).folder, files(i).name));
    end

    file_paths = [file_paths; p]; %#ok<AGROW>
    file_seed_hint = [file_seed_hint; repmat(sd, n, 1)]; %#ok<AGROW>
end
end

function idx = parse_case_idx_perf2(p, fname)
idx = NaN;
if isfield(p, 'meta') && isfield(p.meta, 'sample_id') && isfinite(p.meta.sample_id)
    idx = double(p.meta.sample_id);
    return;
end

t = regexp(fname, 'sample_(\d+)\.mat', 'tokens', 'once');
if ~isempty(t)
    idx = str2double(t{1});
end
end

function seed = parse_seed_perf2(p, fp, seed_hint)
seed = NaN;

if isfield(p, 'meta') && isfield(p.meta, 'seed') && isfinite(p.meta.seed)
    seed = double(p.meta.seed);
elseif isfinite(seed_hint)
    seed = double(seed_hint);
else
    tk = regexp(fp, 'seed_(\d+)', 'tokens', 'once');
    if ~isempty(tk)
        seed = str2double(tk{1});
    end
end

if ~isfinite(seed)
    seed = 0;
end
seed = round(seed);
end

function uid = compose_case_uid_perf2(seed, raw_idx, serial_idx)
s = round(seed);
r = round(raw_idx);

if ~isfinite(s)
    s = 0;
end
if ~isfinite(r)
    r = serial_idx;
end

uid = s * 1e6 + r;
if ~isfinite(uid) || uid <= 0
    uid = serial_idx;
end
end

function [mask, zeta, dnorm] = apply_lhs_like_filter_perf2(dv, cfg, seed_vec)
n = size(dv, 3);
dnorm = zeros(n, 1);
for i = 1:n
    A = dv(:, :, i);
    dnorm(i) = sum(A(:) .^ 2);
end

if nargin < 3
    seed_vec = nan(n, 1);
end
if isempty(seed_vec)
    seed_vec = nan(n, 1);
end
seed_vec = seed_vec(:);

if ~isempty(cfg.filter_zeta_override) && isfinite(cfg.filter_zeta_override)
    zeta = cfg.filter_zeta_override;
else
    dnorm_ref = dnorm;
    if isfield(cfg, 'filter_use_train_only') && cfg.filter_use_train_only && ...
            isfield(cfg, 'train_seed_list') && ~isempty(cfg.train_seed_list)
        m_ref = ismember(seed_vec, cfg.train_seed_list(:));
        if any(m_ref)
            dnorm_ref = dnorm(m_ref);
        end
    end
    zeta = quantile(dnorm_ref, cfg.filter_quantile);
end

mask = dnorm <= zeta;
end

function D2 = subset_dataset_perf2(D, mask)
D2 = struct();
D2.sample_file = D.sample_file(mask);
if isfield(D, 'seed')
    D2.seed = D.seed(mask);
end
if isfield(D, 'raw_case_idx')
    D2.raw_case_idx = D.raw_case_idx(mask);
end
D2.case_idx = D.case_idx(mask);
if isfield(D, 'dataset_dt_hr')
    D2.dataset_dt_hr = D.dataset_dt_hr(mask);
end
D2.obj = D.obj(mask, :);
D2.Xq = D.Xq(mask, :);
D2.policy = D.policy(:, :, mask);
D2.dv = D.dv(:, :, mask);
D2.pi_maps = D.pi_maps(:, :, :, mask);
D2.n_case = sum(mask);
end

function [idx_train, idx_test] = split_train_test_perf2(n_case, cfg, seed_vec)
if nargin >= 3 && ~isempty(seed_vec)
    seed_vec = seed_vec(:);
else
    seed_vec = nan(n_case, 1);
end

use_seed_split = false;
if isfield(cfg, 'split_mode') && strcmpi(string(cfg.split_mode), "seed")
    use_seed_split = true;
end
if isfield(cfg, 'train_seed_list') && ~isempty(cfg.train_seed_list)
    use_seed_split = true;
end

if use_seed_split
    if ~isfield(cfg, 'train_seed_list') || isempty(cfg.train_seed_list)
        error('split_mode=seed requires non-empty train_seed_list');
    end

    m_train = ismember(seed_vec, cfg.train_seed_list(:));
    if isfield(cfg, 'test_seed_list') && ~isempty(cfg.test_seed_list)
        m_test = ismember(seed_vec, cfg.test_seed_list(:));
    else
        m_test = ~m_train;
    end

    idx_train = find(m_train);
    idx_test = find(m_test);

    if isempty(idx_train)
        error('Seed-wise split produced empty training set. train_seed_list=%s', mat2str(cfg.train_seed_list));
    end
    if isempty(idx_test)
        error('Seed-wise split produced empty testing set. test_seed_list=%s', mat2str(cfg.test_seed_list));
    end

    return;
end

rng(cfg.rng_seed + 23, 'twister');
ord = randperm(n_case);
n_train = max(cfg.min_train_cases, round(cfg.train_ratio_tree * n_case));
n_train = min(max(n_train, 1), n_case - 1);

idx_train = sort(ord(1:n_train));
idx_test = sort(ord(n_train + 1:end));
if isempty(idx_test)
    idx_test = idx_train;
end
end

function idx_train = maybe_subsample_train_idx_perf2(idx_train, cfg)
if isempty(idx_train)
    return;
end

if ~isfield(cfg, 'train_sample_k') || isempty(cfg.train_sample_k) || ~isfinite(cfg.train_sample_k)
    idx_train = sort(idx_train(:));
    return;
end

k = round(cfg.train_sample_k);
if k <= 0 || k >= numel(idx_train)
    idx_train = sort(idx_train(:));
    return;
end

seed = 0;
if isfield(cfg, 'train_sample_seed') && ~isempty(cfg.train_sample_seed) && isfinite(cfg.train_sample_seed)
    seed = round(cfg.train_sample_seed);
end

rng(seed, 'twister');
p = randperm(numel(idx_train), k);
idx_train = sort(idx_train(p));
end

function [ok, maps_ori, maps_cond, maps_pi] = try_load_map_cache_perf2(cfg, D, idx_train, idx_test)
ok = false;
maps_ori = [];
maps_cond = [];
maps_pi = [];

if ~cfg.use_map_cache
    return;
end
if exist(cfg.map_cache_file, 'file') ~= 2
    return;
end

try
    S = load(cfg.map_cache_file, 'cache');
    C = S.cache;
catch
    return;
end

if ~isstruct(C) || ~all(isfield(C, {'sample_file', 'case_idx', 'idx_train', 'idx_test', 'maps_ori', 'maps_cond', 'maps_pi'}))
    return;
end

same_case = numel(C.sample_file) == numel(D.sample_file) && all(string(C.sample_file(:)) == string(D.sample_file(:)));
same_idx = isequal(C.case_idx(:), D.case_idx(:)) && isequal(C.idx_train(:), idx_train(:)) && isequal(C.idx_test(:), idx_test(:));
if ~same_case || ~same_idx
    return;
end

maps_ori = C.maps_ori;
maps_cond = C.maps_cond;
maps_pi = C.maps_pi;

ok = true;
end

function save_map_cache_perf2(cfg, D, idx_train, idx_test, maps_ori, maps_cond, maps_pi)
if ~cfg.use_map_cache
    return;
end

cache = struct();
cache.sample_file = D.sample_file;
cache.case_idx = D.case_idx;
cache.idx_train = idx_train;
cache.idx_test = idx_test;
cache.maps_ori = maps_ori;
cache.maps_cond = maps_cond;
cache.maps_pi = maps_pi;

try
    save(cfg.map_cache_file, 'cache', '-v7.3');
catch
end
end

function [maps_ori, maps_cond] = compute_nn_maps_perf2(models_obj, Xbg, Xq, idx_cc, cfg)
n_case = size(Xq, 1);
maps_ori = zeros(cfg.n_time_shap, cfg.n_comp, 3, n_case);
maps_cond = zeros(cfg.n_time_shap, cfg.n_comp, 3, n_case);

for j = 1:3
    f = @(Xinput) predict_scalar_post_external_min(models_obj(j), Xinput);
    sv_ori = run_shapley_batch_perf2(f, Xbg, Xq, 'interventional', cfg.shap_num_subsets_interv, cfg);
    sv_cond = run_shapley_batch_perf2(f, Xbg, Xq, 'conditional', cfg.shap_num_subsets_cond, cfg);

    for i = 1:n_case
        maps_ori(:, :, j, i) = reshape_cc_shap_map_perf2(sv_ori(:, i), idx_cc, cfg.n_time_nn, cfg.n_time_shap, cfg.n_comp);
        maps_cond(:, :, j, i) = reshape_cc_shap_map_perf2(sv_cond(:, i), idx_cc, cfg.n_time_nn, cfg.n_time_shap, cfg.n_comp);
    end
end
end

function sv = run_shapley_batch_perf2(f, Xbg, Xq, method_name, max_subsets, cfg)
n_query = size(Xq, 1);
n_feat = size(Xq, 2);
batch_n = max(1, cfg.shap_query_batch);
sv = zeros(n_feat, n_query);

for st = 1:batch_n:n_query
    ed = min(st + batch_n - 1, n_query);
    idx = st:ed;
    Xb = Xq(idx, :);

    args = {'Method', method_name, 'QueryPoints', Xb, 'MaxNumSubsets', max_subsets};
    ws = warning('off', 'stats:responsible:shapley:MaxNumSubsetsTooSmall');
    cleaner = onCleanup(@() warning(ws)); %#ok<NASGU>

    if cfg.shap_use_parallel
        try
            shp = shapley(f, Xbg, args{:}, 'UseParallel', true);
        catch
            shp = shapley(f, Xbg, args{:});
        end
    else
        shp = shapley(f, Xbg, args{:});
    end

    svb = ensure_matrix_perf2(shp.ShapleyValues.ShapleyValue);
    if size(svb, 1) ~= n_feat && size(svb, 2) == n_feat
        svb = svb';
    end

    if size(svb, 1) ~= n_feat || size(svb, 2) ~= numel(idx)
        svb = reshape(svb, [n_feat, numel(idx)]);
    end

    sv(:, idx) = svb;
end
end

function M = reshape_cc_shap_map_perf2(shap_vec, idx_cc, n_time_nn, n_time_shap, n_comp)
v = shap_vec(idx_cc);
M = reshape(v, [n_comp, n_time_nn])';
if size(M, 1) > n_time_shap
    M = M(1:n_time_shap, :);
elseif size(M, 1) < n_time_shap
    t_in = linspace(0, 1, size(M, 1));
    t_out = linspace(0, 1, n_time_shap);
    Q = zeros(n_time_shap, n_comp);
    for c = 1:n_comp
        Q(:, c) = interp1(t_in, M(:, c), t_out, 'linear', 'extrap');
    end
    M = Q;
end
end

function maps = robust_clip_maps_perf2(maps, pct)
for j = 1:size(maps, 3)
    A = maps(:, :, j, :);
    cap = prctile(abs(A(:)), pct);
    if ~isfinite(cap) || cap <= 0
        continue;
    end
    maps(:, :, j, :) = min(max(A, -cap), cap);
end
end

function maps = sanitize_maps_perf2(maps, cfg)
maps(~isfinite(maps)) = NaN;

for j = 1:size(maps, 3)
    for n = 1:size(maps, 4)
        for c = 1:size(maps, 2)
            v = squeeze(maps(:, c, j, n));
            if all(~isfinite(v))
                v = zeros(size(v));
            elseif any(~isfinite(v))
                try
                    v = fillmissing(v, 'linear', 'EndValues', 'nearest');
                catch
                    id = find(isfinite(v));
                    if isempty(id)
                        v = zeros(size(v));
                    elseif numel(id) == 1
                        v(:) = v(id(1));
                    else
                        xi = (1:numel(v))';
                        v = interp1(id, v(id), xi, 'linear', 'extrap');
                    end
                end
            end

            if cfg.map_smooth_window > 1
                try
                    v = smoothdata(v, 'movmean', cfg.map_smooth_window);
                catch
                    v = movmean(v, cfg.map_smooth_window, 'Endpoints', 'shrink');
                end
            end

            v(~isfinite(v)) = 0;
            maps(:, c, j, n) = v;
        end
    end
end
end

function [pack, tree_tbl] = train_rule_trees_perf2(D, maps_ori, maps_cond, maps_pi, idx_train, idx_test, cfg)
methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
maps_all = {maps_ori, maps_cond, maps_pi};

n_method = numel(methods);
n_obj = 3;
n_comp = cfg.n_comp;

models = cell(n_method, n_obj, n_comp);
weights = zeros(cfg.n_time_shap, cfg.n_comp, n_obj, n_method);
reliability = zeros(n_obj, n_comp, n_method);

rows_method = strings(0, 1);
rows_obj = strings(0, 1);
rows_comp = zeros(0, 1);
rows_leaf = zeros(0, 1);
rows_cv = zeros(0, 1);
rows_test = zeros(0, 1);
rows_refit = false(0, 1);
rows_ntr = zeros(0, 1);
rows_nte = zeros(0, 1);
rows_ptr = nan(0, 1);
rows_pte = nan(0, 1);
rows_rel = zeros(0, 1);

obj_names = ["Jcost", "Jsupp", "Jvar"];
goal_sign = [-1, +1, -1];

for m = 1:n_method
    Mmap = maps_all{m};
    for j = 1:n_obj
        [labels, label_w] = build_labels_perf2(Mmap(:, :, j, :), D.dv, goal_sign(j), idx_train, cfg);
        wj = mean(abs(Mmap(:, :, j, idx_train)), 4);
        sw = sum(wj, 'all');
        if ~isfinite(sw) || sw <= eps
            wj = ones(size(wj)) / numel(wj);
        else
            wj = wj / sw;
        end
        weights(:, :, j, m) = wj;

        for c = 1:n_comp
            [Xtr, Ytr, Wtr] = build_tree_rows_perf2(D.policy, D.dv, labels, label_w, c, idx_train, cfg);
            [Xte, Yte, ~] = build_tree_rows_perf2(D.policy, D.dv, labels, label_w, c, idx_test, cfg);
            [Xall, Yall, Wall] = build_tree_rows_perf2(D.policy, D.dv, labels, label_w, c, 1:D.n_case, cfg);

            if isfield(cfg, 'tree_use_class_balance_weights') && cfg.tree_use_class_balance_weights
                Wtr = apply_class_balance_weights_perf2(Ytr, Wtr, cfg);
                if cfg.tree_refit_all
                    Wall = apply_class_balance_weights_perf2(Yall, Wall, cfg);
                end
            end

            [mdl, best_leaf, acc_cv] = fit_best_tree_perf2(Xtr, Ytr, Wtr, cfg);
            acc_te = tree_acc_perf2(mdl, Xte, Yte, cfg);
            refit_flag = false;

            if acc_te < cfg.tree_acc_thresh && cfg.tree_refit_all && ~isempty(Xall)
                mdl = fit_tree_once_perf2(Xall, Yall, Wall, best_leaf, cfg);
                acc_te = tree_acc_perf2(mdl, Xte, Yte, cfg);
                refit_flag = true;
            end

            models{m, j, c} = mdl;
            reliability(j, c, m) = reliability_from_acc_perf2(acc_cv, acc_te, cfg);

            n_tr = size(Xtr, 1);
            n_te = size(Xte, 1);
            if n_tr > 0
                ytr_num = str2double(string(Ytr));
                p_tr = mean(ytr_num > 0, 'omitnan');
            else
                p_tr = NaN;
            end
            if n_te > 0
                yte_num = str2double(string(Yte));
                p_te = mean(yte_num > 0, 'omitnan');
            else
                p_te = NaN;
            end

            rows_method(end + 1, 1) = methods(m); %#ok<AGROW>
            rows_obj(end + 1, 1) = obj_names(j); %#ok<AGROW>
            rows_comp(end + 1, 1) = c; %#ok<AGROW>
            rows_leaf(end + 1, 1) = best_leaf; %#ok<AGROW>
            rows_cv(end + 1, 1) = acc_cv; %#ok<AGROW>
            rows_test(end + 1, 1) = acc_te; %#ok<AGROW>
            rows_refit(end + 1, 1) = refit_flag; %#ok<AGROW>
            rows_ntr(end + 1, 1) = n_tr; %#ok<AGROW>
            rows_nte(end + 1, 1) = n_te; %#ok<AGROW>
            rows_ptr(end + 1, 1) = p_tr; %#ok<AGROW>
            rows_pte(end + 1, 1) = p_te; %#ok<AGROW>
            rows_rel(end + 1, 1) = reliability(j, c, m); %#ok<AGROW>
        end
    end
end

tree_tbl = table(rows_method, rows_obj, rows_comp, rows_leaf, rows_cv, rows_test, rows_refit, ...
    rows_ntr, rows_nte, rows_ptr, rows_pte, rows_rel, ...
    'VariableNames', {'Method', 'Objective', 'Compressor', 'BestLeaf', 'CVAcc', 'TestAcc', 'RefitAll', ...
    'TrainRows', 'TestRows', 'TrainPosRate', 'TestPosRate', 'Reliability'});

pack = struct();
pack.models_ori = squeeze(models(1, :, :));
pack.models_cond = squeeze(models(2, :, :));
pack.models_pi = squeeze(models(3, :, :));
pack.weights_ori = weights(:, :, :, 1);
pack.weights_cond = weights(:, :, :, 2);
pack.weights_pi = weights(:, :, :, 3);
pack.reliability_ori = reliability(:, :, 1);
pack.reliability_cond = reliability(:, :, 2);
pack.reliability_pi = reliability(:, :, 3);
end

function [labels, label_w] = build_labels_perf2(map_obj, dv, goal_sign, idx_train, cfg)
sz = size(map_obj);
if numel(sz) == 4 && sz(3) == 1
    map_obj = reshape(map_obj, sz(1), sz(2), sz(4));
elseif numel(sz) == 2
    map_obj = reshape(map_obj, sz(1), sz(2), 1);
end

d = dv;
d(~isfinite(d)) = 0;
if cfg.label_use_dv_interaction
    A = goal_sign .* map_obj .* d;
else
    A = goal_sign .* map_obj;
end
A(~isfinite(A)) = 0;

levels = cfg.label_class_levels(:)';
mags = sort(unique(abs(levels)));
if isempty(mags)
    mags = 1;
end

atr = abs(A(:, :, idx_train));
atr = atr(:);
atr = atr(isfinite(atr));
if isempty(atr)
    tau = cfg.label_neutral_abs_floor;
else
    tau = quantile(atr, cfg.label_neutral_abs_quantile);
    tau = max(tau, cfg.label_neutral_abs_floor);
end

labels = zeros(size(A));

if numel(mags) == 1
    labels(A > tau) = mags(1);
    labels(A < -tau) = -mags(1);
else
    a_use = atr(atr > tau);
    if isempty(a_use)
        edges = linspace(tau, tau + 1, numel(mags) + 1);
        edges = edges(2:end-1);
    else
        q = cfg.label_level_quantiles(:)';
        q = q(isfinite(q));
        q = q(q > 0 & q < 1);
        if numel(q) ~= (numel(mags) - 1)
            q = (1:(numel(mags) - 1)) / numel(mags);
        end
        edges = quantile(a_use, q);
        edges = max(edges, tau);
        for ei = 2:numel(edges)
            if edges(ei) <= edges(ei - 1)
                edges(ei) = edges(ei - 1) + max(eps(edges(ei - 1)), 1e-12);
            end
        end
    end

    absA = abs(A);
    mag_idx = ones(size(A));
    for ei = 1:numel(edges)
        mag_idx = mag_idx + (absA > edges(ei));
    end
    mag_idx = min(max(mag_idx, 1), numel(mags));
    mag_val = mags(mag_idx);

    labels(A > tau) = mag_val(A > tau);
    labels(A < -tau) = -mag_val(A < -tau);
end

if cfg.label_fill_from_dv
    s = sign(dv);
    s(~isfinite(s)) = 0;
    m = (labels == 0) & (s ~= 0);
    labels(m) = s(m) * mags(1);
end

label_w = abs(A);
if cfg.label_weight_cap_pct > 0
    cap = prctile(label_w(:), cfg.label_weight_cap_pct);
    if isfinite(cap) && cap > 0
        label_w = min(label_w, cap);
    end
end

label_w(~isfinite(label_w)) = 0;
if tau > 0
    label_w = label_w ./ (tau + label_w);
end
label_w(labels == 0) = 0;
end

function [X, Y, W] = build_tree_rows_perf2(policy, dv, labels, label_w, comp_idx, sample_idx, cfg)
class_vals = cfg.label_class_levels(:)';
class_vals = class_vals(class_vals ~= 0);
if isempty(class_vals)
    class_vals = [-1, 1];
end
class_names = string(class_vals);

n_t = size(dv, 1);
n_s = numel(sample_idx);
n_max = n_t * n_s;

X = zeros(n_max, 10);
Ynum = zeros(n_max, 1);
W = zeros(n_max, 1);
r = 0;

for ii = 1:n_s
    k = sample_idx(ii);
    v = policy(1:n_t, :, k);
    d = dv(:, :, k);
    y = labels(:, comp_idx, k);
    w = label_w(:, comp_idx, k);
    for t = 1:n_t
        yt = y(t);
        if yt == 0 || ~isfinite(yt)
            continue;
        end

        r = r + 1;
        row_x = [v(t, :), d(t, :)];
        row_x(~isfinite(row_x)) = 0;
        X(r, :) = row_x;
        Ynum(r) = yt;

        wt = w(t);
        if ~isfinite(wt) || wt <= 0
            wt = cfg.tree_min_sample_weight;
        end
        W(r) = wt;
    end
end

if r < 1
    X = zeros(0, 10);
    Y = categorical([], class_vals, class_names);
    W = zeros(0, 1);
    return;
end

X = X(1:r, :);
Ynum = Ynum(1:r);
W = W(1:r);

if cfg.tree_use_sample_weights
    W = W / max(mean(W), eps);
else
    W = ones(size(W));
end

Y = categorical(Ynum, class_vals, class_names);
end

function W = apply_class_balance_weights_perf2(Y, W, cfg)
if isempty(Y) || isempty(W)
    return;
end

cls = categories(Y);
n_cls = numel(cls);
if n_cls < 2
    return;
end

yc = string(Y);
counts = zeros(n_cls, 1);
for i = 1:n_cls
    counts(i) = sum(yc == string(cls{i}));
end

ok = counts > 0;
if ~any(ok)
    return;
end

invw = zeros(n_cls, 1);
invw(ok) = 1 ./ counts(ok);
invw = invw / max(mean(invw(ok)), eps);

cap = 6.0;
if isfield(cfg, 'tree_class_weight_cap') && isfinite(cfg.tree_class_weight_cap) && cfg.tree_class_weight_cap > 0
    cap = cfg.tree_class_weight_cap;
end

for i = 1:n_cls
    m = (yc == string(cls{i}));
    if any(m)
        W(m) = W(m) * min(invw(i), cap);
    end
end

W = W / max(mean(W), eps);
end

function [mdl, best_leaf, best_acc] = fit_best_tree_perf2(Xtr, Ytr, Wtr, cfg)
leaf_grid = cfg.tree_leaf_grid(:)';
best_leaf = leaf_grid(1);
class_vals = cfg.label_class_levels(:)';
class_vals = class_vals(class_vals ~= 0);
if numel(class_vals) < 2
    class_vals = [-1, 1];
end
class_names = string(class_vals);

if isempty(Xtr)
    neg = class_vals(class_vals < 0);
    pos = class_vals(class_vals > 0);
    if isempty(neg) || isempty(pos)
        base = class_vals(1:min(2, numel(class_vals)));
        if numel(base) < 2
            base = [-1, 1];
        end
    else
        base = [neg(1), pos(1)];
    end
    y0 = categorical(base', class_vals, class_names);
    mdl = fit_tree_once_perf2(zeros(2, 10), y0, [1; 1], best_leaf, cfg);
    best_acc = NaN;
    return;
end

u = unique(string(Ytr));
if numel(u) < 2
    mdl = fit_tree_once_perf2(Xtr, Ytr, Wtr, best_leaf, cfg);
    best_acc = 1.0;
    return;
end

best_acc = -inf;
for i = 1:numel(leaf_grid)
    leaf = leaf_grid(i);
    mdl_i = fit_tree_once_perf2(Xtr, Ytr, Wtr, leaf, cfg);
    acc = cv_acc_tree_perf2(mdl_i, numel(Ytr), cfg);
    if acc > best_acc
        best_acc = acc;
        best_leaf = leaf;
    end
end

mdl = fit_tree_once_perf2(Xtr, Ytr, Wtr, best_leaf, cfg);
end

function mdl = fit_tree_once_perf2(X, Y, W, leaf, cfg)
mdl = fitctree(X, Y, ...
    'MinLeafSize', leaf, ...
    'MaxNumSplits', cfg.tree_max_splits, ...
    'SplitCriterion', 'gdi', ...
    'PredictorSelection', 'allsplits', ...
    'Weights', W);
end

function acc = cv_acc_tree_perf2(mdl, n_obs, cfg)
if n_obs < 2
    acc = NaN;
    return;
end

kfold = min(cfg.tree_cvfold, max(2, floor(n_obs / max(cfg.tree_cv_min_obs_per_fold, 1))));
kfold = min(kfold, n_obs);

if kfold < 2
    acc = 1 - resubLoss(mdl, 'LossFun', 'classiferror');
    return;
end

try
    cv_i = crossval(mdl, 'KFold', kfold);
    acc = 1 - kfoldLoss(cv_i, 'LossFun', 'classiferror');
catch
    acc = 1 - resubLoss(mdl, 'LossFun', 'classiferror');
end
end

function acc = tree_acc_perf2(mdl, X, Y, cfg)
if isempty(X)
    acc = NaN;
    return;
end
pred = predict(mdl, X);
if cfg.tree_use_balanced_acc
    acc = balanced_acc_perf2(Y, pred);
else
    acc = mean(pred == Y);
end
end

function acc = balanced_acc_perf2(y_true, y_pred)
cls = unique(string(y_true));
rec = zeros(0, 1);
for i = 1:numel(cls)
    m = string(y_true) == cls(i);
    if any(m)
        rec(end + 1, 1) = mean(string(y_pred(m)) == cls(i)); %#ok<AGROW>
    end
end
if isempty(rec)
    acc = NaN;
else
    acc = mean(rec);
end
end

function r = reliability_from_acc_perf2(acc_cv, acc_te, cfg)
x = [acc_cv, acc_te];
x = x(isfinite(x));
if isempty(x)
    r = 0;
    return;
end
acc = mean(x);

use_thresh = false;
if isfield(cfg, 'score_reliability_use_threshold') && ~isempty(cfg.score_reliability_use_threshold)
    use_thresh = logical(cfg.score_reliability_use_threshold);
end

if use_thresh
    r = (acc - cfg.score_reliability_baseline) / max(1 - cfg.score_reliability_baseline, eps);
else
    r = acc;
end
r = max(0, min(1, r));
end

function score = score_by_rules_perf2(D, model_cell, weight_maps, reliability, idx_train, cfg)
n_case = D.n_case;
n_obj = 3;
n_t = cfg.n_time_shap;
n_comp = cfg.n_comp;

if isfield(cfg, 'score_use_multilevel_match') && cfg.score_use_multilevel_match
    level_edges = build_action_level_edges_perf2(D.dv, idx_train, cfg);
else
    level_edges = cell(n_comp, 1);
end

score = zeros(n_case, n_obj);
for j = 1:n_obj
    use_multilevel_obj = is_multilevel_obj_enabled_perf2(cfg, j);

    w = weight_maps(:, :, j);
    sw = sum(w, 'all');
    if ~isfinite(sw) || sw <= eps
        w = ones(size(w)) / numel(w);
    else
        w = w / sw;
    end

    for n = 1:n_case
        v = D.policy(1:n_t, :, n);
        d = D.dv(:, :, n);
        Xn = [v, d];

        miss = zeros(n_t, n_comp);
        for c = 1:n_comp
            mdl = model_cell{j, c};
            [pred, post] = predict(mdl, Xn);
            act = sign(d(:, c));
            act(act == 0) = 1;
            act(~isfinite(act)) = 1;
            abs_act = abs(d(:, c));
            abs_act(~isfinite(abs_act)) = 0;
            rel = reliability(j, c);
            if ~isfinite(rel)
                rel = 0;
            end

            if cfg.score_use_prob_mismatch
                if isfield(cfg, 'score_use_multilevel_match') && cfg.score_use_multilevel_match && use_multilevel_obj
                    pm = prob_match_multilevel_perf2(mdl, post, pred, act, abs_act, level_edges{c}, j, cfg);
                else
                    pm = prob_match_perf2(mdl, post, pred, act);
                end
                base_miss = 1 - pm;
            else
                pred_num = str2double(string(pred));
                base_miss = double(pred_num ~= act);
            end

            miss(:, c) = rel .* base_miss + (1 - rel) .* 0.5;
        end

        score(n, j) = sum(sum(w .* miss));
    end
end
end

function pm = prob_match_perf2(mdl, post, pred, act)
n = numel(act);
pm = zeros(n, 1);

if size(post, 2) < 2 || numel(mdl.ClassNames) < 2
    pred_num = str2double(string(pred));
    pm = double(sign(pred_num) == sign(act));
    return;
end

cn = string(mdl.ClassNames(:));
cls = str2double(cn);
if any(~isfinite(cls))
    pred_num = str2double(string(pred));
    pm = double(sign(pred_num) == sign(act));
    return;
end

id_pos = cls > 0;
id_neg = cls < 0;
if ~any(id_pos) || ~any(id_neg)
    pred_num = str2double(string(pred));
    pm = double(sign(pred_num) == sign(act));
    return;
end

p_pos = sum(post(:, id_pos), 2);
p_neg = sum(post(:, id_neg), 2);
m_pos = act >= 0;
pm(m_pos) = p_pos(m_pos);
pm(~m_pos) = p_neg(~m_pos);
pm = max(0, min(1, pm));
end

function edge_cell = build_action_level_edges_perf2(dv, idx_train, cfg)
n_comp = size(dv, 2);
edge_cell = cell(n_comp, 1);

if nargin < 2 || isempty(idx_train)
    idx_train = 1:size(dv, 3);
end
idx_train = idx_train(:)';
idx_train = idx_train(isfinite(idx_train) & idx_train >= 1 & idx_train <= size(dv, 3));
idx_train = unique(round(idx_train), 'stable');
if isempty(idx_train)
    idx_train = 1:size(dv, 3);
end

class_vals = cfg.label_class_levels(:)';
class_vals = class_vals(class_vals ~= 0);
mags = sort(unique(abs(class_vals)));
if numel(mags) <= 1
    return;
end

q = cfg.label_level_quantiles(:)';
q = q(isfinite(q));
q = q(q > 0 & q < 1);
if numel(q) ~= (numel(mags) - 1)
    q = (1:(numel(mags) - 1)) / numel(mags);
end

for c = 1:n_comp
    a = abs(dv(:, c, idx_train));
    a = a(:);
    a = a(isfinite(a));
    if isempty(a)
        edge_cell{c} = [];
        continue;
    end

    edges = quantile(a, q);
    for ei = 2:numel(edges)
        if edges(ei) <= edges(ei - 1)
            edges(ei) = edges(ei - 1) + max(eps(edges(ei - 1)), 1e-12);
        end
    end
    edge_cell{c} = edges(:)';
end
end

function pm = prob_match_multilevel_perf2(mdl, post, pred, act, abs_act, edges, obj_idx, cfg)
n = numel(act);
pm = zeros(n, 1);

if size(post, 2) < 2 || numel(mdl.ClassNames) < 2
    pm = prob_match_perf2(mdl, post, pred, act);
    return;
end

cn = string(mdl.ClassNames(:));
cls = str2double(cn);
if any(~isfinite(cls))
    pm = prob_match_perf2(mdl, post, pred, act);
    return;
end

mags = sort(unique(abs(cls)));
if isempty(mags)
    pm = prob_match_perf2(mdl, post, pred, act);
    return;
end

if numel(mags) <= 1
    target_mag = repmat(mags(1), n, 1);
else
    target_mag = map_abs_to_levels_perf2(abs_act, mags, edges);
end

target_sign = sign(act);
target_sign(~isfinite(target_sign) | target_sign == 0) = 1;
target_label = target_sign(:) .* target_mag(:);

class_sign = sign(cls(:)');
class_sign(class_sign == 0) = 1;

ws = 0.70;
ws = get_obj_sign_weight_perf2(cfg, obj_idx, ws);
ws = min(max(ws, 0), 1);

den_mag = max(max(mags) - min(mags), 1);
sign_match = double(bsxfun(@eq, target_sign(:), class_sign));
mag_diff = abs(bsxfun(@minus, abs(target_label(:)), abs(cls(:)')));
mag_sim = 1 - (mag_diff / den_mag);
mag_sim = max(0, min(1, mag_sim));

sim = ws * sign_match + (1 - ws) * mag_sim;
pm = sum(post .* sim, 2);
pm = max(0, min(1, pm));
end

function ws = get_obj_sign_weight_perf2(cfg, obj_idx, default_ws)
ws = default_ws;

if isfield(cfg, 'score_multilevel_sign_weight_by_objective') && ~isempty(cfg.score_multilevel_sign_weight_by_objective)
    v = cfg.score_multilevel_sign_weight_by_objective(:)';
    if numel(v) >= obj_idx && isfinite(v(obj_idx))
        ws = v(obj_idx);
        return;
    end
end

if isfield(cfg, 'score_multilevel_sign_weight') && isfinite(cfg.score_multilevel_sign_weight)
    ws = cfg.score_multilevel_sign_weight;
end
end

function tf = is_multilevel_obj_enabled_perf2(cfg, obj_idx)
tf = true;
if isfield(cfg, 'score_use_multilevel_by_objective') && ~isempty(cfg.score_use_multilevel_by_objective)
    v = cfg.score_use_multilevel_by_objective(:)';
    if numel(v) >= obj_idx && isfinite(v(obj_idx))
        tf = logical(v(obj_idx));
    end
end
end

function mag_val = map_abs_to_levels_perf2(abs_act, mags, edges)
abs_act = abs_act(:);
abs_act(~isfinite(abs_act)) = 0;

if isempty(edges)
    mag_val = repmat(mags(1), numel(abs_act), 1);
    return;
end

mag_idx = ones(size(abs_act));
for ei = 1:numel(edges)
    mag_idx = mag_idx + (abs_act > edges(ei));
end
mag_idx = min(max(mag_idx, 1), numel(mags));
mag_val = mags(mag_idx);
end

function prior = compute_prior_scores_perf2(maps, obj, cfg)
n_case = size(maps, 4);
prior = zeros(n_case, 3);

for j = 1:3
    ssum = squeeze(sum(sum(maps(:, :, j, :), 1), 2));
    if numel(ssum) ~= n_case
        ssum = reshape(ssum, [n_case, 1]);
    end

    if cfg.prior_scale_to_objective
        den = obj(:, j);
        ok = isfinite(ssum) & isfinite(den) & abs(den) > eps;
        alpha = 1;
        if any(ok)
            a = median(ssum(ok) ./ den(ok));
            if isfinite(a) && abs(a) > cfg.prior_alpha_floor
                alpha = a;
            end
        end
        ssum = ssum ./ alpha;
    end

    prior(:, j) = ssum;
end
end

function mix = blend_rule_prior_scores_perf2(score_rule, score_prior, idx_train, cfg)
wr = min(max(cfg.rule_prior_blend, 0), 1);
wp = 1 - wr;

if wp <= eps
    mix = score_rule;
    return;
end

mix = zeros(size(score_rule));
for j = 1:3
    zr = robust_z_with_train_perf2(score_rule(:, j), idx_train);
    zp = robust_z_with_train_perf2(score_prior(:, j), idx_train);
    mix(:, j) = wr * zr + wp * zp;
end
end

function z = robust_z_with_train_perf2(x, idx_train)
x = x(:);
xt = x(idx_train);
xt = xt(isfinite(xt));
if isempty(xt)
    z = zeros(size(x));
    return;
end

med = median(xt);
iq = iqr(xt);
if ~isfinite(iq) || iq <= eps
    iq = std(xt);
end
if ~isfinite(iq) || iq <= eps
    iq = 1;
end

z = (x - med) / iq;
z(~isfinite(z)) = 0;
end

function [score_out, calib] = calibrate_scores_perf2(score_in, obj, idx_train, cfg)
score_out = score_in;
calib = repmat(struct('UseCalibration', false, 'Beta0', NaN, 'Beta1', NaN, 'TrainCorr', NaN), 1, 3);

if ~cfg.score_calibrate_linear
    return;
end

for j = 1:3
    x = score_in(idx_train, j);
    y = obj(idx_train, j);
    ok = isfinite(x) & isfinite(y);
    if nnz(ok) < cfg.score_calib_min_samples || std(x(ok)) <= eps
        continue;
    end

    X = [ones(nnz(ok), 1), x(ok)];
    b = X \ y(ok);
    yhat = b(1) + b(2) * score_in(:, j);

    score_out(:, j) = yhat;
    calib(j).UseCalibration = true;
    calib(j).Beta0 = b(1);
    calib(j).Beta1 = b(2);
    calib(j).TrainCorr = corr(yhat(idx_train), y, 'Type', 'Pearson', 'Rows', 'complete');
end
end

function p = fix_policy_shape_perf2(p, n_time, n_comp)
if size(p, 2) ~= n_comp
    error('Policy compressor mismatch: expected %d got %d', n_comp, size(p, 2));
end
if size(p, 1) ~= n_time
    t_in = linspace(0, 1, size(p, 1));
    t_out = linspace(0, 1, n_time);
    q = zeros(n_time, n_comp);
    for c = 1:n_comp
        q(:, c) = interp1(t_in, p(:, c), t_out, 'linear', 'extrap');
    end
    p = q;
end
end

function M = ensure_map_shape_perf2(Min, n_t, n_comp)
M = Min;
if isempty(M)
    M = zeros(n_t, n_comp);
    return;
end

if size(M, 1) < size(M, 2)
    M = M';
end

if size(M, 2) ~= n_comp
    cc = min(size(M, 2), n_comp);
    T = zeros(size(M, 1), n_comp);
    T(:, 1:cc) = M(:, 1:cc);
    M = T;
end

if size(M, 1) ~= n_t
    t_in = linspace(0, 1, size(M, 1));
    t_out = linspace(0, 1, n_t);
    Q = zeros(n_t, n_comp);
    for c = 1:n_comp
        Q(:, c) = interp1(t_in, M(:, c), t_out, 'linear', 'extrap');
    end
    M = Q;
end

M(~isfinite(M)) = 0;
end

function out = ensure_matrix_perf2(A)
if istable(A)
    out = table2array(A);
elseif isvector(A)
    out = A(:);
else
    out = A;
end
end

function cfg = fill_cfg_defaults_perf2(cfg)
script_dir = fileparts(mfilename('fullpath'));

if ~isfield(cfg, 'work_dir') || isempty(cfg.work_dir)
    cfg.work_dir = script_dir;
end
if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.work_dir, 'plots');
end
if ~isfield(cfg, 'table_dir') || isempty(cfg.table_dir)
    cfg.table_dir = fullfile(cfg.work_dir, 'tables');
end
if ~isfield(cfg, 'selection_dir') || isempty(cfg.selection_dir)
    cfg.selection_dir = fullfile(cfg.work_dir, 'selected_top1_policies');
end
if ~isfield(cfg, 'ranking_dir') || isempty(cfg.ranking_dir)
    cfg.ranking_dir = fullfile(cfg.work_dir, 'holdout_rankings');
end
if ~isfield(cfg, 'method_runs_dir') || isempty(cfg.method_runs_dir)
    cfg.method_runs_dir = fullfile(cfg.work_dir, 'method_runs');
end
if ~isfield(cfg, 'candidate_search_dir') || isempty(cfg.candidate_search_dir)
    cfg.candidate_search_dir = fullfile(cfg.work_dir, 'candidate_search');
end
if ~isfield(cfg, 'use_map_cache') || isempty(cfg.use_map_cache)
    cfg.use_map_cache = true;
end
if ~isfield(cfg, 'map_cache_file') || isempty(cfg.map_cache_file)
    cfg.map_cache_file = fullfile(cfg.method_runs_dir, 'holdout_shap_maps_cache.mat');
end

repo_dir = fileparts(fileparts(cfg.work_dir));
if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end

if ~isfield(cfg, 'n_comp') || isempty(cfg.n_comp)
    cfg.n_comp = 5;
end
if ~isfield(cfg, 'n_time_nn') || isempty(cfg.n_time_nn)
    cfg.n_time_nn = 25;
end
if ~isfield(cfg, 'n_time_shap') || isempty(cfg.n_time_shap)
    cfg.n_time_shap = 24;
end

if ~isfield(cfg, 'eval_seed') || isempty(cfg.eval_seed)
    cfg.eval_seed = 37;
end
if ~isfield(cfg, 'eval_seed_list') || isempty(cfg.eval_seed_list)
    cfg.eval_seed_list = cfg.eval_seed;
end
if ~isfield(cfg, 'split_mode') || isempty(cfg.split_mode)
    cfg.split_mode = 'random';
end
if ~isfield(cfg, 'train_seed_list')
    cfg.train_seed_list = [];
end
if ~isfield(cfg, 'test_seed_list')
    cfg.test_seed_list = [];
end
if ~isfield(cfg, 'train_sample_k') || isempty(cfg.train_sample_k)
    cfg.train_sample_k = [];
end
if ~isfield(cfg, 'train_sample_seed') || isempty(cfg.train_sample_seed)
    cfg.train_sample_seed = 0;
end
if ~isfield(cfg, 'eval_dt_hr') || isempty(cfg.eval_dt_hr)
    cfg.eval_dt_hr = 1.0;
end
if ~isfield(cfg, 'max_holdout_cases')
    cfg.max_holdout_cases = [];
end

if ~isfield(cfg, 'dataset_file') || isempty(cfg.dataset_file)
    cfg.dataset_file = fullfile(cfg.repo_dir, 'shap_src_min', 'NNs', 'data', 'seed11_dt1_nn_light_dataset.mat');
end
if ~isfield(cfg, 'models_file') || isempty(cfg.models_file)
    cfg.models_file = fullfile(cfg.repo_dir, 'shap_src_min', 'NNs', 'models', 'seed11_dt1_light_plus_models.mat');
end
if ~isfield(cfg, 'case_root') || isempty(cfg.case_root)
    cfg.case_root = fullfile(cfg.repo_dir, 'shap_src_min', 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'cases');
end

if ~isfield(cfg, 'use_val_for_background') || isempty(cfg.use_val_for_background)
    cfg.use_val_for_background = true;
end
if ~isfield(cfg, 'shap_background_n') || isempty(cfg.shap_background_n)
    cfg.shap_background_n = 90;
end
if ~isfield(cfg, 'shap_num_subsets_interv') || isempty(cfg.shap_num_subsets_interv)
    cfg.shap_num_subsets_interv = 140;
end
if ~isfield(cfg, 'shap_num_subsets_cond') || isempty(cfg.shap_num_subsets_cond)
    cfg.shap_num_subsets_cond = 140;
end
if ~isfield(cfg, 'shap_query_batch') || isempty(cfg.shap_query_batch)
    cfg.shap_query_batch = 96;
end
if ~isfield(cfg, 'shap_use_parallel') || isempty(cfg.shap_use_parallel)
    cfg.shap_use_parallel = true;
end

if ~isfield(cfg, 'rng_seed') || isempty(cfg.rng_seed)
    cfg.rng_seed = 20260304;
end
if ~isfield(cfg, 'filter_quantile') || isempty(cfg.filter_quantile)
    cfg.filter_quantile = 0.90;
end
if ~isfield(cfg, 'filter_zeta_override')
    cfg.filter_zeta_override = [];
end
if ~isfield(cfg, 'filter_use_train_only') || isempty(cfg.filter_use_train_only)
    cfg.filter_use_train_only = false;
end
if ~isfield(cfg, 'train_ratio_tree') || isempty(cfg.train_ratio_tree)
    cfg.train_ratio_tree = 0.70;
end
if ~isfield(cfg, 'min_cases') || isempty(cfg.min_cases)
    cfg.min_cases = 20;
end
if ~isfield(cfg, 'min_train_cases') || isempty(cfg.min_train_cases)
    cfg.min_train_cases = 14;
end

if ~isfield(cfg, 'tree_leaf_grid') || isempty(cfg.tree_leaf_grid)
    cfg.tree_leaf_grid = [5, 10, 20, 30];
end
if ~isfield(cfg, 'tree_max_splits') || isempty(cfg.tree_max_splits)
    cfg.tree_max_splits = 60;
end
if ~isfield(cfg, 'tree_cvfold') || isempty(cfg.tree_cvfold)
    cfg.tree_cvfold = 5;
end
if ~isfield(cfg, 'tree_acc_thresh') || isempty(cfg.tree_acc_thresh)
    cfg.tree_acc_thresh = 0.65;
end
if ~isfield(cfg, 'tree_refit_all') || isempty(cfg.tree_refit_all)
    cfg.tree_refit_all = true;
end
if ~isfield(cfg, 'tree_use_sample_weights') || isempty(cfg.tree_use_sample_weights)
    cfg.tree_use_sample_weights = true;
end
if ~isfield(cfg, 'tree_use_class_balance_weights') || isempty(cfg.tree_use_class_balance_weights)
    cfg.tree_use_class_balance_weights = false;
end
if ~isfield(cfg, 'tree_class_weight_cap') || isempty(cfg.tree_class_weight_cap)
    cfg.tree_class_weight_cap = 6.0;
end
if ~isfield(cfg, 'tree_use_balanced_acc') || isempty(cfg.tree_use_balanced_acc)
    cfg.tree_use_balanced_acc = true;
end
if ~isfield(cfg, 'tree_cv_min_obs_per_fold') || isempty(cfg.tree_cv_min_obs_per_fold)
    cfg.tree_cv_min_obs_per_fold = 40;
end
if ~isfield(cfg, 'tree_min_sample_weight') || isempty(cfg.tree_min_sample_weight)
    cfg.tree_min_sample_weight = 0.05;
end

if ~isfield(cfg, 'label_neutral_abs_quantile') || isempty(cfg.label_neutral_abs_quantile)
    cfg.label_neutral_abs_quantile = 0.20;
end
if ~isfield(cfg, 'label_neutral_abs_floor') || isempty(cfg.label_neutral_abs_floor)
    cfg.label_neutral_abs_floor = 1e-8;
end
if ~isfield(cfg, 'label_fill_from_dv') || isempty(cfg.label_fill_from_dv)
    cfg.label_fill_from_dv = true;
end
if ~isfield(cfg, 'label_use_dv_interaction') || isempty(cfg.label_use_dv_interaction)
    cfg.label_use_dv_interaction = false;
end
if ~isfield(cfg, 'label_weight_cap_pct') || isempty(cfg.label_weight_cap_pct)
    cfg.label_weight_cap_pct = 99.0;
end
if ~isfield(cfg, 'label_class_levels') || isempty(cfg.label_class_levels)
    cfg.label_class_levels = [-1, 1];
end
if ~isfield(cfg, 'label_level_quantiles') || isempty(cfg.label_level_quantiles)
    cfg.label_level_quantiles = [0.25, 0.50, 0.75];
end

cls = unique(round(cfg.label_class_levels(:)'));
cls = cls(isfinite(cls) & cls ~= 0);
if isempty(cls)
    cls = [-1, 1];
end
if numel(unique(abs(cls))) > 1
    cls = sort(cls);
else
    cls = [-1, 1];
end
cfg.label_class_levels = cls;

if ~isfield(cfg, 'score_use_prob_mismatch') || isempty(cfg.score_use_prob_mismatch)
    cfg.score_use_prob_mismatch = true;
end
if ~isfield(cfg, 'score_use_multilevel_match') || isempty(cfg.score_use_multilevel_match)
    cfg.score_use_multilevel_match = true;
end
if ~isfield(cfg, 'score_use_multilevel_by_objective') || isempty(cfg.score_use_multilevel_by_objective)
    cfg.score_use_multilevel_by_objective = [];
end
if ~isfield(cfg, 'score_multilevel_sign_weight') || isempty(cfg.score_multilevel_sign_weight)
    cfg.score_multilevel_sign_weight = 0.70;
end
if ~isfield(cfg, 'score_multilevel_sign_weight_by_objective') || isempty(cfg.score_multilevel_sign_weight_by_objective)
    cfg.score_multilevel_sign_weight_by_objective = [];
end
if ~isfield(cfg, 'score_reliability_baseline') || isempty(cfg.score_reliability_baseline)
    cfg.score_reliability_baseline = 0.50;
end
if ~isfield(cfg, 'score_reliability_use_threshold') || isempty(cfg.score_reliability_use_threshold)
    cfg.score_reliability_use_threshold = false;
end
if ~isfield(cfg, 'score_calibrate_linear') || isempty(cfg.score_calibrate_linear)
    cfg.score_calibrate_linear = true;
end
if ~isfield(cfg, 'score_calib_min_samples') || isempty(cfg.score_calib_min_samples)
    cfg.score_calib_min_samples = 25;
end
if ~isfield(cfg, 'rule_prior_blend') || isempty(cfg.rule_prior_blend)
    cfg.rule_prior_blend = 0.65;
end
if ~isfield(cfg, 'prior_scale_to_objective') || isempty(cfg.prior_scale_to_objective)
    cfg.prior_scale_to_objective = true;
end
if ~isfield(cfg, 'prior_alpha_floor') || isempty(cfg.prior_alpha_floor)
    cfg.prior_alpha_floor = 1e-8;
end

if ~isfield(cfg, 'map_clip_pct') || isempty(cfg.map_clip_pct)
    cfg.map_clip_pct = 99.5;
end
if ~isfield(cfg, 'map_smooth_window') || isempty(cfg.map_smooth_window)
    cfg.map_smooth_window = 3;
end
end

function ensure_dir_perf2(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end
