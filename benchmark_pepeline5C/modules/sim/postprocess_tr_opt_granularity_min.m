function out = postprocess_tr_opt_granularity_min()
stage_dir = fullfile('shap_src_min', 'sim', 'tr_opt_granularity');
plot_dir = fullfile(stage_dir, 'plots');

if exist(stage_dir, 'dir') ~= 7
    error('Missing stage directory: %s', stage_dir);
end
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end

case_files = { ...
    'case_dt_0p25.mat', ...
    'case_dt_0p50.mat', ...
    'case_dt_1p00.mat', ...
    'case_dt_1p50.mat', ...
    'case_dt_2p00.mat'};

cases = [];
for i = 1:numel(case_files)
    fp = fullfile(stage_dir, case_files{i});
    if exist(fp, 'file') ~= 2
        continue;
    end
    S = load(fp);
    c = struct();
    c.dt_hr = S.dt_hr;
    c.optintervals = S.optintervals;
    c.n_actions = size(S.cc_policy, 1);
    c.solve_sec = S.solve_sec;
    c.status = S.status;
    c.start_err_raw = S.start_err_raw;
    c.end_err_raw = S.end_err_raw;
    c.start_err = S.start_err;
    c.end_err = S.end_err;
    c.t_action_hr = S.t_action_hr;
    c.cc_policy = S.cc_policy;
    c.sim_eval = S.sim_eval;
    cases = [cases; c]; %#ok<AGROW>
end

if isempty(cases)
    error('No case_dt_*.mat files found in %s', stage_dir);
end

[~, ord] = sort([cases.dt_hr]);
cases = cases(ord);

summary_tbl = table( ...
    [cases.dt_hr]', ...
    [cases.optintervals]', ...
    [cases.n_actions]', ...
    [cases.solve_sec]', ...
    [cases.status]', ...
    [cases.start_err_raw]', ...
    [cases.end_err_raw]', ...
    [cases.start_err]', ...
    [cases.end_err]', ...
    arrayfun(@(x) x.sim_eval.Jcost, cases), ...
    arrayfun(@(x) x.sim_eval.Jsupp, cases), ...
    arrayfun(@(x) x.sim_eval.Jvar, cases), ...
    'VariableNames', { ...
        'ActionDt_hr', 'OptIntervals', 'NActions', 'SolveSec', 'IpoptStatus', ...
        'StartErrRaw', 'EndErrRaw', 'StartErr', 'EndErr', 'Jcost', 'Jsupp', 'Jvar'});

writetable(summary_tbl, fullfile(stage_dir, 'tr_opt_granularity_summary.csv'));
save(fullfile(stage_dir, 'tr_opt_granularity_results.mat'), 'cases', 'summary_tbl', '-v7.3');

plot_action_profiles_saved_min(cases, plot_dir);
plot_transient_process_saved_min(cases, plot_dir);
plot_metrics_saved_min(summary_tbl, plot_dir);

out = struct();
out.stage_dir = stage_dir;
out.plot_dir = plot_dir;
out.summary_tbl = summary_tbl;
disp(summary_tbl);
end

function plot_action_profiles_saved_min(cases, plot_dir)
n_case = numel(cases);
n_comp = size(cases(1).cc_policy, 2);
cmap = lines(n_case);
markers = {'o','s','d','^','v','>','<','p','h'};

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1500 900]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

legend_text = arrayfun(@(x) sprintf('dt=%.2fh', x.dt_hr), cases, 'UniformOutput', false);

for comp = 1:n_comp
    ax = nexttile;
    hold on;
    hh = gobjects(n_case,1);
    for i = 1:n_case
        mk = markers{mod(i-1, numel(markers))+1};
        hh(i) = plot(cases(i).t_action_hr, cases(i).cc_policy(:,comp), '-', ...
            'Color', cmap(i,:), 'LineWidth', 1.6, 'Marker', mk, 'MarkerSize', 4);
    end
    xlabel('Time (h)');
    ylabel(sprintf('cc_%d', comp));
    title(sprintf('Compressor %d action profile', comp));
    grid on;
    legend(ax, hh, legend_text, 'Location', 'northwest', 'Box', 'on', 'FontSize', 8, 'Interpreter', 'none');
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);
end

