function out = run_doe_try1_sim_batch_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = doe_try1_sim_config_min();
end
cfg = fill_cfg_defaults_min(cfg);

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(fileparts(mfilename('fullpath')));

if exist(cfg.try_root, 'dir') ~= 7
    error('try_root does not exist: %s', cfg.try_root);
end
if exist(cfg.dataset_index_file, 'file') ~= 2
    error('Dataset index not found: %s', cfg.dataset_index_file);
end
if exist(cfg.baseline_file, 'file') ~= 2
    error('Baseline file not found: %s', cfg.baseline_file);
end

ensure_dir_min(cfg.output_root);
run_dir = fullfile(cfg.output_root, cfg.run_name);
ensure_dir_min(run_dir);

if cfg.clean_run_dir
    reset_dir_contents_min(run_dir);
end

cases_root = fullfile(run_dir, 'cases');
ensure_dir_min(cases_root);

cfg_file = fullfile(run_dir, 'run_config.mat');
save(cfg_file, 'cfg', '-v7.3');

ss_ref = load_ss_reference_min();
par_template = load_par_template_min(cfg, ss_ref);

[pool_used, n_workers, n_cpu, target_workers] = maybe_prepare_parallel_pool_min(cfg);

manifest_rows = repmat(new_manifest_row_min(), 0, 1);

for si = 1:numel(cfg.seeds)
    seed = cfg.seeds(si);
    seed_dir = fullfile(cases_root, sprintf('seed_%03d', seed));
    ensure_dir_min(seed_dir);

    for di = 1:numel(cfg.dt_list)
        dt_hr = cfg.dt_list(di);
        dt_tag = dt_tag_min(dt_hr);
        ds_src_dir = fullfile(cfg.try_root, sprintf('seed_%03d', seed), ['dataset_dt_' dt_tag]);
        actions_file = fullfile(ds_src_dir, 'actions.mat');

        if exist(actions_file, 'file') ~= 2
            warning('Missing actions file, skip: %s', actions_file);
            continue;
        end

        S = load(actions_file, 'cc_samples', 't_hr');
        cc_samples = S.cc_samples;
        t_action_hr = S.t_hr;

        n_samples_total = size(cc_samples, 3);
        sample_ids = select_sample_ids_min(n_samples_total, cfg);
        n_sel = numel(sample_ids);
        if n_sel == 0
            warning('No selected samples for seed=%03d dt=%.2f. Skip.', seed, dt_hr);
            continue;
        end

        ds_out_dir = fullfile(seed_dir, ['dataset_dt_' dt_tag]);
        ensure_dir_min(ds_out_dir);

        fprintf('simulate seed=%03d dt=%.2fh selected=%d/%d\n', seed, dt_hr, n_sel, n_samples_total);

        rows_ds = repmat(new_manifest_row_min(), n_sel, 1);
        mat_version = cfg.save.mat_version;

        todo_idx = false(n_sel, 1);
        for ii = 1:n_sel
            sid = sample_ids(ii);
            case_file = fullfile(ds_out_dir, sprintf('sample_%06d.mat', sid));

            if cfg.skip_existing_cases && exist(case_file, 'file') == 2
                [ok_loaded, row_loaded] = row_from_existing_case_min(case_file, seed, dt_hr, sid);
                if ok_loaded
                    rows_ds(ii) = row_loaded;
                    continue;
                end
            end
            todo_idx(ii) = true;
        end

        todo_pos = find(todo_idx);
        n_todo = numel(todo_pos);
        fprintf('  existing=%d, todo=%d\n', n_sel - n_todo, n_todo);

        if n_todo > 0
            if pool_used && n_todo > 1
                p = gcp('nocreate');
                batch_size = max(1, n_workers * cfg.parallel_batch_factor);
                ptr = 1;

                while ptr <= n_todo
                    idx_end = min(n_todo, ptr + batch_size - 1);
                    batch_pos = todo_pos(ptr:idx_end);
                    n_batch = numel(batch_pos);

                    futures(1:n_batch) = parallel.FevalFuture;
                    for jj = 1:n_batch
                        ii = batch_pos(jj);
                        sid = sample_ids(ii);
                        cc_policy = cc_samples(:, :, sid);
                        case_file = fullfile(ds_out_dir, sprintf('sample_%06d.mat', sid));
                        futures(jj) = parfeval(p, @simulate_and_store_case_min, 1, ...
                            par_template, ss_ref, cc_policy, t_action_hr, seed, dt_hr, sid, case_file, cfg, mat_version);
                    end

                    for kk = 1:n_batch
                        [idx_done, row] = fetchNext(futures);
                        ii = batch_pos(idx_done);
                        rows_ds(ii) = row;

                        if cfg.fail_fast && ~row.OK
                            cancel(futures);
                            error('Simulation failed at seed=%03d dt=%.2f sample=%d. %s', ...
                                seed, dt_hr, row.SampleID, row.ErrorMessage);
                        end
                    end

                    ptr = idx_end + 1;
                end
            else
                for kk = 1:n_todo
                    ii = todo_pos(kk);
                    sid = sample_ids(ii);
                    cc_policy = cc_samples(:, :, sid);
                    case_file = fullfile(ds_out_dir, sprintf('sample_%06d.mat', sid));
                    [payload, row] = run_one_case_min(par_template, ss_ref, cc_policy, t_action_hr, seed, dt_hr, sid, case_file, cfg);
                    save(case_file, 'payload', mat_version);
                    rows_ds(ii) = row;

                    if cfg.fail_fast && ~row.OK
                        error('Simulation failed at seed=%03d dt=%.2f sample=%d. %s', seed, dt_hr, sid, row.ErrorMessage);
                    end
                end
            end
        end

        manifest_rows = [manifest_rows; rows_ds]; %#ok<AGROW>
        if cfg.flush_manifest_every_dataset
            flush_manifest_min(run_dir, manifest_rows);
        end
    end
