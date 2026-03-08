function out = export_seed11_dt1_dataset_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_min(cfg);
ensure_dir_min(cfg.data_dir);

T = readtable(cfg.manifest_csv);
mask = (T.Seed == cfg.seed) & (abs(T.ActionDt_hr - cfg.dt_hr) < 1e-9) & (T.OK == 1);
T = T(mask, :);

if isempty(T)
    error('No rows found for seed=%d dt=%.3f in %s', cfg.seed, cfg.dt_hr, cfg.manifest_csv);
end

case0 = resolve_case_path_min(T.CaseFile{1}, cfg.repo_dir);
S0 = load(case0, 'payload');
n_t = size(S0.payload.inputs.cc_policy, 1);
n_comp = size(S0.payload.inputs.cc_policy, 2);
n_curve = numel(S0.payload.outputs.quick.m_cost);
curve_t_hr = S0.payload.outputs.t_hr(:);

n_action_feat = n_t * n_comp;
n_pin_feat = n_t;
n_features = n_action_feat + n_pin_feat;
n_obj = 3;
n_flow = 8;

n_base = height(T);
n_rep = cfg.noise_repeats;
n_rows = n_base * n_rep;

X = zeros(n_rows, n_features);
Y_obj = zeros(n_rows, n_obj);
Y_flow = zeros(n_rows, n_flow);
Y_curve_cost = zeros(n_rows, n_curve);
Y_curve_supp = zeros(n_rows, n_curve);

meta_seed = zeros(n_rows, 1);
meta_dt = zeros(n_rows, 1);
meta_sample_id = zeros(n_rows, 1);
meta_case_idx = zeros(n_rows, 1);
meta_noise_id = zeros(n_rows, 1);
meta_case_file = strings(n_rows, 1);

rng(cfg.rng_seed, 'twister');
row = 0;

fprintf('Exporting seed=%d dt=%.1f dataset (%d base samples, repeats=%d)...\n', ...
    cfg.seed, cfg.dt_hr, n_base, n_rep);

