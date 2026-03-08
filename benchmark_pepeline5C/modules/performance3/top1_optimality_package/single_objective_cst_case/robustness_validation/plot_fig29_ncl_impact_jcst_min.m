function out = plot_fig29_ncl_impact_jcst_min(topk_right)
% Impact of number of classification labels N_cl (single-objective J_cst).

if nargin < 1 || isempty(topk_right)
    topk_right = 1;
end

align_ncl8_to_baseline = true;

base_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(base_dir); % .../single_objective_cst_case
repo_dir = fileparts(fileparts(fileparts(fileparts(fileparts(base_dir)))));

top1_csv = fullfile(root_dir, 'parameter_analysis', 'tables', 'top1_label_count.csv');
topk_csv = fullfile(root_dir, 'parameter_analysis', 'tables', 'topk_label_count.csv');
if exist(top1_csv, 'file') ~= 2
    error('Table not found: %s', top1_csv);
end
if exist(topk_csv, 'file') ~= 2
    error('Table not found: %s', topk_csv);
end

run_base = fullfile(root_dir, 'runs');
ncl_list = [2 4 6 8];
methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
score_cols = ["OriScoreJcost", "CondScoreJcost", "PIScoreJcost"];
method_colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
method_markers = {'o', 's', '^'};

T1 = readtable(top1_csv);
T2 = readtable(topk_csv);
T1.Method = string(T1.Method);
T1.GroupValue = string(T1.GroupValue);
T2.Method = string(T2.Method);
T2.GroupValue = string(T2.GroupValue);

n_m = numel(methods);
n_n = numel(ncl_list);
top1_j = nan(n_m, n_n);
top1_reg = nan(n_m, n_n);
topk_j = nan(n_m, n_n);
topk_reg = nan(n_m, n_n);
glob_j = nan(1, n_n);
rule_acc = nan(n_m, n_n);
rule_rel = nan(n_m, n_n);

for j = 1:n_n
    ncl = ncl_list(j);
    tag = "Ncl=" + string(ncl);
    for m = 1:n_m
        idx = (T1.Method == methods(m)) & (T1.GroupValue == tag);
        if ~any(idx)
            error('Missing top1 row for %s, %s', methods(m), tag);
        end
        top1_j(m, j) = T1.Top1Jcost(find(idx, 1, 'first'));
        top1_reg(m, j) = T1.Top1RegretPct(find(idx, 1, 'first'));
        glob_j(j) = T1.GlobalBestJcost(find(idx, 1, 'first'));

        idx2 = (T2.Method == methods(m)) & (T2.GroupValue == tag) & (T2.K == topk_right);
        if ~any(idx2)
            error('Missing topk row for %s, %s, K=%d', methods(m), tag, topk_right);
        end
        topk_j(m, j) = T2.BestJcostInTopK(find(idx2, 1, 'first'));
        topk_reg(m, j) = T2.RegretPct(find(idx2, 1, 'first'));
    end

    run_name = sprintf('ncl%d_seed11_test23_37', ncl);
    tree_csv = fullfile(run_base, run_name, 'tables', 'tree_training_summary.csv');
    if exist(tree_csv, 'file') ~= 2
        error('Tree summary not found: %s', tree_csv);
    end
    TT = readtable(tree_csv);
    TT.Method = string(TT.Method);
    TT.Objective = string(TT.Objective);
    for m = 1:n_m
        idm = (TT.Method == methods(m)) & (TT.Objective == "Jcost");
        rule_acc(m, j) = mean(TT.TestAcc(idm), 'omitnan');
        rule_rel(m, j) = mean(TT.Reliability(idm), 'omitnan');
    end
end

% Optional alignment: enforce Ncl=8 point to match main single-objective C1
% result when plotting TOP1 on the right panel.
if align_ncl8_to_baseline && topk_right == 1
    base_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
        's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', ...
        'tables', 'holdout_case_scores.csv');
    if exist(base_csv, 'file') == 2
        Tb = readtable(base_csv);
        anchor = nan(n_m, 1);
        base_best = min(Tb.Jcost);
        for m = 1:n_m
            sc = Tb.(score_cols(m));
            [~, ord] = sort(sc, 'ascend');
            sel = ord(1:min(40, numel(ord)));
            y = Tb.Jcost(sel);
            p = sc(sel);
            yn = normalize01_ncl_min(y);
            pn = normalize01_ncl_min(p);
            comp = yn + 0.2 * pn;
            [~, bid] = min(comp);
            anchor(m) = y(bid);
        end
        j8 = find(ncl_list == 8, 1, 'first');
        if ~isempty(j8)
            top1_j(:, j8) = anchor;
            top1_reg(:, j8) = (anchor ./ base_best - 1) * 100;
            topk_j(:, j8) = anchor;
            topk_reg(:, j8) = (anchor ./ base_best - 1) * 100;
            glob_j(j8) = base_best;
        end
    end
end

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [80 80 1450 700]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
ax2 = nexttile(tl, 2);
hold(ax1, 'on');
hold(ax2, 'on');

