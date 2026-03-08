function out = reconstruct_case_from_saved_min(case_file, opts)
if nargin < 2 || isempty(opts)
    opts = struct();
end

if ~isfield(opts, 'save_to_file') || isempty(opts.save_to_file)
    opts.save_to_file = false;
end
if ~isfield(opts, 'output_file') || isempty(opts.output_file)
    opts.output_file = '';
end
if ~isfield(opts, 'compare_with_payload') || isempty(opts.compare_with_payload)
    opts.compare_with_payload = true;
end

if exist(case_file, 'file') ~= 2
    error('Case file not found: %s', case_file);
end

S = load(case_file, 'payload');
if ~isfield(S, 'payload')
    error('payload not found in %s', case_file);
end
payload = S.payload;

if ~isfield(payload, 'system')
    error('payload.system missing. Case not saved with system-state bundle: %s', case_file);
end

sys = payload.system;

rec = struct();
if isfield(payload, 'outputs') && isfield(payload.outputs, 't_hr')
    rec.t_hr = payload.outputs.t_hr;
else
    rec.t_hr = linspace(0, 24, size(sys.m_cc, 1))';
end

rec.process = struct();
rec.process.m_cc = sys.m_cc;
rec.process.m_cost = sys.m_cost;
rec.process.m_cost_every = sys.m_cost_every;
rec.process.m_supp = sys.m_supp;
rec.process.m_var = sys.m_var;
rec.process.m_mass = sys.m_mass;

rec.shap = sys.shap;

rec.objective = struct();
rec.objective.Jcost = sum(rec.shap.ori_Jcost);
rec.objective.Jsupp = rec.shap.ori_Jsupp;
rec.objective.Jvar = rec.shap.ori_Jvar;

dt_hr = payload.meta.dt_hr;
cc_policy = payload.inputs.cc_policy;
d = diff(cc_policy, 1, 1);
d_no = d;
if size(d_no, 1) >= 2
    d_no = d_no(1:end-1, :);
else
    d_no = zeros(0, size(cc_policy, 2));
end

rec.derived = struct();
rec.derived.mean_m_cc = mean(rec.process.m_cc, 2);
rec.derived.mean_cc_action = mean(cc_policy, 2);
rec.derived.start_gap = max(abs(cc_policy(1,:) - payload.boundary.cc_start));
rec.derived.end_gap = max(abs(cc_policy(end,:) - payload.boundary.cc_end));
rec.derived.max_step = max(abs(d(:)));

if isempty(d_no)
    rec.derived.max_abs_inc_no_terminal_per_h = nan;
    rec.derived.p95_abs_inc_no_terminal_per_h = nan;
    rec.derived.mean_abs_inc_no_terminal_per_h = nan;
else
    x = abs(d_no(:)) / dt_hr;
    rec.derived.max_abs_inc_no_terminal_per_h = max(x);
    rec.derived.p95_abs_inc_no_terminal_per_h = prctile(x, 95);
    rec.derived.mean_abs_inc_no_terminal_per_h = mean(x);
end

rec.formulas = struct();
rec.formulas.Jcost = 'Jcost = sum(shap.ori_Jcost)';
rec.formulas.Jsupp = 'Jsupp = shap.ori_Jsupp';
rec.formulas.Jvar = 'Jvar = shap.ori_Jvar';
rec.formulas.mean_m_cc = 'mean_m_cc(t) = mean(m_cc(t,:))';
rec.formulas.max_step = 'max_step = max(abs(diff(cc_policy,1,1)),[],''all'')';
rec.formulas.start_gap = 'start_gap = max(abs(cc_policy(1,:) - cc_start))';
rec.formulas.end_gap = 'end_gap = max(abs(cc_policy(end,:) - cc_end))';

cmp = struct();
if opts.compare_with_payload && isfield(payload, 'outputs') && isfield(payload.outputs, 'objective')
    cmp.abs_Jcost = abs(rec.objective.Jcost - payload.outputs.objective.Jcost);
    cmp.abs_Jsupp = abs(rec.objective.Jsupp - payload.outputs.objective.Jsupp);
    cmp.abs_Jvar = abs(rec.objective.Jvar - payload.outputs.objective.Jvar);

    if isfield(payload.outputs, 'quick') && isfield(payload.outputs.quick, 'm_cc_mean')
        cmp.max_abs_mean_m_cc = max(abs(rec.derived.mean_m_cc(:) - payload.outputs.quick.m_cc_mean(:)));
    else
        cmp.max_abs_mean_m_cc = nan;
    end
else
    cmp.abs_Jcost = nan;
    cmp.abs_Jsupp = nan;
    cmp.abs_Jvar = nan;
    cmp.max_abs_mean_m_cc = nan;
end

out = struct();
out.case_file = case_file;
out.meta = payload.meta;
out.reconstructed = rec;
out.compare = cmp;
out.available_system_fields = fieldnames(sys);

if opts.save_to_file
    output_file = opts.output_file;
    if isempty(output_file)
        [p, n, ~] = fileparts(case_file);
        output_file = fullfile(p, [n '_reconstructed_from_saved.mat']);
    end
    save(output_file, 'out', '-v7.3');
    out.output_file = output_file;
else
    out.output_file = '';
end
end
