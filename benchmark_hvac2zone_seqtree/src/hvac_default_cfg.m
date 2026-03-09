function cfg = hvac_default_cfg()
cfg = struct();
cfg.seed = 20260309;

cfg.horizon = 24;
cfg.dt_hr = 1.0;
cfg.n_zones = 2;

cfg.n_blocks = 4;
cfg.block_hours = cfg.horizon / cfg.n_blocks;
cfg.action_levels = [0.00, 0.35, 0.70, 1.00];

cfg.setpoint = 24.0;
cfg.deadband = 1.0;
cfg.temp_floor = 16.0;
cfg.temp_ceil = 38.0;

cfg.k_out = [0.16, 0.14];
cfg.k_cross = 0.05;
cfg.k_solar = [0.55, 0.40];
cfg.k_occ = [0.70, 0.55];
cfg.k_cool = [2.80, 2.30];

cfg.cooling_kw_max = [7.5, 6.5];

cfg.w_discomfort = 2.20;
cfg.w_smooth = 0.40;
cfg.terminal_weight = 1.50;
cfg.u_prev0 = [0.25, 0.25];

cfg.peak_hours = 16:21;
cfg.peak_idx = cfg.peak_hours + 1;

cfg.n_doe = 48;
cfg.progress_every = 5000;

cfg.shap_n_train = 2400;
cfg.shap_n_test = 800;
cfg.shap_mc_draws = 30;
cfg.shap_cond_k = 80;
cfg.shap_ridge_lambda = 1e-3;

cfg.shap_fair_split_seeds = [11, 23, 37, 53, 71];
cfg.shap_fair_n_train = 1800;
cfg.shap_fair_n_test = 320;
cfg.shap_fair_mc_draws = 12;
cfg.shap_fair_cond_k = 48;
end
