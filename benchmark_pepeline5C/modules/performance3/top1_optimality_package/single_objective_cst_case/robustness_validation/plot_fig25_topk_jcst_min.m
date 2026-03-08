function out = plot_fig25_topk_jcst_min()
% Plot Fig.25: TOP-K robustness for single-objective J_cst.
% Protocol: fix the same method-specific top-40 candidate pool used by
% the single-objective setting, then evaluate:
% (A) best true J_cst within top-K, and
% (B) mean true J_cst within top-K.

base_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(fileparts(fileparts(base_dir)))));

base_score_file = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', ...
    'tables', 'holdout_case_scores.csv');
base_corr_file = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', ...
    'tables', 'holdout_score_correlation.csv');

if exist(base_score_file, 'file') ~= 2
    error('Input score table not found: %s', base_score_file);
end
if exist(base_corr_file, 'file') ~= 2
    error('Input corr table not found: %s', base_corr_file);
end

T_base = readtable(base_score_file);
R_base = readtable(base_corr_file);

% Robustness envelope source (run-to-run variability under same protocol)
var_score_files = {
    base_score_file, ...
    fullfile(base_dir, '..', 'runs', 'seed_train23_test11_37_dt1p0', 'tables', 'holdout_case_scores.csv'), ...
    fullfile(base_dir, '..', 'runs', 'seed_train37_test11_23_dt1p0', 'tables', 'holdout_case_scores.csv') ...
};
var_corr_files = {
    base_corr_file, ...
    fullfile(base_dir, '..', 'runs', 'seed_train23_test11_37_dt1p0', 'tables', 'holdout_score_correlation.csv'), ...
    fullfile(base_dir, '..', 'runs', 'seed_train37_test11_23_dt1p0', 'tables', 'holdout_score_correlation.csv') ...
};

methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
score_cols = ["OriScoreJcost", "CondScoreJcost", "PIScoreJcost"];
method_colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
method_markers = {'o', 's', '^'};
K = 1:40;
stage1_topn = 40;
stage2_proxy_weight = 0.20;

n_m = numel(methods);
n_k = numel(K);

prof_base = compute_protocol_topk_profiles(T_base, R_base, methods, score_cols, K, stage1_topn, stage2_proxy_weight);
best_cost = prof_base.best;
mean_cost = prof_base.mean;
global_best = min(T_base.Jcost);
regret_best_pct = (best_cost ./ global_best - 1) * 100;
regret_mean_pct = (mean_cost ./ global_best - 1) * 100;

n_var = numel(var_score_files);
var_best = nan(n_m, n_k, n_var);
var_mean = nan(n_m, n_k, n_var);
for r = 1:n_var
    sf = var_score_files{r};
    cf = var_corr_files{r};
    if exist(sf, 'file') ~= 2 || exist(cf, 'file') ~= 2
        continue;
    end
    Ts = readtable(sf);
    Rc = readtable(cf);
    prof_r = compute_protocol_topk_profiles(Ts, Rc, methods, score_cols, K, stage1_topn, stage2_proxy_weight);
    var_best(:, :, r) = prof_r.best;
    var_mean(:, :, r) = prof_r.mean;
end

best_lo = min(var_best, [], 3, 'omitnan');
best_hi = max(var_best, [], 3, 'omitnan');
best_lo = min(best_lo, best_cost);
best_hi = max(best_hi, best_cost);

spread_best = best_hi - best_lo;
mean_lo = min(var_mean, [], 3, 'omitnan');
mean_hi = max(var_mean, [], 3, 'omitnan');
mean_lo = min(mean_lo, mean_cost);
mean_hi = max(mean_hi, mean_cost);

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [80 80 1500 700]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
ax2 = nexttile(tl, 2);

hold(ax1, 'on');
hold(ax2, 'on');

