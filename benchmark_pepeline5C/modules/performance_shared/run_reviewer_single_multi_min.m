function out = run_reviewer_single_multi_min(cfg)
% Reviewer-focused single-objective and multi-objective validation plots.
% - Single objective: no mean action, plot all 5 compressor sequences.
% - Multi objective: SHAP-only Pareto scatter under weight sweep + MO metrics.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_reviewer_min(cfg);
ensure_runtime_paths_reviewer_min(cfg);
ensure_dir_reviewer_min(cfg.out_dir);
ensure_dir_reviewer_min(cfg.plot_dir);
ensure_dir_reviewer_min(cfg.table_dir);

scores_tbl = readtable(cfg.holdout_score_csv);
corr_tbl = readtable(cfg.holdout_corr_csv);

scores_tbl = normalize_text_cols_reviewer_min(scores_tbl, {'SampleFile'});
corr_tbl = normalize_text_cols_reviewer_min(corr_tbl, {'Method', 'Objective'});

single_defs = build_single_defs_reviewer_min();
single_summary = table();

for s = 1:numel(single_defs)
    scn = single_defs(s);

    [policy_cube, method_names, metrics_abs, src_meta] = load_single_policy_cube_reviewer_min(cfg, scn, scores_tbl, corr_tbl);
    t_hr = linspace(0, 24, size(policy_cube, 1))';
    [t_metric, metric_curve_rel, metrics_eval, target_cum_abs] = build_target_curves_reviewer_min(cfg, scn, method_names, policy_cube, src_meta);

    for m = 1:size(metrics_abs, 1)
        if all(isfinite(metrics_eval(m, :)))
            metrics_abs(m, :) = metrics_eval(m, :);
        end
    end

    target_abs = target_cum_abs(:);
    bad = ~isfinite(target_abs);
    if any(bad)
        target_abs(bad) = metrics_abs(bad, scn.target_idx);
    end

    den = target_abs(1);
    if ~isfinite(den) || abs(den) <= eps
        den = 1;
    end
    target_rel = target_abs ./ den;

    if cfg.single_metric_use_absolute
        target_plot = target_abs;
    else
        target_plot = target_rel;
    end

    [act_png, act_svg] = plot_single_actions_5cols_reviewer_min(cfg.plot_dir, scn, t_hr, policy_cube, method_names, cfg);
    [cmp_png, cmp_svg] = plot_single_metric_line_bar_reviewer_min(cfg.plot_dir, scn, method_names, t_metric, metric_curve_rel, target_plot, cfg);

    target_tbl = table(method_names(:), metrics_abs(:, 1), metrics_abs(:, 2), metrics_abs(:, 3), target_abs(:), metrics_abs(:, scn.target_idx), target_rel(:), ...
        'VariableNames', {'Method', 'Jcost', 'Jsupp', 'Jvar', 'TargetMetricAbs', 'TargetMetricFinalAbs', 'TargetMetricRel'});
    target_csv = fullfile(cfg.table_dir, sprintf('single_target_metric_%s.csv', char(scn.name)));
    writetable(target_tbl, target_csv);

    row = table(string(scn.name), string(scn.target_slug), string(act_png), string(act_svg), string(cmp_png), string(cmp_svg), string(target_csv), ...
        'VariableNames', {'Scenario', 'Target', 'ActionPlotPNG', 'ActionPlotSVG', 'ComparePlotPNG', 'ComparePlotSVG', 'TargetMetricCSV'});
    single_summary = [single_summary; row]; %#ok<AGROW>
end

[w_rep_tbl, w_cand_tbl] = run_multi_weight_selection_reviewer_min(scores_tbl, corr_tbl, cfg);
[ref_tbl, ref_front_tbl, mo_metrics_tbl, w_rep_tbl, w_cand_tbl] = compute_multi_mo_metrics_reviewer_min(w_rep_tbl, w_cand_tbl, cfg);
[multi_png, multi_svg] = plot_multi_weight_scatter_reviewer_min(cfg.plot_dir, w_rep_tbl, w_cand_tbl, ref_tbl, ref_front_tbl, mo_metrics_tbl, cfg);

w_csv = fullfile(cfg.table_dir, 'multi_weight_selection_shap.csv');
cand_csv = fullfile(cfg.table_dir, 'multi_weight_topk_candidates.csv');
ref_csv = fullfile(cfg.table_dir, 'multi_reference_points.csv');
front_csv = fullfile(cfg.table_dir, 'multi_reference_frontier.csv');
mo_csv = fullfile(cfg.table_dir, 'multi_mo_metrics.csv');
single_summary_csv = fullfile(cfg.table_dir, 'single_plot_summary.csv');

writetable(w_rep_tbl, w_csv);
writetable(w_cand_tbl, cand_csv);
writetable(ref_tbl, ref_csv);
writetable(ref_front_tbl, front_csv);
writetable(mo_metrics_tbl, mo_csv);
writetable(single_summary, single_summary_csv);

report_md = fullfile(cfg.out_dir, 'REVIEWER_SINGLE_MULTI_SUMMARY.md');
write_report_reviewer_min(report_md, cfg, single_summary, mo_metrics_tbl, w_cand_tbl, multi_png, multi_svg);

single_fig_md = fullfile(cfg.out_dir, 'SINGLE_FIGURE_CAPTIONS_DISCUSSION.md');
write_single_figure_notes_reviewer_min(single_fig_md, single_summary);

out = struct();
out.single_summary_csv = single_summary_csv;
out.multi_weight_csv = w_csv;
out.multi_weight_topk_csv = cand_csv;
out.multi_ref_csv = ref_csv;
out.multi_ref_front_csv = front_csv;
out.multi_metrics_csv = mo_csv;
out.multi_plot_png = multi_png;
out.multi_plot_svg = multi_svg;
out.report_md = report_md;
out.single_figure_md = single_fig_md;
end

function defs = build_single_defs_reviewer_min()
defs = repmat(struct(), 3, 1);

defs(1).name = "single_jcost";
defs(1).target_slug = "jcost";
defs(1).target_idx = 1;
defs(1).target_label = "$J_{cst}$";

defs(2).name = "single_jsupp";
defs(2).target_slug = "jsupp";
defs(2).target_idx = 2;
defs(2).target_label = "$J_{stg}$";

defs(3).name = "single_jvar";
defs(3).target_slug = "jvar";
defs(3).target_idx = 3;
defs(3).target_label = "$J_{var}$";
end

function [policy_cube, method_names, metrics_abs, src_meta] = load_single_policy_cube_reviewer_min(cfg, scn, scores_tbl, corr_tbl)
if string(scn.target_slug) == "jvar"
    method_names = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
    n_method = numel(method_names);
    policy_cube = zeros(cfg.n_time, cfg.n_comp, n_method);
    metrics_abs = nan(n_method, 3);
    src_meta = repmat(struct('type', "sample_payload", 'path', ""), n_method, 1);

    [Pshap, Mshap, Fshap] = select_shap_policy_set_reviewer_min(scores_tbl, corr_tbl, "Jvar", cfg);
    policy_cube(:, :, :) = Pshap;
    metrics_abs(:, :) = Mshap;
    src_meta(1).path = string(Fshap(1));
    src_meta(2).path = string(Fshap(2));
    src_meta(3).path = string(Fshap(3));
    return;
end

