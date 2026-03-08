function par = load_baseline_min(cfg)
if exist(cfg.baseline_mat, 'file') ~= 2
    error('Baseline MAT file not found: %s', cfg.baseline_mat);
end

S = load(cfg.baseline_mat, 'par');
if ~isfield(S, 'par')
    error('Variable "par" not found in %s', cfg.baseline_mat);
end
par = S.par;

cfg_model_folder = normalize_path_min(cfg.model_folder);
par_model_folder = normalize_path_min(par.mfolder);

if ~strcmp(cfg_model_folder, par_model_folder)
    warning('Baseline mfolder is %s, forcing to %s.', par_model_folder, cfg_model_folder);
end
par.mfolder = cfg_model_folder;
end

function p = normalize_path_min(p)
p = strrep(p, '\\', filesep);
p = strrep(p, '/', filesep);
end