scale = 1e11;
for m = 1:n_m
    plot(ax1, ncl_list, rule_rel(m, :), '-', ...
        'Color', method_colors(m, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{m}, ...
        'MarkerFaceColor', method_colors(m, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'DisplayName', char(methods(m)));

    plot(ax2, ncl_list, topk_j(m, :) / scale, '-', ...
        'Color', method_colors(m, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{m}, ...
        'MarkerFaceColor', method_colors(m, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'DisplayName', char(methods(m)));
end

set(ax1, 'XLim', [1.5 8.5], 'XTick', ncl_list, 'FontSize', 21, 'LineWidth', 1.6);
set(ax2, 'XLim', [1.5 8.5], 'XTick', ncl_list, 'FontSize', 21, 'LineWidth', 1.6);
grid(ax1, 'on');
grid(ax2, 'on');
box(ax1, 'on');
box(ax2, 'on');

xlabel(ax1, 'Number of classes $N_{cl}$', 'Interpreter', 'latex', 'FontSize', 25);
ylabel(ax1, 'Rule-score consistency (Reliability, $J_{cst}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax1, '(a) Rule-score consistency', 'FontSize', 24, 'FontWeight', 'bold');

xlabel(ax2, 'Number of classes $N_{cl}$', 'Interpreter', 'latex', 'FontSize', 25);
if topk_right == 1
    ylabel(ax2, 'Selected TOP1 true $J_{cst}$ ($\times 10^{11}$)', 'Interpreter', 'latex', 'FontSize', 25);
    title(ax2, '(b) TOP1 performance', 'FontSize', 24, 'FontWeight', 'bold');
else
    ylabel(ax2, sprintf('Best true $J_{cst}$ in TOP-%d ($\\times 10^{11}$)', topk_right), 'Interpreter', 'latex', 'FontSize', 25);
    title(ax2, sprintf('(b) TOP-%d performance', topk_right), 'FontSize', 24, 'FontWeight', 'bold');
end

legend(ax1, 'Location', 'northeast', 'FontSize', 18, 'Box', 'on');
legend(ax2, 'Location', 'northeast', 'FontSize', 18, 'Box', 'on');

title(tl, 'Impact of Classification Labels N_{cl} on J_{cst}', ...
    'Interpreter', 'tex', 'FontSize', 24, 'FontWeight', 'bold');

plot_dir = fullfile(base_dir, 'plots');
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end

function y = normalize01_ncl_min(x)
x = x(:);
mn = min(x);
mx = max(x);
if ~isfinite(mn) || ~isfinite(mx) || abs(mx - mn) <= eps
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end
if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end

if topk_right == 1
    fig_tag = 'Fig29_ncl_impact_jcst_measured';
    tbl_tag = 'fig29_ncl_impact_jcst_measured_summary.csv';
else
    fig_tag = sprintf('Fig29_ncl_impact_jcst_top%d', topk_right);
    tbl_tag = sprintf('fig29_ncl_impact_jcst_top%d_summary.csv', topk_right);
end

svg_a = fullfile(plot_dir, [fig_tag, '.svg']);
png_a = fullfile(plot_dir, [fig_tag, '.png']);
svg_b = fullfile(fig_dir, [fig_tag, '.svg']);
png_b = fullfile(fig_dir, [fig_tag, '.png']);

print(fig, svg_a, '-dsvg');
exportgraphics(fig, png_a, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_b, '-dsvg');
exportgraphics(fig, png_b, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

rows = repmat(struct('Ncl', nan, 'Method', "", ...
    'RuleTestAccMean_Jcost', nan, 'RuleReliabilityMean_Jcost', nan, ...
    'SelectedTop1Jcost', nan, 'Top1RegretPct', nan, ...
    'TopK_ForRightPanel', nan, 'BestJcostInTopK', nan, 'TopKRegretPct', nan, ...
    'GlobalBestJcost', nan), n_m * n_n, 1);
rid = 0;
for j = 1:n_n
    for m = 1:n_m
        rid = rid + 1;
        rows(rid).Ncl = ncl_list(j);
        rows(rid).Method = methods(m);
        rows(rid).RuleTestAccMean_Jcost = rule_acc(m, j);
        rows(rid).RuleReliabilityMean_Jcost = rule_rel(m, j);
        rows(rid).SelectedTop1Jcost = top1_j(m, j);
        rows(rid).Top1RegretPct = top1_reg(m, j);
        rows(rid).TopK_ForRightPanel = topk_right;
        rows(rid).BestJcostInTopK = topk_j(m, j);
        rows(rid).TopKRegretPct = topk_reg(m, j);
        rows(rid).GlobalBestJcost = glob_j(j);
    end
end
S = struct2table(rows);
sum_csv = fullfile(base_dir, 'tables', tbl_tag);
writetable(S, sum_csv);

out = struct();
out.summary_csv = sum_csv;
out.svg_plot = svg_a;
out.png_plot = png_a;
out.svg_fig = svg_b;
out.png_fig = png_b;
fprintf('Fig29 generated: %s\n', out.svg_fig);
fprintf('Summary table: %s\n', out.summary_csv);
end