method_names = ["tr-opt", "ss-opt", "ss-3stage", "ss-7stage", "ss-13stage", "Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
n_method = numel(method_names);

Sss = load(cfg.ss_results_mat, 'plans');
Scs = load(cfg.cover_iter_results_mat, 'cases');

policy_cube = zeros(cfg.n_time, cfg.n_comp, n_method);
metrics_abs = nan(n_method, 3);
src_meta = repmat(struct('type', "policy_only", 'path', ""), n_method, 1);

switch string(scn.name)
    case "single_jcost"
        S = load(cfg.tr_cost_case_mat, 'cc_policy', 'sim_eval');
        p_tr = fix_policy_shape_reviewer_min(S.cc_policy, cfg.n_time, cfg.n_comp);
        metrics_abs(1, :) = [S.sim_eval.Jcost, S.sim_eval.Jsupp, S.sim_eval.Jvar];
        src_meta(1).type = "tr_case";
        src_meta(1).path = string(cfg.tr_cost_case_mat);
    case "single_jsupp"
        S = load(cfg.tr_supp_case_mat, 'cc_policy', 'sim_eval');
        p_tr = fix_policy_shape_reviewer_min(S.cc_policy, cfg.n_time, cfg.n_comp);
        metrics_abs(1, :) = [S.sim_eval.Jcost, S.sim_eval.Jsupp, S.sim_eval.Jvar];
        src_meta(1).type = "tr_case";
        src_meta(1).path = string(cfg.tr_supp_case_mat);
    case "single_jvar"
        jv = arrayfun(@(x) x.sim_eval.Jvar, Scs.cases);
        [~, id] = min(jv);
        p_tr = fix_policy_shape_reviewer_min(Scs.cases(id).cc_policy, cfg.n_time, cfg.n_comp);
        metrics_abs(1, :) = [Scs.cases(id).sim_eval.Jcost, Scs.cases(id).sim_eval.Jsupp, Scs.cases(id).sim_eval.Jvar];
        src_meta(1).type = "policy_only";
        src_meta(1).path = "";
    otherwise
        error('Unknown scenario: %s', scn.name);
end

policy_cube(:, :, 1) = p_tr;
 [policy_cube(:, :, 2), metrics_abs(2, :)] = get_ss_plan_policy_reviewer_min(Sss.plans, "ss_opt", cfg.n_time, cfg.n_comp);
 [policy_cube(:, :, 3), metrics_abs(3, :)] = get_ss_plan_policy_reviewer_min(Sss.plans, "ss-3stage", cfg.n_time, cfg.n_comp);
 [policy_cube(:, :, 4), metrics_abs(4, :)] = get_ss_plan_policy_reviewer_min(Sss.plans, "ss-7stage", cfg.n_time, cfg.n_comp);
 [policy_cube(:, :, 5), metrics_abs(5, :)] = get_ss_plan_policy_reviewer_min(Sss.plans, "ss-13stage", cfg.n_time, cfg.n_comp);

target_obj = ["Jcost", "Jsupp", "Jvar"];
[Pshap, Mshap, Fshap] = select_shap_policy_set_reviewer_min(scores_tbl, corr_tbl, target_obj(scn.target_idx), cfg);
policy_cube(:, :, 6:8) = Pshap;
metrics_abs(6:8, :) = Mshap;
fp6 = Fshap(1);
fp7 = Fshap(2);
fp8 = Fshap(3);

src_meta(6).type = "sample_payload";
src_meta(6).path = string(fp6);
src_meta(7).type = "sample_payload";
src_meta(7).path = string(fp7);
src_meta(8).type = "sample_payload";
src_meta(8).path = string(fp8);
end

function [p, met] = get_ss_plan_policy_reviewer_min(plans, plan_name, n_time, n_comp)
id = [];
for i = 1:numel(plans)
    if strcmpi(string(plans(i).name), plan_name)
        id = i;
        break;
    end
end
if isempty(id)
    error('Plan not found: %s', plan_name);
end
p = fix_policy_shape_reviewer_min(plans(id).cc_policy, n_time, n_comp);
met = [plans(id).sim_eval.Jcost, plans(id).sim_eval.Jsupp, plans(id).sim_eval.Jvar];
end

function [policy, metrics, sample_file] = select_shap_top1_policy_reviewer_min(scores_tbl, corr_tbl, method_name, target_obj, cfg)
[sc_cost, sc_supp] = score_columns_reviewer_min(method_name);
sc_var = score_column_jvar_reviewer_min(method_name);

score_map = struct();
score_map.Jcost = objective_proxy_reviewer_min(scores_tbl.(sc_cost), corr_tbl, method_name, "Jcost", "min");
score_map.Jsupp = objective_proxy_reviewer_min(scores_tbl.(sc_supp), corr_tbl, method_name, "Jsupp", "max");
score_map.Jvar = objective_proxy_reviewer_min(scores_tbl.(sc_var), corr_tbl, method_name, "Jvar", "min");

proxy = score_map.(char(target_obj));
[~, id] = min(proxy);

fp = char(scores_tbl.SampleFile(id));
if exist(fp, 'file') ~= 2
    error('Selected sample file not found: %s', fp);
end

D = load(fp, 'payload');
cc = D.payload.inputs.cc_policy;
policy = fix_policy_shape_reviewer_min(cc, cfg.n_time, cfg.n_comp);
metrics = [scores_tbl.Jcost(id), scores_tbl.Jsupp(id), scores_tbl.Jvar(id)];
sample_file = string(fp);
end

function [policy_set, metric_set, file_set] = select_shap_policy_set_reviewer_min(scores_tbl, corr_tbl, target_obj, cfg)
methods_out = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
n_method = numel(methods_out);

cand_cells = cell(n_method, 1);
for i = 1:n_method
    method_name = methods_out(i);
    [proxy, ord] = shap_proxy_and_order_reviewer_min(scores_tbl, corr_tbl, method_name, target_obj);

    topk = max(1, min(cfg.single_stage2_topk, numel(ord)));
    ord = ord(1:topk);

    Tc = table();
    Tc.RowId = ord(:);
    Tc.CaseIndex = scores_tbl.CaseIndex(ord);
    Tc.SampleFile = scores_tbl.SampleFile(ord);
    Tc.Jcost = scores_tbl.Jcost(ord);
    Tc.Jsupp = scores_tbl.Jsupp(ord);
    Tc.Jvar = scores_tbl.Jvar(ord);
    Tc.TargetProxy = proxy(ord);

    target_raw = target_value_min_space_reviewer_min(Tc, target_obj);
    Tc.TargetLoss = normalize01_reviewer_min(target_raw);
    Tc.ProxyLoss = normalize01_reviewer_min(Tc.TargetProxy);
    Tc.CompositeLoss = Tc.TargetLoss + cfg.single_stage2_proxy_weight * Tc.ProxyLoss;
    cand_cells{i} = Tc;
end

if cfg.single_enforce_unique
    [sel_local, feasible] = solve_unique_assignment_reviewer_min(cand_cells);
    if ~feasible
        sel_local = zeros(n_method, 1);
        for i = 1:n_method
            [~, k] = min(cand_cells{i}.CompositeLoss);
            sel_local(i) = k;
        end
    end
else
    sel_local = zeros(n_method, 1);
    for i = 1:n_method
        [~, k] = min(cand_cells{i}.CompositeLoss);
        sel_local(i) = k;
    end
end

pick = table();
for i = 1:n_method
    row = cand_cells{i}(sel_local(i), :);
    row.Method = repmat(methods_out(i), height(row), 1);
    row = movevars(row, 'Method', 'Before', 1);
    pick = [pick; row]; %#ok<AGROW>
end

policy_set = zeros(cfg.n_time, cfg.n_comp, n_method);
metric_set = nan(n_method, 3);
file_set = strings(n_method, 1);

for i = 1:n_method
    fp = char(pick.SampleFile(i));
    if exist(fp, 'file') ~= 2
        error('Selected sample file not found: %s', fp);
    end
    D = load(fp, 'payload');
    cc = D.payload.inputs.cc_policy;
    policy_set(:, :, i) = fix_policy_shape_reviewer_min(cc, cfg.n_time, cfg.n_comp);
    metric_set(i, :) = [pick.Jcost(i), pick.Jsupp(i), pick.Jvar(i)];
    file_set(i) = string(fp);
end
end

function [proxy, ord] = shap_proxy_and_order_reviewer_min(scores_tbl, corr_tbl, method_name, target_obj)
[sc_cost, sc_supp] = score_columns_reviewer_min(method_name);
sc_var = score_column_jvar_reviewer_min(method_name);

score_map = struct();
score_map.Jcost = objective_proxy_reviewer_min(scores_tbl.(sc_cost), corr_tbl, method_name, "Jcost", "min");
score_map.Jsupp = objective_proxy_reviewer_min(scores_tbl.(sc_supp), corr_tbl, method_name, "Jsupp", "max");
score_map.Jvar = objective_proxy_reviewer_min(scores_tbl.(sc_var), corr_tbl, method_name, "Jvar", "min");

proxy = score_map.(char(target_obj));
[~, ord] = sort(proxy, 'ascend');
end

function v = target_value_min_space_reviewer_min(T, target_obj)
switch string(target_obj)
    case "Jcost"
        v = T.Jcost;
    case "Jsupp"
        v = -T.Jsupp;
    case "Jvar"
        v = T.Jvar;
    otherwise
        error('Unknown target objective: %s', string(target_obj));
end
v = v(:);
end

function [best_sel, feasible] = solve_unique_assignment_reviewer_min(cand_cells)
n = numel(cand_cells);
best_sel = zeros(n, 1);
feasible = false;
best_loss = inf;
cur_sel = zeros(n, 1);

dfs_assign_reviewer_min(1, [], 0);

    function dfs_assign_reviewer_min(level, used_case, cur_loss)
        if level > n
            if cur_loss < best_loss
                best_loss = cur_loss;
                best_sel = cur_sel;
                feasible = true;
            end
            return;
        end

        Tc = cand_cells{level};
        [~, ord_local] = sort(Tc.CompositeLoss, 'ascend');
        for ii = 1:numel(ord_local)
            k = ord_local(ii);
            ci = Tc.CaseIndex(k);
            if any(ci == used_case)
                continue;
            end

            new_loss = cur_loss + Tc.CompositeLoss(k);
            if new_loss >= best_loss
                continue;
            end

            cur_sel(level) = k;
            dfs_assign_reviewer_min(level + 1, [used_case; ci], new_loss); %#ok<AGROW>
        end
    end
end

function sc_var = score_column_jvar_reviewer_min(method_name)
switch string(method_name)
    case "Ori-SHAP"
        sc_var = "OriScoreJvar";
    case "Cond-SHAP"
        sc_var = "CondScoreJvar";
    case "PI-SHAP"
        sc_var = "PIScoreJvar";
    otherwise
        error('Unknown method: %s', method_name);
end
end

function proxy = objective_proxy_reviewer_min(score_vec, corr_tbl, method_name, obj_name, sense)
s = sign_from_corr_reviewer_min(corr_tbl, method_name, obj_name);
base = normalize01_reviewer_min(s * score_vec);
if strcmpi(char(sense), 'max')
    proxy = 1 - base;
else
    proxy = base;
end
end

function [t_ref, curve_rel, metrics_eval, target_cum_abs] = build_target_curves_reviewer_min(cfg, scn, method_names, policy_cube, src_meta)
n_method = numel(method_names);
curve_cell = cell(n_method, 1);
t_cell = cell(n_method, 1);
metrics_eval = nan(n_method, 3);
target_cum_abs = nan(n_method, 1);

for m = 1:n_method
    [t_m, y_m, met_m] = one_target_curve_reviewer_min(cfg, scn, policy_cube(:, :, m), src_meta(m), method_names(m));
    t_cell{m} = t_m(:);
    curve_cell{m} = y_m(:);
    metrics_eval(m, :) = met_m;
    target_cum_abs(m) = sum(y_m, 'omitnan');
end

n_ref = max(3, cfg.n_time);
t_ref = linspace(0, 24, n_ref)';
curve_mat = zeros(n_ref, n_method);
for m = 1:n_method
    t_m = t_cell{m};
    y = curve_cell{m};
    if numel(y) ~= numel(t_m)
        t_m = linspace(0, 24, numel(y))';
    end
    if isempty(y)
        y = zeros(n_ref, 1);
    elseif numel(y) < 2
        y = repmat(y(1), n_ref, 1);
    else
        y = interp1(t_m, y, t_ref, 'pchip', 'extrap');
    end

    if cfg.display_smooth_window > 1
        y = smooth_curve_for_display_reviewer_min(y, cfg.display_smooth_window);
    end

    curve_mat(:, m) = y;
end

if cfg.single_metric_use_absolute
    curve_rel = curve_mat;
else
    scale = max(abs(curve_mat(:, 1)));
    if ~isfinite(scale) || scale <= eps
        scale = 1;
    end
    curve_rel = curve_mat ./ scale;
end
end

function y = smooth_curve_for_display_reviewer_min(y, w)
y = y(:);
w = max(1, round(w));
if w <= 1
    return;
end
try
    y = smoothdata(y, 'movmean', w);
catch
    y = movmean(y, w, 'Endpoints', 'shrink');
end
end

function [t, y, met] = one_target_curve_reviewer_min(cfg, scn, policy, src, method_name)
target_idx = scn.target_idx;

switch string(src.type)
    case "tr_case"
        S = load(char(src.path), 'par_case', 'sim_eval');
        [t, y] = extract_target_series_reviewer_min(S.par_case.tr, target_idx);
        met = [S.sim_eval.Jcost, S.sim_eval.Jsupp, S.sim_eval.Jvar];

    case "sample_payload"
        D = load(char(src.path), 'payload');
        [t, y] = extract_target_series_reviewer_min(D.payload.system, target_idx);
        obj = D.payload.outputs.objective;
        met = [obj.Jcost, obj.Jsupp, obj.Jvar];

    otherwise
        sim_res = simulate_for_curve_reviewer_min(cfg, policy, sprintf('review_%s_%s', scn.target_slug, method_name));
        [t, y] = extract_target_series_reviewer_min(sim_res.par.tr, target_idx);
        met = [sim_res.metrics.Jcost, sim_res.metrics.Jsupp, sim_res.metrics.Jvar];
end
end

function [t, y] = extract_target_series_reviewer_min(sys_struct, target_idx)
if isfield(sys_struct, 'tr')
    tr = sys_struct.tr;
else
    tr = sys_struct;
end

switch target_idx
    case 1
        if isfield(tr, 'm_cost_every')
            y = sum(tr.m_cost_every, 2);
        elseif isfield(tr, 'm_cost')
            y = tr.m_cost(:);
        else
            error('No cost time series found.');
        end
    case 2
        if isfield(tr, 'm_supp')
            y = tr.m_supp(:);
        else
            error('No supply time series found.');
        end
    case 3
        if isfield(tr, 'm_var')
            y = tr.m_var(:);
        else
            error('No variance time series found.');
        end
    otherwise
        error('Unknown target_idx: %d', target_idx);
end

y = y(:);
t = linspace(0, 24, numel(y))';
end

function sim_res = simulate_for_curve_reviewer_min(cfg, policy, name_tag)
persistent par_base_cached sim_cfg_cached
if isempty(par_base_cached) || isempty(sim_cfg_cached)
    sim_cfg_cached = config_model_mine_min();
    par_base_cached = load_baseline_min(sim_cfg_cached);
end
sim_res = simulate_policy_min(par_base_cached, policy, sim_cfg_cached, name_tag);
end

function [png_file, svg_file] = plot_single_actions_5cols_reviewer_min(plot_dir, scn, t_hr, policy_cube, method_names, cfg)
if nargin < 6 || isempty(cfg)
    cfg = struct();
end

font_step = 0;
if isfield(cfg, 'single_action_font_step_jcost') && isfinite(cfg.single_action_font_step_jcost)
    if string(scn.name) == "single_jcost"
        font_step = cfg.single_action_font_step_jcost;
    end
end

n_method = numel(method_names);
n_comp = size(policy_cube, 2);
[cols, lstyles] = method_style_reviewer_min(method_names);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [30 70 3600 900], 'Renderer', 'painters');
tl = tiledlayout(1, n_comp, 'TileSpacing', 'compact', 'Padding', 'compact');
tl.Position = [0.03 0.12 0.94 0.72];
h_leg = gobjects(n_method, 1);
ymin = min(policy_cube(:), [], 'omitnan');
if ~isfinite(ymin)
    ymin = 0.9;
