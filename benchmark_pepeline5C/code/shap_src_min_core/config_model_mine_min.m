function cfg = config_model_mine_min()
cfg = struct();

cfg.model_folder = fullfile('data', 'model_mine');
cfg.baseline_mat = fullfile('shap_src', 'par_baseline_opt.mat');

cfg.tree_root = fullfile('shap_src', 'data');
cfg.tree_k = 10;
cfg.tree_ids = 1:24;

cfg.solsteps = 24 * 6 * 2;
cfg.nperiods = 2;
cfg.startup = 1 / 8;

cfg.rtol0 = 1e-2;
cfg.atol0 = 1e-1;
cfg.rtol1 = 1e-3;
cfg.atol1 = 1e-2;
cfg.rtol = 1e-5;
cfg.atol = 1e-3;

cfg.output_dir = fullfile('shap_src_min', 'output');
cfg.verbose = true;
end
