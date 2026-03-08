function out = run_seed11_dt1_light_plus_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_min(cfg);
ensure_dir_min(cfg.data_dir);
ensure_dir_min(cfg.model_dir);
ensure_dir_min(cfg.plot_dir);
ensure_dir_min(cfg.report_dir);

if cfg.force_reexport || exist(cfg.dataset_file, 'file') ~= 2
    export_cfg = struct();
    export_cfg.repo_dir = cfg.repo_dir;
    export_cfg.data_dir = cfg.data_dir;
    export_cfg.manifest_csv = cfg.manifest_csv;
    export_cfg.seed = cfg.seed;
    export_cfg.dt_hr = cfg.dt_hr;
    export_cfg.noise_sigma = cfg.noise_sigma;
    export_cfg.noise_repeats = cfg.noise_repeats;
    export_cfg.rng_seed = cfg.rng_seed;
    export_cfg.train_ratio = cfg.train_ratio;
    export_cfg.val_ratio = cfg.val_ratio;
    export_seed11_dt1_dataset_min(export_cfg);
end

S = load(cfg.dataset_file, ...
    'X', 'Y_obj', 'Y_flow', 'Y_curve_cost', 'Y_curve_supp', 'curve_t_hr', ...
    'feature_names', 'target_names_obj', 'target_names_flow', ...
    'train_idx', 'val_idx', 'test_idx', 'meta_tbl');

X = S.X;
Y_obj = S.Y_obj;
Y_flow = S.Y_flow;
Y_scalar = [Y_obj Y_flow];
Y_curve_cost = S.Y_curve_cost;
Y_curve_supp = S.Y_curve_supp;
curve_t_hr = S.curve_t_hr(:);

feature_names = string(S.feature_names(:));
target_names = [string(S.target_names_obj(:)); string(S.target_names_flow(:))];
meta_tbl = S.meta_tbl;

train_idx = S.train_idx(:);
val_idx = S.val_idx(:);
test_idx = S.test_idx(:);

if cfg.use_val_for_training
    train_use = sort([train_idx; val_idx]);
else
    train_use = train_idx;
end

X_train = X(train_use, :);
X_test = X(test_idx, :);
Y_train = Y_scalar(train_use, :);
Y_test = Y_scalar(test_idx, :);

rng(cfg.rng_seed, 'twister');

[scalar_models, scalar_metrics_tbl, Yhat_test] = train_scalar_models_min(X_train, Y_train, X_test, Y_test, target_names, cfg);

[curve_models, curve_metrics_tbl, curve_pred_test] = train_curve_models_min( ...
    X_train, X_test, Y_curve_cost(train_use, :), Y_curve_cost(test_idx, :), ...
    Y_curve_supp(train_use, :), Y_curve_supp(test_idx, :), cfg);

plot_objective_parity_min(cfg.plot_dir, Y_test(:, 1:3), Yhat_test(:, 1:3), target_names(1:3), scalar_metrics_tbl);
plot_flow_parity_min(cfg.plot_dir, Y_test(:, 4:end), Yhat_test(:, 4:end), target_names(4:end), scalar_metrics_tbl);
plot_curve_test_overlay_min(cfg.plot_dir, curve_t_hr, Y_curve_cost(test_idx, :), curve_pred_test.cost, Y_curve_supp(test_idx, :), curve_pred_test.supp);
plot_split_overview_min(cfg.plot_dir, numel(train_idx), numel(val_idx), numel(test_idx));
plot_network_schematic_min(cfg.plot_dir, size(X, 2), cfg.layer_sizes, size(Y_scalar, 2), curve_models);

[shap_map_int, shap_tbl_int] = run_objective_shap_method_min( ...
    scalar_models(1:3), X, train_use, test_idx, feature_names, cfg, "interventional", cfg.shap_num_subsets_interv);
[shap_map_cond, shap_tbl_cond] = run_objective_shap_method_min( ...
    scalar_models(1:3), X, train_use, test_idx, feature_names, cfg, "conditional", cfg.shap_num_subsets_cond);

plot_shap_action_heatmaps_method_min(cfg.plot_dir, shap_map_int, cfg.objective_names, 'interventional');
plot_shap_action_heatmaps_method_min(cfg.plot_dir, shap_map_cond, cfg.objective_names, 'conditional');
plot_shap_method_compare_min(cfg.plot_dir, shap_map_int, shap_map_cond, cfg.objective_names);

shap_tbl_int.Method = repmat("interventional", height(shap_tbl_int), 1);
shap_tbl_cond.Method = repmat("conditional", height(shap_tbl_cond), 1);
shap_compare_tbl = [shap_tbl_int; shap_tbl_cond];
writetable(shap_compare_tbl, fullfile(cfg.report_dir, 'seed11_dt1_light_shap_compare.csv'));

[cases_struct, case_eval_tbl] = evaluate_selected_doe_cases_min( ...
    meta_tbl, X, Y_obj, Y_curve_cost, Y_curve_supp, curve_t_hr, test_idx, scalar_models, curve_models);

plot_selected_case_curves_min(cfg.plot_dir, cases_struct, curve_t_hr);
plot_selected_case_objectives_min(cfg.plot_dir, cases_struct);
writetable(case_eval_tbl, fullfile(cfg.report_dir, 'seed11_dt1_case_eval_doe3.csv'));

writetable(scalar_metrics_tbl, fullfile(cfg.report_dir, 'seed11_dt1_light_metrics.csv'));
writetable(curve_metrics_tbl, fullfile(cfg.report_dir, 'seed11_dt1_light_curve_metrics.csv'));

models_file = fullfile(cfg.model_dir, 'seed11_dt1_light_plus_models.mat');
save(models_file, ...
    'scalar_models', 'curve_models', 'target_names', 'feature_names', ...
    'cfg', 'curve_t_hr', '-v7.3');

report_md = fullfile(cfg.report_dir, 'SEED11_DT1_LIGHT_PLUS_REPORT.md');
write_detailed_report_md_min(report_md, cfg, X, Y_scalar, target_names, ...
    train_idx, val_idx, test_idx, scalar_metrics_tbl, curve_metrics_tbl, case_eval_tbl);