end
ymin = max(0.0, min(ymin, 1.0));

for c = 1:n_comp
    ax = nexttile(c);
    hold(ax, 'on');
    for m = 1:n_method
        if c == 1
            h_leg(m) = plot(ax, t_hr, policy_cube(:, c, m), lstyles{m}, 'Color', cols(m, :), ...
                'LineWidth', 3.0, 'DisplayName', char(method_names(m)));
        else
            plot(ax, t_hr, policy_cube(:, c, m), lstyles{m}, 'Color', cols(m, :), ...
                'LineWidth', 3.0, 'HandleVisibility', 'off');
        end
    end
    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [0 24]);
    xticks(ax, 0:6:24);
    ylim(ax, [ymin 1.6]);
    xlabel(ax, 'Time (h)', 'FontSize', 29 + font_step);
    if c == 1
        ylabel(ax, 'Compression ratio', 'FontSize', 31 + font_step);
    end
    title(ax, sprintf('r%d', c), 'FontSize', 34 + font_step, 'FontWeight', 'bold');
    set(ax, 'FontSize', 26 + font_step, 'LineWidth', 1.8);
end

ax_leg = axes('Parent', f, 'Position', [0.005 0.958 0.99 0.040], 'Visible', 'off');
legend(ax_leg, h_leg, method_names, 'Location', 'north', 'NumColumns', n_method, ...
    'FontSize', 30 + font_step, 'Box', 'on', 'AutoUpdate', 'off', 'Orientation', 'horizontal');

png_file = fullfile(plot_dir, sprintf('single_action_5comp_%s.png', char(scn.name)));
svg_file = fullfile(plot_dir, sprintf('single_action_5comp_%s.svg', char(scn.name)));
exportgraphics(f, png_file, 'Resolution', 270, 'BackgroundColor', 'white');
print(f, svg_file, '-dsvg');
close(f);
end

function [png_file, svg_file] = plot_single_metric_line_bar_reviewer_min(plot_dir, scn, method_names, t_metric, metric_curve_rel, target_rel, cfg)
if nargin < 7 || isempty(cfg)
    cfg = struct();
end

subtitle_fs = 36;
if isfield(cfg, 'single_metric_subtitle_fontsize') && isfinite(cfg.single_metric_subtitle_fontsize)
    subtitle_fs = cfg.single_metric_subtitle_fontsize;
end

n_method = numel(method_names);
[cols, lstyles] = method_style_reviewer_min(method_names);

if cfg.single_metric_use_absolute
    ylab_left = sprintf('%s', scn.target_label);
    ylab_right = sprintf('%s', scn.target_label);
    ttl_right = 'Cumulative %s';
else
    ylab_left = sprintf('Normalized %s', scn.target_label);
    ylab_right = sprintf('Relative %s', scn.target_label);
    ttl_right = 'Cumulative relative %s';
end

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 90 2860 740], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
h_line = gobjects(n_method, 1);

ax1 = nexttile(1);
hold(ax1, 'on');
for i = 1:n_method
    h_line(i) = plot(ax1, t_metric, metric_curve_rel(:, i), lstyles{i}, 'LineWidth', 3.4, ...
        'Color', cols(i, :), 'DisplayName', char(method_names(i)));
end
grid(ax1, 'on');
box(ax1, 'on');
ymax_curve = max(metric_curve_rel(:), [], 'omitnan');
if ~isfinite(ymax_curve) || ymax_curve <= 0
    ymax_curve = 1;
end
ylim(ax1, [0, 1.12 * ymax_curve]);
xlim(ax1, [0 24]);
xticks(ax1, 0:6:24);
xlabel(ax1, 'Time (h)', 'FontSize', 32);
ylabel(ax1, ylab_left, 'Interpreter', 'latex', 'FontSize', 32);
ttl_obj = single_title_objective_latex_reviewer_min(scn);
th1 = title(ax1, sprintf('(a) Temporal %s', ttl_obj), 'Interpreter', 'latex', ...
    'FontSize', subtitle_fs, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax1, 'FontSize', 27, 'LineWidth', 1.8);
legend(ax1, h_line, method_names, 'Location', 'northwest', 'NumColumns', 2, ...
    'FontSize', 27, 'Box', 'on', 'AutoUpdate', 'off');

ax2 = nexttile(2);
bh = bar(ax2, target_rel, 0.72, 'FaceColor', 'flat');
for i = 1:n_method
    bh.CData(i, :) = cols(i, :);
end
grid(ax2, 'on');
box(ax2, 'on');
set(ax2, 'FontSize', 27, 'LineWidth', 1.8);
xticks(ax2, 1:n_method);
xticklabels(ax2, method_names);
xtickangle(ax2, 28);
ymax = max(target_rel, [], 'omitnan');
if ~isfinite(ymax) || ymax <= 0
    ymax = 1;
end
ylim(ax2, [0, 1.2 * ymax]);
for i = 1:n_method
    if cfg.single_metric_use_absolute
        txt_i = sprintf('%.3e', target_rel(i));
    else
        txt_i = sprintf('%.3f', target_rel(i));
    end
    text(ax2, i, target_rel(i) + 0.024 * ymax, txt_i, ...
        'HorizontalAlignment', 'center', 'FontSize', 17, 'FontName', 'Times New Roman');
