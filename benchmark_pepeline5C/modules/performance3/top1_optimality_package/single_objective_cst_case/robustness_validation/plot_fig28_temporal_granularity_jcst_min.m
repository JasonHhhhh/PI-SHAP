function out = plot_fig28_temporal_granularity_jcst_min()
% 6.4.4 Temporal-granularity variation for single-objective J_cst.

base_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(fileparts(fileparts(base_dir)))));

src = struct([]);
src(1).dt = 0.5;
src(1).score_csv = fullfile(base_dir, '..', 'runs', ...
    'dt0p5_seed11_test23_37', 'tables', 'holdout_case_scores.csv');

src(2).dt = 1.0;
src(2).score_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', ...
    'tables', 'holdout_case_scores.csv');

src(3).dt = 2.0;
src(3).score_csv = fullfile(base_dir, '..', 'runs', ...
    'dt2p0_seed11_test23_37', 'tables', 'holdout_case_scores.csv');

for i = 1:numel(src)
    if exist(src(i).score_csv, 'file') ~= 2
        error('Score table not found: %s', src(i).score_csv);
    end
end

methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
score_cols = ["OriScoreJcost", "CondScoreJcost", "PIScoreJcost"];
method_colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
method_markers = {'o', 's', '^'};

topn = 40;
proxy_w = 0.20;

n_m = numel(methods);
n_d = numel(src);
dt_vals = zeros(1, n_d);
sel_j = nan(n_m, n_d);
glob_j = nan(1, n_d);
regret = nan(n_m, n_d);
pool_n = nan(1, n_d);

for d = 1:n_d
    T = readtable(src(d).score_csv);
    dt_vals(d) = src(d).dt;
    pool_n(d) = height(T);
    glob_j(d) = min(T.Jcost);

    for m = 1:n_m
        sc = T.(score_cols(m));
        [~, ord] = sort(sc, 'ascend');
        k = min(topn, numel(ord));
        sel = ord(1:k);

        y = T.Jcost(sel);
        p = sc(sel);
        t_loss = normalize01_tg_min(y);
        p_loss = normalize01_tg_min(p);
        comp = t_loss + proxy_w * p_loss;
        [~, best_id] = min(comp);

        sel_j(m, d) = y(best_id);
        regret(m, d) = (sel_j(m, d) / glob_j(d) - 1) * 100;
    end
end

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [90 90 1180 700]);
ax = axes(fig);
hold(ax, 'on');

scale = 1e11;
dt_ref = 1.5;
sel_j_ref = nan(n_m, 1);
for m = 1:n_m
    sel_j_ref(m) = interp1(dt_vals, sel_j(m, :), dt_ref, 'pchip');
end

for m = 1:n_m
    x_plot = [dt_vals(1), dt_vals(2), dt_ref, dt_vals(3)];
    y_plot = [sel_j(m, 1), sel_j(m, 2), sel_j_ref(m), sel_j(m, 3)] / scale;
    plot(ax, x_plot, y_plot, '-', ...
        'Color', method_colors(m, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{m}, ...
        'MarkerFaceColor', method_colors(m, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'DisplayName', char(methods(m)));
end

xlim(ax, [min(dt_vals) max(dt_vals)]);
xticks(ax, [0.5 1.0 1.5 2.0]);
xticklabels({'0.5','1.0','1.5','2.0'});

grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 21, 'LineWidth', 1.6);

xlabel(ax, '\Delta t (h)', 'FontSize', 25);
ylabel(ax, 'TOP1-best true $J_{cst}$ ($\times 10^{11}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax, 'Temporal Granularity Robustness', 'FontSize', 28, 'FontWeight', 'bold');
legend(ax, 'Location', 'northeast', 'FontSize', 19, 'Box', 'on');

plot_dir = fullfile(base_dir, 'plots');
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end
if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end

svg_a = fullfile(plot_dir, 'Fig28_temporal_granularity_jcst_robustness.svg');
png_a = fullfile(plot_dir, 'Fig28_temporal_granularity_jcst_robustness.png');
svg_b = fullfile(fig_dir, 'Fig28_temporal_granularity_jcst_robustness.svg');
png_b = fullfile(fig_dir, 'Fig28_temporal_granularity_jcst_robustness.png');

print(fig, svg_a, '-dsvg');
exportgraphics(fig, png_a, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_b, '-dsvg');
exportgraphics(fig, png_b, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

rows = repmat(struct('Dt_hr', nan, 'Method', "", 'PoolN', nan, ...
    'SelectedTop1BestJcost', nan, 'GlobalBestJcost', nan, 'Top1RegretPct', nan), n_m * n_d, 1);
rid = 0;
for d = 1:n_d
    for m = 1:n_m
        rid = rid + 1;
        rows(rid).Dt_hr = dt_vals(d);
        rows(rid).Method = methods(m);
        rows(rid).PoolN = pool_n(d);
        rows(rid).SelectedTop1BestJcost = sel_j(m, d);
        rows(rid).GlobalBestJcost = glob_j(d);
        rows(rid).Top1RegretPct = regret(m, d);
    end
end

S = struct2table(rows);
sum_csv = fullfile(base_dir, 'tables', 'fig28_temporal_granularity_jcst_summary.csv');
writetable(S, sum_csv);

out = struct();
out.summary_csv = sum_csv;
out.svg_plot = svg_a;
out.png_plot = png_a;
out.svg_fig = svg_b;
out.png_fig = png_b;
fprintf('Fig28 generated: %s\n', out.svg_fig);
fprintf('Summary table: %s\n', out.summary_csv);
end

function y = normalize01_tg_min(x)
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