out = struct();
out.models_file = models_file;
out.report_md = report_md;
out.plot_dir = cfg.plot_dir;
out.metrics_scalar = fullfile(cfg.report_dir, 'seed11_dt1_light_metrics.csv');
out.metrics_curve = fullfile(cfg.report_dir, 'seed11_dt1_light_curve_metrics.csv');
out.shap_compare = fullfile(cfg.report_dir, 'seed11_dt1_light_shap_compare.csv');
out.case_eval = fullfile(cfg.report_dir, 'seed11_dt1_case_eval_doe3.csv');

fprintf('Completed light-plus run. Report: %s\n', report_md);
end

function [models, metrics_tbl, Yhat_test] = train_scalar_models_min(X_train, Y_train, X_test, Y_test, target_names, cfg)
n_targets = size(Y_train, 2);
models = repmat(struct('name', "", 'model', [], 'use_log', false, 'fit_lower', nan, 'fit_upper', nan), n_targets, 1);
Yhat_test = zeros(size(Y_test));

rows = 2 * n_targets;
target_col = strings(rows, 1);
split_col = strings(rows, 1);
r2_col = zeros(rows, 1);
rmse_col = zeros(rows, 1);
mae_col = zeros(rows, 1);

for j = 1:n_targets
    ytr = Y_train(:, j);
    yte = Y_test(:, j);

    use_log = any(strcmp(target_names(j), cfg.log_targets));
    if use_log
        ytr_fit = log10(max(ytr, eps));
        fit_lower = min(ytr_fit) - cfg.log_pred_clip_margin;
        fit_upper = max(ytr_fit) + cfg.log_pred_clip_margin;
    else
        ytr_fit = ytr;
        rg = max(ytr) - min(ytr);
        fit_lower = min(ytr) - cfg.pred_clip_margin * rg;
        fit_upper = max(ytr) + cfg.pred_clip_margin * rg;
    end

    mdl = fitrnet(X_train, ytr_fit, ...
        'LayerSizes', cfg.layer_sizes, ...
        'Activations', 'relu', ...
        'Standardize', true, ...
        'Lambda', cfg.lambda, ...
        'InitialStepSize', cfg.initial_step_size, ...
        'IterationLimit', cfg.iteration_limit);

    ytr_pred_fit = predict(mdl, X_train);
    yte_pred_fit = predict(mdl, X_test);

    ytr_pred = apply_scalar_postprocess_min(ytr_pred_fit, use_log, fit_lower, fit_upper);
    yte_pred = apply_scalar_postprocess_min(yte_pred_fit, use_log, fit_lower, fit_upper);

    Yhat_test(:, j) = yte_pred;

    [r2_tr, rmse_tr, mae_tr] = regression_metrics_min(ytr, ytr_pred);
    [r2_te, rmse_te, mae_te] = regression_metrics_min(yte, yte_pred);

    r0 = 2 * (j - 1) + 1;
    target_col(r0) = target_names(j);
    split_col(r0) = "train";
    r2_col(r0) = r2_tr;
    rmse_col(r0) = rmse_tr;
    mae_col(r0) = mae_tr;

    target_col(r0 + 1) = target_names(j);
    split_col(r0 + 1) = "test";
    r2_col(r0 + 1) = r2_te;
    rmse_col(r0 + 1) = rmse_te;
    mae_col(r0 + 1) = mae_te;

    models(j).name = target_names(j);
    models(j).model = mdl;
    models(j).use_log = use_log;
    models(j).fit_lower = fit_lower;
    models(j).fit_upper = fit_upper;

    fprintf('Scalar %-10s | test R2=%.4f RMSE=%.4e MAE=%.4e\n', target_names(j), r2_te, rmse_te, mae_te);
end

metrics_tbl = table(target_col, split_col, r2_col, rmse_col, mae_col, ...
    'VariableNames', {'Target', 'Split', 'R2', 'RMSE', 'MAE'});
end

function [curve_models, curve_metrics_tbl, pred_test] = train_curve_models_min(X_train, X_test, Yc_train, Yc_test, Ys_train, Ys_test, cfg)
[curve_models_cost, pred_cost_test, met_cost] = train_one_curve_branch_min(X_train, X_test, Yc_train, Yc_test, cfg, "m_cost");
[curve_models_supp, pred_supp_test, met_supp] = train_one_curve_branch_min(X_train, X_test, Ys_train, Ys_test, cfg, "m_supp");

curve_models = struct();
curve_models.cost = curve_models_cost;
curve_models.supp = curve_models_supp;

pred_test = struct();
pred_test.cost = pred_cost_test;
pred_test.supp = pred_supp_test;

curve_metrics_tbl = [met_cost; met_supp];
end

function [branch, Ypred_test, met_tbl] = train_one_curve_branch_min(X_train, X_test, Y_train, Y_test, cfg, name)
[coeff, score, ~, ~, explained, mu] = pca(Y_train, 'Centered', true);
cumexp = cumsum(explained);
k = find(cumexp >= cfg.curve_pca_var_percent, 1, 'first');
if isempty(k)
    k = min(size(coeff, 2), cfg.curve_pca_maxcomp);
end
k = min(k, cfg.curve_pca_maxcomp);

coef_models = cell(k, 1);
for i = 1:k
    yi = score(:, i);
    coef_models{i} = fitrnet(X_train, yi, ...
        'LayerSizes', cfg.curve_layer_sizes, ...
        'Activations', 'relu', ...
        'Standardize', true, ...
        'Lambda', cfg.curve_lambda, ...
        'InitialStepSize', cfg.curve_initial_step_size, ...
        'IterationLimit', cfg.curve_iteration_limit);
end

branch = struct();
branch.name = name;
branch.mu = mu;
branch.coeff = coeff(:, 1:k);
branch.k = k;
branch.explained = explained;
branch.cumexp_at_k = cumexp(k);
branch.coef_models = coef_models;
branch.score_min = min(score(:, 1:k), [], 1);
branch.score_max = max(score(:, 1:k), [], 1);
branch.score_clip_margin = cfg.curve_coef_clip_margin;

Ypred_test = predict_curve_model_min(branch, X_test);

[r2_flat, rmse_flat, mae_flat] = regression_metrics_min(Y_test(:), Ypred_test(:));
per_case_rmse = sqrt(mean((Y_test - Ypred_test) .^ 2, 2));
per_case_mae = mean(abs(Y_test - Ypred_test), 2);