end

manifest_tbl = flush_manifest_min(run_dir, manifest_rows);
summary_tbl = build_summary_min(manifest_tbl);
writetable(summary_tbl, fullfile(run_dir, 'summary_by_dataset.csv'));

write_run_summary_md_min(run_dir, cfg, ss_ref, manifest_tbl, summary_tbl, pool_used, n_workers, n_cpu, target_workers);

out = struct();
out.run_dir = run_dir;
out.manifest_tbl = manifest_tbl;
out.summary_tbl = summary_tbl;
out.pool_used = pool_used;
out.n_workers = n_workers;
out.n_cpu = n_cpu;
out.target_workers = target_workers;

disp(summary_tbl);
fprintf('DOE try1 simulation run output: %s\n', run_dir);
end

function [payload, row] = run_one_case_min(par_template, ss_ref, cc_policy, t_action_hr, seed, dt_hr, sample_id, case_file, cfg)
t0 = tic;

row = new_manifest_row_min();
row.Seed = seed;
row.ActionDt_hr = dt_hr;
row.SampleID = sample_id;
row.CaseFile = string(case_file);

payload = struct();
payload.meta = struct();
payload.meta.seed = seed;
payload.meta.dt_hr = dt_hr;
payload.meta.sample_id = sample_id;
payload.meta.generated_utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm:ss''Z'''));

payload.boundary = struct();
payload.boundary.cc_min = cfg.bounds.cc_min;
payload.boundary.cc_max = cfg.bounds.cc_max;
payload.boundary.delta_cap_per_hour = cfg.bounds.delta_cap_per_hour;
payload.boundary.ss_source = ss_ref.source;
payload.boundary.cc_start = ss_ref.cc_start(1:size(cc_policy, 2));
payload.boundary.cc_end = ss_ref.cc_end(1:size(cc_policy, 2));

payload.inputs = struct();
payload.inputs.t_action_hr = t_action_hr;
payload.inputs.cc_policy = cc_policy;

payload.sim_cfg = cfg.sim;

try
    par_sim = setup_par_sim_min(par_template, cfg.sim);
    par_sim = tran_sim_setup_0_min(par_sim, cc_policy');
    par_sim.sim = tran_sim_base_flat_noextd(par_sim.sim);
    par_sim = process_output_tr_nofd_sim(par_sim);

    out_core = extract_core_outputs_min(par_sim, cfg.save);
    payload.outputs = out_core;

    if cfg.save.save_system_state_all
        payload.system = extract_system_state_all_min(par_sim);
    else
        payload.system = extract_system_state_core_min(par_sim);
    end

    if cfg.save.save_full_par_struct
        payload.par_sim = par_sim;
    end

    row.OK = true;
    row.SimSec = toc(t0);
    row.TransientSteps = numel(out_core.t_hr);
    row.Jcost = out_core.objective.Jcost;
    row.Jsupp = out_core.objective.Jsupp;
    row.Jvar = out_core.objective.Jvar;
    row.ErrorMessage = "";

    payload.meta.sim_sec = row.SimSec;
    payload.meta.ok = row.OK;
    payload.status = struct('ok', true, 'message', "");
catch ME
    row.OK = false;
    row.SimSec = toc(t0);
    row.TransientSteps = nan;
    row.Jcost = nan;
    row.Jsupp = nan;
    row.Jvar = nan;
    row.ErrorMessage = string(sprintf('%s: %s', ME.identifier, ME.message));

    payload.meta.sim_sec = row.SimSec;
    payload.meta.ok = row.OK;
    payload.status = struct('ok', false, 'message', row.ErrorMessage);
end
end

function row = simulate_and_store_case_min(par_template, ss_ref, cc_policy, t_action_hr, seed, dt_hr, sid, case_file, cfg, mat_version)
[payload, row] = run_one_case_min(par_template, ss_ref, cc_policy, t_action_hr, seed, dt_hr, sid, case_file, cfg);
save(case_file, 'payload', mat_version);
end

function [ok, row] = row_from_existing_case_min(case_file, seed, dt_hr, sid)
ok = false;
row = new_manifest_row_min();
row.Seed = seed;
row.ActionDt_hr = dt_hr;
row.SampleID = sid;
row.CaseFile = string(case_file);

try
    S = load(case_file, 'payload');
    if ~isfield(S, 'payload')
        return;
    end
    payload = S.payload;

    if isfield(payload, 'status') && isfield(payload.status, 'ok')
        row.OK = logical(payload.status.ok);
    else
        row.OK = true;
    end

    if isfield(payload, 'meta') && isfield(payload.meta, 'sim_sec')
        row.SimSec = payload.meta.sim_sec;
    else
        row.SimSec = nan;
    end

    if isfield(payload, 'outputs') && isfield(payload.outputs, 't_hr')
        row.TransientSteps = numel(payload.outputs.t_hr);
    elseif isfield(payload, 'system') && isfield(payload.system, 'm_cc')
        row.TransientSteps = size(payload.system.m_cc, 1);
    else
        row.TransientSteps = nan;
    end

    if isfield(payload, 'outputs') && isfield(payload.outputs, 'objective')
        row.Jcost = payload.outputs.objective.Jcost;
        row.Jsupp = payload.outputs.objective.Jsupp;
        row.Jvar = payload.outputs.objective.Jvar;
    elseif isfield(payload, 'system') && isfield(payload.system, 'objective')
        row.Jcost = payload.system.objective.Jcost;
        row.Jsupp = payload.system.objective.Jsupp;
        row.Jvar = payload.system.objective.Jvar;
    else
        row.Jcost = nan;
        row.Jsupp = nan;
        row.Jvar = nan;
    end

    if isfield(payload, 'status') && isfield(payload.status, 'message')
        row.ErrorMessage = string(payload.status.message);
    else
        row.ErrorMessage = "";
    end

    ok = true;
catch ME
    row.OK = false;
    row.ErrorMessage = string(sprintf('load_failed:%s', ME.message));
    ok = false;
end
end

function par_sim = setup_par_sim_min(par_template, sim_cfg)
par_sim = par_template;
par_sim.sim = par_sim.ss;
par_sim.sim.rtol0 = sim_cfg.rtol0;
par_sim.sim.atol0 = sim_cfg.atol0;
par_sim.sim.rtol1 = sim_cfg.rtol1;
par_sim.sim.atol1 = sim_cfg.atol1;
par_sim.sim.rtol = sim_cfg.rtol;
par_sim.sim.atol = sim_cfg.atol;
par_sim.sim.startup = sim_cfg.startup;
par_sim.sim.nperiods = sim_cfg.nperiods;
par_sim.sim.solsteps = sim_cfg.solsteps;
par_sim.sim.fromss = 1;
end

function out_core = extract_core_outputs_min(par_sim, save_cfg)
n_t = size(par_sim.tr.m_cc, 1);
t_hr = linspace(0, 24, n_t)';

out_core = struct();
out_core.t_hr = t_hr;

out_core.objective = struct();
out_core.objective.Jcost = sum(par_sim.tr.shap.ori_Jcost);
out_core.objective.Jsupp = par_sim.tr.shap.ori_Jsupp;
out_core.objective.Jvar = par_sim.tr.shap.ori_Jvar;

if save_cfg.save_outputs_quick
    out_core.quick = struct();
    out_core.quick.m_cc_mean = mean(par_sim.tr.m_cc, 2);
    out_core.quick.m_cost = par_sim.tr.m_cost;
    out_core.quick.m_supp = par_sim.tr.m_supp;
    out_core.quick.m_var = par_sim.tr.m_var;
    out_core.quick.m_mass = par_sim.tr.m_mass;
else
    out_core.quick = struct();
end
end

function sys = extract_system_state_core_min(par_sim)
sys = struct();

sys.n0 = par_sim.tr.n0;
sys.n = par_sim.tr.n;
sys.units = par_sim.tr.units;
sys.intervals = par_sim.tr.intervals;
sys.c = par_sim.tr.c;

sys.m_cc = par_sim.tr.m_cc;
sys.m_cost = par_sim.tr.m_cost;
sys.m_cost_every = par_sim.tr.m_cost_every;
sys.m_supp = par_sim.tr.m_supp;
sys.m_var = par_sim.tr.m_var;
sys.m_mass = par_sim.tr.m_mass;

sys.shap = par_sim.tr.shap;
sys.objective = struct();
sys.objective.Jcost = sum(par_sim.tr.shap.ori_Jcost);
sys.objective.Jsupp = par_sim.tr.shap.ori_Jsupp;
sys.objective.Jvar = par_sim.tr.shap.ori_Jvar;
end

function sys = extract_system_state_all_min(par_sim)
sys = extract_system_state_core_min(par_sim);

sys.pp0 = par_sim.tr.pp0;
sys.qq0 = par_sim.tr.qq0;
sys.cc0 = par_sim.tr.cc0;
sys.tt0 = par_sim.tr.tt0;
sys.fd0 = par_sim.tr.fd0;

sys.pslout = par_sim.tr.pslout;
sys.xf = par_sim.tr.xf;

if isfield(par_sim.tr, 'ip_info')
    sys.ip_info = par_sim.tr.ip_info;
end
if isfield(par_sim.tr, 'objval')
    sys.objval = par_sim.tr.objval;
end
if isfield(par_sim.tr, 'objecon')
    sys.objecon = par_sim.tr.objecon;
end
if isfield(par_sim.tr, 'objeff')
    sys.objeff = par_sim.tr.objeff;
end
if isfield(par_sim.tr, 'resid')
    sys.resid = par_sim.tr.resid;
end

sys.available_tr_fields = fieldnames(par_sim.tr);
end

function par_template = load_par_template_min(cfg, ss_ref)
S = load(cfg.baseline_file, cfg.baseline_var);
if ~isfield(S, cfg.baseline_var)
    error('Variable %s not found in %s', cfg.baseline_var, cfg.baseline_file);
end

par_template = S.(cfg.baseline_var);
par_template.ss_start = ss_ref.ss_start;
par_template.ss_terminal = ss_ref.ss_terminal;
if isfield(par_template, 'tr')
    par_template.tr.ss_start = ss_ref.ss_start;
    par_template.tr.ss_terminal = ss_ref.ss_terminal;
end
end

function sample_ids = select_sample_ids_min(n_samples_total, cfg)
switch lower(cfg.sample_mode)
    case 'all'
        sample_ids = (1:n_samples_total)';

    case 'first_n'
        n = min(max(0, round(cfg.first_n)), n_samples_total);
        sample_ids = (1:n)';

    case 'custom_list'
        ids = unique(round(cfg.custom_sample_ids(:)), 'stable');
        ids = ids(ids >= 1 & ids <= n_samples_total);
        sample_ids = ids;

    case 'random_n'
        n = min(max(0, round(cfg.first_n)), n_samples_total);
        rng(cfg.sample_subset_seed, 'twister');
        sample_ids = sort(randperm(n_samples_total, n))';

    otherwise
        error('Unsupported sample_mode: %s', cfg.sample_mode);
end
end

function [pool_used, n_workers, n_cpu, target_workers] = maybe_prepare_parallel_pool_min(cfg)
pool_used = false;
n_workers = 1;
n_cpu = detect_num_cores_min();
target_workers = max(1, floor(n_cpu * cfg.parallel_worker_ratio));

if ~isempty(cfg.requested_workers)
    target_workers = max(1, round(cfg.requested_workers));
end

if ~cfg.use_parallel
    return;
end
if ~can_use_parallel_min()
    return;
end

try
    p = gcp('nocreate');
    if isempty(p)
        p = parpool('local', target_workers);
    elseif cfg.force_pool_size && p.NumWorkers ~= target_workers
        delete(p);
        p = parpool('local', target_workers);
    end
    pool_used = true;
    n_workers = p.NumWorkers;
catch
    pool_used = false;
    n_workers = 1;
end

function n = detect_num_cores_min()
n = 1;
try
    n = feature('numcores');
catch
    n = 1;
end
if isempty(n) || ~isfinite(n) || n < 1
    n = 1;
end
n = floor(n);
end
end

function tf = can_use_parallel_min()
tf = false;
try
    tf = ~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox');
catch
    tf = false;
end
end

function manifest_tbl = flush_manifest_min(run_dir, rows)
if isempty(rows)
    manifest_tbl = struct2table(rows);
else
    manifest_tbl = struct2table(rows);
    manifest_tbl = sortrows(manifest_tbl, {'Seed', 'ActionDt_hr', 'SampleID'});
end

writetable(manifest_tbl, fullfile(run_dir, 'manifest.csv'));
end

function summary_tbl = build_summary_min(manifest_tbl)
if isempty(manifest_tbl)
    summary_tbl = table();
    return;
end

g = findgroups(manifest_tbl.Seed, manifest_tbl.ActionDt_hr);
seed_col = splitapply(@(x) x(1), manifest_tbl.Seed, g);
dt_col = splitapply(@(x) x(1), manifest_tbl.ActionDt_hr, g);
count_col = splitapply(@numel, manifest_tbl.SampleID, g);
ok_rate_col = splitapply(@(x) mean(x), manifest_tbl.OK, g);
mean_sec_col = splitapply(@(x) mean(x, 'omitnan'), manifest_tbl.SimSec, g);
median_jc_col = splitapply(@(x) median(x, 'omitnan'), manifest_tbl.Jcost, g);
median_js_col = splitapply(@(x) median(x, 'omitnan'), manifest_tbl.Jsupp, g);
median_jv_col = splitapply(@(x) median(x, 'omitnan'), manifest_tbl.Jvar, g);

summary_tbl = table(seed_col, dt_col, count_col, ok_rate_col, mean_sec_col, median_jc_col, median_js_col, median_jv_col, ...
    'VariableNames', {'Seed', 'ActionDt_hr', 'NSamples', 'OKRate', 'MeanSimSec', 'MedianJcost', 'MedianJsupp', 'MedianJvar'});
summary_tbl = sortrows(summary_tbl, {'Seed', 'ActionDt_hr'});
end

function write_run_summary_md_min(run_dir, cfg, ss_ref, manifest_tbl, summary_tbl, pool_used, n_workers, n_cpu, target_workers)
md = fullfile(run_dir, 'RUN_SUMMARY.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write markdown: %s', md);
end

fprintf(fid, '# try1 DOE transient run summary\n\n');
fprintf(fid, '- try root: `%s`\n', cfg.try_root);
fprintf(fid, '- run dir: `%s`\n', run_dir);
fprintf(fid, '- seeds: `%s`\n', mat2str(cfg.seeds));
fprintf(fid, '- dt list: `%s` h\n', mat2str(cfg.dt_list));
fprintf(fid, '- sample mode: `%s`\n', cfg.sample_mode);
fprintf(fid, '- baseline: `%s::%s`\n', cfg.baseline_file, cfg.baseline_var);
fprintf(fid, '- ss reference: `%s`\n', ss_ref.source);
fprintf(fid, '- bounds: `cc in [%.1f, %.1f]`\n', cfg.bounds.cc_min, cfg.bounds.cc_max);
fprintf(fid, '- increment magnitude variable: `|Delta c|/h in [0, %.4f]`\n', cfg.bounds.delta_cap_per_hour);
fprintf(fid, '- cpu cores detected: `%d`\n', n_cpu);
fprintf(fid, '- target workers (90%% rule or override): `%d`\n', target_workers);
fprintf(fid, '- parallel used: `%d` (actual workers=%d)\n', pool_used, n_workers);
fprintf(fid, '- skip existing cases: `%d`\n', cfg.skip_existing_cases);
fprintf(fid, '- parallel batch factor: `%d`\n', cfg.parallel_batch_factor);
fprintf(fid, '- save system state all: `%d`\n', cfg.save.save_system_state_all);
fprintf(fid, '- save outputs quick: `%d`\n', cfg.save.save_outputs_quick);
fprintf(fid, '- reconstruction mode: `from saved system-state only (no second simulation)`\n');
fprintf(fid, '- save full par struct: `%d`\n\n', cfg.save.save_full_par_struct);

fprintf(fid, '## Manifest\n\n');
fprintf(fid, '- total simulated rows: `%d`\n', height(manifest_tbl));
if ~isempty(manifest_tbl)
    fprintf(fid, '- success rows: `%d`\n', sum(manifest_tbl.OK));
    fprintf(fid, '- failed rows: `%d`\n\n', sum(~manifest_tbl.OK));
else
    fprintf(fid, '- success rows: `0`\n- failed rows: `0`\n\n');
end

fprintf(fid, '## By dataset\n\n');
if isempty(summary_tbl)
    fprintf(fid, '- no rows\n\n');
else
    fprintf(fid, '| seed | dt(h) | n | ok_rate | mean_sec | median Jcost | median Jsupp | median Jvar |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary_tbl)
        fprintf(fid, '| %d | %.2f | %d | %.4f | %.4f | %.10g | %.10g | %.10g |\n', ...
            summary_tbl.Seed(i), summary_tbl.ActionDt_hr(i), summary_tbl.NSamples(i), ...
            summary_tbl.OKRate(i), summary_tbl.MeanSimSec(i), ...
            summary_tbl.MedianJcost(i), summary_tbl.MedianJsupp(i), summary_tbl.MedianJvar(i));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `run_config.mat`\n');
fprintf(fid, '- `manifest.csv`\n');
fprintf(fid, '- `summary_by_dataset.csv`\n');
fprintf(fid, '- `RUN_SUMMARY.md`\n');
fprintf(fid, '- `cases/seed_*/dataset_dt_*/sample_*.mat`\n');

fclose(fid);
end

function cfg = fill_cfg_defaults_min(cfg)
if ~isfield(cfg, 'parallel_worker_ratio') || isempty(cfg.parallel_worker_ratio)
    cfg.parallel_worker_ratio = 0.90;
end
cfg.parallel_worker_ratio = min(max(cfg.parallel_worker_ratio, 0.05), 1.0);

if ~isfield(cfg, 'force_pool_size') || isempty(cfg.force_pool_size)
    cfg.force_pool_size = false;
end

if ~isfield(cfg, 'parallel_batch_factor') || isempty(cfg.parallel_batch_factor)
    cfg.parallel_batch_factor = 4;
end
cfg.parallel_batch_factor = max(1, round(cfg.parallel_batch_factor));

if ~isfield(cfg, 'skip_existing_cases') || isempty(cfg.skip_existing_cases)
    cfg.skip_existing_cases = true;
end

if ~isfield(cfg, 'save') || ~isstruct(cfg.save)
    cfg.save = struct();
end
if ~isfield(cfg.save, 'save_system_state_all') || isempty(cfg.save.save_system_state_all)
    cfg.save.save_system_state_all = true;
end
if ~isfield(cfg.save, 'save_outputs_quick') || isempty(cfg.save.save_outputs_quick)
    cfg.save.save_outputs_quick = true;
end
if ~isfield(cfg.save, 'save_full_par_struct') || isempty(cfg.save.save_full_par_struct)
    cfg.save.save_full_par_struct = false;
end
if ~isfield(cfg.save, 'mat_version') || isempty(cfg.save.mat_version)
    cfg.save.mat_version = '-v7.3';
end
end

function row = new_manifest_row_min()
row = struct();
row.Seed = nan;
row.ActionDt_hr = nan;
row.SampleID = nan;
row.CaseFile = "";
row.OK = false;
row.SimSec = nan;
row.TransientSteps = nan;
row.Jcost = nan;
row.Jsupp = nan;
row.Jvar = nan;
row.ErrorMessage = "";
end

function s = dt_tag_min(dt_hr)
s = strrep(sprintf('%.1f', dt_hr), '.', 'p');
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_min(path_str)
if exist(path_str, 'dir') ~= 7
    return;
end

items = dir(path_str);
for i = 1:numel(items)
    name = items(i).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue;
    end
    fp = fullfile(path_str, name);
    if items(i).isdir
        rmdir(fp, 's');
    else
        delete(fp);
    end
end
end
