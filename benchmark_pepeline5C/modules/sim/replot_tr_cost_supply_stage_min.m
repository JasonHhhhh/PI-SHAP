function out = replot_tr_cost_supply_stage_min(stage_dir)
if nargin < 1 || isempty(stage_dir)
    stage_dir = fullfile('shap_src_min', 'tr', 'cost_supply', 'try1');
end

plot_dir = fullfile(stage_dir, 'plots');
ensure_dir_min(plot_dir);

results_file = fullfile(stage_dir, 'results.mat');
cases = [];
summary_tbl = table();
pareto_tbl = table();

if exist(results_file, 'file') == 2
    S = load(results_file, 'cases', 'summary_tbl', 'pareto_tbl');
    if isfield(S, 'cases')
        cases = S.cases;
    end
    if isfield(S, 'summary_tbl')
        summary_tbl = S.summary_tbl;
    end
    if isfield(S, 'pareto_tbl')
        pareto_tbl = S.pareto_tbl;
    end
end

if isempty(summary_tbl)
    summary_tbl = readtable(fullfile(stage_dir, 'summary.csv'));
end
if isempty(pareto_tbl)
    pareto_tbl = readtable(fullfile(stage_dir, 'pareto.csv'));
end

if isempty(cases)
    case_files = dir(fullfile(stage_dir, 'case_*.mat'));
    if ~isempty(case_files)
        ctmp = repmat(struct(), numel(case_files), 1);
        for i = 1:numel(case_files)
            X = load(fullfile(case_files(i).folder, case_files(i).name), 'w_s', 'w_c', 'solve_meta', 't_action_hr', 'cc_policy', 'sim_eval');
            ctmp(i).w_supply = X.w_s;
            ctmp(i).w_cost = X.w_c;
            ctmp(i).status = X.solve_meta.status;
            ctmp(i).t_action_hr = X.t_action_hr;
            ctmp(i).cc_policy = X.cc_policy;
            ctmp(i).sim_eval = X.sim_eval;
        end
        cases = ctmp;
    end
end

if ~isempty(cases)
    plot_action_profiles_min(cases, plot_dir);
    plot_transient_process_min(cases, plot_dir);
end
plot_metrics_min(summary_tbl, plot_dir);
plot_pareto_min(summary_tbl, pareto_tbl, plot_dir);

out = struct();
out.stage_dir = stage_dir;
out.plot_dir = plot_dir;
out.has_cases = ~isempty(cases);
out.n_summary = height(summary_tbl);
out.n_pareto = height(pareto_tbl);
end

function plot_action_profiles_min(cases, plot_dir)
[~, idx] = sort([cases.w_supply]);
cases = cases(idx);

n_case = numel(cases);
n_comp = size(cases(1).cc_policy, 2);
cmap = turbo(n_case);
markers = {'o','s','d','^','v','>','<','p','h','x','+'};

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1800 920], 'Renderer', 'painters');
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

legend_text = arrayfun(@(x) sprintf('w_s=%.3f (status=%g)', x.w_supply, x.status), cases, 'UniformOutput', false);
h_legend = [];

for comp = 1:n_comp
    ax = nexttile;
    hold on;
    h = gobjects(n_case,1);
    for i = 1:n_case
        mk = markers{mod(i-1, numel(markers))+1};
        h(i) = plot(cases(i).t_action_hr, cases(i).cc_policy(:,comp), '-', ...
            'Color', cmap(i,:), 'LineWidth', 1.6, 'Marker', mk, 'MarkerSize', 3);
        scatter(cases(i).t_action_hr(end), cases(i).cc_policy(end,comp), 42, ...
            'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor', 'w', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    end
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('Compressor %d action profile', comp));
    xlim([0 24.2]);
    grid on;
    if comp == 1
        h_legend = h;
    end
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
hold on;
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    y = mean(cases(i).cc_policy, 2);
    plot(cases(i).t_action_hr, y, '-', ...
        'Color', cmap(i,:), 'LineWidth', 1.7, 'Marker', mk, 'MarkerSize', 3);
end
xlabel('Time (h)');
ylabel('mean(cc)');
title('Mean action profile');
xlim([0 24.2]);
grid on;
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

if ~isempty(h_legend)
    lgd = legend(h_legend, legend_text, 'Location', 'eastoutside');
    lgd.Layout.Tile = 'east';
end

sgtitle('TR COST+SUPPLY action profiles', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'action.png'), 260);
close(f);
end

function plot_transient_process_min(cases, plot_dir)
[~, idx] = sort([cases.w_supply]);
cases = cases(idx);

n_case = numel(cases);
cmap = turbo(n_case);
legend_text = arrayfun(@(x) sprintf('w_s=%.3f (status=%g)', x.w_supply, x.status), cases, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1600 500], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold on;
h1 = gobjects(n_case,1);
for i = 1:n_case
    h1(i) = plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cc_mean, 'Color', cmap(i,:), 'LineWidth', 1.6);