met_tbl = table( ...
    string(name), r2_flat, rmse_flat, mae_flat, mean(per_case_rmse), mean(per_case_mae), k, branch.cumexp_at_k, ...
    'VariableNames', {'Curve', 'R2Flat', 'RMSEFlat', 'MAEFlat', 'RMSEPerCaseMean', 'MAEPerCaseMean', 'PCAComponents', 'PCAExplainedPercent'});

fprintf('Curve %-8s | test R2(flat)=%.4f RMSE(flat)=%.4e | k=%d (%.2f%% var)\n', ...
    name, r2_flat, rmse_flat, k, branch.cumexp_at_k);
end

function Ypred = predict_curve_model_min(branch, Xq)
n = size(Xq, 1);
score_pred = zeros(n, branch.k);
for i = 1:branch.k
    zi = predict(branch.coef_models{i}, Xq);
    lo = branch.score_min(i);
    hi = branch.score_max(i);
    rg = hi - lo;
    lo = lo - branch.score_clip_margin * rg;
    hi = hi + branch.score_clip_margin * rg;
    score_pred(:, i) = min(max(zi, lo), hi);
end
Ypred = score_pred * branch.coeff' + branch.mu;
end

function ypred = predict_scalar_models_min(scalar_models, xrow)
n = numel(scalar_models);
ypred = zeros(1, n);
for j = 1:n
    z = predict(scalar_models(j).model, xrow);
    ypred(j) = apply_scalar_postprocess_min(z, scalar_models(j).use_log, scalar_models(j).fit_lower, scalar_models(j).fit_upper);
end
end

function y = apply_scalar_postprocess_min(z, use_log, lo, hi)
z = min(max(z, lo), hi);
if use_log
    y = 10 .^ z;
else
    y = z;
end
end

function [r2, rmse, mae] = regression_metrics_min(y_true, y_pred)
err = y_true - y_pred;
rmse = sqrt(mean(err .^ 2));
mae = mean(abs(err));
den = sum((y_true - mean(y_true)) .^ 2);
if den < eps
    r2 = nan;
else
    r2 = 1 - sum(err .^ 2) / den;
end
end

function [shap_maps, summary_tbl] = run_objective_shap_method_min(models_obj, X, train_use, test_use, feature_names, cfg, method_name, max_subsets)
fn = string(feature_names(:));
is_action = startsWith(fn, "cc_");
is_pin = startsWith(fn, "pin_");

n_action = sum(is_action);
n_pin = sum(is_pin);
n_t = n_pin;
n_comp = n_action / max(n_t, 1);
if mod(n_comp, 1) ~= 0
    error('Cannot infer [time, compressor] shape from feature names.');
end
n_comp = round(n_comp);

n_bg = min(cfg.shap_background_n, numel(train_use));
n_q = min(cfg.shap_query_n, numel(test_use));
bg_pick = train_use(randperm(numel(train_use), n_bg));
q_pick = test_use(randperm(numel(test_use), n_q));

shap_maps = zeros(n_t, n_comp, 3);
rows = 3 * (n_t + n_comp + 1);
metric_name = strings(rows, 1);
objective_name = strings(rows, 1);
value = zeros(rows, 1);
r = 0;

for j = 1:3
    ws = warning('off', 'stats:responsible:shapley:MaxNumSubsetsTooSmall');
    cleaner = onCleanup(@() warning(ws)); %#ok<NASGU>
    shp = shapley(models_obj(j).model, X(bg_pick, :), ...
        'Method', char(method_name), ...
        'QueryPoints', X(q_pick, :), ...
        'MaxNumSubsets', max_subsets);

    sv = shp.ShapleyValues.ShapleyValue;
    mean_abs = mean(abs(sv), 2);

    action_abs = mean_abs(is_action);
    pin_abs = mean_abs(is_pin);

    m = zeros(n_t, n_comp);
    idx = 0;
    for t = 1:n_t
        for c = 1:n_comp
            idx = idx + 1;
            m(t, c) = action_abs(idx);
        end
    end
    shap_maps(:, :, j) = m;

    time_imp = sum(m, 2);
    comp_imp = sum(m, 1)';

    for t = 1:n_t
        r = r + 1;
        metric_name(r) = sprintf('time_t%02d', t);
        objective_name(r) = cfg.objective_names(j);
        value(r) = time_imp(t);
    end

    for c = 1:n_comp
        r = r + 1;
        metric_name(r) = sprintf('comp_c%d', c);
        objective_name(r) = cfg.objective_names(j);
        value(r) = comp_imp(c);
    end

    r = r + 1;
    metric_name(r) = 'pin_total';
    objective_name(r) = cfg.objective_names(j);
    value(r) = sum(pin_abs);
end

summary_tbl = table(metric_name(1:r), objective_name(1:r), value(1:r), ...
    'VariableNames', {'Metric', 'Objective', 'MeanAbsSHAP'});
end

function [cases_struct, eval_tbl] = evaluate_selected_doe_cases_min(meta_tbl, X, Y_obj, Y_curve_cost, Y_curve_supp, curve_t_hr, test_idx, scalar_models, curve_models)
doe_rows = select_doe_rows_min(meta_tbl, test_idx, Y_obj(:, 1));
n = numel(doe_rows);
cases_struct = repmat(struct(), n, 1);

label_col = strings(n, 1);
jc_true = nan(n, 1);
jc_pred = nan(n, 1);
js_true = nan(n, 1);
js_pred = nan(n, 1);
jv_true = nan(n, 1);
jv_pred = nan(n, 1);
rmse_cost = nan(n, 1);
rmse_supp = nan(n, 1);