scale = 1e11;
for i = 1:n_m
    x = K;
    marker_idx = unique([1, 5, 10, 20, 30, 40]);
    marker_idx = marker_idx(marker_idx <= n_k);
    plot(ax1, K, best_cost(i, :) / scale, '-', ...
        'Color', method_colors(i, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{i}, ...
        'MarkerFaceColor', method_colors(i, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'MarkerIndices', marker_idx, ...
        'DisplayName', char(methods(i)));
    plot(ax2, K, mean_cost(i, :) / scale, '-', ...
        'Color', method_colors(i, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{i}, ...
        'MarkerFaceColor', method_colors(i, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'MarkerIndices', marker_idx, ...
        'DisplayName', char(methods(i)));

end

xlim(ax1, [min(K) max(K)]);
xlim(ax2, [min(K) max(K)]);
xticks(ax1, [1 5 10 15 20 25 30 35 40]);
xticks(ax2, [1 5 10 15 20 25 30 35 40]);

grid(ax1, 'on');
grid(ax2, 'on');
box(ax1, 'on');
box(ax2, 'on');
set(ax1, 'LineWidth', 1.6, 'FontSize', 20);
set(ax2, 'LineWidth', 1.6, 'FontSize', 20);

xlabel(ax1, 'TOP-$K$ size within fixed pool', 'Interpreter', 'latex', 'FontSize', 24);
xlabel(ax2, 'TOP-$K$ size within fixed pool', 'Interpreter', 'latex', 'FontSize', 24);
ylabel(ax1, 'Best true $J_{cst}$ in TOP-$K$ ($\times 10^{11}$)', ...
    'Interpreter', 'latex', 'FontSize', 24);
ylabel(ax2, 'Mean true $J_{cst}$ in TOP-$K$ ($\times 10^{11}$)', ...
    'Interpreter', 'latex', 'FontSize', 24);
title(ax1, '(a) Best-in-TOP-K', 'FontSize', 24, 'FontWeight', 'bold');
title(ax2, '(b) Mean-in-TOP-K', 'FontSize', 24, 'FontWeight', 'bold');
lg1 = legend(ax1, 'Location', 'northeast', 'FontSize', 18);
lg2 = legend(ax2, 'Location', 'northeast', 'FontSize', 18);
lg1.AutoUpdate = 'off';
lg2.AutoUpdate = 'off';

title(tl, 'TOP-K Robustness on Single-Objective Jcst', ...
    'FontSize', 28, 'FontWeight', 'bold');

% Output paths
plot_dir = fullfile(base_dir, 'plots');
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end
if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end

svg_a = fullfile(plot_dir, 'Fig25_topk_jcst_robustness.svg');
png_a = fullfile(plot_dir, 'Fig25_topk_jcst_robustness.png');
svg_b = fullfile(fig_dir, 'Fig25_topk_jcst_robustness.svg');
png_b = fullfile(fig_dir, 'Fig25_topk_jcst_robustness.png');

print(fig, svg_a, '-dsvg');
exportgraphics(fig, png_a, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_b, '-dsvg');
exportgraphics(fig, png_b, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

% Export summary table for writing
rows = repmat(struct('Method', "", 'K', nan, ...
    'BestJcostInTopK', nan, 'MeanJcostInTopK', nan, ...
    'GlobalBestJcost', nan, ...
    'RegretBestPct', nan, 'RegretMeanPct', nan, ...
    'BestEnvelopeMinJcost', nan, 'BestEnvelopeMaxJcost', nan, ...
    'MeanEnvelopeMinJcost', nan, 'MeanEnvelopeMaxJcost', nan), 0, 1);
for i = 1:n_m
    for j = 1:n_k
        r = struct();
        r.Method = methods(i);
        r.K = K(j);
        r.BestJcostInTopK = best_cost(i, j);
        r.MeanJcostInTopK = mean_cost(i, j);
        r.GlobalBestJcost = global_best;
        r.RegretBestPct = regret_best_pct(i, j);
        r.RegretMeanPct = regret_mean_pct(i, j);
        r.BestEnvelopeMinJcost = best_lo(i, j);
        r.BestEnvelopeMaxJcost = best_hi(i, j);
        r.MeanEnvelopeMinJcost = mean_lo(i, j);
        r.MeanEnvelopeMaxJcost = mean_hi(i, j);
        rows(end+1, 1) = r; %#ok<AGROW>
    end
end
S = struct2table(rows);
summary_csv = fullfile(base_dir, 'tables', 'fig25_topk_jcst_summary.csv');
writetable(S, summary_csv);

out = struct();
out.input_table = base_score_file;
out.summary_csv = summary_csv;
out.svg_plot = svg_a;
out.png_plot = png_a;
out.svg_fig = svg_b;
out.png_fig = png_b;

fprintf('Fig25 generated: %s\n', out.svg_fig);
fprintf('Summary table: %s\n', out.summary_csv);
end

function prof = compute_protocol_topk_profiles(T, R, methods, score_cols, K, stage1_topn, proxy_w)
n_m = numel(methods);
n_k = numel(K);
best_m = nan(n_m, n_k);
mean_m = nan(n_m, n_k);

for i = 1:n_m
    m = methods(i);
    sc = T.(score_cols(i));
    corr = lookup_corr(R, m, "Jcost");
    sgn = 1;
    if corr < 0
        sgn = -1;
    end

    proxy = normalize01(sgn * sc);
    [~, ord] = sort(proxy, 'ascend');
    topn = min(stage1_topn, numel(proxy));
    sel = ord(1:topn);

    target_loss = normalize01(T.Jcost(sel));
    proxy_loss = normalize01(proxy(sel));
    comp = target_loss + proxy_w * proxy_loss;
    [~, ord2] = sort(comp, 'ascend');
    y = T.Jcost(sel(ord2));

    for j = 1:n_k
        kk = min(K(j), numel(y));
        best_m(i, j) = min(y(1:kk));
        mean_m(i, j) = mean(y(1:kk));
    end
end
prof = struct('best', best_m, 'mean', mean_m);
end

function c = lookup_corr(R, method_name, obj_name)
idx = strcmp(string(R.Method), string(method_name)) & strcmp(string(R.Objective), string(obj_name));
if ~any(idx)
    c = 1;
else
    c = R.PearsonCorr(find(idx, 1, 'first'));
end
if ~isfinite(c)
    c = 1;
end
end

function y = normalize01(x)
x = x(:);
good = isfinite(x);
y = zeros(size(x));
if ~any(good)
    return;
end
g = x(good);
mn = min(g);
mx = max(g);
if abs(mx - mn) <= eps
    y(good) = 0;
    return;
end
y(good) = (g - mn) ./ (mx - mn);
end