for i = 1:n_base
    fp = resolve_case_path_min(T.CaseFile{i}, cfg.repo_dir);
    S = load(fp, 'payload');
    p = S.payload;

    cc = p.inputs.cc_policy;          % [n_t, n_comp]
    pp0 = p.system.pp0;               % [n_nodes, n_t]
    qq0 = p.system.qq0;               % [n_nodes, n_t]
    m_cost = p.system.m_cost;         % transient vector
    m_supp = p.system.m_supp;         % transient vector
    m_mass = p.system.m_mass;         % transient vector

    yc_cost = p.outputs.quick.m_cost(:)';
    yc_supp = p.outputs.quick.m_supp(:)';

    pin_base = pp0(1, :);
    x_action = reshape(cc', 1, []);   % [c1..cN at t1, c1..cN at t2, ...]

    y_obj = [p.outputs.objective.Jcost, p.outputs.objective.Jsupp, p.outputs.objective.Jvar];
    y_flow = [ ...
        mean(m_cost), ...
        max(m_cost), ...
        prctile(m_cost, 95), ...
        mean(m_supp), ...
        max(m_supp), ...
        prctile(m_supp, 5), ...
        m_mass(end), ...
        min(m_mass) ...
        ];

    for k = 1:n_rep
        row = row + 1;

        if k == 1
            pin_noisy = pin_base;
        else
            pin_noisy = pin_base .* (1 + cfg.noise_sigma * randn(size(pin_base)));
        end

        X(row, :) = [x_action, pin_noisy];
        Y_obj(row, :) = y_obj;
        Y_flow(row, :) = y_flow;
        Y_curve_cost(row, :) = yc_cost;
        Y_curve_supp(row, :) = yc_supp;

        meta_seed(row) = cfg.seed;
        meta_dt(row) = cfg.dt_hr;
        meta_sample_id(row) = p.meta.sample_id;
        meta_case_idx(row) = i;
        meta_noise_id(row) = k - 1;
        meta_case_file(row) = string(T.CaseFile{i});
    end
end

feature_names = cell(n_features, 1);
idx = 0;
for t = 1:n_t
    for c = 1:n_comp
        idx = idx + 1;
        feature_names{idx} = sprintf('cc_t%02d_c%d', t, c);
    end
end
for t = 1:n_t
    idx = idx + 1;
    feature_names{idx} = sprintf('pin_t%02d_noise', t);
end

target_names_obj = {'Jcost', 'Jsupp', 'Jvar'};
target_names_flow = { ...
    'CostMean', 'CostPeak', 'CostP95', ...
    'SuppMean', 'SuppPeak', 'SuppP05', ...
    'MassFinal', 'MassMin'};

perm = randperm(n_rows);
n_train = floor(cfg.train_ratio * n_rows);
n_val = floor(cfg.val_ratio * n_rows);
n_test = n_rows - n_train - n_val;

train_idx = sort(perm(1:n_train));
val_idx = sort(perm(n_train+1:n_train+n_val));
test_idx = sort(perm(n_train+n_val+1:end)); %#ok<NASGU>

if n_test < 1
    error('Split failed: test size is zero.');
end

meta_tbl = table((1:n_rows)', meta_seed, meta_dt, meta_case_idx, meta_sample_id, meta_noise_id, meta_case_file, ...
    'VariableNames', {'RowID', 'Seed', 'ActionDt_hr', 'BaseCaseIndex', 'SampleID', 'NoiseReplicaID', 'CaseFile'});

summary_file = fullfile(cfg.data_dir, 'seed11_dt1_dataset_summary.csv');
writetable(meta_tbl, summary_file);

dataset_file = fullfile(cfg.data_dir, 'seed11_dt1_nn_light_dataset.mat');
save(dataset_file, ...
    'X', 'Y_obj', 'Y_flow', 'Y_curve_cost', 'Y_curve_supp', 'curve_t_hr', ...
    'feature_names', 'target_names_obj', 'target_names_flow', ...
    'train_idx', 'val_idx', 'test_idx', ...
    'meta_tbl', 'cfg', '-v7');

out = struct();
out.dataset_file = dataset_file;
out.summary_file = summary_file;
out.n_rows = n_rows;
out.n_base = n_base;
out.n_features = n_features;
out.n_targets_obj = n_obj;
out.n_targets_flow = n_flow;
out.n_t = n_t;
out.n_comp = n_comp;
out.n_curve = n_curve;

fprintf('Saved dataset: %s\n', dataset_file);
fprintf('Rows=%d, Features=%d, ObjTargets=%d, FlowTargets=%d\n', n_rows, n_features, n_obj, n_flow);
end

function fp = resolve_case_path_min(case_path, repo_dir)
if isstring(case_path)
    case_path = char(case_path);
end

if exist(case_path, 'file') == 2
    fp = case_path;
    return;
end

fp = fullfile(repo_dir, case_path);
if exist(fp, 'file') ~= 2
    error('Case file not found: %s', case_path);
end
end

function cfg = fill_cfg_defaults_min(cfg)
script_dir = fileparts(mfilename('fullpath'));
nns_dir = fileparts(script_dir);

parent_dir = fileparts(nns_dir);
if exist(fullfile(parent_dir, 'doe'), 'dir') == 7 && exist(fullfile(parent_dir, 'tr'), 'dir') == 7
    shap_root = parent_dir;
    repo_dir = fileparts(shap_root);
else
    repo_dir = parent_dir;
    shap_root = fullfile(repo_dir, 'shap_src_min');
end

if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end
if ~isfield(cfg, 'data_dir') || isempty(cfg.data_dir)
    cfg.data_dir = fullfile(nns_dir, 'data');
end
if ~isfield(cfg, 'manifest_csv') || isempty(cfg.manifest_csv)
    cfg.manifest_csv = fullfile(shap_root, 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'manifest.csv');
end
if ~isfield(cfg, 'seed') || isempty(cfg.seed)
    cfg.seed = 11;
end
if ~isfield(cfg, 'dt_hr') || isempty(cfg.dt_hr)
    cfg.dt_hr = 1.0;
end
if ~isfield(cfg, 'noise_sigma') || isempty(cfg.noise_sigma)
    cfg.noise_sigma = 0.01;
end
if ~isfield(cfg, 'noise_repeats') || isempty(cfg.noise_repeats)
    cfg.noise_repeats = 3;
end
if ~isfield(cfg, 'rng_seed') || isempty(cfg.rng_seed)
    cfg.rng_seed = 2026;
end
if ~isfield(cfg, 'train_ratio') || isempty(cfg.train_ratio)
    cfg.train_ratio = 0.70;
end
if ~isfield(cfg, 'val_ratio') || isempty(cfg.val_ratio)
    cfg.val_ratio = 0.15;
end
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end