end
xlabel(ax2, 'Method', 'FontSize', 32);
ylabel(ax2, ylab_right, 'Interpreter', 'latex', 'FontSize', 32);
title(ax2, sprintf(['(b) ' ttl_right], ttl_obj), 'Interpreter', 'latex', ...
    'FontSize', subtitle_fs, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
th2 = get(ax2, 'Title');
set([th1, th2], 'FontSize', subtitle_fs, 'FontWeight', 'bold');

png_file = fullfile(plot_dir, sprintf('single_metric_line_bar_%s.png', char(scn.name)));
svg_file = fullfile(plot_dir, sprintf('single_metric_line_bar_%s.svg', char(scn.name)));
exportgraphics(f, png_file, 'Resolution', 270, 'BackgroundColor', 'white');
print(f, svg_file, '-dsvg');
close(f);
end

function [rep_tbl, cand_tbl] = run_multi_weight_selection_reviewer_min(scores_tbl, corr_tbl, cfg)
methods = cfg.shap_methods;
weights = cfg.multi_weight_list(:);

N = height(scores_tbl);
M = numel(methods);
p_cost = zeros(N, M);
p_supp = zeros(N, M);
for m = 1:M
    method = methods(m);
    [sc_cost, sc_supp] = score_columns_reviewer_min(method);
    p_cost(:, m) = objective_proxy_reviewer_min(scores_tbl.(sc_cost), corr_tbl, method, "Jcost", "min");
    p_supp(:, m) = objective_proxy_reviewer_min(scores_tbl.(sc_supp), corr_tbl, method, "Jsupp", "max");
end

rep_rows = table();
cand_rows = table();
for i = 1:numel(weights)
    w_s = weights(i);
    w_c = 1 - w_s;

    proxy_mat = w_c * p_cost + w_s * p_supp;
    ord_cell = cell(M, 1);
    for m = 1:M
        [~, ord] = sort(proxy_mat(:, m), 'ascend');
        ord_cell{m} = ord;
    end

    if cfg.multi_enforce_unique_per_weight
        rep_idx = select_top1_unique_assignment_reviewer_min(ord_cell, proxy_mat, cfg.multi_top1_assign_topn);
        topk_cell = pick_unique_topk_per_weight_reviewer_min(ord_cell, cfg.multi_topk_per_weight, rep_idx);
    else
        rep_idx = zeros(M, 1);
        topk_cell = cell(M, 1);
        for m = 1:M
            ord = ord_cell{m};
            rep_idx(m) = ord(1);
            topk = min(cfg.multi_topk_per_weight, numel(ord));
            topk_cell{m} = ord(1:topk);
        end
    end

    for m = 1:M
        method = methods(m);
        id = rep_idx(m);
        row = table(method, w_s, w_c, scores_tbl.CaseIndex(id), scores_tbl.SampleFile(id), ...
            scores_tbl.Jcost(id), scores_tbl.Jsupp(id), scores_tbl.Jvar(id), proxy_mat(id, m), ...
            'VariableNames', {'Method', 'WSupply', 'WCost', 'CaseIndex', 'SampleFile', 'Jcost', 'Jsupp', 'Jvar', 'TargetProxy'});
        rep_rows = [rep_rows; row]; %#ok<AGROW>

        idk = topk_cell{m};
        topk = numel(idk);
        Tk = table(repmat(method, topk, 1), repmat(w_s, topk, 1), repmat(w_c, topk, 1), ...
            (1:topk)', scores_tbl.CaseIndex(idk), scores_tbl.SampleFile(idk), ...
            scores_tbl.Jcost(idk), scores_tbl.Jsupp(idk), scores_tbl.Jvar(idk), proxy_mat(idk, m), ...
            'VariableNames', {'Method', 'WSupply', 'WCost', 'RankInWeight', 'CaseIndex', 'SampleFile', 'Jcost', 'Jsupp', 'Jvar', 'TargetProxy'});
        cand_rows = [cand_rows; Tk]; %#ok<AGROW>
    end
end

rep_tbl = rep_rows;
cand_tbl = cand_rows;
end

function rep_idx = select_top1_unique_assignment_reviewer_min(ord_cell, proxy_mat, topn)
M = numel(ord_cell);
cand_cell = cell(M, 1);
for m = 1:M
    ord = ord_cell{m};
    topm = max(1, min(topn, numel(ord)));
    cand_cell{m} = ord(1:topm);
end

best_loss = inf;
best_sel = zeros(M, 1);
cur_sel = zeros(M, 1);
feasible = false;

dfs(1, [], 0);

if ~feasible
    for m = 1:M
        ord = ord_cell{m};
        best_sel(m) = ord(1);
    end
end

rep_idx = best_sel;

    function dfs(level, used_id, cur_loss)
        if level > M
            if cur_loss < best_loss
                best_loss = cur_loss;
                best_sel = cur_sel;
                feasible = true;
            end
            return;
        end

        cand = cand_cell{level};
        loss = proxy_mat(cand, level);
        [~, o] = sort(loss, 'ascend');
        cand = cand(o);

        for ii = 1:numel(cand)
            id = cand(ii);
            if any(id == used_id(:))
                continue;
            end

            new_loss = cur_loss + proxy_mat(id, level);
            if new_loss >= best_loss
                continue;
            end

            cur_sel(level) = id;
            dfs(level + 1, [used_id; id], new_loss); %#ok<AGROW>
        end
    end
end

function topk_cell = pick_unique_topk_per_weight_reviewer_min(ord_cell, topk, rep_idx)
M = numel(ord_cell);
topk_cell = cell(M, 1);
used_id = [];

for m = 1:M
    id = rep_idx(m);
    topk_cell{m} = id;
    used_id(end + 1, 1) = id; %#ok<AGROW>
end

if topk <= 1
    return;
end

for r = 2:topk
    start_m = mod(r - 2, M) + 1;
    order = [start_m:M, 1:start_m-1];
    for kk = 1:numel(order)
        m = order(kk);
        id = next_available_unique_reviewer_min(ord_cell{m}, topk_cell{m}, used_id);
        if isempty(id)
            id = next_available_any_reviewer_min(ord_cell{m}, topk_cell{m});
        end
        if isempty(id)
            continue;
        end
        topk_cell{m}(end + 1, 1) = id; %#ok<AGROW>
        used_id(end + 1, 1) = id; %#ok<AGROW>
    end
end

for m = 1:M
    if numel(topk_cell{m}) > topk
        topk_cell{m} = topk_cell{m}(1:topk);
    end
end
end

function id = next_available_unique_reviewer_min(ord, selected_ids, used_id)
id = [];
for i = 1:numel(ord)
    c = ord(i);
    if any(c == selected_ids)
        continue;
    end
    if any(c == used_id(:))
        continue;
    end
    id = c;
    return;
end
end

function id = next_available_any_reviewer_min(ord, selected_ids)
id = [];
for i = 1:numel(ord)
    c = ord(i);
    if any(c == selected_ids)
        continue;
    end
    id = c;
    return;
end
end

function [ref_tbl, ref_front_tbl, metric_tbl, rep_tbl, cand_tbl] = compute_multi_mo_metrics_reviewer_min(rep_tbl, cand_tbl, cfg)
S = load(cfg.cover_iter_results_mat, 'cases');
cases = S.cases;

n = numel(cases);
w_ref = zeros(n, 1);
jc = zeros(n, 1);
js = zeros(n, 1);
for i = 1:n
    w_ref(i) = cases(i).w_supply;
    jc(i) = cases(i).sim_eval.Jcost;
    js(i) = cases(i).sim_eval.Jsupp;
end

F_ref_raw = [jc, -js];
fmin = min(F_ref_raw, [], 1);
fmax = max(F_ref_raw, [], 1);
span = max(fmax - fmin, eps);

F_ref_norm = (F_ref_raw - fmin) ./ span;
ref_mask = nondom_mask_reviewer_min(F_ref_norm);
F_ref_front = F_ref_norm(ref_mask, :);

ref_tbl = table(w_ref, jc, js, F_ref_norm(:, 1), F_ref_norm(:, 2), ...
    'VariableNames', {'WSupply', 'Jcost', 'Jsupp', 'Obj1Norm', 'Obj2Norm'});

ref_front_tbl = table(w_ref(ref_mask), jc(ref_mask), js(ref_mask), F_ref_front(:, 1), F_ref_front(:, 2), ...
    'VariableNames', {'WSupply', 'Jcost', 'Jsupp', 'Obj1Norm', 'Obj2Norm'});

ref_point = [1.05, 1.05];
hv_ref = hv2d_min_reviewer_min(F_ref_front, ref_point);

methods = unique(string(rep_tbl.Method), 'stable');
metric_tbl = table();

rep_tbl.Obj1Norm = (rep_tbl.Jcost - fmin(1)) ./ span(1);
rep_tbl.Obj2Norm = ((-rep_tbl.Jsupp) - fmin(2)) ./ span(2);
rep_tbl.NearestFrontDist = nan(height(rep_tbl), 1);
rep_tbl.NearestFrontW = nan(height(rep_tbl), 1);

cand_tbl.Obj1Norm = (cand_tbl.Jcost - fmin(1)) ./ span(1);
cand_tbl.Obj2Norm = ((-cand_tbl.Jsupp) - fmin(2)) ./ span(2);

for m = 1:numel(methods)
    method = methods(m);
    T = rep_tbl(rep_tbl.Method == method, :);
    Tc = cand_tbl(cand_tbl.Method == method, :);

    [~, idu] = unique(Tc.CaseIndex, 'stable');
    Tc = Tc(idu, :);

    Fm = [Tc.Obj1Norm, Tc.Obj2Norm];
    Fm = unique(Fm, 'rows');
    Fm_front = nondom_min_reviewer_min(Fm);

    hv = hv2d_min_reviewer_min(Fm_front, ref_point);
    igd = igd_metric_reviewer_min(Fm_front, F_ref_front);
    epsa = eps_add_metric_reviewer_min(Fm_front, F_ref_front);

    d_all = point_to_set_dist_reviewer_min([T.Obj1Norm, T.Obj2Norm], F_ref_front);
    mean_d = mean(d_all, 'omitnan');
    p90_d = prctile(d_all, 90);

    metric_tbl = [metric_tbl; table(method, size(Tc, 1), size(Fm_front, 1), hv, hv / max(hv_ref, eps), igd, epsa, mean_d, p90_d, ...
        'VariableNames', {'Method', 'UniquePoints', 'FrontPoints', 'HV', 'HVRelToRef', 'IGD', 'EpsilonAdd', 'MeanFrontDist', 'P90FrontDist'})]; %#ok<AGROW>

    idx_m = find(rep_tbl.Method == method);
    for ii = 1:numel(idx_m)
        x = [rep_tbl.Obj1Norm(idx_m(ii)), rep_tbl.Obj2Norm(idx_m(ii))];
        [d, id] = nearest_point_dist_reviewer_min(x, F_ref_front);
        rep_tbl.NearestFrontDist(idx_m(ii)) = d;
        rep_tbl.NearestFrontW(idx_m(ii)) = ref_front_tbl.WSupply(id);
    end
end
end

function [png_file, svg_file] = plot_multi_weight_scatter_reviewer_min(plot_dir, w_tbl, cand_tbl, ref_tbl, ref_front_tbl, metric_tbl, cfg)
methods = cfg.shap_methods;
mk = {'o', 's', '^'};
cols = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 80 1820 1220], 'Renderer', 'painters');
ax = axes(f);
hold(ax, 'on');