ax = nexttile;
hold on;
hmean = gobjects(n_case,1);
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    hmean(i) = plot(cases(i).t_action_hr, mean(cases(i).cc_policy, 2), '-', ...
        'Color', cmap(i,:), 'LineWidth', 1.8, 'Marker', mk, 'MarkerSize', 4);
end
xlabel('Time (h)');
ylabel('Mean cc');
title('Mean action profile');
grid on;
legend(ax, hmean, legend_text, 'Location', 'northwest', 'Box', 'on', 'FontSize', 8, 'Interpreter', 'none');
set(ax, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR optimization actions under different time granularities', ...
    'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'action_profile_compare.png'), '-dpng', '-r260');
close(f);
end

function plot_transient_process_saved_min(cases, plot_dir)
n_case = numel(cases);
cmap = lines(n_case);
legend_text = arrayfun(@(x) sprintf('dt=%.2fh', x.dt_hr), cases, 'UniformOutput', false);
markers = {'o','s','d','^','v','>','<','p','h'};

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1400 430]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold on;
h1 = gobjects(n_case,1);
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    h1(i) = plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cc_mean, ...
        'Color', cmap(i,:), 'LineWidth', 1.7, 'Marker', mk, 'MarkerSize', 3);
end
xlabel('Time (h)');
ylabel('Mean cc (sim)');
title('Compressor ratio trajectory');
grid on;
lg1 = legend(ax1, h1, legend_text, 'Location', 'northwest', 'Box', 'on', 'Interpreter', 'none');
set(lg1, 'Color', 'w', 'EdgeColor', 'k', 'FontSize', 9);
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
h2 = gobjects(n_case,1);
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    h2(i) = plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_cost/1e9, ...
        'Color', cmap(i,:), 'LineWidth', 1.7, 'Marker', mk, 'MarkerSize', 3);
end
xlabel('Time (h)');
ylabel('Mean power (GW)');
title('Transient compressor power');
grid on;
lg2 = legend(ax2, h2, legend_text, 'Location', 'northwest', 'Box', 'on', 'Interpreter', 'none');
set(lg2, 'Color', 'w', 'EdgeColor', 'k', 'FontSize', 9);
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
hold on;
h3 = gobjects(n_case,1);
for i = 1:n_case
    mk = markers{mod(i-1, numel(markers))+1};
    h3(i) = plot(cases(i).sim_eval.t_hr, cases(i).sim_eval.m_supp, ...
        'Color', cmap(i,:), 'LineWidth', 1.7, 'Marker', mk, 'MarkerSize', 3);
end
xlabel('Time (h)');
ylabel('Supply flow');
title('Transient supply trajectory');
grid on;
lg3 = legend(ax3, h3, legend_text, 'Location', 'northwest', 'Box', 'on', 'Interpreter', 'none');
set(lg3, 'Color', 'w', 'EdgeColor', 'k', 'FontSize', 9);
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Transient process comparison by action granularity', ...
    'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'transient_process_compare.png'), '-dpng', '-r260');
close(f);
end

function plot_metrics_saved_min(summary_tbl, plot_dir)
dt_labels = arrayfun(@(x) sprintf('%.2fh', x), summary_tbl.ActionDt_hr, 'UniformOutput', false);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1200 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
bar(summary_tbl.Jcost);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jcost');
title('Total energy metric Jcost');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
bar(summary_tbl.Jsupp);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jsupp');
title('Supply metric Jsupp');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
bar(summary_tbl.Jvar);
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
ylabel('Jvar');
title('Variation metric Jvar');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
yyaxis left;
bar(summary_tbl.SolveSec, 0.65);
ylabel('Solve time (s)');
yyaxis right;
plot(1:height(summary_tbl), summary_tbl.IpoptStatus, 'ko-', 'LineWidth', 1.4);
ylabel('IPOPT status');
xticks(1:height(summary_tbl));
xticklabels(dt_labels);
title('Solve effort and status');
grid on;
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Performance vs action time granularity', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'metrics_vs_granularity.png'), '-dpng', '-r260');
close(f);
end
