function out = plot_try1_summary_stats_min()
try_root = fullfile('shap_src_min', 'doe', 'try1');
seeds = [11 23 37];
dt_list = [0.5 1.0 1.5 2.0];

seed_cols = [
    0.82 0.18 0.18;
    0.10 0.55 0.20;
    0.12 0.12 0.12];

dt_tags = arrayfun(@(d) strrep(sprintf('%.1f', d), '.', 'p'), dt_list, 'UniformOutput', false);
dt_tick_labels = arrayfun(@(d) sprintf('Δt=%.1f h', d), dt_list, 'UniformOutput', false);
seed_tick_labels = arrayfun(@(s) sprintf('Seed %03d', s), seeds, 'UniformOutput', false);

n_seed = numel(seeds);
n_dt = numel(dt_list);
tbl = cell(n_seed, n_dt);

p95_mean = zeros(n_seed, n_dt);
p95_max = zeros(n_seed, n_dt);
p95_min = zeros(n_seed, n_dt);
p95_q10 = zeros(n_seed, n_dt);
p95_q90 = zeros(n_seed, n_dt);

for si = 1:n_seed
    for di = 1:n_dt
        fp = fullfile(try_root, sprintf('seed_%03d', seeds(si)), ...
            ['dataset_dt_' dt_tags{di}], 'sample_stats.csv');
        if exist(fp, 'file') ~= 2
            error('Missing file: %s', fp);
        end
        T = readtable(fp);
        tbl{si, di} = T;

        v = T.P95AbsIncNoTerminalPerHour;
        p95_mean(si, di) = mean(v);
        p95_max(si, di) = max(v);
        p95_min(si, di) = min(v);
        p95_q10(si, di) = prctile(v, 10);
        p95_q90(si, di) = prctile(v, 90);
    end
end

% Figure 1: boxplot distribution (formula style labels)
f1 = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [80 80 1950 820]);
ax1 = axes(f1);
hold(ax1, 'on');

font_sz = 22;

offsets = [-0.24, 0, 0.24];
box_w = 0.18;

for di = 1:n_dt
    for si = 1:n_seed
        T = tbl{si, di};
        y = T.P95AbsIncNoTerminalPerHour;
        x0 = di + offsets(si);

        b = boxchart(ax1, x0 * ones(size(y)), y, 'BoxWidth', box_w);
        b.BoxFaceColor = seed_cols(si, :);
        b.BoxFaceAlpha = 0.30;
        b.MarkerStyle = 'none';
        b.WhiskerLineColor = seed_cols(si, :);
        b.LineWidth = 2.0;
        b.BoxEdgeColor = seed_cols(si, :);
        b.HandleVisibility = 'off';

        n_show = min(120, numel(y));
        rng(10000 + 100 * si + 10 * di, 'twister');
        idx = randperm(numel(y), n_show);
        xj = x0 + (rand(n_show, 1) - 0.5) * 0.07;
        sc = scatter(ax1, xj, y(idx), 24, seed_cols(si, :), 'filled');
        sc.MarkerFaceAlpha = 0.55;
        sc.MarkerEdgeColor = max(0, seed_cols(si, :) * 0.45);
        sc.MarkerEdgeAlpha = 0.85;
        sc.LineWidth = 0.55;
        sc.HandleVisibility = 'off';
    end
end

hl = gobjects(n_seed, 1);
for si = 1:n_seed
    hl(si) = plot(ax1, nan, nan, 's', ...
        'MarkerSize', 11, ...
        'MarkerFaceColor', seed_cols(si, :), ...
        'MarkerEdgeColor', seed_cols(si, :), ...
        'LineStyle', 'none');
end

grid(ax1, 'on');
box(ax1, 'on');
set(ax1, 'FontSize', font_sz, 'LineWidth', 1.5);
xticks(ax1, 1:n_dt);
xticklabels(ax1, dt_tick_labels);
xlim(ax1, [0.5, n_dt + 0.5]);

xlabel(ax1, 'Sample time resolution', 'FontSize', font_sz);
ylabel(ax1, '$P_{95}\!\left(\left|v_i^{\prime}(t)\right|\right)$', ...
    'FontSize', font_sz, 'Interpreter', 'latex');
title(ax1, 'Distribution of derivative-magnitude statistic across seeds and sample Δt', ...
    'FontSize', font_sz, 'FontWeight', 'normal', 'Interpreter', 'none');
legend(ax1, hl, seed_tick_labels, 'Location', 'best', 'FontSize', font_sz, 'Box', 'on');
ylim(ax1, [0.045 0.085]);

