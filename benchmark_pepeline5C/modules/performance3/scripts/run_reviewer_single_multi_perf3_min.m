function out = run_reviewer_single_multi_perf3_min(cfg)
% Performance3:
% 1) run rule-tree scoring on seeds [11,23,37], dt=1.0h
% 2) reuse reviewer single/multi plotting pipeline

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

this_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(this_dir)));
perf_dir = fullfile(repo_dir, 'modules', 'performance_shared');

run_dir = this_dir;
if isfield(cfg, 'work_dir') && ~isempty(cfg.work_dir)
    run_dir = char(cfg.work_dir);
end
if exist(run_dir, 'dir') ~= 7
    mkdir(run_dir);
end

score_cfg = struct();
if isfield(cfg, 'score_cfg') && isstruct(cfg.score_cfg)
    score_cfg = cfg.score_cfg;
end

score_cfg = fill_cfg_defaults_perf3_score(score_cfg, run_dir, repo_dir);
score_out = run_performance_compare_top1_perf3_min(score_cfg);

review_cfg = struct();
if isfield(cfg, 'review_cfg') && isstruct(cfg.review_cfg)
    review_cfg = cfg.review_cfg;
end

review_cfg.work_dir = run_dir;
review_cfg.repo_dir = score_cfg.repo_dir;
review_cfg.out_dir = fullfile(run_dir, 'reviewer_outputs');
review_cfg.plot_dir = fullfile(review_cfg.out_dir, 'plots');
review_cfg.table_dir = fullfile(review_cfg.out_dir, 'tables');
review_cfg.holdout_score_csv = score_out.case_score_csv;
review_cfg.holdout_corr_csv = score_out.corr_csv;

if ~isfield(review_cfg, 'multi_use_dense_weight_grid')
    review_cfg.multi_use_dense_weight_grid = true;
end
if ~isfield(review_cfg, 'multi_weight_dense_step')
    review_cfg.multi_weight_dense_step = 0.02;
end

if exist(perf_dir, 'dir') ~= 7
    error('performance directory not found: %s', perf_dir);
end
addpath(perf_dir);
review_out = run_reviewer_single_multi_min(review_cfg);

out = struct();
out.score = score_out;
out.reviewer = review_out;

fprintf('Performance3 completed. Reviewer report: %s\n', review_out.report_md);
end

function score_cfg = fill_cfg_defaults_perf3_score(score_cfg, run_dir, repo_dir)
if ~isfield(score_cfg, 'repo_dir') || isempty(score_cfg.repo_dir)
    score_cfg.repo_dir = repo_dir;
end
if ~isfield(score_cfg, 'work_dir') || isempty(score_cfg.work_dir)
    score_cfg.work_dir = run_dir;
end
if ~isfield(score_cfg, 'eval_seed_list') || isempty(score_cfg.eval_seed_list)
    score_cfg.eval_seed_list = [11, 23, 37];
end
if ~isfield(score_cfg, 'split_mode') || isempty(score_cfg.split_mode)
    score_cfg.split_mode = 'seed';
end
if ~isfield(score_cfg, 'train_seed_list') || isempty(score_cfg.train_seed_list)
    score_cfg.train_seed_list = 11;
end
if ~isfield(score_cfg, 'test_seed_list') || isempty(score_cfg.test_seed_list)
    score_cfg.test_seed_list = [23, 37];
end
if ~isfield(score_cfg, 'eval_dt_hr') || isempty(score_cfg.eval_dt_hr)
    score_cfg.eval_dt_hr = 1.0;
end
if ~isfield(score_cfg, 'case_root') || isempty(score_cfg.case_root)
    score_cfg.case_root = fullfile(score_cfg.repo_dir, 'modules', 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'cases');
end

method_runs_dir = fullfile(score_cfg.work_dir, 'method_runs');
if ~isfield(score_cfg, 'method_runs_dir') || isempty(score_cfg.method_runs_dir)
    score_cfg.method_runs_dir = method_runs_dir;
end
if ~isfield(score_cfg, 'map_cache_file') || isempty(score_cfg.map_cache_file)
    score_cfg.map_cache_file = fullfile(score_cfg.method_runs_dir, 'holdout_shap_maps_cache_seedwise_train11_test23_37_dt1p0.mat');
end
if ~isfield(score_cfg, 'filter_use_train_only') || isempty(score_cfg.filter_use_train_only)
    score_cfg.filter_use_train_only = true;
end
if ~isfield(score_cfg, 'tree_refit_all') || isempty(score_cfg.tree_refit_all)
    score_cfg.tree_refit_all = false;
end
if ~isfield(score_cfg, 'rule_prior_blend') || isempty(score_cfg.rule_prior_blend)
    score_cfg.rule_prior_blend = 1.0;
end
if ~isfield(score_cfg, 'label_class_levels') || isempty(score_cfg.label_class_levels)
    score_cfg.label_class_levels = [-4, -3, -2, -1, 1, 2, 3, 4];
end
if ~isfield(score_cfg, 'label_level_quantiles') || isempty(score_cfg.label_level_quantiles)
    score_cfg.label_level_quantiles = [0.25, 0.50, 0.75];
end
end
