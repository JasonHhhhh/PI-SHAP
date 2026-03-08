function out = run_seed11_dt1_light_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_min(cfg);
ensure_dir_min(cfg.data_dir);
ensure_dir_min(cfg.model_dir);
ensure_dir_min(cfg.plot_dir);
ensure_dir_min(cfg.report_dir);

if exist(cfg.dataset_file, 'file') ~= 2
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
    'X', 'Y_obj', 'Y_flow', 'feature_names', 'target_names_obj', 'target_names_flow', ...
    'train_idx', 'val_idx', 'test_idx');

X = S.X;
Y = [S.Y_obj S.Y_flow];
target_names = [string(S.target_names_obj(:)); string(S.target_names_flow(:))];
feature_names = string(S.feature_names(:));

if cfg.use_val_for_training
    train_use = sort([S.train_idx(:); S.val_idx(:)]);
else
    train_use = S.train_idx(:);
end
test_use = S.test_idx(:);

X_train = X(train_use, :);
X_test = X(test_use, :);

n_targets = size(Y, 2);
models = cell(n_targets, 1);

Yhat_train = zeros(numel(train_use), n_targets);
Yhat_test = zeros(numel(test_use), n_targets);

metric_target = strings(2 * n_targets, 1);
metric_split = strings(2 * n_targets, 1);
metric_r2 = zeros(2 * n_targets, 1);
metric_rmse = zeros(2 * n_targets, 1);
metric_mae = zeros(2 * n_targets, 1);

rng(cfg.rng_seed, 'twister');

for j = 1:n_targets
    y_train = Y(train_use, j);
    y_test = Y(test_use, j);

    use_log_target = any(strcmp(target_names(j), cfg.log_targets));
    if use_log_target
        y_train_fit = log10(max(y_train, eps));
    else
        y_train_fit = y_train;
    end

    mdl = fitrnet(X_train, y_train_fit, ...
        'LayerSizes', cfg.layer_sizes, ...
        'Activations', 'relu', ...
        'Standardize', true, ...
        'Lambda', cfg.lambda, ...
        'InitialStepSize', cfg.initial_step_size, ...
        'IterationLimit', cfg.iteration_limit);

    models{j} = mdl;

    yp_train_fit = predict(mdl, X_train);
    yp_test_fit = predict(mdl, X_test);

    if use_log_target
        yp_train = 10 .^ yp_train_fit;
        yp_test = 10 .^ yp_test_fit;
    else
        yp_train = yp_train_fit;
        yp_test = yp_test_fit;
    end

    Yhat_train(:, j) = yp_train;
    Yhat_test(:, j) = yp_test;

    [r2_tr, rmse_tr, mae_tr] = regression_metrics_min(y_train, yp_train);
    [r2_te, rmse_te, mae_te] = regression_metrics_min(y_test, yp_test);

    r0 = 2 * (j - 1) + 1;
    metric_target(r0) = target_names(j);
    metric_split(r0) = "train";
    metric_r2(r0) = r2_tr;
    metric_rmse(r0) = rmse_tr;
    metric_mae(r0) = mae_tr;

    metric_target(r0 + 1) = target_names(j);
    metric_split(r0 + 1) = "test";
    metric_r2(r0 + 1) = r2_te;
    metric_rmse(r0 + 1) = rmse_te;
    metric_mae(r0 + 1) = mae_te;

    fprintf('Trained %-10s | test R2=%.4f RMSE=%.4e MAE=%.4e | log_target=%d\n', target_names(j), r2_te, rmse_te, mae_te, use_log_target);
end

metrics_tbl = table(metric_target, metric_split, metric_r2, metric_rmse, metric_mae, ...
    'VariableNames', {'Target', 'Split', 'R2', 'RMSE', 'MAE'});

metrics_csv = fullfile(cfg.report_dir, 'seed11_dt1_light_metrics.csv');
writetable(metrics_tbl, metrics_csv);

models_file = fullfile(cfg.model_dir, 'seed11_dt1_light_models.mat');
save(models_file, 'models', 'target_names', 'feature_names', 'cfg', '-v7.3');

pred_file = fullfile(cfg.model_dir, 'seed11_dt1_light_predictions.mat');
Y_test = Y(test_use, :); %#ok<NASGU>
save(pred_file, 'Y_test', 'Yhat_test', 'target_names', 'test_use', '-v7');