for i = 1:n
    row_id = doe_rows(i);
    xrow = X(row_id, :);

    yobj_true = Y_obj(row_id, :);
    yobj_pred = predict_scalar_models_min(scalar_models(1:3), xrow);

    yc_true = Y_curve_cost(row_id, :);
    ys_true = Y_curve_supp(row_id, :);
    yc_pred = predict_curve_model_min(curve_models.cost, xrow);
    ys_pred = predict_curve_model_min(curve_models.supp, xrow);

    cases_struct(i).source = 'DOE';
    cases_struct(i).label = sprintf('DOE sample %d', meta_tbl.SampleID(row_id));
    cases_struct(i).t_hr = curve_t_hr;
    cases_struct(i).true_cost = yc_true(:);
    cases_struct(i).pred_cost = yc_pred(:);
    cases_struct(i).true_supp = ys_true(:);
    cases_struct(i).pred_supp = ys_pred(:);
    cases_struct(i).yobj_true = yobj_true(:)';
    cases_struct(i).yobj_pred = yobj_pred(:)';

    label_col(i) = string(cases_struct(i).label);
    jc_true(i) = yobj_true(1);
    jc_pred(i) = yobj_pred(1);
    js_true(i) = yobj_true(2);
    js_pred(i) = yobj_pred(2);
    jv_true(i) = yobj_true(3);
    jv_pred(i) = yobj_pred(3);
    rmse_cost(i) = sqrt(mean((yc_true(:) - yc_pred(:)).^2));
    rmse_supp(i) = sqrt(mean((ys_true(:) - ys_pred(:)).^2));
end

eval_tbl = table(label_col, jc_true, jc_pred, js_true, js_pred, jv_true, jv_pred, rmse_cost, rmse_supp, ...
    'VariableNames', {'CaseLabel', 'JcostTrue', 'JcostPred', 'JsuppTrue', 'JsuppPred', 'JvarTrue', 'JvarPred', 'RMSECostCurve', 'RMSESuppCurve'});
end

function rows = select_doe_rows_min(meta_tbl, test_idx, jcost)
is_test = false(height(meta_tbl), 1);
is_test(test_idx) = true;
mask = is_test & meta_tbl.NoiseReplicaID == 0;
idx = find(mask);
if numel(idx) < 3
    idx = test_idx(:);
end

vals = jcost(idx);
[vals_sorted, ord] = sort(vals, 'ascend'); %#ok<ASGLU>
idx_sorted = idx(ord);

qpos = unique(round([0.1 0.5 0.9] * (numel(idx_sorted) - 1)) + 1, 'stable');
rows = idx_sorted(qpos);
if numel(rows) < 3
    rows = idx_sorted(unique(round(linspace(1, numel(idx_sorted), 3))));
end
rows = rows(:);
end


function plot_objective_parity_min(plot_dir, y_true, y_pred, names, metrics_tbl)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1450 460], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:3
    ax = nexttile;
    hold on;
    scatter(y_true(:, j), y_pred(:, j), 20, [0.12 0.44 0.82], 'filled', ...
        'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);
    lo = min([y_true(:, j); y_pred(:, j)]);
    hi = max([y_true(:, j); y_pred(:, j)]);
    plot([lo hi], [lo hi], 'k--', 'LineWidth', 1.2);
    mk = metrics_tbl(metrics_tbl.Target == names(j) & metrics_tbl.Split == "test", :);
    title(sprintf('%s | R2=%.3f', names(j), mk.R2));
    xlabel('True');
    ylabel('Predicted');
    grid on;
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

sgtitle('Objective parity on test set', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'objective_parity_test.png'), 260);
close(f);
end

function plot_flow_parity_min(plot_dir, y_true, y_pred, names, metrics_tbl)
n = size(y_true, 2);
nrow = 2;
ncol = ceil(n / nrow);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1600 760], 'Renderer', 'painters');
tiledlayout(nrow, ncol, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:n
    ax = nexttile;
    hold on;
    scatter(y_true(:, j), y_pred(:, j), 18, [0.22 0.62 0.30], 'filled', ...
        'MarkerFaceAlpha', 0.42, 'MarkerEdgeAlpha', 0.42);
    lo = min([y_true(:, j); y_pred(:, j)]);
    hi = max([y_true(:, j); y_pred(:, j)]);
    plot([lo hi], [lo hi], 'k--', 'LineWidth', 1.1);
    mk = metrics_tbl(metrics_tbl.Target == names(j) & metrics_tbl.Split == "test", :);
    title(sprintf('%s | R2=%.3f', names(j), mk.R2));
    xlabel('True');
    ylabel('Predicted');
    grid on;
    set(ax, 'FontSize', 9, 'LineWidth', 1.0);
end

sgtitle('Key-flow parity on test set', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'flow_parity_test.png'), 260);
close(f);
end

function plot_curve_test_overlay_min(plot_dir, t_hr, true_cost, pred_cost, true_supp, pred_supp)
pick = unique(round(linspace(1, size(true_cost, 1), 6)));

n_pick = numel(pick);
f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1500 220 * n_pick], 'Renderer', 'painters');
tiledlayout(n_pick, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(pick)
    idx = pick(i);

    ax1 = nexttile;
    hold on;
    plot(t_hr, true_cost(idx, :), 'k-', 'LineWidth', 1.2, 'DisplayName', 'true');
    plot(t_hr, pred_cost(idx, :), 'r--', 'LineWidth', 1.3, 'DisplayName', 'pred');
    title(sprintf('m\\_cost case #%d', idx));
    xlabel('Time (h)');
    ylabel('m\_cost');
    grid on;
    if i == 1
        legend('Location', 'best');
    end
    set(ax1, 'FontSize', 9, 'LineWidth', 1.0);

    ax2 = nexttile;
    hold on;
    plot(t_hr, true_supp(idx, :), 'k-', 'LineWidth', 1.2, 'DisplayName', 'true');
    plot(t_hr, pred_supp(idx, :), 'r--', 'LineWidth', 1.3, 'DisplayName', 'pred');
    title(sprintf('m\\_supp case #%d', idx));
    xlabel('Time (h)');
    ylabel('m\_supp');
    grid on;
    if i == 1
        legend('Location', 'best');
    end
    set(ax2, 'FontSize', 9, 'LineWidth', 1.0);
end

sgtitle('Curve surrogate overlay on sampled test cases', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'curve_overlay_sampled_test.png'), 250);
close(f);
end

function plot_split_overview_min(plot_dir, n_train, n_val, n_test)
labels = {'train', 'val', 'test'};
vals = [n_train n_val n_test];

f = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 980 440], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
pie(vals, labels);
title('Dataset split ratio');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
bar(categorical(labels), vals, 0.6);
ylabel('Sample count');
title('Dataset split count');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

save_plot_png_min(f, fullfile(plot_dir, 'split_overview.png'), 240);
close(f);
end

