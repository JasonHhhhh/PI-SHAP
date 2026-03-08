function [results, summary_tbl] = run_case_sim()
cfg = case_config_sim();
sim_dir = fileparts(mfilename('fullpath'));

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

[results, summary_tbl] = run_model_mine_min();

if exist(cfg.output_dir, 'dir') ~= 7
    mkdir(cfg.output_dir);
end

save(cfg.sim_output_mat, 'results', 'summary_tbl', '-v7.3');
writetable(summary_tbl, cfg.sim_summary_csv);

disp(['Saved simulation evaluation MAT: ' cfg.sim_output_mat]);
disp(['Saved simulation summary CSV: ' cfg.sim_summary_csv]);
end
