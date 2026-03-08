function par = run_case_ss_opt()
cfg = case_config_sim();
sim_dir = fileparts(mfilename('fullpath'));

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

if exist(cfg.baseline_mat, 'file') ~= 2
    error('Baseline MAT not found: %s', cfg.baseline_mat);
end

S = load(cfg.baseline_mat, 'par');
par = S.par;

all_nodes = 2:4:101;
mid_nodes = all_nodes(2:end-1);

for mid_node = mid_nodes
    field_name = sprintf('ss_%d', mid_node);
    par.(field_name) = static_opt_base_ends(par.ss, mid_node);
    par = process_output_ss_nofd(par, field_name);
end

par.ss_start = static_opt_base_ends(par.ss, 1);
par = process_output_ss_nofd(par, 'ss_start');

par.ss_terminal = static_opt_base_ends(par.ss_start, 101);
par = process_output_ss_nofd(par, 'ss_terminal');

if exist(cfg.output_dir, 'dir') ~= 7
    mkdir(cfg.output_dir);
end

save(cfg.ss_output_mat, 'par', '-v7.3');
disp(['Saved SS optimization results: ' cfg.ss_output_mat]);
end
