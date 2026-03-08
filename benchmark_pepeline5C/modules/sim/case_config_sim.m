function cfg = case_config_sim()
cfg = struct();

cfg.model_folder = fullfile('data', 'model_mine');
cfg.baseline_mat = fullfile('shap_src', 'par_baseline_opt.mat');

cfg.root_dir = fullfile('shap_src_min', 'sim');
cfg.settings_dir = fullfile(cfg.root_dir, 'settings');
cfg.plot_dir = fullfile(cfg.settings_dir, 'plots');
cfg.output_dir = fullfile(cfg.root_dir, 'output');

cfg.settings_md = fullfile(cfg.settings_dir, 'case_setting_model_mine.md');

cfg.topology_nodes_csv = fullfile(cfg.settings_dir, 'topology_nodes.csv');
cfg.topology_edges_csv = fullfile(cfg.settings_dir, 'topology_edges.csv');
cfg.topology_compressors_csv = fullfile(cfg.settings_dir, 'topology_compressors.csv');
cfg.topology_gnodes_csv = fullfile(cfg.settings_dir, 'topology_gnodes.csv');

cfg.boundary_ts_csv = fullfile(cfg.settings_dir, 'boundary_timeseries.csv');
cfg.boundary_stats_csv = fullfile(cfg.settings_dir, 'boundary_stats.csv');
cfg.case_snapshot_json = fullfile(cfg.settings_dir, 'case_snapshot.json');

cfg.boundary_plot_png = fullfile(cfg.plot_dir, 'boundary_conditions_overview.png');
cfg.topology_plot_png = fullfile(cfg.plot_dir, 'network_topology.png');

cfg.ss_output_mat = fullfile(cfg.output_dir, 'par_ss_opt_sim.mat');
cfg.tr_output_mat = fullfile(cfg.output_dir, 'par_tr_opt_sim.mat');
cfg.sim_output_mat = fullfile(cfg.output_dir, 'par_sim_eval.mat');
cfg.sim_summary_csv = fullfile(cfg.output_dir, 'par_sim_eval_summary.csv');
end