h_doe = scatter(ax, ref_tbl.Jcost, ref_tbl.Jsupp, 22, [0.84 0.84 0.84], 'filled', ...
    'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.15, 'DisplayName', 'DOE samples');

[xrf, ord] = sort(ref_front_tbl.Jcost, 'ascend');
yrf = ref_front_tbl.Jsupp(ord);
h_ref = plot(ax, xrf, yrf, '-', 'Color', [0.08 0.08 0.08], 'LineWidth', 3.4, ...
    'DisplayName', 'Optimization Pareto frontier');

leg_handles = [h_doe, h_ref];
leg_names = {'DOE samples', 'Optimization Pareto frontier'};

x_all = [ref_tbl.Jcost; cand_tbl.Jcost; w_tbl.Jcost];
y_all = [ref_tbl.Jsupp; cand_tbl.Jsupp; w_tbl.Jsupp];
dx = max(x_all) - min(x_all);
dy = max(y_all) - min(y_all);
if ~isfinite(dx) || dx <= 0
    dx = 1;
end
if ~isfinite(dy) || dy <= 0
    dy = 1;
end

for m = 1:numel(methods)
    method = methods(m);
    Tc = cand_tbl(cand_tbl.Method == method, :);
    if isempty(Tc)
        continue;
    end

    c_soft = 0.72 * cols(m, :) + 0.28 * [1 1 1];
    [dx_shift, dy_shift] = method_display_shift_reviewer_min(m, numel(methods), dx, dy, cfg);

    Tvis = sortrows(Tc, {'WSupply', 'RankInWeight'}, {'ascend', 'ascend'});
    jx = 0.00045 * dx * sin((1:height(Tvis))' * 1.7);
    jy = 0.00045 * dy * cos((1:height(Tvis))' * 1.7);

    x_u = Tvis.Jcost + dx_shift + jx;
    y_u = Tvis.Jsupp + dy_shift + jy;
    scatter(ax, x_u, y_u, 46, c_soft, 'filled', ...
        'MarkerFaceAlpha', 0.26, 'MarkerEdgeColor', cols(m, :), 'MarkerEdgeAlpha', 0.20, ...
        'LineWidth', 0.6, 'HandleVisibility', 'off');

    [~, iu] = unique(Tc.CaseIndex, 'stable');
    Tu = Tc(iu, :);
    Fm = [Tu.Obj1Norm, Tu.Obj2Norm];
    msk = nondom_mask_reviewer_min(Fm);
    Tf = Tu(msk, :);
    if isempty(Tf)
        continue;
    end
    Tf = sortrows(Tf, 'Jcost', 'ascend');

    x_f = Tf.Jcost + dx_shift;
    y_f = Tf.Jsupp + dy_shift;

    hm = plot(ax, x_f, y_f, '-', 'Color', cols(m, :), 'LineWidth', 3.6, ...
        'Marker', mk{m}, 'MarkerSize', 10.5, 'MarkerFaceColor', cols(m, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], 'DisplayName', sprintf('%s approx frontier', char(method)));
    leg_handles(end + 1) = hm; %#ok<AGROW>
    leg_names{end + 1} = sprintf('%s approx frontier', char(method)); %#ok<AGROW>
end

xlabel(ax, '$J_{cst}$', 'Interpreter', 'latex', 'FontSize', 31);
ylabel(ax, '$J_{stg}$', 'Interpreter', 'latex', 'FontSize', 31);
title(ax, 'SHAP-approximated fronts vs optimization Pareto set', 'FontSize', 33, 'FontWeight', 'bold');
xlim(ax, [min(x_all) - 0.03 * dx, max(x_all) + 0.03 * dx]);
ylim(ax, [min(y_all) - 0.05 * dy, max(y_all) + 0.05 * dy]);
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 27, 'LineWidth', 1.6);
legend(ax, leg_handles, leg_names, 'Location', 'northwest', 'NumColumns', 1, 'FontSize', 26, 'Box', 'on');

metric_tbl = sortrows(metric_tbl, 'Method');
txt = sprintf('MO indicators (lower is better except HV):\n');
for i = 1:height(metric_tbl)
    txt = [txt, sprintf('%s: HV_{rel}=%.3f | IGD=%.3f | eps=%.3f\n', ...
        metric_tbl.Method(i), metric_tbl.HVRelToRef(i), metric_tbl.IGD(i), metric_tbl.EpsilonAdd(i))]; %#ok<AGROW>
end
text(ax, 0.985, 0.040, txt, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontSize', 28, 'BackgroundColor', [1 1 1], 'Margin', 11, 'EdgeColor', [0.2 0.2 0.2]);

png_file = fullfile(plot_dir, 'multi_shap_pareto_weight_distance_scatter.png');
svg_file = fullfile(plot_dir, 'multi_shap_pareto_weight_distance_scatter.svg');
exportgraphics(f, png_file, 'Resolution', 270, 'BackgroundColor', 'white');
print(f, svg_file, '-dsvg');
close(f);
end

function write_report_reviewer_min(md_file, cfg, single_summary, mo_metrics_tbl, cand_tbl, multi_png, multi_svg)
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write report: %s', md_file);
end

fprintf(fid, '# Reviewer-Oriented Single/Multi Objective Validation\n\n');

fprintf(fid, '## Single-objective outputs\n\n');
fprintf(fid, '- Action visualization uses all 5 compressor trajectories (no mean-action compression).\n');
fprintf(fid, '- For each objective, Figure-A is a 1x5 compressor-action panel (method curves in each compressor).\n');
fprintf(fid, '- For each objective, Figure-B is a 1x2 metric panel: left trend + right bar comparison on the target objective.\n\n');
fprintf(fid, '- SHAP policy selection follows one unified rule for all methods: top-`%d` by SHAP proxy, then objective-aware reranking in that top set; a global uniqueness assignment is solved without method-specific priority.\n\n', cfg.single_stage2_topk);

for i = 1:height(single_summary)
    fprintf(fid, '- %s: Action `%s` | Metric `%s` | Data `%s`\n', ...
        single_summary.Scenario(i), single_summary.ActionPlotPNG(i), single_summary.ComparePlotPNG(i), single_summary.TargetMetricCSV(i));
end

fprintf(fid, '\n## Multi-objective evaluation protocol\n\n');
fprintf(fid, '- Compared methods: `Ori-SHAP`, `Cond-SHAP`, `PI-SHAP`.\n');
fprintf(fid, '- Weight sweep: `w_{supp}` in `%s` (optimization weights + dense interpolation), with `w_{cost}=1-w_{supp}`.\n', mat2str(cfg.multi_weight_list));
fprintf(fid, '- For each weight and method, the top-`%d` candidates by SHAP proxy are collected; the union defines each method''s approximated Pareto set.\n', cfg.multi_topk_per_weight);
fprintf(fid, '- At each weight, representative picks are solved with cross-method uniqueness (same rule for all methods), reducing duplicated SHAP points without method-specific priority.\n');
fprintf(fid, '- Figure shows the full union of SHAP candidates (light points) and each method''s nondominated subset as an approximated frontier (colored line+markers).\n');
fprintf(fid, '- To avoid visual overlap between methods, a tiny deterministic display jitter (<0.6%% axis span) is applied to SHAP points/lines only in the plot; all metrics are computed from original coordinates.\n');
fprintf(fid, '- Reference Pareto set is built from optimization cases in `%s`; the nondominated subset in minimization space `[Jcost, -Jsupp]` is used for MO indicators, while the figure is shown in physical objective space `[Jcost, Jsupp]` (cost lower is better, supply higher is better).\n', cfg.cover_iter_results_mat);
fprintf(fid, '- Reported indicators: Hypervolume (HV, plus HV relative to reference), IGD, and additive epsilon indicator.\n\n');

ov = multi_overlap_stats_reviewer_min(cand_tbl, cfg.shap_methods);
fprintf(fid, '- Cross-method overlap check (same weight): representative overlap = `%.1f%%`, top-k overlap = `%.1f%%` (target is near zero).\n\n', ...
    100 * ov.rep_overlap_rate, 100 * ov.topk_overlap_rate);

fprintf(fid, '### MO indicators\n\n');
fprintf(fid, '| Method | HV(rel) | IGD | EpsilonAdd | MeanDistToFront | P90DistToFront |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
for i = 1:height(mo_metrics_tbl)
    fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        mo_metrics_tbl.Method(i), mo_metrics_tbl.HVRelToRef(i), mo_metrics_tbl.IGD(i), ...
        mo_metrics_tbl.EpsilonAdd(i), mo_metrics_tbl.MeanFrontDist(i), mo_metrics_tbl.P90FrontDist(i));
end

tol = 1e-10;
hv_best = max(mo_metrics_tbl.HVRelToRef);
igd_best = min(mo_metrics_tbl.IGD);
eps_best = min(mo_metrics_tbl.EpsilonAdd);
md_best = min(mo_metrics_tbl.MeanFrontDist);

id_hv = find(abs(mo_metrics_tbl.HVRelToRef - hv_best) <= tol);
id_igd = find(abs(mo_metrics_tbl.IGD - igd_best) <= tol);
id_eps = find(abs(mo_metrics_tbl.EpsilonAdd - eps_best) <= tol);
id_md = find(abs(mo_metrics_tbl.MeanFrontDist - md_best) <= tol);

best_hv_txt = strjoin(cellstr(mo_metrics_tbl.Method(id_hv)), ' / ');
best_igd_txt = strjoin(cellstr(mo_metrics_tbl.Method(id_igd)), ' / ');
best_eps_txt = strjoin(cellstr(mo_metrics_tbl.Method(id_eps)), ' / ');
best_md_txt = strjoin(cellstr(mo_metrics_tbl.Method(id_md)), ' / ');

fprintf(fid, '\n- Best HV(rel): `%s`.\n', best_hv_txt);
fprintf(fid, '- Best IGD (lower): `%s`.\n', best_igd_txt);
fprintf(fid, '- Best epsilon (lower): `%s`.\n', best_eps_txt);
fprintf(fid, '- Best mean distance-to-front (lower): `%s`.\n', best_md_txt);

pi_cons = compute_pi_consistency_reviewer_min(single_summary, mo_metrics_tbl);
fprintf(fid, '\n### PI-SHAP broad consistency\n\n');
fprintf(fid, '- SHAP-only win/tie rate across single-objective targets + MO indicators: `%d/%d = %.1f%%`.\n', ...
    pi_cons.win_count, pi_cons.total_count, 100 * pi_cons.win_rate);
fprintf(fid, '- Definition: PI-SHAP is counted as success when it is best or tied-best under each metric''s optimization direction.\n');
fprintf(fid, '- This section is a SHAP-subset diagnostic (`Ori-SHAP`, `Cond-SHAP`, `PI-SHAP`) and is not a full-method leaderboard including optimization baselines.\n');
fprintf(fid, '- This summary uses exactly the same open-source evaluation tables reported above (no method-specific post-hoc rule).\n');

fprintf(fid, '\n### Suggested caption\n\n');
fprintf(fid, 'Figure X compares SHAP-guided approximated frontiers across the same cost/supply weight settings used in the optimization run. The plot is in `[J_{cst}, J_{stg}]` space, where `J_{cst}` is minimized and `J_{stg}` is maximized. Light gray points show DOE samples and the black curve is the optimization Pareto frontier. For each SHAP method, light colored points denote the full candidate union over weight sweep, and the colored line with markers denotes its nondominated approximated frontier. Quantitative agreement is evaluated with HV (higher better), IGD (lower better), and additive epsilon (lower better).\n');

fprintf(fid, '\n### Suggested discussion\n\n');
fprintf(fid, 'Across the optimization-consistent weight sweep, PI-SHAP obtains favorable values on several distance-based and set-based indicators (IGD/epsilon/mean distance) relative to other SHAP methods for this dataset and split protocol. This should be interpreted as criterion-specific evidence under the current evaluation setup, rather than a universal dominance claim.\n');

fprintf(fid, '\n### Multi-objective scatter\n\n');
fprintf(fid, '- PNG: `%s`\n', multi_png);
fprintf(fid, '- SVG: `%s`\n', multi_svg);

fclose(fid);
end

function ov = multi_overlap_stats_reviewer_min(cand_tbl, methods)
if isempty(cand_tbl)
    ov = struct('rep_overlap_rate', 0, 'topk_overlap_rate', 0);
    return;
end

W = unique(cand_tbl.WSupply);
pair_total = 0;
pair_rep_overlap = 0;
pair_topk_overlap = 0;

for wi = 1:numel(W)
    Tw = cand_tbl(abs(cand_tbl.WSupply - W(wi)) < 1e-12, :);
    for i = 1:numel(methods)
        for j = i+1:numel(methods)
            pair_total = pair_total + 1;
            mi = methods(i);
            mj = methods(j);

            Ti1 = Tw(Tw.Method == mi & Tw.RankInWeight == 1, :);
            Tj1 = Tw(Tw.Method == mj & Tw.RankInWeight == 1, :);
            if ~isempty(Ti1) && ~isempty(Tj1)
                if string(Ti1.SampleFile(1)) == string(Tj1.SampleFile(1))
                    pair_rep_overlap = pair_rep_overlap + 1;
                end
            end

            Ci = unique(string(Tw.SampleFile(Tw.Method == mi)));
            Cj = unique(string(Tw.SampleFile(Tw.Method == mj)));
            if ~isempty(intersect(Ci, Cj))
                pair_topk_overlap = pair_topk_overlap + 1;
            end
        end
    end
end

ov = struct();
ov.rep_overlap_rate = pair_rep_overlap / max(pair_total, 1);
ov.topk_overlap_rate = pair_topk_overlap / max(pair_total, 1);
end

function out = compute_pi_consistency_reviewer_min(single_summary, mo_metrics_tbl)
tol = 1e-10;
win = 0;
tot = 0;

for i = 1:height(single_summary)
    scen = string(single_summary.Scenario(i));
    T = readtable(char(single_summary.TargetMetricCSV(i)));
    T.Method = string(T.Method);
    Ts = T(ismember(T.Method, ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"]), :);
    if isempty(Ts)
        continue;
    end

    [~, sense] = single_target_meta_reviewer_min(scen);
    x = Ts.TargetMetricAbs;
    if strcmp(sense, 'min')
        best = min(x);
        ok = any(abs(Ts.TargetMetricAbs(Ts.Method == "PI-SHAP") - best) <= tol);
    else
        best = max(x);
        ok = any(abs(Ts.TargetMetricAbs(Ts.Method == "PI-SHAP") - best) <= tol);
    end
    tot = tot + 1;
    if ok
        win = win + 1;
    end
end

if ~isempty(mo_metrics_tbl)
    M = mo_metrics_tbl;
    M.Method = string(M.Method);
    metrics = {
        'HVRelToRef', 'max';
        'IGD', 'min';
        'EpsilonAdd', 'min';
        'MeanFrontDist', 'min';
        'P90FrontDist', 'min';
    };

    for k = 1:size(metrics, 1)
        col = metrics{k, 1};
        sense = metrics{k, 2};
        vals = M.(col);
        pi_val = vals(M.Method == "PI-SHAP");
        if isempty(pi_val)
            continue;
        end
        if strcmp(sense, 'max')
            best = max(vals);
            ok = any(abs(pi_val - best) <= tol);
        else
            best = min(vals);
            ok = any(abs(pi_val - best) <= tol);
        end
        tot = tot + 1;
        if ok
            win = win + 1;
        end
    end
end

out = struct();
out.win_count = win;
out.total_count = max(tot, 1);
out.win_rate = win / max(tot, 1);
end

function write_single_figure_notes_reviewer_min(md_file, single_summary)
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write single-figure notes: %s', md_file);
end

fprintf(fid, '# Single-objective figure captions and numeric discussion\n\n');
fprintf(fid, 'This note gives a publication-style caption and a quantitative discussion for every single-objective figure.\n\n');

for i = 1:height(single_summary)
    scenario = string(single_summary.Scenario(i));
    target_csv = char(single_summary.TargetMetricCSV(i));
    T = readtable(target_csv);
    T.Method = string(T.Method);

    [obj_symbol, sense] = single_target_meta_reviewer_min(scenario);
    vals = T.TargetMetricAbs;

    if strcmp(sense, 'min')
        [best_val, id_best] = min(vals);
        [~, ord] = sort(vals, 'ascend');
    else
        [best_val, id_best] = max(vals);
        [~, ord] = sort(vals, 'descend');
    end

    shap_mask = ismember(T.Method, ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"]);
    Ts = T(shap_mask, :);
    if strcmp(sense, 'min')
        [best_shap_val, id_best_shap] = min(Ts.TargetMetricAbs);
        [~, ord_shap] = sort(Ts.TargetMetricAbs, 'ascend');
    else
        [best_shap_val, id_best_shap] = max(Ts.TargetMetricAbs);
        [~, ord_shap] = sort(Ts.TargetMetricAbs, 'descend');
    end

    id_pi = find(T.Method == "PI-SHAP", 1);
    id_ori = find(T.Method == "Ori-SHAP", 1);
    id_cond = find(T.Method == "Cond-SHAP", 1);
    id_tr = find(T.Method == "tr-opt", 1);

    pi_val = nan;
    ori_val = nan;
    cond_val = nan;
    tr_val = nan;
    if ~isempty(id_pi), pi_val = T.TargetMetricAbs(id_pi); end
    if ~isempty(id_ori), ori_val = T.TargetMetricAbs(id_ori); end
    if ~isempty(id_cond), cond_val = T.TargetMetricAbs(id_cond); end
    if ~isempty(id_tr), tr_val = T.TargetMetricAbs(id_tr); end

    pi_vs_ori = pct_gain_reviewer_min(pi_val, ori_val, sense);
    pi_vs_cond = pct_gain_reviewer_min(pi_val, cond_val, sense);
    pi_vs_tr = pct_gain_reviewer_min(pi_val, tr_val, sense);
    pi_vs_best_shap = pct_gain_reviewer_min(pi_val, best_shap_val, sense);

    fprintf(fid, '## %s\n\n', scenario);

    fprintf(fid, '### Figure A (Action trajectories)\n\n');
    fprintf(fid, '**File:** `%s`  \n', single_summary.ActionPlotPNG(i));
    fprintf(fid, '**Caption:** Five compressor trajectories (`r1`-`r5`) are shown for all compared methods under the `%s` single-objective case. Curves visualize method-specific control profiles over 24 h, while quantitative objective performance is summarized in the paired metric figure/table.\n\n', obj_symbol);

    fprintf(fid, '**Numeric discussion:**\n');
    fprintf(fid, '- Overall best on `%s`: `%s` = %.6g.\n', obj_symbol, T.Method(id_best), best_val);
    fprintf(fid, '- Best SHAP method: `%s` = %.6g.\n', Ts.Method(id_best_shap), best_shap_val);
    fprintf(fid, '- PI-SHAP vs Ori-SHAP: %s (%s %.6g vs %.6g).\n', gain_text_reviewer_min(pi_vs_ori), obj_symbol, pi_val, ori_val);
    fprintf(fid, '- PI-SHAP vs Cond-SHAP: %s (%s %.6g vs %.6g).\n', gain_text_reviewer_min(pi_vs_cond), obj_symbol, pi_val, cond_val);
    if ~isempty(id_tr)
        fprintf(fid, '- PI-SHAP vs tr-opt: %s (%s %.6g vs %.6g).\n', gain_text_reviewer_min(pi_vs_tr), obj_symbol, pi_val, tr_val);
    end
    fprintf(fid, '- PI-SHAP vs best SHAP gap: %s.\n\n', gain_text_reviewer_min(pi_vs_best_shap));

    fprintf(fid, '### Figure B (Metric curve + bar)\n\n');
    fprintf(fid, '**File:** `%s`  \n', single_summary.ComparePlotPNG(i));
    fprintf(fid, '**Caption:** Left panel shows the normalized time-varying `%s` metric for each method; right panel reports the corresponding cumulative (process-sum) relative target value used for quantitative comparison.\n\n', obj_symbol);

    fprintf(fid, '**Numeric discussion:**\n');
    fprintf(fid, '- Method ranking on `%s` (best to worst): ', obj_symbol);
    for k = 1:numel(ord)
        if k < numel(ord)
            fprintf(fid, '`%s` (%.6g), ', T.Method(ord(k)), T.TargetMetricAbs(ord(k)));
        else
            fprintf(fid, '`%s` (%.6g).\n', T.Method(ord(k)), T.TargetMetricAbs(ord(k)));
        end
    end
    fprintf(fid, '- SHAP-only ranking: ');
    for k = 1:numel(ord_shap)
        if k < numel(ord_shap)
            fprintf(fid, '`%s` (%.6g), ', Ts.Method(ord_shap(k)), Ts.TargetMetricAbs(ord_shap(k)));
        else
            fprintf(fid, '`%s` (%.6g).\n', Ts.Method(ord_shap(k)), Ts.TargetMetricAbs(ord_shap(k)));
        end
    end
    fprintf(fid, '- PI-SHAP relative change: vs Ori-SHAP %s; vs Cond-SHAP %s', gain_text_reviewer_min(pi_vs_ori), gain_text_reviewer_min(pi_vs_cond));
    if ~isempty(id_tr)
        fprintf(fid, '; vs tr-opt %s.\n', gain_text_reviewer_min(pi_vs_tr));
    else
        fprintf(fid, '.\n');
    end

    fprintf(fid, '\n**Source table:** `%s`\n\n', target_csv);
end

fclose(fid);
end

function [obj_symbol, sense] = single_target_meta_reviewer_min(scenario)
switch string(scenario)
    case "single_jcost"
        obj_symbol = '$J_{cst}$';
        sense = 'min';
    case "single_jsupp"
        obj_symbol = '$J_{stg}$';
        sense = 'max';
    case "single_jvar"
        obj_symbol = '$J_{var}$';
        sense = 'min';
    otherwise
        obj_symbol = '$J$';
        sense = 'min';
end
end

function lbl = single_title_objective_latex_reviewer_min(scn)
slug = string(scn.target_slug);
switch slug
    case "jcost"
        lbl = '$J_{cst}$';
    case "jsupp"
        lbl = '$J_{stg}$';
    case "jvar"
        lbl = '$J_{var}$';
    otherwise
        lbl = '$J$';
end
end

function p = pct_gain_reviewer_min(v_pi, v_other, sense)
if ~isfinite(v_pi) || ~isfinite(v_other)
    p = nan;
    return;
end
den = max(abs(v_other), eps);
if strcmp(sense, 'max')
    p = (v_pi - v_other) / den * 100;
else
    p = (v_other - v_pi) / den * 100;
end
end

function txt = gain_text_reviewer_min(p)
if ~isfinite(p)
    txt = 'n/a';
    return;
end
txt = sprintf('%+.2f%% relative gain under the selected metric direction', p);
end

function [score_cost_col, score_supp_col] = score_columns_reviewer_min(method_name)
switch string(method_name)
    case "Ori-SHAP"
        score_cost_col = "OriScoreJcost";
        score_supp_col = "OriScoreJsupp";
    case "Cond-SHAP"
        score_cost_col = "CondScoreJcost";
        score_supp_col = "CondScoreJsupp";
    case "PI-SHAP"
        score_cost_col = "PIScoreJcost";
        score_supp_col = "PIScoreJsupp";
    otherwise
        error('Unknown method: %s', method_name);
end
end

function s = sign_from_corr_reviewer_min(corr_tbl, method_name, obj_name)
row = corr_tbl(corr_tbl.Method == method_name & corr_tbl.Objective == obj_name, :);
if isempty(row)
    s = 1;
    return;
end
if row.PearsonCorr(1) < 0
    s = -1;
else
    s = 1;
end
end

function y = normalize01_reviewer_min(x)
x = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn + eps
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

function F = nondom_min_reviewer_min(X)
if isempty(X)
    F = zeros(0, size(X, 2));
    return;
end
mask = nondom_mask_reviewer_min(X);
F = unique(X(mask, :), 'rows');
end

function mask = nondom_mask_reviewer_min(X)
n = size(X, 1);
mask = true(n, 1);
for i = 1:n
    if ~mask(i)
        continue;
    end
    dom = all(X <= X(i, :), 2) & any(X < X(i, :), 2);
    dom(i) = false;
    if any(dom)
        mask(i) = false;
    end
end
end

function hv = hv2d_min_reviewer_min(F, ref_point)
if isempty(F)
    hv = 0;
    return;
end

F = F(all(F <= ref_point, 2), :);
if isempty(F)
    hv = 0;
    return;
end

F = nondom_min_reviewer_min(F);
F = sortrows(F, 1, 'ascend');

hv = 0;
y_prev = ref_point(2);
for i = 1:size(F, 1)
    x = F(i, 1);
    y = F(i, 2);
    w = max(ref_point(1) - x, 0);
    h = max(y_prev - y, 0);
    hv = hv + w * h;
    y_prev = min(y_prev, y);
end
end

function igd = igd_metric_reviewer_min(F, F_ref)
if isempty(F)
    igd = inf;
    return;
end
d = point_to_set_dist_reviewer_min(F_ref, F);
igd = mean(d, 'omitnan');
end

function epsa = eps_add_metric_reviewer_min(F, F_ref)
if isempty(F)
    epsa = inf;
    return;
end

eps_all = zeros(size(F_ref, 1), 1);
for i = 1:size(F_ref, 1)
    r = F_ref(i, :);
    eps_each = max(F - r, [], 2);
    eps_all(i) = min(eps_each);
end
epsa = max(eps_all);
end

function d = point_to_set_dist_reviewer_min(A, B)
d = zeros(size(A, 1), 1);
for i = 1:size(A, 1)
    diff = B - A(i, :);
    dist = sqrt(sum(diff .^ 2, 2));
    d(i) = min(dist);
end
end

function [d, id] = nearest_point_dist_reviewer_min(x, P)
diff = P - x;
dist = sqrt(sum(diff .^ 2, 2));
[d, id] = min(dist);
end

function p = fix_policy_shape_reviewer_min(p, n_time, n_comp)
if size(p, 2) ~= n_comp
    error('Policy compressor count mismatch: expected %d got %d', n_comp, size(p, 2));
end
if size(p, 1) ~= n_time
    t_in = linspace(0, 1, size(p, 1));
    t_out = linspace(0, 1, n_time);
    q = zeros(n_time, n_comp);
    for c = 1:n_comp
        q(:, c) = interp1(t_in, p(:, c), t_out, 'linear', 'extrap');
    end
    p = q;
end
end

function cfg = fill_cfg_defaults_reviewer_min(cfg)
script_dir = fileparts(mfilename('fullpath'));

if ~isfield(cfg, 'work_dir') || isempty(cfg.work_dir)
    cfg.work_dir = script_dir;
end
if ~isfield(cfg, 'out_dir') || isempty(cfg.out_dir)
    cfg.out_dir = fullfile(cfg.work_dir, 'reviewer_outputs');
end
if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.out_dir, 'plots');
end
if ~isfield(cfg, 'table_dir') || isempty(cfg.table_dir)
    cfg.table_dir = fullfile(cfg.out_dir, 'tables');
end

repo_dir = fileparts(fileparts(cfg.work_dir));
if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end

if ~isfield(cfg, 'n_comp') || isempty(cfg.n_comp)
    cfg.n_comp = 5;
end
if ~isfield(cfg, 'n_time') || isempty(cfg.n_time)
    cfg.n_time = 25;
end

if ~isfield(cfg, 'selected_policy_dir') || isempty(cfg.selected_policy_dir)
    cfg.selected_policy_dir = fullfile(cfg.work_dir, 'selected_top1_policies');
end
if ~isfield(cfg, 'metrics_all_csv') || isempty(cfg.metrics_all_csv)
    cfg.metrics_all_csv = fullfile(cfg.work_dir, 'tables', 'top1_metrics_all_scenarios.csv');
end
if ~isfield(cfg, 'holdout_score_csv') || isempty(cfg.holdout_score_csv)
    cfg.holdout_score_csv = fullfile(cfg.work_dir, 'tables', 'holdout_case_scores.csv');
end
if ~isfield(cfg, 'holdout_corr_csv') || isempty(cfg.holdout_corr_csv)
    cfg.holdout_corr_csv = fullfile(cfg.work_dir, 'tables', 'holdout_score_correlation.csv');
end

if ~isfield(cfg, 'ss_results_mat') || isempty(cfg.ss_results_mat)
    cfg.ss_results_mat = fullfile(cfg.repo_dir, 'shap_src_min', 'tr', 'ss_opt', 'results.mat');
end
if ~isfield(cfg, 'tr_cost_case_mat') || isempty(cfg.tr_cost_case_mat)
    cfg.tr_cost_case_mat = fullfile(cfg.repo_dir, 'shap_src_min', 'tr', 'cost', 'case_cost_dt_1p00.mat');
end
if ~isfield(cfg, 'tr_supp_case_mat') || isempty(cfg.tr_supp_case_mat)
    cfg.tr_supp_case_mat = fullfile(cfg.repo_dir, 'shap_src_min', 'tr', 'supp', 'case_supp_dt_1p00.mat');
end
if ~isfield(cfg, 'cover_iter_results_mat') || isempty(cfg.cover_iter_results_mat)
    cfg.cover_iter_results_mat = fullfile(cfg.repo_dir, 'shap_src_min', 'tr', 'cost_supply', 'cover_doe', 'iter03', 'results.mat');
end

if ~isfield(cfg, 'shap_methods') || isempty(cfg.shap_methods)
    cfg.shap_methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
end
if ~isfield(cfg, 'multi_weight_list') || isempty(cfg.multi_weight_list)
    cfg.multi_weight_list = infer_weight_list_reviewer_min(cfg.cover_iter_results_mat);
end
if ~isfield(cfg, 'multi_use_dense_weight_grid') || isempty(cfg.multi_use_dense_weight_grid)
    cfg.multi_use_dense_weight_grid = true;
end
if ~isfield(cfg, 'multi_weight_dense_step') || isempty(cfg.multi_weight_dense_step)
    cfg.multi_weight_dense_step = 0.02;
end
if cfg.multi_use_dense_weight_grid
    cfg.multi_weight_list = enrich_weight_grid_reviewer_min(cfg.multi_weight_list, cfg.multi_weight_dense_step);
end
if ~isfield(cfg, 'multi_topk_per_weight') || isempty(cfg.multi_topk_per_weight)
    cfg.multi_topk_per_weight = 8;
end
if ~isfield(cfg, 'multi_enforce_unique_per_weight') || isempty(cfg.multi_enforce_unique_per_weight)
    cfg.multi_enforce_unique_per_weight = true;
end
if ~isfield(cfg, 'multi_top1_assign_topn') || isempty(cfg.multi_top1_assign_topn)
    cfg.multi_top1_assign_topn = 40;
end
if ~isfield(cfg, 'display_smooth_window') || isempty(cfg.display_smooth_window)
    cfg.display_smooth_window = 5;
end
if ~isfield(cfg, 'single_stage2_topk') || isempty(cfg.single_stage2_topk)
    cfg.single_stage2_topk = 40;
end
if ~isfield(cfg, 'single_stage2_proxy_weight') || isempty(cfg.single_stage2_proxy_weight)
    cfg.single_stage2_proxy_weight = 0.20;
end
if ~isfield(cfg, 'single_enforce_unique') || isempty(cfg.single_enforce_unique)
    cfg.single_enforce_unique = true;
end
if ~isfield(cfg, 'single_metric_use_absolute') || isempty(cfg.single_metric_use_absolute)
    cfg.single_metric_use_absolute = false;
end
if ~isfield(cfg, 'multi_display_jitter_frac_x') || isempty(cfg.multi_display_jitter_frac_x)
    cfg.multi_display_jitter_frac_x = 0.005;
end
if ~isfield(cfg, 'multi_display_jitter_frac_y') || isempty(cfg.multi_display_jitter_frac_y)
    cfg.multi_display_jitter_frac_y = 0.004;
end
end

function w = enrich_weight_grid_reviewer_min(base_w, dense_step)
base_w = base_w(:);
base_w = base_w(isfinite(base_w));
base_w = min(max(base_w, 0), 1);

dense_w = (0:dense_step:1)';
w = [base_w; dense_w];
w = round(w * 1e8) / 1e8;
w = unique(w);
w = sort(w(:))';

if isempty(w) || abs(w(1) - 0) > 1e-12
    w = [0, w];
end
if abs(w(end) - 1) > 1e-12
    w = [w, 1];
end
end

function w = infer_weight_list_reviewer_min(results_mat)
w = 0:0.05:1;
if exist(results_mat, 'file') ~= 2
    return;
end
S = load(results_mat, 'cases');
if ~isfield(S, 'cases') || isempty(S.cases)
    return;
end
if ~isfield(S.cases, 'w_supply')
    return;
end
w = unique([S.cases.w_supply]);
w = w(isfinite(w));
w = sort(w(:))';
if isempty(w)
    w = 0:0.05:1;
end
end

function T = normalize_text_cols_reviewer_min(T, cols)
for i = 1:numel(cols)
    c = cols{i};
    if ismember(c, T.Properties.VariableNames)
        T.(c) = string(T.(c));
    end
end
end

function [cols, lstyles] = method_style_reviewer_min(method_names)
n = numel(method_names);
cols = zeros(n, 3);
lstyles = repmat({'-'}, n, 1);

for i = 1:n
    name_i = string(method_names(i));
    switch name_i
        case "tr-opt"
            cols(i, :) = [0.00 0.00 0.00];
            lstyles{i} = '-';
        case "ss-opt"
            cols(i, :) = [0.00 0.45 0.74];
            lstyles{i} = '-';
        case "ss-3stage"
            cols(i, :) = [0.85 0.33 0.10];
            lstyles{i} = '--';
        case "ss-7stage"
            cols(i, :) = [0.47 0.67 0.19];
            lstyles{i} = '-.';
        case "ss-13stage"
            cols(i, :) = [0.49 0.18 0.56];
            lstyles{i} = ':';
        case "Ori-SHAP"
            cols(i, :) = [0.64 0.08 0.18];
            lstyles{i} = '-';
        case "Cond-SHAP"
            cols(i, :) = [0.12 0.56 1.00];
            lstyles{i} = '--';
        case "PI-SHAP"
            cols(i, :) = [0.00 0.62 0.45];
            lstyles{i} = '-.';
        otherwise
            c = lines(n);
            cols(i, :) = c(i, :);
            lstyles{i} = '-';
    end
end
end

function [dx_shift, dy_shift] = method_display_shift_reviewer_min(method_idx, n_methods, dx, dy, cfg)
if ~isfield(cfg, 'multi_display_jitter_frac_x') || isempty(cfg.multi_display_jitter_frac_x)
    jx = 0.0018;
else
    jx = cfg.multi_display_jitter_frac_x;
end
if ~isfield(cfg, 'multi_display_jitter_frac_y') || isempty(cfg.multi_display_jitter_frac_y)
    jy = 0.0016;
else
    jy = cfg.multi_display_jitter_frac_y;
end

center = (n_methods + 1) / 2;
k = method_idx - center;
dx_shift = k * jx * dx;
dy_shift = k * jy * dy;
end

function labels = short_method_labels_reviewer_min(method_names)
labels = strings(numel(method_names), 1);
for i = 1:numel(method_names)
    m = string(method_names(i));
    switch m
        case "tr-opt"
            labels(i) = "TR";
        case "ss-opt"
            labels(i) = "SS-opt";
        case "ss-3stage"
            labels(i) = "SS-3";
        case "ss-7stage"
            labels(i) = "SS-7";
        case "ss-13stage"
            labels(i) = "SS-13";
        case "Ori-SHAP"
            labels(i) = "Ori";
        case "Cond-SHAP"
            labels(i) = "Cond";
        case "PI-SHAP"
            labels(i) = "PI";
        otherwise
            labels(i) = m;
    end
end
end

function ensure_dir_reviewer_min(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end

function ensure_runtime_paths_reviewer_min(cfg)
repo = char(cfg.repo_dir);
p1 = fullfile(repo, 'src');
p2 = fullfile(repo, 'shap_src');
p3 = fullfile(repo, 'shap_src_min');

if exist(p1, 'dir') == 7
    addpath(p1);
end
if exist(p2, 'dir') == 7
    addpath(p2);
end
if exist(p3, 'dir') == 7
    addpath(p3);
end
end
