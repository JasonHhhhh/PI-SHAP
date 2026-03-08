function out = plot_fig26_seed_variation_jcst_min()
% Seed-pool variation under a fixed TOP1-best selection rule for J_cst.

base_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(fileparts(fileparts(base_dir)))));

runs = struct([]);
runs(1).pool = "Pool-A";
runs(1).score_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', ...
    'tables', 'holdout_case_scores.csv');
runs(1).corr_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', ...
    'tables', 'holdout_score_correlation.csv');

runs(2).pool = "Pool-B";
runs(2).score_csv = fullfile(base_dir, '..', 'runs', ...
    'seed_train23_test11_37_dt1p0', 'tables', 'holdout_case_scores.csv');
runs(2).corr_csv = fullfile(base_dir, '..', 'runs', ...
    'seed_train23_test11_37_dt1p0', 'tables', 'holdout_score_correlation.csv');

runs(3).pool = "Pool-C";
runs(3).score_csv = fullfile(base_dir, '..', 'runs', ...
    'seed_train37_test11_23_dt1p0', 'tables', 'holdout_case_scores.csv');
runs(3).corr_csv = fullfile(base_dir, '..', 'runs', ...
    'seed_train37_test11_23_dt1p0', 'tables', 'holdout_score_correlation.csv');

for i = 1:numel(runs)
    if exist(runs(i).score_csv, 'file') ~= 2
        error('Score table not found: %s', runs(i).score_csv);
    end
    if exist(runs(i).corr_csv, 'file') ~= 2
        error('Correlation table not found: %s', runs(i).corr_csv);
    end
end

methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
score_cols = ["OriScoreJcost", "CondScoreJcost", "PIScoreJcost"];
method_colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
method_markers = {'o', 's', '^'};

topn = 40;
proxy_w = 0.20;
n_resample = 400;
sub_frac = 1.00;
base_seed = 20260306;

n_m = numel(methods);
n_r = numel(runs);
x = 1:n_r;
best_full = nan(n_m, n_r);
regret_full = nan(n_m, n_r);
best_med = nan(n_m, n_r);
best_lo = nan(n_m, n_r);
best_hi = nan(n_m, n_r);
pool_n = nan(1, n_r);
pool_best = nan(1, n_r);

for r = 1:n_r
    T = readtable(runs(r).score_csv);
    C = readtable(runs(r).corr_csv);

    pool_n(r) = height(T);
    pool_best(r) = min(T.Jcost);

    for m = 1:n_m
        best_full(m, r) = eval_top1best_jcst(T, C, methods(m), score_cols(m), topn, proxy_w);
        regret_full(m, r) = (best_full(m, r) / pool_best(r) - 1) * 100;

        vals = nan(n_resample, 1);
        n_sub = max(topn + 20, round(sub_frac * height(T)));
        n_sub = min(n_sub, height(T));
        for b = 1:n_resample
            rng(base_seed + 1000 * r + b, 'twister');
            idx = randi(height(T), n_sub, 1);
            Tb = T(idx, :);
            vals(b) = eval_top1best_jcst(Tb, C, methods(m), score_cols(m), topn, proxy_w);
        end
        vals = vals(isfinite(vals));
        best_med(m, r) = quantile_linear(vals, 0.50);
        best_lo(m, r) = quantile_linear(vals, 0.025);
        best_hi(m, r) = quantile_linear(vals, 0.975);
    end
end

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [90 90 1180 700]);
ax = axes(fig);
hold(ax, 'on');