function plot_network_schematic_min(plot_dir, n_in, layer_sizes, n_out_scalar, curve_models)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1220 520], 'Renderer', 'painters');
axes('Position', [0 0 1 1]);
axis off;

annotation('textbox', [0.03 0.38 0.16 0.24], 'String', sprintf('Input\n%d features\n(25x5 actions + 25 pin)', n_in), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [0.94 0.98 1.0], 'Interpreter', 'none');

annotation('textbox', [0.27 0.53 0.18 0.16], 'String', sprintf('Hidden-1\n%d neurons\nReLU', layer_sizes(1)), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [0.95 1.00 0.95], 'Interpreter', 'none');

annotation('textbox', [0.50 0.53 0.18 0.16], 'String', sprintf('Hidden-2\n%d neurons\nReLU', layer_sizes(2)), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [0.95 1.00 0.95], 'Interpreter', 'none');

annotation('textbox', [0.74 0.53 0.22 0.16], 'String', sprintf('Scalar heads\n%d targets\n(Jcost/Jsupp/Jvar + key flow)', n_out_scalar), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [1.00 0.96 0.92], 'Interpreter', 'none');

annotation('textbox', [0.50 0.19 0.18 0.16], 'String', sprintf('Curve coeff heads\nPCA coeff: cost k=%d, supp k=%d', curve_models.cost.k, curve_models.supp.k), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [0.99 0.94 1.00], 'Interpreter', 'none');

annotation('textbox', [0.74 0.19 0.22 0.16], 'String', sprintf('PCA decoder\nreconstruct m_cost(t), m_supp(t)'), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [0.99 0.94 1.00], 'Interpreter', 'none');

annotation('arrow', [0.19 0.27], [0.50 0.61], 'LineWidth', 1.5);
annotation('arrow', [0.45 0.50], [0.61 0.61], 'LineWidth', 1.5);
annotation('arrow', [0.68 0.74], [0.61 0.61], 'LineWidth', 1.5);
annotation('arrow', [0.68 0.74], [0.27 0.27], 'LineWidth', 1.5);

annotation('textbox', [0.03 0.04 0.94 0.10], ...
    'String', 'Light-plus architecture: per-target MLP for scalar outputs + PCA-coefficient MLP branches for trajectory reconstruction.', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'LineStyle', 'none', 'FontSize', 10, 'Interpreter', 'none');

save_plot_png_min(f, fullfile(plot_dir, 'network_architecture_schematic.png'), 240);
close(f);
end

function plot_shap_action_heatmaps_method_min(plot_dir, shap_maps, names, method_name)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1500 460], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:3
    ax = nexttile;
    imagesc(shap_maps(:, :, j));
    xlabel('Compressor index');
    ylabel('Time step (1h grid)');
    title(sprintf('%s | %s', names(j), method_name));
    set(ax, 'YDir', 'normal', 'FontSize', 10, 'LineWidth', 1.0);
    xticks(1:size(shap_maps, 2));
    yticks(1:size(shap_maps, 1));
    colorbar;
end

sgtitle(sprintf('Action SHAP heatmaps (%s)', method_name), 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, sprintf('shap_action_heatmap_%s.png', method_name)), 260);
close(f);
end

function plot_shap_method_compare_min(plot_dir, map_int, map_cond, names)
n_t = size(map_int, 1);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1420 460], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:3
    ax = nexttile;
    ti = sum(map_int(:, :, j), 2);
    tc = sum(map_cond(:, :, j), 2);
    ti = ti / max(sum(ti), eps);
    tc = tc / max(sum(tc), eps);

    hold on;
    plot(1:n_t, ti, 'LineWidth', 1.8, 'DisplayName', 'interventional');
    plot(1:n_t, tc, '--', 'LineWidth', 1.8, 'DisplayName', 'conditional');
    xlabel('Time step');
    ylabel('Normalized importance');
    title(sprintf('%s time-importance profile', names(j)));
    grid on;
    legend('Location', 'best');
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

sgtitle('SHAP method comparison (interventional vs conditional)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'shap_method_compare_time_profile.png'), 260);
close(f);
end

function plot_selected_case_curves_min(plot_dir, cases_struct, curve_t_hr)
n = numel(cases_struct);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1700 260 * n], 'Renderer', 'painters');
tiledlayout(n, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:n
    cs = cases_struct(i);
    t = cs.t_hr;
    if isempty(t)
        t = curve_t_hr;
    end

    ax1 = nexttile;
    hold on;
    plot(t, cs.true_cost, 'k-', 'LineWidth', 1.4, 'DisplayName', 'true');
    plot(t, cs.pred_cost, 'r--', 'LineWidth', 1.5, 'DisplayName', 'pred');
    rm = sqrt(mean((cs.true_cost - cs.pred_cost) .^ 2));
    title(sprintf('%s | m_cost | RMSE=%.3e', cs.label, rm));
    xlabel('Time (h)');
    ylabel('m\_cost');
    grid on;
    if i == 1
        legend('Location', 'best');
    end
    set(ax1, 'FontSize', 9, 'LineWidth', 1.0);

    ax2 = nexttile;
    hold on;
    plot(t, cs.true_supp, 'k-', 'LineWidth', 1.4, 'DisplayName', 'true');
    plot(t, cs.pred_supp, 'r--', 'LineWidth', 1.5, 'DisplayName', 'pred');
    rm = sqrt(mean((cs.true_supp - cs.pred_supp) .^ 2));
    title(sprintf('%s | m_supp | RMSE=%.3e', cs.label, rm));
    xlabel('Time (h)');
    ylabel('m\_supp');
    grid on;
    if i == 1
        legend('Location', 'best');
    end
    set(ax2, 'FontSize', 9, 'LineWidth', 1.0);
end

sgtitle('Selected 3-case curve check (DOE only)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'curve_case_compare_doe3.png'), 250);
close(f);
end

function plot_selected_case_objectives_min(plot_dir, cases_struct)
n = numel(cases_struct);
labels = strings(n, 1);
jt = zeros(n, 3);
jp = zeros(n, 3);
for i = 1:n
    labels(i) = string(cases_struct(i).label);
    jt(i, :) = cases_struct(i).yobj_true;
    jp(i, :) = cases_struct(i).yobj_pred;
end

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1500 880], 'Renderer', 'painters');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
obj_names = {'Jcost', 'Jsupp', 'Jvar'};

