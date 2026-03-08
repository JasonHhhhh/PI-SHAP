function ss_ref = load_ss_reference_min()
candidates = { ...
    struct('file', fullfile('shap_src_min', 'ss', 'par_ss_opt_synced.mat'), 'vars', {{'par_ss_old', 'par'}}), ...
    struct('file', fullfile('shap_src', 'res_baseline.mat'), 'vars', {{'par_ssopt'}}), ...
    struct('file', fullfile('shap_src', 'par_ss_opt.mat'), 'vars', {{'par'}}), ...
    struct('file', fullfile('shap_src', 'par_baseline_opt.mat'), 'vars', {{'par'}})};

for i = 1:numel(candidates)
    c = candidates{i};
    if exist(c.file, 'file') ~= 2
        continue;
    end

    for j = 1:numel(c.vars)
        v = c.vars{j};
        try
            S = load(c.file, v);
        catch
            continue;
        end

        if ~isfield(S, v)
            continue;
        end

        par = S.(v);
        if ~isstruct(par) || ~isfield(par, 'ss_start') || ~isfield(par, 'ss_terminal')
            continue;
        end

        if ~isfield(par.ss_start, 'cc0') || ~isfield(par.ss_terminal, 'cc0')
            continue;
        end

        ss_ref = struct();
        ss_ref.par = par;
        ss_ref.ss_start = par.ss_start;
        ss_ref.ss_terminal = par.ss_terminal;
        ss_ref.cc_start = par.ss_start.cc0(:,2)';
        ss_ref.cc_end = par.ss_terminal.cc0(:,2)';
        ss_ref.source_file = c.file;
        ss_ref.source_var = v;
        ss_ref.source = sprintf('%s::%s', c.file, v);
        return;
    end
end

error('No valid SS reference with ss_start/ss_terminal found.');
end