dist_svg = fullfile(try_root, 'doe_summary_p95_distribution.svg');
print(f1, dist_svg, '-dsvg');
close(f1);

% Figure 2: one-row two-column summary (max/mean/range)
f2 = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [100 100 1900 780]);
tlo = tiledlayout(f2, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax2 = nexttile(tlo, 1);
hold(ax2, 'on');
h2 = gobjects(2 * n_seed, 1);
lab2 = cell(2 * n_seed, 1);
for si = 1:n_seed
    h2(2 * si - 1) = plot(ax2, dt_list, p95_mean(si, :), '-o', ...
        'Color', seed_cols(si, :), 'LineWidth', 3.0, 'MarkerSize', 7.5, ...
        'MarkerFaceColor', seed_cols(si, :));
    h2(2 * si) = plot(ax2, dt_list, p95_max(si, :), '--^', ...
        'Color', seed_cols(si, :), 'LineWidth', 2.6, 'MarkerSize', 7.5, ...
        'MarkerFaceColor', 'w');
    lab2{2 * si - 1} = sprintf('Seed %03d mean', seeds(si));
    lab2{2 * si} = sprintf('Seed %03d max', seeds(si));
end
grid(ax2, 'on');
box(ax2, 'on');
set(ax2, 'FontSize', 18, 'LineWidth', 1.35);
xticks(ax2, dt_list);
xticklabels(ax2, dt_tick_labels);
xlabel(ax2, 'Sample time resolution', 'FontSize', 21);
ylabel(ax2, '$P_{95}(\,|v_i^{\prime}(t)|\,)$ statistics', 'FontSize', 21, 'Interpreter', 'latex');
title(ax2, '(a) Mean and max', 'FontSize', 23, 'FontWeight', 'bold');
legend(ax2, h2, lab2, 'Location', 'best', 'FontSize', 13.5, 'Box', 'on');

ax3 = nexttile(tlo, 2);
hold(ax3, 'on');
offsets2 = [-0.18, 0, 0.18];
for di = 1:n_dt
    for si = 1:n_seed
        x = di + offsets2(si);
        plot(ax3, [x, x], [p95_min(si, di), p95_max(si, di)], '-', ...
            'Color', seed_cols(si, :), 'LineWidth', 1.9);
        plot(ax3, [x, x], [p95_q10(si, di), p95_q90(si, di)], '-', ...
            'Color', seed_cols(si, :), 'LineWidth', 5.2);
        plot(ax3, x, p95_mean(si, di), 'o', 'Color', seed_cols(si, :), ...
            'MarkerFaceColor', 'w', 'MarkerSize', 8.4, 'LineWidth', 1.7);
    end
end
h_rng = plot(ax3, nan, nan, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.9);
h_mid = plot(ax3, nan, nan, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 5.2);
h_mu = plot(ax3, nan, nan, 'o', 'Color', [0.2 0.2 0.2], ...
    'MarkerFaceColor', 'w', 'MarkerSize', 8.4, 'LineWidth', 1.7);

grid(ax3, 'on');
box(ax3, 'on');
set(ax3, 'FontSize', 18, 'LineWidth', 1.35);
xticks(ax3, 1:n_dt);
xticklabels(ax3, dt_tick_labels);
xlim(ax3, [0.5, n_dt + 0.5]);
xlabel(ax3, 'Sample time resolution', 'FontSize', 21);
ylabel(ax3, '$P_{95}(\,|v_i^{\prime}(t)|\,)$ statistics', 'FontSize', 21, 'Interpreter', 'latex');
title(ax3, '(b) Range and central band', 'FontSize', 23, 'FontWeight', 'bold');
legend(ax3, [h_rng, h_mid, h_mu], {'min-max range', 'q10-q90 band', 'mean'}, ...
    'Location', 'best', 'FontSize', 15, 'Box', 'on');

title(tlo, '$\mathcal{T}_{\Delta t,seed}$ summary: max, mean, and spread of $P_{95}(|v_i^{\prime}(t)|)$', ...
    'FontSize', 24, 'FontWeight', 'bold', 'Interpreter', 'latex');

stat_svg = fullfile(try_root, 'doe_summary_derivative_stats_1x2.svg');
print(f2, stat_svg, '-dsvg');
close(f2);

out = struct();
out.dist_svg = dist_svg;
out.stat_svg = stat_svg;
fprintf('Saved: %s\n', dist_svg);
fprintf('Saved: %s\n', stat_svg);
end