for j = 1:3
    ax = nexttile;
    hold on;
    x = 1:n;
    w = 0.35;
    bar(x - w/2, jt(:, j), w, 'FaceColor', [0.20 0.20 0.20], 'DisplayName', 'true');
    bar(x + w/2, jp(:, j), w, 'FaceColor', [0.85 0.20 0.20], 'DisplayName', 'pred');
    xticks(x);
    xticklabels(labels);
    xtickangle(20);
    ylabel(obj_names{j});
    title(sprintf('DOE selected case objective comparison: %s', obj_names{j}));
    grid on;
    if j == 1
        legend('Location', 'best');
    end
    set(ax, 'FontSize', 9, 'LineWidth', 1.0);
end

save_plot_png_min(f, fullfile(plot_dir, 'selected_case_objective_compare_doe3.png'), 250);
close(f);
end

function write_detailed_report_md_min(md_file, cfg, X, Y, target_names, train_idx, val_idx, test_idx, scalar_metrics_tbl, curve_metrics_tbl, case_eval_tbl)
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write markdown report: %s', md_file);
end

wline(fid, '# Seed11 dt=1h neural surrogate report (light-plus)');
wline(fid, '');
wline(fid, '## 1) Scope and objective');
wline(fid, '');
wline(fid, '- Dataset scope: `seed=11`, `dt=1h`, `OK=1` from DOE try1.');
wline(fid, '- Goal: build a lightweight NN surrogate that approximates transient simulator outputs under this boundary-condition regime.');
wline(fid, '- Input: compressor action sequence + inlet-pressure sequence with random noise.');
wline(fid, '- Outputs: (`Jcost`, `Jsupp`, `Jvar`) + key flow indicators + reconstructed `m_cost(t)` / `m_supp(t)` curves.');
wline(fid, '');

wline(fid, '## 2) Data and split');
wline(fid, '');
wline(fid, sprintf('- Total samples: `%d`', size(X, 1)));
wline(fid, sprintf('- Input dimension: `%d`', size(X, 2)));
wline(fid, sprintf('- Output dimension (scalar heads): `%d`', size(Y, 2)));
wline(fid, sprintf('- Split: train `%d`, val `%d`, test `%d`', numel(train_idx), numel(val_idx), numel(test_idx)));
wline(fid, '');
wline(fid, 'Input feature construction:');
wline(fid, '');
wline(fid, '- action features: `cc_{t,c}` for `t=1..25`, `c=1..5`');
wline(fid, '- pressure features: `p_{in,t}^{noise} = p_{in,t} (1 + \sigma \epsilon_t)`, `\epsilon_t \sim \mathcal{N}(0,1)`');
wline(fid, '- final feature vector: `x \in \mathbb{R}^{150}`');
wline(fid, '');

wline(fid, '## 3) Modeling equations');
wline(fid, '');
wline(fid, '### 3.1 Scalar surrogate');
wline(fid, '');
wline(fid, 'For each scalar target `y_k`, train one NN regressor:');
wline(fid, '');
wline(fid, '$$\hat{y}_k = f_{\theta_k}(x)$$');
wline(fid, '');
wline(fid, 'Loss (MSE + L2 regularization, implicit in solver settings):');
wline(fid, '');
wline(fid, '$$\mathcal{L}(\theta_k)=\frac{1}{N}\sum_{n=1}^N\left(y_k^{(n)}-f_{\theta_k}(x^{(n)})\right)^2 + \lambda\|\theta_k\|_2^2$$');
wline(fid, '');
wline(fid, 'For `Jcost`, train in log-space for stability:');
wline(fid, '');
wline(fid, '$$\tilde{y}_{cost}=\log_{10}(y_{cost}),\quad \hat{y}_{cost}=10^{f_{\theta}(x)}$$');
wline(fid, '');

wline(fid, '### 3.2 Curve surrogate (PCA + NN coefficients)');
wline(fid, '');
wline(fid, 'For each trajectory `y(t)` (`m_cost`, `m_supp`), use PCA on training curves:');
wline(fid, '');
wline(fid, '$$y \approx \mu + P_K z,\quad z=[z_1,\dots,z_K]^T$$');
wline(fid, '');
wline(fid, 'Then learn each coefficient with NN:');
wline(fid, '');
wline(fid, '$$\hat{z}_i = g_{\psi_i}(x),\quad i=1,\dots,K$$');
wline(fid, '');
wline(fid, 'Curve reconstruction:');
wline(fid, '');
wline(fid, '$$\hat{y}=\mu + P_K \hat{z}$$');
wline(fid, '');

wline(fid, '## 4) SHAP methods, formulas, and differences');
wline(fid, '');
wline(fid, 'Shapley definition used by all SHAP variants (`M` features):');
wline(fid, '');
wline(fid, '$$\phi_i(x)=\sum_{S\subseteq N\setminus\{i\}}\frac{|S|!(M-|S|-1)!}{M!}\left[v_x(S\cup\{i\})-v_x(S)\right]$$');
wline(fid, '');
wline(fid, 'Method-specific value functions / estimators:');
wline(fid, '');
wline(fid, '1. **Interventional SHAP** (this run): feature dependence is cut when integrating missing features.');
wline(fid, '$$v_x^{int}(S)=\mathbb{E}_{X_{\bar S}}\left[f(x_S, X_{\bar S})\right]$$');
wline(fid, '');
wline(fid, '2. **Conditional SHAP** (this run): keeps empirical dependence among features.');
wline(fid, '$$v_x^{cond}(S)=\mathbb{E}\left[f(X)\mid X_S=x_S\right]$$');
wline(fid, '');
wline(fid, '3. **Kernel SHAP** (model-agnostic estimator): weighted local linear regression around `x`.');
wline(fid, '$$\min_{\phi_0,\phi}\sum_{u}\pi_x(u)\left(f(h_x(u))-\phi_0-\sum_{i=1}^M\phi_i u_i\right)^2$$');
wline(fid, '');
wline(fid, '4. **TreeSHAP** (tree-model exact/fast): additive over trees with exact tree expectations.');
wline(fid, '$$\phi_i(x)=\sum_{t=1}^{T}\phi_i^{(t)}(x),\quad \phi_i^{(t)}\text{ computed exactly on tree }t$$');
wline(fid, '');
wline(fid, '5. **DeepSHAP** (deep nets): DeepLIFT-style multipliers averaged over background references.');
wline(fid, '$$\phi_i(x)\approx\mathbb{E}_{x''\sim B}\left[(x_i-x_i'')\,m_i(x,x'')\right]$$');
wline(fid, '');
wline(fid, '6. **Permutation / Sampling SHAP** (Monte Carlo): average marginal contribution over random permutations.');
wline(fid, '$$\phi_i(x)\approx\frac{1}{K}\sum_{k=1}^{K}\left[f\left(x_{S_i^{\pi_k}\cup\{i\}}\right)-f\left(x_{S_i^{\pi_k}}\right)\right]$$');
wline(fid, '');
wline(fid, 'Practical difference summary:');
wline(fid, '');
wline(fid, '- Interventional: robust and simple, but can violate realistic feature coupling.');
wline(fid, '- Conditional: respects dependence, but needs stronger distribution modeling assumptions.');
wline(fid, '- Kernel/Permutation: model-agnostic, but slower and variance-sensitive.');
wline(fid, '- TreeSHAP/DeepSHAP: architecture-specific accelerations/approximations for trees/deep nets.');
wline(fid, '');

