function ok = smoke_check_benchmark_pepeline5C()
this_dir = fileparts(mfilename('fullpath'));

must_exist = {
    fullfile(this_dir, 'PROJECT_SUMMARY_CN.md')
    fullfile(this_dir, 'PROJECT_SUMMARY_EN.md')
    fullfile(this_dir, 'docs', 'CURATED_RENAME_MAP.csv')
    fullfile(this_dir, 'setup_paths_benchmark_pepeline5C.m')
    fullfile(this_dir, 'tools', 'refresh_release_views.py')
    fullfile(this_dir, 'tools', 'normalize_sample_paths.py')
    fullfile(this_dir, 'modules', 'performance3', 'curated', 'single_objective_cost', 'figures', 'single_cost_action_top1_s020_baseline.png')
    fullfile(this_dir, 'modules', 'performance3', 'curated', 'multi_objective_cost_var', 'figures', 'multi_branch_pareto_top1_s020_baseline.png')
    fullfile(this_dir, 'modules', 'doe', 'run_doe_try1_generate_actions_min.m')
    fullfile(this_dir, 'modules', 'sim', 'run_tr_sim_grid_independence_min.m')
    fullfile(this_dir, 'modules', 'shap_vs_nn', 'scripts', 'run_seed11_dt1_light_plus_min.m')
    fullfile(this_dir, 'modules', 'performance3', 'scripts', 'run_rule_learner_baseline_compare_perf3_min.m')
    fullfile(this_dir, 'release', 'figures')
    fullfile(this_dir, 'release', 'tables')
    fullfile(this_dir, 'release', 'tables_sanitized')
    fullfile(this_dir, 'docs', 'FIGURE_RENAME_MAP.csv')
    fullfile(this_dir, 'docs', 'TABLE_RENAME_MAP.csv')
    fullfile(this_dir, 'docs', 'PATH_SANITIZE_REPORT.csv')
    };

missing = strings(0, 1);
for i = 1:numel(must_exist)
    p = must_exist{i};
    if exist(p, 'file') ~= 2 && exist(p, 'dir') ~= 7
        missing(end + 1, 1) = string(p); %#ok<AGROW>
    end
end

if isempty(missing)
    ok = true;
    fprintf('[smoke] benchmark_pepeline5C: PASS\n');
else
    ok = false;
    fprintf('[smoke] benchmark_pepeline5C: FAIL\n');
    disp(missing);
end
end