end
xlabel('Time (h)');
ylabel('Mean cc');
title('Compressor ratio trajectory');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cost/1e9, 'Color', cmap(i,:), 'LineWidth', 1.6);
end
xlabel('Time (h)');
ylabel('Power (GW)');
title('Transient compressor power');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
hold on;
for i = 1:n_case
    plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_supp, 'Color', cmap(i,:), 'LineWidth', 1.6);
end
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

lgd = legend(h1, legend_text, 'Location', 'eastoutside');
lgd.Layout.Tile = 'east';

sgtitle('TR COST+SUPPLY transient process', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'transient.png'), 260);
close(f);
end

function plot_metrics_min(summary_tbl, plot_dir)
summary_tbl = sortrows(summary_tbl, 'WSupply');
x = 1:height(summary_tbl);
labels = arrayfun(@(v) sprintf('%.2f', v), summary_tbl.WSupply, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1250 720], 'Renderer', 'painters');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
yyaxis left;
h11 = plot(x, summary_tbl.Jcost, 'o-', 'LineWidth', 1.6);
ylabel('Jcost');
yyaxis right;
h12 = plot(x, summary_tbl.Jsupp, 's-', 'LineWidth', 1.6);
ylabel('Jsupp');
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
title('Raw objectives vs weight');
grid on;
legend([h11 h12], {'Jcost', 'Jsupp'}, 'Location', 'best');
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

if ~ismember('JcostNorm', summary_tbl.Properties.VariableNames)
    den = max(max(summary_tbl.Jcost)-min(summary_tbl.Jcost), eps);
    summary_tbl.JcostNorm = (summary_tbl.Jcost-min(summary_tbl.Jcost))/den;
end
if ~ismember('JsuppNorm', summary_tbl.Properties.VariableNames)
    den = max(max(summary_tbl.Jsupp)-min(summary_tbl.Jsupp), eps);
    summary_tbl.JsuppNorm = (summary_tbl.Jsupp-min(summary_tbl.Jsupp))/den;
end

ax2 = nexttile;
h21 = plot(x, summary_tbl.JcostNorm, 'o-', 'LineWidth', 1.6); hold on;
h22 = plot(x, 1 - summary_tbl.JsuppNorm, 's-', 'LineWidth', 1.6);
if ismember('WeightedNormScore', summary_tbl.Properties.VariableNames)
    h23 = plot(x, summary_tbl.WeightedNormScore, 'd-', 'LineWidth', 1.8);
    legend([h21 h22 h23], {'Jcost norm', '1-Jsupp norm', 'weighted score'}, 'Location', 'best');
else
    legend([h21 h22], {'Jcost norm', '1-Jsupp norm'}, 'Location', 'best');
end
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
ylabel('Normalized value');
title('Normalized objective scales');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
bar(summary_tbl.SolveSec);
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
ylabel('Solve time (s)');
title('Solve time');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
yyaxis left;
bar(summary_tbl.MaxStep, 0.65);
ylabel('Max |Delta cc|');
yyaxis right;
plot(x, summary_tbl.EndGapToSS, 'ko-', 'LineWidth', 1.4);
ylabel('End gap to SS');
xticks(x);
xticklabels(labels);
xlabel('w_{supply}');
title('Control movement and terminal gap');
grid on;
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR COST+SUPPLY metrics by weight', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f, fullfile(plot_dir, 'metrics.png'), 260);
close(f);
end

function plot_pareto_min(summary_tbl, pareto_tbl, plot_dir)
summary_tbl = sortrows(summary_tbl, 'WSupply');
f = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 860 620], 'Renderer', 'painters');

hold on;
cmap = turbo(height(summary_tbl));
h_all = gobjects(height(summary_tbl),1);
for i = 1:height(summary_tbl)
    h_all(i) = scatter(summary_tbl.Jcost(i), summary_tbl.Jsupp(i), 64, cmap(i,:), 'filled');
end

if ~isempty(pareto_tbl)
    p = sortrows(pareto_tbl, 'Jcost');
    plot(p.Jcost, p.Jsupp, 'k-', 'LineWidth', 1.8, 'DisplayName', 'Pareto front');
    scatter(p.Jcost, p.Jsupp, 86, 'ko', 'LineWidth', 1.2, 'DisplayName', 'Pareto points');
end

xlabel('Jcost (lower is better)');
ylabel('Jsupp (higher is better)');
title('Cost-Supply Pareto plane (cost min, supply max)');
grid on;

leg_text = arrayfun(@(v) sprintf('w_{s}=%.2f', v), summary_tbl.WSupply, 'UniformOutput', false);
legend(h_all, leg_text, 'Location', 'bestoutside');

save_plot_png_min(f, fullfile(plot_dir, 'pareto.png'), 260);
close(f);
end

function save_plot_png_min(fig_handle, out_file, dpi)
if nargin < 3 || isempty(dpi)
    dpi = 260;
end
set(fig_handle, 'Renderer', 'painters');
set(fig_handle, 'InvertHardcopy', 'off');
drawnow('nocallbacks');
print(fig_handle, out_file, '-dpng', sprintf('-r%d', dpi), '-painters');
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end