wline(fid, '## 5) Scalar metrics (test split)');
wline(fid, '');
wline(fid, '| Target | R2 | RMSE | MAE |');
wline(fid, '|---|---:|---:|---:|');
mk = scalar_metrics_tbl(scalar_metrics_tbl.Split == "test", :);
for i = 1:height(mk)
    wline(fid, sprintf('| %s | %.4f | %.6g | %.6g |', mk.Target(i), mk.R2(i), mk.RMSE(i), mk.MAE(i)));
end

wline(fid, '');
wline(fid, '## 6) Curve metrics (test split)');
wline(fid, '');
wline(fid, '| Curve | R2(flat) | RMSE(flat) | MAE(flat) | Mean RMSE/case | PCA K | Explained(%) |');
wline(fid, '|---|---:|---:|---:|---:|---:|---:|');
for i = 1:height(curve_metrics_tbl)
    wline(fid, sprintf('| %s | %.4f | %.6g | %.6g | %.6g | %d | %.2f |', ...
        curve_metrics_tbl.Curve(i), curve_metrics_tbl.R2Flat(i), curve_metrics_tbl.RMSEFlat(i), ...
        curve_metrics_tbl.MAEFlat(i), curve_metrics_tbl.RMSEPerCaseMean(i), ...
        curve_metrics_tbl.PCAComponents(i), curve_metrics_tbl.PCAExplainedPercent(i)));
end

wline(fid, '');
wline(fid, '## 7) 3-case curve check (DOE only)');
wline(fid, '');
wline(fid, '| Case | Jcost true/pred | Jsupp true/pred | Jvar true/pred | RMSE m_cost | RMSE m_supp |');
wline(fid, '|---|---:|---:|---:|---:|---:|');
for i = 1:height(case_eval_tbl)
    wline(fid, sprintf('| %s | %.6g / %.6g | %.6g / %.6g | %.6g / %.6g | %.6g | %.6g |', ...
        case_eval_tbl.CaseLabel(i), ...
        case_eval_tbl.JcostTrue(i), case_eval_tbl.JcostPred(i), ...
        case_eval_tbl.JsuppTrue(i), case_eval_tbl.JsuppPred(i), ...
        case_eval_tbl.JvarTrue(i), case_eval_tbl.JvarPred(i), ...
        case_eval_tbl.RMSECostCurve(i), case_eval_tbl.RMSESuppCurve(i)));
end

wline(fid, '');
wline(fid, '## 8) Generated plots');
wline(fid, '');
wline(fid, '- `shap_src_min/NNs/plots/split_overview.png`');
wline(fid, '- `shap_src_min/NNs/plots/network_architecture_schematic.png`');
wline(fid, '- `shap_src_min/NNs/plots/objective_parity_test.png`');
wline(fid, '- `shap_src_min/NNs/plots/flow_parity_test.png`');
wline(fid, '- `shap_src_min/NNs/plots/curve_overlay_sampled_test.png`');
wline(fid, '- `shap_src_min/NNs/plots/curve_case_compare_doe3.png`');
wline(fid, '- `shap_src_min/NNs/plots/selected_case_objective_compare_doe3.png`');
wline(fid, '- `shap_src_min/NNs/plots/shap_action_heatmap_interventional.png`');
wline(fid, '- `shap_src_min/NNs/plots/shap_action_heatmap_conditional.png`');
wline(fid, '- `shap_src_min/NNs/plots/shap_method_compare_time_profile.png`');
wline(fid, '');

wline(fid, '## 9) SHAP references');
wline(fid, '');
wline(fid, '- Shapley value foundation: Shapley, 1953, *A Value for n-Person Games* (`https://doi.org/10.1515/9781400881970-018`).');
wline(fid, '- SHAP framework and Kernel SHAP: Lundberg and Lee, 2017, *A Unified Approach to Interpreting Model Predictions* (`https://arxiv.org/abs/1705.07874`).');
wline(fid, '- Conditional/dependence-aware SHAP: Aas, Jullum, and Lolo, 2021, *Artificial Intelligence* (`https://doi.org/10.1016/j.artint.2021.103502`).');
wline(fid, '- TreeSHAP and global interpretation for trees: Lundberg et al., 2020, *Nature Machine Intelligence* (`https://doi.org/10.1038/s42256-019-0138-9`).');
wline(fid, '- DeepLIFT basis used by DeepSHAP: Shrikumar, Greenside, and Kundaje, 2017 (`https://proceedings.mlr.press/v70/shrikumar17a.html`).');
wline(fid, '- Sampling/permutation-style Shapley estimation: Strumbelj and Kononenko, 2014, *Knowledge and Information Systems* (`https://doi.org/10.1007/s10115-013-0679-x`).');
wline(fid, '');

wline(fid, '## 10) Current limitation');
wline(fid, '');
wline(fid, '- Scope is intentionally limited to seed11 + 1h + fixed boundary-condition regime.');
wline(fid, '- Surrogate is light and practical; full PDE-state replacement for all state channels is deferred to next iteration.');
wline(fid, '- All reported metrics and selected-case checks are DOE-scope only.');