plot_objective_parity_min(cfg.plot_dir, Y(test_use, 1:3), Yhat_test(:, 1:3), target_names(1:3), metrics_tbl);
plot_flow_parity_min(cfg.plot_dir, Y(test_use, 4:end), Yhat_test(:, 4:end), target_names(4:end), metrics_tbl);

[shap_maps, shap_summary_tbl] = run_objective_shap_min(models(1:3), X, train_use, test_use, feature_names, cfg);

shap_csv = fullfile(cfg.report_dir, 'seed11_dt1_light_shap_summary.csv');
writetable(shap_summary_tbl, shap_csv);

plot_shap_action_heatmaps_min(cfg.plot_dir, shap_maps, target_names(1:3));
plot_shap_time_comp_summary_min(cfg.plot_dir, shap_maps, target_names(1:3));

report_md = fullfile(cfg.report_dir, 'SEED11_DT1_LIGHT_REPORT.md');
write_report_md_min(report_md, cfg, X, Y, train_use, test_use, metrics_tbl, shap_summary_tbl);

out = struct();
out.dataset_file = cfg.dataset_file;
out.models_file = models_file;
out.metrics_csv = metrics_csv;
out.shap_csv = shap_csv;
out.report_md = report_md;
out.plot_dir = cfg.plot_dir;

fprintf('Done. Report: %s\n', report_md);
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

sgtitle('Objective parity on test set (light surrogate)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'objective_parity_test.png'), 250);
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

sgtitle('Key-flow parity on test set (light surrogate)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'flow_parity_test.png'), 250);
close(f);
end

function [shap_maps, summary_tbl] = run_objective_shap_min(models_obj, X, train_use, test_use, feature_names, cfg)
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
    shp = shapley(models_obj{j}, X(bg_pick, :), ...
        'QueryPoints', X(q_pick, :), ...
        'MaxNumSubsets', cfg.shap_num_subsets);

    sv = shp.ShapleyValues.ShapleyValue;   % [n_features, n_q]
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
    metric_name(r) = "pin_total";
    objective_name(r) = cfg.objective_names(j);
    value(r) = sum(pin_abs);
end

summary_tbl = table(metric_name(1:r), objective_name(1:r), value(1:r), ...
    'VariableNames', {'Metric', 'Objective', 'MeanAbsSHAP'});
end

function plot_shap_action_heatmaps_min(plot_dir, shap_maps, names)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1500 460], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for j = 1:3
    ax = nexttile;
    imagesc(shap_maps(:, :, j));
    xlabel('Compressor index');
    ylabel('Time step (1h grid)');
    title(sprintf('%s mean(|SHAP|)', names(j)));
    set(ax, 'YDir', 'normal', 'FontSize', 10, 'LineWidth', 1.0);
    xticks(1:size(shap_maps, 2));
    yticks(1:size(shap_maps, 1));
    colorbar;
end

sgtitle('Action SHAP heatmaps (time x compressor)', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'shap_action_heatmap_objectives.png'), 260);
close(f);
end

function plot_shap_time_comp_summary_min(plot_dir, shap_maps, names)
n_t = size(shap_maps, 1);
n_c = size(shap_maps, 2);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1350 640], 'Renderer', 'painters');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold on;
for j = 1:3
    plot(1:n_t, sum(shap_maps(:, :, j), 2), 'LineWidth', 1.8, 'DisplayName', names(j));
end
xlabel('Time step');
ylabel('Sum mean(|SHAP|) over compressors');
title('Action importance across time');
grid on;
legend('Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
bar_data = zeros(n_c, 3);
for j = 1:3
    bar_data(:, j) = sum(shap_maps(:, :, j), 1)';
end
bar(bar_data);
xlabel('Compressor index');
ylabel('Sum mean(|SHAP|) over time');
title('Action importance across compressors');
grid on;
legend(cellstr(names), 'Location', 'best');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('SHAP summaries for action sequence', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'shap_action_time_comp_summary.png'), 260);
close(f);
end

function write_report_md_min(md_file, cfg, X, Y, train_use, test_use, metrics_tbl, shap_tbl)
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write report markdown: %s', md_file);
end

