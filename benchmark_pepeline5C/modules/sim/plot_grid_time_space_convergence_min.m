function out = plot_grid_time_space_convergence_min(stage_dir)
if nargin < 1 || isempty(stage_dir)
    stage_dir = fullfile('shap_src_min', 'sim', 'grid_independence');
end

summary_csv = fullfile(stage_dir, 'run_summary.csv');
if exist(summary_csv, 'file') ~= 2
    error('run_summary.csv not found: %s', summary_csv);
end

plot_dir = fullfile(stage_dir, 'plots');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end

T = readtable(summary_csv);
T = T(T.Status == "ok", :);
if isempty(T)
    error('No successful rows found in %s', summary_csv);
end

if ~all(ismember({'RelErrJcost','RelErrJsupp','RelErrJvar','CurveErrPnodMean','CurveErrCost','CurveErrSupp'}, T.Properties.VariableNames))
    error('Required error columns are missing in run_summary.csv.');
end

l_fine = min(T.Lmax_km);
s_fine = max(T.Solsteps);

T_time = T(abs(T.Lmax_km - l_fine) < 1e-12, :);
T_time = sortrows(T_time, 'Solsteps', 'ascend');

T_space = T(abs(T.Solsteps - s_fine) < 1e-12, :);
T_space = sortrows(T_space, 'Lmax_km', 'descend');

if height(T_time) < 2 || height(T_space) < 2
    error('Not enough sweep points to build convergence plot.');
end

[time_int, time_curve, time_all] = aggregate_err_min(T_time);
[space_int, space_curve, space_all] = aggregate_err_min(T_space);

x1 = (1:height(T_time))';
x2 = (1:height(T_space))';

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1380 460], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
semilogy(x1, time_all, 'k-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'overall max error');
hold on;
semilogy(x1, time_int, 'b-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'integral-metric max');
semilogy(x1, time_curve, 'Color', [0.85 0.33 0.10], 'Marker', '^', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'curve-metric max');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);
xticks(x1);
xticklabels(arrayfun(@(v) sprintf('%d', v), T_time.Solsteps, 'UniformOutput', false));
xlabel('Internal time grid (solsteps / 24h), finer ->');
ylabel('Relative error to finest reference');
title(sprintf('Temporal convergence at fixed finest space (l_{max}=%.2f km)', l_fine));
legend('Location', 'best', 'Box', 'on');

ax2 = nexttile;
semilogy(x2, space_all, 'k-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'overall max error');
hold on;
semilogy(x2, space_int, 'b-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'integral-metric max');
semilogy(x2, space_curve, 'Color', [0.85 0.33 0.10], 'Marker', '^', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'curve-metric max');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);
xticks(x2);
xticklabels(arrayfun(@(v) sprintf('%.2f', v), T_space.Lmax_km, 'UniformOutput', false));
xlabel('Internal space grid l_{max} (km), coarse -> fine');
ylabel('Relative error to finest reference');
title(sprintf('Spatial convergence at fixed finest time (solsteps=%d)', s_fine));
legend('Location', 'best', 'Box', 'on');

sgtitle('Time-space grid convergence trends (single fixed TR-opt policy)', 'FontSize', 13, 'FontWeight', 'bold');

out_png = fullfile(plot_dir, 'grid_time_space_convergence.png');
print(f, out_png, '-dpng', '-r260');
close(f);

out_tbl = table();
out_tbl.SweepType = [repmat("time", height(T_time), 1); repmat("space", height(T_space), 1)];
out_tbl.Solsteps = [T_time.Solsteps; T_space.Solsteps];
out_tbl.Lmax_km = [T_time.Lmax_km; T_space.Lmax_km];
out_tbl.ErrIntegralMax = [time_int; space_int];
out_tbl.ErrCurveMax = [time_curve; space_curve];
out_tbl.ErrOverallMax = [time_all; space_all];
writetable(out_tbl, fullfile(stage_dir, 'convergence_sweep_summary.csv'));

out = struct();
out.plot_png = out_png;
out.sweep_csv = fullfile(stage_dir, 'convergence_sweep_summary.csv');
out.time_fine_lmax = l_fine;
out.space_fine_solsteps = s_fine;

fprintf('Saved convergence plot: %s\n', out.plot_png);
end

function [err_int, err_curve, err_all] = aggregate_err_min(T)
err_int = max([T.RelErrJcost, T.RelErrJsupp, T.RelErrJvar], [], 2);
err_curve = max([T.CurveErrPnodMean, T.CurveErrCost, T.CurveErrSupp], [], 2);
err_all = max([err_int, err_curve], [], 2);
end