fclose(fid);
end

function wline(fid, txt)
fprintf(fid, '%s\n', txt);
end

function save_plot_png_min(fig_handle, out_file, dpi)
if nargin < 3 || isempty(dpi)
    dpi = 250;
end
set(fig_handle, 'Renderer', 'painters');
set(fig_handle, 'InvertHardcopy', 'off');
drawnow('nocallbacks');
print(fig_handle, out_file, '-dpng', sprintf('-r%d', dpi), '-painters');
end

function cfg = fill_cfg_defaults_min(cfg)
script_dir = fileparts(mfilename('fullpath'));
nns_dir = fileparts(script_dir);
parent_dir = fileparts(nns_dir);

if exist(fullfile(parent_dir, 'doe'), 'dir') == 7 && exist(fullfile(parent_dir, 'tr'), 'dir') == 7
    shap_root = parent_dir;
    repo_dir = fileparts(shap_root);
else
    repo_dir = parent_dir;
    shap_root = fullfile(repo_dir, 'shap_src_min');
end

if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end
if ~isfield(cfg, 'shap_root') || isempty(cfg.shap_root)
    cfg.shap_root = shap_root;
end
if ~isfield(cfg, 'manifest_csv') || isempty(cfg.manifest_csv)
    cfg.manifest_csv = fullfile(cfg.shap_root, 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'manifest.csv');
end

if ~isfield(cfg, 'seed') || isempty(cfg.seed)
    cfg.seed = 11;
end
if ~isfield(cfg, 'dt_hr') || isempty(cfg.dt_hr)
    cfg.dt_hr = 1.0;
end
if ~isfield(cfg, 'noise_sigma') || isempty(cfg.noise_sigma)
    cfg.noise_sigma = 0.01;
end
if ~isfield(cfg, 'noise_repeats') || isempty(cfg.noise_repeats)
    cfg.noise_repeats = 3;
end
if ~isfield(cfg, 'rng_seed') || isempty(cfg.rng_seed)
    cfg.rng_seed = 2026;
end

if ~isfield(cfg, 'train_ratio') || isempty(cfg.train_ratio)
    cfg.train_ratio = 0.70;
end
if ~isfield(cfg, 'val_ratio') || isempty(cfg.val_ratio)
    cfg.val_ratio = 0.15;
end

if ~isfield(cfg, 'data_dir') || isempty(cfg.data_dir)
    cfg.data_dir = fullfile(nns_dir, 'data');
end
if ~isfield(cfg, 'model_dir') || isempty(cfg.model_dir)
    cfg.model_dir = fullfile(nns_dir, 'models');
end
if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(nns_dir, 'plots');
end
if ~isfield(cfg, 'report_dir') || isempty(cfg.report_dir)
    cfg.report_dir = fullfile(nns_dir, 'reports');
end
if ~isfield(cfg, 'dataset_file') || isempty(cfg.dataset_file)
    cfg.dataset_file = fullfile(cfg.data_dir, 'seed11_dt1_nn_light_dataset.mat');
end

if ~isfield(cfg, 'layer_sizes') || isempty(cfg.layer_sizes)
    cfg.layer_sizes = [64 32];
end
if ~isfield(cfg, 'iteration_limit') || isempty(cfg.iteration_limit)
    cfg.iteration_limit = 220;
end
if ~isfield(cfg, 'lambda') || isempty(cfg.lambda)
    cfg.lambda = 1e-4;
end
if ~isfield(cfg, 'initial_step_size') || isempty(cfg.initial_step_size)
    cfg.initial_step_size = 0.005;
end
if ~isfield(cfg, 'log_targets') || isempty(cfg.log_targets)
    cfg.log_targets = ["Jcost"];
end
if ~isfield(cfg, 'log_pred_clip_margin') || isempty(cfg.log_pred_clip_margin)
    cfg.log_pred_clip_margin = 0.20;
end
if ~isfield(cfg, 'pred_clip_margin') || isempty(cfg.pred_clip_margin)
    cfg.pred_clip_margin = 0.15;
end

if ~isfield(cfg, 'curve_layer_sizes') || isempty(cfg.curve_layer_sizes)
    cfg.curve_layer_sizes = [48 24];
end
if ~isfield(cfg, 'curve_iteration_limit') || isempty(cfg.curve_iteration_limit)
    cfg.curve_iteration_limit = 180;
end
if ~isfield(cfg, 'curve_lambda') || isempty(cfg.curve_lambda)
    cfg.curve_lambda = 1e-4;
end
if ~isfield(cfg, 'curve_initial_step_size') || isempty(cfg.curve_initial_step_size)
    cfg.curve_initial_step_size = 0.005;
end
if ~isfield(cfg, 'curve_pca_var_percent') || isempty(cfg.curve_pca_var_percent)
    cfg.curve_pca_var_percent = 99.5;
end
if ~isfield(cfg, 'curve_pca_maxcomp') || isempty(cfg.curve_pca_maxcomp)
    cfg.curve_pca_maxcomp = 12;
end
if ~isfield(cfg, 'curve_coef_clip_margin') || isempty(cfg.curve_coef_clip_margin)
    cfg.curve_coef_clip_margin = 0.20;
end

if ~isfield(cfg, 'shap_background_n') || isempty(cfg.shap_background_n)
    cfg.shap_background_n = 90;
end
if ~isfield(cfg, 'shap_query_n') || isempty(cfg.shap_query_n)
    cfg.shap_query_n = 16;
end
if ~isfield(cfg, 'shap_num_subsets_interv') || isempty(cfg.shap_num_subsets_interv)
    cfg.shap_num_subsets_interv = 260;
end
if ~isfield(cfg, 'shap_num_subsets_cond') || isempty(cfg.shap_num_subsets_cond)
    cfg.shap_num_subsets_cond = 260;
end

if ~isfield(cfg, 'objective_names') || isempty(cfg.objective_names)
    cfg.objective_names = ["Jcost" "Jsupp" "Jvar"];
end

if ~isfield(cfg, 'use_val_for_training') || isempty(cfg.use_val_for_training)
    cfg.use_val_for_training = true;
end
if ~isfield(cfg, 'force_reexport') || isempty(cfg.force_reexport)
    cfg.force_reexport = false;
end
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end