fprintf(fid, '# Seed11 dt=1h neural surrogate (light v1)\n\n');
fprintf(fid, '## Setup\n\n');
fprintf(fid, '- data source: `%s`\n', strrep(cfg.manifest_csv, '\\', '/'));
fprintf(fid, '- filter: `Seed=11`, `ActionDt_hr=1.0`, `OK=1`\n');
fprintf(fid, '- inlet pressure noise sigma: `%.4f`\n', cfg.noise_sigma);
fprintf(fid, '- noise repeats per base sample: `%d`\n', cfg.noise_repeats);
fprintf(fid, '- model: `fitrnet` per target, layers=`%s`, iteration limit=`%d`\n\n', mat2str(cfg.layer_sizes), cfg.iteration_limit);
fprintf(fid, '- log-transformed targets during training: `%s`\n\n', strjoin(cellstr(cfg.log_targets), ', '));

fprintf(fid, '## Data shape\n\n');
fprintf(fid, '- samples (after augmentation): `%d`\n', size(X, 1));
fprintf(fid, '- input features: `%d`\n', size(X, 2));
fprintf(fid, '- output targets: `%d` (3 objectives + key flow indicators)\n', size(Y, 2));
fprintf(fid, '- train samples: `%d`\n', numel(train_use));
fprintf(fid, '- test samples: `%d`\n\n', numel(test_use));

fprintf(fid, '## Test metrics\n\n');
fprintf(fid, '| Target | R2 | RMSE | MAE |\n');
fprintf(fid, '|---|---:|---:|---:|\n');
mk = metrics_tbl(metrics_tbl.Split == "test", :);
for i = 1:height(mk)
    fprintf(fid, '| %s | %.4f | %.6g | %.6g |\n', mk.Target(i), mk.R2(i), mk.RMSE(i), mk.MAE(i));
end

fprintf(fid, '\n## SHAP outputs\n\n');
fprintf(fid, '- objective SHAP computed with background `%d` and query `%d` points\n', cfg.shap_background_n, cfg.shap_query_n);
fprintf(fid, '- SHAP summary CSV: `seed11_dt1_light_shap_summary.csv`\n');
fprintf(fid, '- focus: action feature impacts by time/compressor for `Jcost`, `Jsupp`, `Jvar`\n\n');

fprintf(fid, '## Plots\n\n');
fprintf(fid, '- `NNs/plots/objective_parity_test.png`\n');
fprintf(fid, '- `NNs/plots/flow_parity_test.png`\n');
fprintf(fid, '- `NNs/plots/shap_action_heatmap_objectives.png`\n');
fprintf(fid, '- `NNs/plots/shap_action_time_comp_summary.png`\n\n');

fprintf(fid, '## Notes\n\n');
fprintf(fid, '- This is a lightweight replacement prototype under one boundary condition only.\n');
fprintf(fid, '- Flow outputs are reduced key indicators (not full PDE state reconstruction yet).\n');
fprintf(fid, '- Next step can expand to full trajectory/state decoding and stricter physics constraints.\n');

fclose(fid);
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
if ~isfield(cfg, 'manifest_csv') || isempty(cfg.manifest_csv)
    cfg.manifest_csv = fullfile(shap_root, 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'manifest.csv');
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

if ~isfield(cfg, 'dataset_file') || isempty(cfg.dataset_file)
    cfg.dataset_file = fullfile(nns_dir, 'data', 'seed11_dt1_nn_light_dataset.mat');
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
if ~isfield(cfg, 'use_val_for_training') || isempty(cfg.use_val_for_training)
    cfg.use_val_for_training = true;
end

if ~isfield(cfg, 'shap_background_n') || isempty(cfg.shap_background_n)
    cfg.shap_background_n = 120;
end
if ~isfield(cfg, 'shap_query_n') || isempty(cfg.shap_query_n)
    cfg.shap_query_n = 32;
end
if ~isfield(cfg, 'shap_num_subsets') || isempty(cfg.shap_num_subsets)
    cfg.shap_num_subsets = 280;
end
if ~isfield(cfg, 'objective_names') || isempty(cfg.objective_names)
    cfg.objective_names = ["Jcost" "Jsupp" "Jvar"];
end
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end
