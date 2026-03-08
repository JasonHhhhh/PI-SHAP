function cfg = doe_try1_sim_config_min()
cfg = struct();

cfg.try_root = fullfile('shap_src_min', 'doe', 'try1');
cfg.dataset_index_file = fullfile(cfg.try_root, 'try1_dataset_index.csv');

cfg.output_root = fullfile(cfg.try_root, 'sim_outputs');
cfg.run_name = 'run_try1_default';
cfg.clean_run_dir = false;

cfg.seeds = [11 23 37];
cfg.dt_list = [0.5 1.0 1.5 2.0];

cfg.sample_mode = 'all';
cfg.first_n = 50;
cfg.custom_sample_ids = [];
cfg.sample_subset_seed = 260226;

cfg.use_parallel = true;
cfg.requested_workers = [];
cfg.parallel_worker_ratio = 0.90;
cfg.force_pool_size = false;
cfg.parallel_batch_factor = 4;
cfg.fail_fast = false;
cfg.flush_manifest_every_dataset = true;
cfg.skip_existing_cases = true;

cfg.baseline_file = fullfile('shap_src', 'res_baseline.mat');
cfg.baseline_var = 'par_tropt';

cfg.bounds = struct();
cfg.bounds.cc_min = 1.0;
cfg.bounds.cc_max = 1.6;
cfg.bounds.delta_cap_per_hour = 0.08;

cfg.sim = struct();
cfg.sim.rtol0 = 1e-2;
cfg.sim.atol0 = 1e-1;
cfg.sim.rtol1 = 1e-3;
cfg.sim.atol1 = 1e-2;
cfg.sim.rtol = 1e-5;
cfg.sim.atol = 1e-3;
cfg.sim.startup = 1 / 8;
cfg.sim.nperiods = 2;
cfg.sim.solsteps = 24 * 6 * 2;

cfg.save = struct();
cfg.save.save_system_state_all = true;
cfg.save.save_outputs_quick = true;
cfg.save.save_full_par_struct = false;
cfg.save.mat_version = '-v7.3';
end
