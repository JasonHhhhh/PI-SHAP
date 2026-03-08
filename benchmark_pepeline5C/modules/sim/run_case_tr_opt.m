function par = run_case_tr_opt()
cfg = case_config_sim();
sim_dir = fileparts(mfilename('fullpath'));

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

if exist(cfg.ss_output_mat, 'file') == 2
    S = load(cfg.ss_output_mat, 'par');
    par = S.par;
elseif exist(cfg.baseline_mat, 'file') == 2
    S = load(cfg.baseline_mat, 'par');
    par = S.par;
else
    error('Neither SS output nor baseline MAT is available.');
end

if ~isfield(par, 'ss_start') || ~isfield(par, 'ss_terminal')
    par = run_case_ss_opt();
end

par.tr.m.use_init_state = 1;
par.tr.ss_start = par.ss_start;
par.tr.ss_terminal = par.ss_terminal;

par.tr = tran_opt_base_shap(par.tr);

if exist(cfg.output_dir, 'dir') ~= 7
    mkdir(cfg.output_dir);
end

save(cfg.tr_output_mat, 'par', '-v7.3');
disp(['Saved TR optimization results: ' cfg.tr_output_mat]);
end