scale = 1e11;
for m = 1:n_m
    y = best_med(m, :) / scale;
    y_lo = best_lo(m, :) / scale;
    y_hi = best_hi(m, :) / scale;
    plot(ax, x, y, '-', ...
        'Color', method_colors(m, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{m}, ...
        'MarkerFaceColor', method_colors(m, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'DisplayName', char(methods(m)));

    e = errorbar(ax, x, y, y - y_lo, y_hi - y, 'LineStyle', 'none', ...
        'Color', method_colors(m, :), 'LineWidth', 1.8, 'HandleVisibility', 'off');
    if isprop(e, 'CapSize')
        e.CapSize = 11;
    end
end

xlim(ax, [0.75, n_r + 0.25]);
xticks(ax, x);
xticklabels(ax, string({runs.pool}));

grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 21, 'LineWidth', 1.6);

xlabel(ax, 'Seed-varied candidate pool', 'FontSize', 25);
ylabel(ax, 'TOP1-best true $J_{cst}$ ($\times 10^{11}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax, 'Seed variation under fixed TOP1-best rule (95% interval)', 'FontSize', 28, 'FontWeight', 'bold');
legend(ax, 'Location', 'northeast', 'FontSize', 19, 'Box', 'on');

plot_dir = fullfile(base_dir, 'plots');
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end
if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end

svg_a = fullfile(plot_dir, 'Fig26_seed_variation_jcst_robustness.svg');
png_a = fullfile(plot_dir, 'Fig26_seed_variation_jcst_robustness.png');
svg_b = fullfile(fig_dir, 'Fig26_seed_variation_jcst_robustness.svg');
png_b = fullfile(fig_dir, 'Fig26_seed_variation_jcst_robustness.png');

print(fig, svg_a, '-dsvg');
exportgraphics(fig, png_a, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_b, '-dsvg');
exportgraphics(fig, png_b, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

rows = repmat(struct('Pool', "", 'Method', "", 'N', nan, ...
    'Top1BestJcost_FullPool', nan, ...
    'Top1BestJcost_Median', nan, 'Top1BestJcost_CI95_Low', nan, 'Top1BestJcost_CI95_High', nan, ...
    'PoolGlobalBestJcost_FullPool', nan, 'Top1BestRegretPct_FullPool', nan), 0, 1);
for r = 1:n_r
    for m = 1:n_m
        rr = struct();
        rr.Pool = runs(r).pool;
        rr.Method = methods(m);
        rr.N = pool_n(r);
        rr.Top1BestJcost_FullPool = best_full(m, r);
        rr.Top1BestJcost_Median = best_med(m, r);
        rr.Top1BestJcost_CI95_Low = best_lo(m, r);
        rr.Top1BestJcost_CI95_High = best_hi(m, r);
        rr.PoolGlobalBestJcost_FullPool = pool_best(r);
        rr.Top1BestRegretPct_FullPool = regret_full(m, r);
        rows(end + 1, 1) = rr; %#ok<AGROW>
    end
end
S = struct2table(rows);
summary_csv = fullfile(base_dir, 'tables', 'fig26_seed_variation_jcst_summary.csv');
writetable(S, summary_csv);

out = struct();
out.summary_csv = summary_csv;
out.svg_plot = svg_a;
out.png_plot = png_a;
out.svg_fig = svg_b;
out.png_fig = png_b;
fprintf('Fig26 generated: %s\n', out.svg_fig);
fprintf('Summary table: %s\n', out.summary_csv);
end

function c = lookup_corr(T, method_name, obj_name)
idx = strcmp(string(T.Method), string(method_name)) & strcmp(string(T.Objective), string(obj_name));
if any(idx)
    c = T.PearsonCorr(find(idx, 1, 'first'));
else
    c = 1;
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
else
    y(good) = (g - mn) ./ (mx - mn);
end
end

function best = eval_top1best_jcst(T, C, method_name, score_col, topn, proxy_w)
sc = T.(score_col);
corr = lookup_corr(C, method_name, "Jcost");
sgn = 1;
if corr < 0
    sgn = -1;
end
proxy = normalize01(sgn * sc);
[~, ord] = sort(proxy, 'ascend');
k = min(topn, numel(ord));
sel = ord(1:k);

target_loss = normalize01(T.Jcost(sel));
proxy_loss = normalize01(proxy(sel));
comp = target_loss + proxy_w * proxy_loss;
[~, ord2] = sort(comp, 'ascend');
y = T.Jcost(sel(ord2));
best = min(y);
end

function qv = quantile_linear(x, q)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    qv = nan;
    return;
end
x = sort(x, 'ascend');
if numel(x) == 1
    qv = x(1);
    return;
end
q = min(max(q, 0), 1);
pos = 1 + (numel(x) - 1) * q;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    qv = x(lo);
else
    t = pos - lo;
    qv = x(lo) * (1 - t) + x(hi) * t;
end
end
