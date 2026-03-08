function out = run_performance_compare_top1_perf3_min(cfg)
% Performance3 entry:
% - same rule-tree pipeline as performance2
% - holdout uses dt=1.0h from seeds [11, 23, 37]

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_perf3_compare(cfg);

repo_dir = char(cfg.repo_dir);
shared_perf_dir = fullfile(repo_dir, 'modules', 'performance_shared');
if exist(shared_perf_dir, 'dir') ~= 7
    error('performance_shared directory not found: %s', shared_perf_dir);
end
addpath(shared_perf_dir);

out = run_performance_compare_top1_min(cfg);
end

function cfg = fill_cfg_defaults_perf3_compare(cfg)
this_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(this_dir)));

if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end
if ~isfield(cfg, 'work_dir') || isempty(cfg.work_dir)
    cfg.work_dir = fullfile(repo_dir, 'modules', 'performance3');
end
if ~isfield(cfg, 'eval_seed_list') || isempty(cfg.eval_seed_list)
    cfg.eval_seed_list = [11, 23, 37];
end
if ~isfield(cfg, 'split_mode') || isempty(cfg.split_mode)
    cfg.split_mode = 'seed';
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
if ~isfield(cfg, 'case_root') || isempty(cfg.case_root)
    cfg.case_root = fullfile(cfg.repo_dir, 'modules', 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'cases');
end

if ~isfield(cfg, 'method_runs_dir') || isempty(cfg.method_runs_dir)
    cfg.method_runs_dir = fullfile(cfg.work_dir, 'method_runs');
end
if ~isfield(cfg, 'map_cache_file') || isempty(cfg.map_cache_file)
    cfg.map_cache_file = fullfile(cfg.method_runs_dir, 'holdout_shap_maps_cache_seedwise_train11_test23_37_dt1p0.mat');
end
if ~isfield(cfg, 'filter_use_train_only') || isempty(cfg.filter_use_train_only)
    cfg.filter_use_train_only = true;
end
if ~isfield(cfg, 'tree_refit_all') || isempty(cfg.tree_refit_all)
    cfg.tree_refit_all = false;
end
if ~isfield(cfg, 'rule_prior_blend') || isempty(cfg.rule_prior_blend)
    cfg.rule_prior_blend = 1.0;
end
if ~isfield(cfg, 'label_class_levels') || isempty(cfg.label_class_levels)
    cfg.label_class_levels = [-4, -3, -2, -1, 1, 2, 3, 4];
end
if ~isfield(cfg, 'label_level_quantiles') || isempty(cfg.label_level_quantiles)
    cfg.label_level_quantiles = [0.25, 0.50, 0.75];
end
end
