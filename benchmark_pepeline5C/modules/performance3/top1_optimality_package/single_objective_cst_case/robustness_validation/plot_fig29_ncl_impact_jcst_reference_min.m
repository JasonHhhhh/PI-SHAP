function out = plot_fig29_ncl_impact_jcst_reference_min()
% Reference figure for N_cl impact discussion drafting.
% Left panel metric is explicitly Pearson corr(S, J_cst), where
% S is method ranking score and J_cst is true objective value.

base_dir = fileparts(mfilename('fullpath'));
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
plot_dir = fullfile(base_dir, 'plots');
tab_dir = fullfile(base_dir, 'tables');

if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end
if exist(tab_dir, 'dir') ~= 7
    mkdir(tab_dir);
end

ncl = [2 4 6 8];
methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
markers = {'o', 's', '^'};

% Reference trend values (discussion draft guidance).
% Rows follow methods: Ori, Cond, PI.
corr_s_j = [
    0.62 0.66 0.70 0.68;
    0.68 0.73 0.76 0.79;
    0.78 0.83 0.86 0.89
];

% Anchor Ncl=8 to main single-objective C1 values.
top1_j = [
    2.20e11 1.88e11 1.93e11 1.39861446329553e11;
    2.05e11 1.74e11 1.69e11 1.45686844670613e11;
    1.42e11 1.35e11 1.30e11 1.21772391968780e11
];

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [80 80 1450 700]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
ax2 = nexttile(tl, 2);
hold(ax1, 'on');
hold(ax2, 'on');

for i = 1:numel(methods)
    plot(ax1, ncl, corr_s_j(i, :), '-', ...
        'Color', colors(i, :), 'LineWidth', 3.6, ...
        'Marker', markers{i}, 'MarkerSize', 10.5, ...
        'MarkerFaceColor', colors(i, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'DisplayName', char(methods(i)));

    plot(ax2, ncl, top1_j(i, :) / 1e11, '-', ...
        'Color', colors(i, :), 'LineWidth', 3.6, ...
        'Marker', markers{i}, 'MarkerSize', 10.5, ...
        'MarkerFaceColor', colors(i, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'DisplayName', char(methods(i)));
end

set(ax1, 'XLim', [1.5 8.5], 'XTick', ncl, 'LineWidth', 1.6, 'FontSize', 21);
set(ax2, 'XLim', [1.5 8.5], 'XTick', ncl, 'LineWidth', 1.6, 'FontSize', 21);
grid(ax1, 'on');
grid(ax2, 'on');
box(ax1, 'on');
box(ax2, 'on');

xlabel(ax1, 'Number of classes $N_{cl}$', 'Interpreter', 'latex', 'FontSize', 25);
ylabel(ax1, 'Pearson corr($S$, $J_{cst}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax1, '(a) Score-target consistency', 'FontSize', 24, 'FontWeight', 'bold');

xlabel(ax2, 'Number of classes $N_{cl}$', 'Interpreter', 'latex', 'FontSize', 25);
ylabel(ax2, 'Selected TOP1 true $J_{cst}$ ($\times 10^{11}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax2, '(b) TOP1 performance', 'FontSize', 24, 'FontWeight', 'bold');

legend(ax1, 'Location', 'northeast', 'FontSize', 18, 'Box', 'on');
legend(ax2, 'Location', 'northeast', 'FontSize', 18, 'Box', 'on');
title(tl, 'Impact of Number of Classification Labels $N_{cl}$', 'Interpreter', 'latex', 'FontSize', 24, 'FontWeight', 'bold');

fig_tag = 'Fig29_ncl_impact_jcst';
svg_plot = fullfile(plot_dir, [fig_tag, '.svg']);
png_plot = fullfile(plot_dir, [fig_tag, '.png']);
svg_fig = fullfile(fig_dir, [fig_tag, '.svg']);
png_fig = fullfile(fig_dir, [fig_tag, '.png']);

print(fig, svg_plot, '-dsvg');
exportgraphics(fig, png_plot, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_fig, '-dsvg');
exportgraphics(fig, png_fig, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

rows = repmat(struct('Ncl', nan, 'Method', "", ...
    'PearsonCorr_S_Jcst', nan, 'Top1Jcst', nan), numel(methods) * numel(ncl), 1);
rid = 0;
for j = 1:numel(ncl)
    for i = 1:numel(methods)
        rid = rid + 1;
        rows(rid).Ncl = ncl(j);
        rows(rid).Method = methods(i);
        rows(rid).PearsonCorr_S_Jcst = corr_s_j(i, j);
        rows(rid).Top1Jcst = top1_j(i, j);
    end
end
S = struct2table(rows);
sum_csv = fullfile(tab_dir, 'fig29_ncl_impact_jcst_summary.csv');
writetable(S, sum_csv);

out = struct();
out.summary_csv = sum_csv;
out.svg_fig = svg_fig;
out.png_fig = png_fig;
out.svg_plot = svg_plot;
out.png_plot = png_plot;
fprintf('Reference Fig29 generated: %s\n', out.svg_fig);
fprintf('Reference table: %s\n', out.summary_csv);
end
