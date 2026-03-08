function [results, summary_tbl] = run_min_pipeline_min()
addpath('src');
addpath('shap_src');
addpath('shap_src_min');

cfg = config_model_mine_min();
par_base = load_baseline_min(cfg);

ccc_tropt = par_base.tr.cc0';
ccc_ssopt = build_ss_policy_min(par_base);
ccc_linear = build_linear_policy_min(ccc_ssopt);

policy_names = {'tr_opt', 'ss_opt', 'linear'};
policy_list = {ccc_tropt, ccc_ssopt, ccc_linear};

results = repmat(struct(), numel(policy_names), 1);

for k = 1:numel(policy_names)
    sim_result = simulate_policy_min(par_base, policy_list{k}, cfg, policy_names{k});
    score_result = score_policy_tree_min(sim_result, cfg);

    results(k).policy = policy_names{k};
    results(k).sim_result = sim_result;
    results(k).score_result = score_result;

    if cfg.verbose
        fprintf('%s -> Jcost=%.6e, Jsupp=%.6e, Jvar=%.6e\n', ...
            policy_names{k}, ...
            sim_result.metrics.Jcost, ...
            sim_result.metrics.Jsupp, ...
            sim_result.metrics.Jvar);
    end
end

policy_col = string({results.policy}');
jcost_col = arrayfun(@(r) r.sim_result.metrics.Jcost, results);
jsupp_col = arrayfun(@(r) r.sim_result.metrics.Jsupp, results);
jvar_col = arrayfun(@(r) r.sim_result.metrics.Jvar, results);
score_cost_col = arrayfun(@(r) r.score_result.score_sum(1), results);
score_supp_col = arrayfun(@(r) r.score_result.score_sum(2), results);
score_var_col = arrayfun(@(r) r.score_result.score_sum(3), results);
score_costw_col = arrayfun(@(r) r.score_result.score_weighted(1), results);
score_suppw_col = arrayfun(@(r) r.score_result.score_weighted(2), results);
score_varw_col = arrayfun(@(r) r.score_result.score_weighted(3), results);

summary_tbl = table( ...
    policy_col(:), ...
    jcost_col(:), ...
    jsupp_col(:), ...
    jvar_col(:), ...
    score_cost_col(:), ...
    score_supp_col(:), ...
    score_var_col(:), ...
    score_costw_col(:), ...
    score_suppw_col(:), ...
    score_varw_col(:), ...
    'VariableNames', { ...
        'Policy', 'Jcost', 'Jsupp', 'Jvar', ...
        'ScoreCost', 'ScoreSupp', 'ScoreVar', ...
        'ScoreCostW', 'ScoreSuppW', 'ScoreVarW'});

if exist(cfg.output_dir, 'dir') ~= 7
    mkdir(cfg.output_dir);
end

save(fullfile(cfg.output_dir, 'run_min_pipeline_output.mat'), 'results', 'summary_tbl', 'cfg');
writetable(summary_tbl, fullfile(cfg.output_dir, 'run_min_pipeline_output.csv'));

disp(summary_tbl);
end

function ccc_linear = build_linear_policy_min(ccc_ssopt)
n_steps = size(ccc_ssopt, 1);
ccc_linear = zeros(size(ccc_ssopt));
for i = 1:n_steps
    w = (i - 1) / (n_steps - 1);
    ccc_linear(i,:) = (1 - w) .* ccc_ssopt(1,:) + w .* ccc_ssopt(end,:);
end
end
