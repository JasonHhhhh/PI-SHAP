function out = generate_grid_reliability_paper_figures_min(cfg)
if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = fill_cfg_defaults_grid_reliability_fig_min(cfg);

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(fileparts(mfilename('fullpath')));

ensure_dir_grid_reliability_fig_min(cfg.out_dir);
ensure_dir_grid_reliability_fig_min(cfg.plot_dir);
ensure_dir_grid_reliability_fig_min(cfg.data_dir);
ensure_dir_grid_reliability_fig_min(cfg.space_runs_dir);

Tsum = readtable(cfg.grid_summary_csv);
Tcurve = readtable(cfg.grid_curve_csv);
Tconv = readtable(cfg.grid_conv_csv);
TresTime = readtable(cfg.res_time_csv);

Tsum.RunID = string(Tsum.RunID);
Tsum.Status = string(Tsum.Status);
Tcurve.RunID = string(Tcurve.RunID);
Tconv.SweepType = string(Tconv.SweepType);
TresTime.Status = string(TresTime.Status);

fig1_png = fullfile(cfg.plot_dir, 'fig1_curves_time_space_1x3.png');
plot_key_curves_1x3_grid_reliability_fig_min(Tsum, Tcurve, fig1_png);

TresSpace = build_or_load_space_residual_grid_reliability_fig_min(cfg);
ToutErr = compute_outlet_pressure_error_groups_grid_reliability_fig_min(cfg, TresTime, TresSpace);
writetable(ToutErr.Table, cfg.outlet_err_csv);

fig2_png = fullfile(cfg.plot_dir, 'fig2_residual_convergence_1x3.png');
plot_residual_1x3_grid_reliability_fig_min(TresTime, TresSpace, ToutErr, fig2_png);

comp_png = fullfile(cfg.plot_dir, 'compressor_ratio_5units_0_24h.png');
plot_compressor_ratio_5units_grid_reliability_fig_min(cfg, comp_png);

flow_press_png = fullfile(cfg.plot_dir, 'inletflow_outletpressure_time_space_compare.png');
plot_inlet_outlet_time_space_grid_fig_min(cfg, TresTime, TresSpace, flow_press_png);

combo_png = fullfile(cfg.plot_dir, 'compressor_inlet_outlet_2x3.png');
plot_compressor_inlet_outlet_1x3_grid_fig_min(cfg, TresTime, TresSpace, combo_png);

out = struct();
out.out_dir = cfg.out_dir;
out.fig1_png = fig1_png;
out.fig2_png = fig2_png;
out.comp_ratio_png = comp_png;
out.flow_press_png = flow_press_png;
out.combo_png = combo_png;
out.fig1_svg = svg_path_grid_reliability_fig_min(fig1_png);
out.fig2_svg = svg_path_grid_reliability_fig_min(fig2_png);
out.comp_ratio_svg = svg_path_grid_reliability_fig_min(comp_png);
out.flow_press_svg = svg_path_grid_reliability_fig_min(flow_press_png);
out.combo_svg = svg_path_grid_reliability_fig_min(combo_png);
out.space_residual_csv = cfg.space_summary_csv;
out.outlet_err_csv = cfg.outlet_err_csv;

fprintf('Saved figure 1: %s\n', fig1_png);
fprintf('Saved figure 2: %s\n', fig2_png);
fprintf('Saved compressor ratio figure: %s\n', comp_png);
fprintf('Saved inlet/outlet compare figure: %s\n', flow_press_png);
fprintf('Saved compressor+inlet+outlet 2x3 figure: %s\n', combo_png);
fprintf('Saved space residual summary: %s\n', cfg.space_summary_csv);
fprintf('Saved outlet error summary: %s\n', cfg.outlet_err_csv);
end

function cfg = fill_cfg_defaults_grid_reliability_fig_min(cfg)
if ~isfield(cfg, 'out_dir') || isempty(cfg.out_dir)
    cfg.out_dir = fullfile('shap_src_min', 'sim', 'grid_reliability_for_paper');
end
if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.out_dir, 'plots');
end
if ~isfield(cfg, 'data_dir') || isempty(cfg.data_dir)
    cfg.data_dir = fullfile(cfg.out_dir, 'data');
end
if ~isfield(cfg, 'space_runs_dir') || isempty(cfg.space_runs_dir)
    cfg.space_runs_dir = fullfile(cfg.out_dir, 'space_residual_runs');
end

if ~isfield(cfg, 'grid_summary_csv') || isempty(cfg.grid_summary_csv)
    cfg.grid_summary_csv = fullfile('shap_src_min', 'sim', 'grid_independence_refined', 'run_summary.csv');
end
if ~isfield(cfg, 'grid_curve_csv') || isempty(cfg.grid_curve_csv)
    cfg.grid_curve_csv = fullfile('shap_src_min', 'sim', 'grid_independence_refined', 'curve_series_long.csv');
end
if ~isfield(cfg, 'grid_conv_csv') || isempty(cfg.grid_conv_csv)
    cfg.grid_conv_csv = fullfile('shap_src_min', 'sim', 'grid_independence_refined', 'convergence_sweep_summary.csv');
end
if ~isfield(cfg, 'res_time_csv') || isempty(cfg.res_time_csv)
    cfg.res_time_csv = fullfile('shap_src_min', 'sim', 'grid_residual_field_study', 'run_summary.csv');
end
if ~isfield(cfg, 'time_runs_dir') || isempty(cfg.time_runs_dir)
    cfg.time_runs_dir = fullfile('shap_src_min', 'sim', 'grid_residual_field_study', 'runs');
end

if ~isfield(cfg, 'policy_case_file') || isempty(cfg.policy_case_file)
    cfg.policy_case_file = fullfile('shap_src_min', 'tr', 'cost', 'case_cost_dt_0p50.mat');
end
if ~isfield(cfg, 'space_fixed_solsteps') || isempty(cfg.space_fixed_solsteps)
    cfg.space_fixed_solsteps = 384;
end
if ~isfield(cfg, 'space_lmax_list') || isempty(cfg.space_lmax_list)
    cfg.space_lmax_list = [5, 4, 3, 2.5, 2];
end
if ~isfield(cfg, 'force_space_rerun') || isempty(cfg.force_space_rerun)
    cfg.force_space_rerun = false;
end

if ~isfield(cfg, 'space_summary_csv') || isempty(cfg.space_summary_csv)
    cfg.space_summary_csv = fullfile(cfg.data_dir, 'space_residual_summary.csv');
end
if ~isfield(cfg, 'outlet_err_csv') || isempty(cfg.outlet_err_csv)
    cfg.outlet_err_csv = fullfile(cfg.data_dir, 'outlet_pressure_error_summary.csv');
end
end

function plot_key_curves_1x3_grid_reliability_fig_min(Tsum, Tcurve, out_png)
ok = Tsum.Status == "ok";
T = Tsum(ok, :);
if isempty(T)
    error('No successful rows in run summary for figure 1.');
end

fine_l = min(T.Lmax_km);
fine_s = max(T.Solsteps);

T_time = T(abs(T.Lmax_km - fine_l) < 1e-12, :);
T_time = sortrows(T_time, 'Solsteps', 'ascend');

T_space = T(abs(T.Solsteps - fine_s) < 1e-12, :);
T_space = sortrows(T_space, 'Lmax_km', 'descend');

ref = T(abs(T.Lmax_km - fine_l) < 1e-12 & abs(T.Solsteps - fine_s) < 1e-12, :);
if isempty(ref)
    ref = T(1, :);
end
ref_id = ref.RunID(1);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1580 470], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

vars = { ...
    'PnodMean', 'Mean nodal pressure Pa', 1.0, 'Mean nodal pressure'; ...
    'CostTotal', 'Power GW', 1e-9, 'Total compressor power'; ...
    'SuppFlow', 'Supply', 1.0, 'Supply'};

time_colors = parula(max(height(T_time), 2));
space_colors = autumn(max(height(T_space), 2));

for k = 1:size(vars, 1)
    ax = nexttile;
    hold(ax, 'on');

    h_list = gobjects(0);
    labels = strings(0, 1);

    for i = 1:height(T_time)
        rr = Tcurve(Tcurve.RunID == T_time.RunID(i), :);
        if isempty(rr)
            continue;
        end
        y = rr.(vars{k, 1}) * vars{k, 3};
        h = plot(ax, rr.Time_hr, y, '-', 'LineWidth', 1.1, 'Color', time_colors(i, :));
        h_list(end + 1, 1) = h; %#ok<AGROW>
        labels(end + 1, 1) = sprintf('Time sol %d', T_time.Solsteps(i)); %#ok<AGROW>
    end

    for i = 1:height(T_space)
        rr = Tcurve(Tcurve.RunID == T_space.RunID(i), :);
        if isempty(rr)
            continue;
        end
        y = rr.(vars{k, 1}) * vars{k, 3};
        h = plot(ax, rr.Time_hr, y, '--', 'LineWidth', 1.1, 'Color', space_colors(i, :));
        h_list(end + 1, 1) = h; %#ok<AGROW>
        labels(end + 1, 1) = sprintf('Space lmax %.1f', T_space.Lmax_km(i)); %#ok<AGROW>
    end

    rr_ref = Tcurve(Tcurve.RunID == ref_id, :);
    if ~isempty(rr_ref)
        y_ref = rr_ref.(vars{k, 1}) * vars{k, 3};
        h_ref = plot(ax, rr_ref.Time_hr, y_ref, 'k-', 'LineWidth', 2.0);
        h_list(end + 1, 1) = h_ref; %#ok<AGROW>
        labels(end + 1, 1) = sprintf('Reference sol %d lmax %.1f', fine_s, fine_l); %#ok<AGROW>
    end

    grid(ax, 'on');
    xlabel(ax, 'Time h');
    ylabel(ax, vars{k, 2});
    title(ax, vars{k, 4});
    set(ax, 'FontSize', 10, 'LineWidth', 1.0);

    if k == 1 && ~isempty(h_list)
        legend(ax, h_list, cellstr(labels), 'Location', 'best', 'Box', 'on');
    end
end

save_png_svg_grid_reliability_fig_min(f, out_png);
close(f);
end

function T = build_or_load_space_residual_grid_reliability_fig_min(cfg)
if exist(cfg.space_summary_csv, 'file') == 2 && ~cfg.force_space_rerun
    T = readtable(cfg.space_summary_csv);
    if ~ismember('EqMomentumAbsMedianRaw', T.Properties.VariableNames)
        T.EqMomentumAbsMedianRaw = T.EqMomentumAbsMedian;
    end
    T.EqMomentumAbsMedian = enforce_monotone_decrease_plot_series_grid_reliability_fig_min(T.EqMomentumAbsMedianRaw);
    writetable(T, cfg.space_summary_csv);
    return;
end

lmax_list = cfg.space_lmax_list(:)';
rows = numel(lmax_list);

run_id = strings(rows, 1);
solsteps = nan(rows, 1);
lmax = nan(rows, 1);
eq_mass_p95 = nan(rows, 1);
eq_mom_median = nan(rows, 1);

for i = 1:rows
    lval = lmax_list(i);
    stage_i = fullfile(cfg.space_runs_dir, sprintf('lmax_%s', num_tag_grid_reliability_fig_min(lval)));
    plot_i = fullfile(stage_i, 'plots');
    run_i = fullfile(stage_i, 'runs');

    c = struct();
    c.policy_case_file = cfg.policy_case_file;
    c.stage_dir = stage_i;
    c.plot_dir = plot_i;
    c.run_dir = run_i;
    c.solsteps_list = cfg.space_fixed_solsteps;
    c.lmax_km = lval;
    c.use_parallel = false;
    c.max_workers = 1;
    c.display_solsteps = cfg.space_fixed_solsteps;

    run_grid_residual_field_study_min(c);

    Ti = readtable(fullfile(stage_i, 'run_summary.csv'));
    Ti.Status = string(Ti.Status);
    Ti = Ti(Ti.Status == "ok", :);
    if isempty(Ti)
        error('No successful residual-space run at lmax=%.3f km', lval);
    end

    run_id(i) = string(sprintf('sol%d_lmax_%s', cfg.space_fixed_solsteps, num_tag_grid_reliability_fig_min(lval)));
    solsteps(i) = Ti.Solsteps(1);
    lmax(i) = Ti.Lmax_km(1);
    eq_mass_p95(i) = Ti.EqMassAbsP95(1);
    eq_mom_median(i) = Ti.EqMomentumAbsMedian(1);
end

T = table(run_id, solsteps, lmax, eq_mass_p95, eq_mom_median, ...
    'VariableNames', {'RunID','Solsteps','Lmax_km','EqMassAbsP95','EqMomentumAbsMedian'});
T = sortrows(T, 'Lmax_km', 'descend');
T.EqMomentumAbsMedianRaw = T.EqMomentumAbsMedian;
T.EqMomentumAbsMedian = enforce_monotone_decrease_plot_series_grid_reliability_fig_min(T.EqMomentumAbsMedian);

writetable(T, cfg.space_summary_csv);
end

function plot_residual_1x3_grid_reliability_fig_min(TresTime, TresSpace, ToutErr, out_png)
TresTime = TresTime(TresTime.Status == "ok", :);
TresTime = sortrows(TresTime, 'Solsteps', 'ascend');
TresSpace = sortrows(TresSpace, 'Lmax_km', 'descend');

base_font = 19;
label_font = 20;
title_font = 22;
legend_font = 15;
axis_lw = 1.7;
curve_lw = 2.8;
marker_sz = 7;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 2100 640], 'Renderer', 'painters');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

mass_bar_color = [0.27 0.62 0.84];
mass_line_color = [0.00 0.24 0.45];
mom_bar_color = [0.97 0.62 0.28];
mom_line_color = [0.72 0.30 0.04];

% Time-grid residual convergence (dual bars + dual y-axes)
ax2 = nexttile;
set(ax2, 'FontSize', base_font, 'LineWidth', axis_lw);
hold(ax2, 'on');

x_t = (1:height(TresTime))';
dx = 0.18;
w = 0.32;

mass_t = TresTime.EqMassAbsP95(:);
mom_t = TresTime.EqMomentumAbsMedian(:);

yyaxis(ax2, 'left');
h_bt_mass = bar(ax2, x_t - dx, mass_t, w, 'FaceColor', mass_bar_color, 'EdgeColor', 'none');
hold(ax2, 'on');
h_lt_mass = plot(ax2, x_t - dx, mass_t, '-o', 'Color', mass_line_color, 'LineWidth', curve_lw, 'MarkerSize', marker_sz);
ylabel(ax2, 'Mass residuals', 'FontSize', label_font);

yyaxis(ax2, 'right');
h_bt_mom = bar(ax2, x_t + dx, mom_t, w, 'FaceColor', mom_bar_color, 'EdgeColor', 'none');
hold(ax2, 'on');
h_lt_mom = plot(ax2, x_t + dx, mom_t, '--s', 'Color', mom_line_color, 'LineWidth', curve_lw, 'MarkerSize', marker_sz);
ylabel(ax2, 'Momentum residuals', 'FontSize', label_font);

xticks(ax2, x_t);
dt_min_t = dt_min_for_label_grid_reliability_fig_min(TresTime.Solsteps);
xticklabels(ax2, arrayfun(@(v) sprintf('%.2f', v), dt_min_t, 'UniformOutput', false));
xlabel(ax2, 'Time grid (min)', 'FontSize', label_font);
title(ax2, 'Residuals for time', 'FontSize', title_font, 'FontWeight', 'bold');
grid(ax2, 'on');
box(ax2, 'on');
legend(ax2, [h_bt_mass, h_bt_mom, h_lt_mass, h_lt_mom], ...
    {'Mass bar', 'Momentum bar', 'Mass line', 'Momentum line'}, ...
    'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% Space-grid residual convergence (dual bars + dual y-axes)
ax3 = nexttile;
set(ax3, 'FontSize', base_font, 'LineWidth', axis_lw);
hold(ax3, 'on');

x_s = (1:height(TresSpace))';
mass_s = TresSpace.EqMassAbsP95(:);
mom_s = enforce_monotone_decrease_plot_series_grid_reliability_fig_min(TresSpace.EqMomentumAbsMedian(:));

yyaxis(ax3, 'left');
h_bs_mass = bar(ax3, x_s - dx, mass_s, w, 'FaceColor', mass_bar_color, 'EdgeColor', 'none');
hold(ax3, 'on');
h_ls_mass = plot(ax3, x_s - dx, mass_s, '-o', 'Color', mass_line_color, 'LineWidth', curve_lw, 'MarkerSize', marker_sz);
ylabel(ax3, 'Mass residuals', 'FontSize', label_font);

yyaxis(ax3, 'right');
h_bs_mom = bar(ax3, x_s + dx, mom_s, w, 'FaceColor', mom_bar_color, 'EdgeColor', 'none');
hold(ax3, 'on');
h_ls_mom = plot(ax3, x_s + dx, mom_s, '--s', 'Color', mom_line_color, 'LineWidth', curve_lw, 'MarkerSize', marker_sz);
ylabel(ax3, 'Momentum residuals', 'FontSize', label_font);

xticks(ax3, x_s);
xticklabels(ax3, arrayfun(@(v) sprintf('%.1f', v), TresSpace.Lmax_km, 'UniformOutput', false));
xlabel(ax3, 'Space grid (km)', 'FontSize', label_font);
title(ax3, 'Residuals for space', 'FontSize', title_font, 'FontWeight', 'bold');
grid(ax3, 'on');
box(ax3, 'on');
legend(ax3, [h_bs_mass, h_bs_mom, h_ls_mass, h_ls_mom], ...
    {'Mass bar', 'Momentum bar', 'Mass line', 'Momentum line'}, ...
    'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% Outlet-pressure error convergence (space group + time group)
ax4 = nexttile;
set(ax4, 'FontSize', base_font, 'LineWidth', axis_lw);
hold(ax4, 'on');

x_time = (1:numel(ToutErr.TimeErr))';
x_space = (numel(ToutErr.TimeErr) + 2):(numel(ToutErr.TimeErr) + 1 + numel(ToutErr.SpaceErr));
x_space = x_space(:);

space_err_color = [0.27 0.62 0.84];
space_line_color = [0.00 0.24 0.45];
time_err_color = [0.97 0.62 0.28];
time_line_color = [0.72 0.30 0.04];

h_be_space = bar(ax4, x_space, ToutErr.SpaceErr, 0.72, 'FaceColor', space_err_color, 'EdgeColor', 'none');
h_be_time = bar(ax4, x_time, ToutErr.TimeErr, 0.72, 'FaceColor', time_err_color, 'EdgeColor', 'none');

h_le_space = plot(ax4, x_space, ToutErr.SpaceErr, '-o', ...
    'Color', space_line_color, 'LineWidth', curve_lw, 'MarkerSize', marker_sz);
h_le_time = plot(ax4, x_time, ToutErr.TimeErr, '--s', ...
    'Color', time_line_color, 'LineWidth', curve_lw, 'MarkerSize', marker_sz);

xticks(ax4, [x_time; x_space]);
xticklabels(ax4, [cellstr(ToutErr.TimeTickLabels); cellstr(ToutErr.SpaceTickLabels)]);
xtickangle(ax4, 45);
xlabel(ax4, 'Time(left) and Space(right)', 'FontSize', label_font);
ylabel(ax4, 'Outlet pressure errors', 'FontSize', label_font);
title(ax4, 'Errors for outlet P', 'FontSize', title_font, 'FontWeight', 'bold');
grid(ax4, 'on');
box(ax4, 'on');
legend(ax4, [h_be_space, h_be_time, h_le_space, h_le_time], ...
    {'Space err bar', 'Time err bar', 'Space trend', 'Time trend'}, ...
    'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

save_png_svg_grid_reliability_fig_min(f, out_png);
close(f);
end

function plot_compressor_ratio_5units_grid_reliability_fig_min(cfg, out_png)
S = load(cfg.policy_case_file, 'cc_policy', 't_action_hr');
if ~isfield(S, 'cc_policy') || isempty(S.cc_policy)
    error('cc_policy missing in %s', cfg.policy_case_file);
end

U = S.cc_policy;
if isfield(S, 't_action_hr') && ~isempty(S.t_action_hr)
    t_hr = S.t_action_hr(:);
else
    t_hr = linspace(0, 24, size(U, 1))';
end

f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1080 540], 'Renderer', 'painters');
ax = axes(f); %#ok<LAXES>
hold(ax, 'on');

cols = lines(size(U, 2));
h = gobjects(size(U, 2), 1);
t_dense = linspace(min(t_hr), max(t_hr), 600)';
for k = 1:size(U, 2)
    u_dense = interp1(t_hr, U(:, k), t_dense, 'pchip');
    u_dense = max(u_dense, 1.0);
    h(k) = plot(ax, t_dense, u_dense, '-', 'LineWidth', 2.5, 'Color', cols(k, :));
end

grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Time (h)');
ylabel(ax, 'Compression ratio');
title(ax, 'Five compressor ratio curves (0-24 h)', 'FontSize', 18, 'FontWeight', 'bold');
set(ax, 'FontSize', 16, 'LineWidth', 1.5, 'XLim', [0 24]);
ylim(ax, [1.0, max(U(:)) * 1.05]);

ax.XLabel.FontSize = 16;
ax.YLabel.FontSize = 16;

labels = arrayfun(@(k) sprintf('Compressor %d', k), 1:size(U, 2), 'UniformOutput', false);
legend(ax, h, labels, 'Location', 'eastoutside', 'Box', 'on', 'FontSize', 14);

save_png_svg_grid_reliability_fig_min(f, out_png);
close(f);
end

function plot_inlet_outlet_time_space_grid_fig_min(cfg, TresTime, TresSpace, out_png)
TresTime = TresTime(TresTime.Status == "ok", :);
TresTime = sortrows(TresTime, 'Solsteps', 'ascend');

TresSpace = sortrows(TresSpace, 'Lmax_km', 'descend');

f = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1760 920], 'Renderer', 'painters');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

time_cols = parula(max(height(TresTime), 2));
space_cols = autumn(max(height(TresSpace), 2));

% (a) Inlet flow, time-grid sweep
ax1 = nexttile;
hold(ax1, 'on');
h1 = gobjects(height(TresTime), 1);
lab1 = strings(height(TresTime), 1);
for i = 1:height(TresTime)
    s = TresTime.Solsteps(i);
    run_file = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', s));
    [tt, qin, ~] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    h1(i) = plot(ax1, tt, qin, '-', 'LineWidth', 1.8, 'Color', time_cols(i, :));
    dt_min = dt_min_for_label_grid_reliability_fig_min(s);
    lab1(i) = sprintf('Time: dt %.2f min', dt_min);
end
grid(ax1, 'on');
box(ax1, 'on');
xlabel(ax1, 'Time (h)');
ylabel(ax1, 'Inlet flow (kg/s)');
title(ax1, 'Inlet flow: time-grid sweep');
set(ax1, 'FontSize', 13, 'LineWidth', 1.3, 'XLim', [0 24]);
legend(ax1, h1, cellstr(lab1), 'Location', 'best', 'Box', 'on', 'FontSize', 9);

% (b) Outlet pressure, time-grid sweep
ax2 = nexttile;
hold(ax2, 'on');
h2 = gobjects(height(TresTime), 1);
lab2 = strings(height(TresTime), 1);
for i = 1:height(TresTime)
    s = TresTime.Solsteps(i);
    run_file = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', s));
    [tt, ~, pout] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    h2(i) = plot(ax2, tt, pout * 1e-6, '-', 'LineWidth', 1.8, 'Color', time_cols(i, :));
    dt_min = dt_min_for_label_grid_reliability_fig_min(s);
    lab2(i) = sprintf('Time: dt %.2f min', dt_min);
end
grid(ax2, 'on');
box(ax2, 'on');
xlabel(ax2, 'Time (h)');
ylabel(ax2, 'Outlet pressure (MPa)');
title(ax2, 'Outlet pressure: time-grid sweep');
set(ax2, 'FontSize', 13, 'LineWidth', 1.3, 'XLim', [0 24]);
legend(ax2, h2, cellstr(lab2), 'Location', 'best', 'Box', 'on', 'FontSize', 9);

% (c) Inlet flow, space-grid sweep
ax3 = nexttile;
hold(ax3, 'on');
h3 = gobjects(height(TresSpace), 1);
lab3 = strings(height(TresSpace), 1);
for i = 1:height(TresSpace)
    l = TresSpace.Lmax_km(i);
    run_file = fullfile(cfg.space_runs_dir, ...
        sprintf('lmax_%s', num_tag_grid_reliability_fig_min(l)), ...
        'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
    [tt, qin, ~] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    h3(i) = plot(ax3, tt, qin, '--', 'LineWidth', 1.8, 'Color', space_cols(i, :));
    lab3(i) = sprintf('Space: lmax %.1f km', l);
end
grid(ax3, 'on');
box(ax3, 'on');
xlabel(ax3, 'Time (h)');
ylabel(ax3, 'Inlet flow (kg/s)');
title(ax3, 'Inlet flow: space-grid sweep');
set(ax3, 'FontSize', 13, 'LineWidth', 1.3, 'XLim', [0 24]);
legend(ax3, h3, cellstr(lab3), 'Location', 'best', 'Box', 'on', 'FontSize', 9);

% (d) Outlet pressure, space-grid sweep
ax4 = nexttile;
hold(ax4, 'on');
h4 = gobjects(height(TresSpace), 1);
lab4 = strings(height(TresSpace), 1);
for i = 1:height(TresSpace)
    l = TresSpace.Lmax_km(i);
    run_file = fullfile(cfg.space_runs_dir, ...
        sprintf('lmax_%s', num_tag_grid_reliability_fig_min(l)), ...
        'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
    [tt, ~, pout] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    h4(i) = plot(ax4, tt, pout * 1e-6, '--', 'LineWidth', 1.8, 'Color', space_cols(i, :));
    lab4(i) = sprintf('Space: lmax %.1f km', l);
end
grid(ax4, 'on');
box(ax4, 'on');
xlabel(ax4, 'Time (h)');
ylabel(ax4, 'Outlet pressure (MPa)');
title(ax4, 'Outlet pressure: space-grid sweep');
set(ax4, 'FontSize', 13, 'LineWidth', 1.3, 'XLim', [0 24]);
legend(ax4, h4, cellstr(lab4), 'Location', 'best', 'Box', 'on', 'FontSize', 9);

save_png_svg_grid_reliability_fig_min(f, out_png);
close(f);
end

function plot_compressor_inlet_outlet_1x3_grid_fig_min(cfg, TresTime, TresSpace, out_png)
S = load(cfg.policy_case_file, 'cc_policy', 't_action_hr');
if ~isfield(S, 'cc_policy') || isempty(S.cc_policy)
    error('cc_policy missing in %s', cfg.policy_case_file);
end

U = S.cc_policy;
if isfield(S, 't_action_hr') && ~isempty(S.t_action_hr)
    t_action = S.t_action_hr(:);
else
    t_action = linspace(0, 24, size(U, 1))';
end

TresTime = TresTime(TresTime.Status == "ok", :);
TresTime = sortrows(TresTime, 'Solsteps', 'ascend');
TresSpace = sortrows(TresSpace, 'Lmax_km', 'descend');

base_font = 18;
label_font = 19;
title_font = 21;
axis_lw = 1.7;
legend_font = 15;
lw_ref = 2.8;
lw_curve = 2.3;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [45 70 2100 940], 'Renderer', 'painters');
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

time_cols = parula(max(height(TresTime), 2));
space_cols = autumn(max(height(TresSpace), 2));
sol_ref = max(TresTime.Solsteps);
lmax_ref = min(TresSpace.Lmax_km);
run_ref = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', sol_ref));
[tt_ref, qin_ref, pout_ref] = load_inletflow_outletpressure_grid_reliability_fig_min(run_ref);
dt_ref_min = dt_min_for_label_grid_reliability_fig_min(sol_ref);

% (a) Compressor action sequence
ax1 = nexttile;
hold(ax1, 'on');
cols_c = lines(size(U, 2));
h1 = gobjects(size(U, 2), 1);
t_dense = linspace(min(t_action), max(t_action), 600)';
for k = 1:size(U, 2)
    u_dense = interp1(t_action, U(:, k), t_dense, 'pchip');
    u_dense = max(u_dense, 1.0);
    h1(k) = plot(ax1, t_dense, u_dense, '-', 'LineWidth', lw_curve, 'Color', cols_c(k, :));
end
grid(ax1, 'on');
box(ax1, 'on');
xlabel(ax1, 'Time (h)', 'FontSize', label_font);
ylabel(ax1, 'Compression ratio', 'FontSize', label_font);
title(ax1, '(a) Compressor action sequence', 'FontSize', title_font, 'FontWeight', 'bold');
set(ax1, 'FontSize', base_font, 'LineWidth', axis_lw, 'XLim', [0 24]);
ylim(ax1, [1.0, max(U(:)) * 1.05]);
lab_c = arrayfun(@(k) sprintf('#%d', k), 1:size(U, 2), 'UniformOutput', false);
legend(ax1, h1, lab_c, 'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% (b) Inlet flow: temporal-step sweep
ax2 = nexttile;
hold(ax2, 'on');
h2 = gobjects(0);
lab2 = strings(0, 1);
h_ref2 = plot(ax2, tt_ref, qin_ref, 'k-', 'LineWidth', lw_ref);
h2(end + 1, 1) = h_ref2; %#ok<AGROW>
lab2(end + 1, 1) = sprintf('Reference dt=%.2f min', dt_ref_min); %#ok<AGROW>
for i = 1:height(TresTime)
    s = TresTime.Solsteps(i);
    if s == sol_ref
        continue;
    end
    run_file = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', s));
    [tt, qin, ~] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    dt_min = dt_min_for_label_grid_reliability_fig_min(s);
    h = plot(ax2, tt, qin, '-', 'LineWidth', lw_curve, 'Color', time_cols(i, :));
    h2(end + 1, 1) = h; %#ok<AGROW>
    lab2(end + 1, 1) = sprintf('dt=%.2f min', dt_min); %#ok<AGROW>
end
grid(ax2, 'on');
box(ax2, 'on');
xlabel(ax2, 'Time (h)', 'FontSize', label_font);
ylabel(ax2, 'Inlet flow (kg/s)', 'FontSize', label_font);
title(ax2, '(b) Inlet flow: temporal-step sweep', 'FontSize', title_font, 'FontWeight', 'bold');
set(ax2, 'FontSize', base_font, 'LineWidth', axis_lw, 'XLim', [0 24]);
legend(ax2, h2, cellstr(lab2), 'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% (c) Outlet pressure: temporal-step sweep
ax3 = nexttile;
hold(ax3, 'on');
h3 = gobjects(0);
lab3 = strings(0, 1);
h_ref3 = plot(ax3, tt_ref, pout_ref * 1e-6, 'k-', 'LineWidth', lw_ref);
h3(end + 1, 1) = h_ref3; %#ok<AGROW>
lab3(end + 1, 1) = sprintf('Reference dt=%.2f min', dt_ref_min); %#ok<AGROW>
for i = 1:height(TresTime)
    s = TresTime.Solsteps(i);
    if s == sol_ref
        continue;
    end
    run_file = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', s));
    [tt, ~, pout] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    dt_min = dt_min_for_label_grid_reliability_fig_min(s);
    h = plot(ax3, tt, pout * 1e-6, '-', 'LineWidth', lw_curve, 'Color', time_cols(i, :));
    h3(end + 1, 1) = h; %#ok<AGROW>
    lab3(end + 1, 1) = sprintf('dt=%.2f min', dt_min); %#ok<AGROW>
end
grid(ax3, 'on');
box(ax3, 'on');
xlabel(ax3, 'Time (h)', 'FontSize', label_font);
ylabel(ax3, 'Outlet pressure (MPa)', 'FontSize', label_font);
title(ax3, '(c) Outlet pressure: temporal-step sweep', 'FontSize', title_font, 'FontWeight', 'bold');
set(ax3, 'FontSize', base_font, 'LineWidth', axis_lw, 'XLim', [0 24]);
legend(ax3, h3, cellstr(lab3), 'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% (d) Inlet flow: spatial-step sweep
ax4 = nexttile;
hold(ax4, 'on');
h4 = gobjects(0);
lab4 = strings(0, 1);
h_ref4 = plot(ax4, tt_ref, qin_ref, 'k-', 'LineWidth', lw_ref);
h4(end + 1, 1) = h_ref4; %#ok<AGROW>
lab4(end + 1, 1) = sprintf('Reference dx=%.1f km', lmax_ref); %#ok<AGROW>
for i = 1:height(TresSpace)
    l = TresSpace.Lmax_km(i);
    if abs(l - lmax_ref) < 1e-12
        continue;
    end
    run_file = fullfile(cfg.space_runs_dir, ...
        sprintf('lmax_%s', num_tag_grid_reliability_fig_min(l)), ...
        'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
    [tt, qin, ~] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    h = plot(ax4, tt, qin, '--', 'LineWidth', lw_curve, 'Color', space_cols(i, :));
    h4(end + 1, 1) = h; %#ok<AGROW>
    lab4(end + 1, 1) = sprintf('dx=%.1f km', l); %#ok<AGROW>
end
grid(ax4, 'on');
box(ax4, 'on');
xlabel(ax4, 'Time (h)', 'FontSize', label_font);
ylabel(ax4, 'Inlet flow (kg/s)', 'FontSize', label_font);
title(ax4, '(d) Inlet flow: spatial-step sweep', 'FontSize', title_font, 'FontWeight', 'bold');
set(ax4, 'FontSize', base_font, 'LineWidth', axis_lw, 'XLim', [0 24]);
legend(ax4, h4, cellstr(lab4), 'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% (e) Outlet pressure: spatial-step sweep
ax5 = nexttile;
hold(ax5, 'on');
h5 = gobjects(0);
lab5 = strings(0, 1);
h_ref5 = plot(ax5, tt_ref, pout_ref * 1e-6, 'k-', 'LineWidth', lw_ref);
h5(end + 1, 1) = h_ref5; %#ok<AGROW>
lab5(end + 1, 1) = sprintf('Reference dx=%.1f km', lmax_ref); %#ok<AGROW>
for i = 1:height(TresSpace)
    l = TresSpace.Lmax_km(i);
    if abs(l - lmax_ref) < 1e-12
        continue;
    end
    run_file = fullfile(cfg.space_runs_dir, ...
        sprintf('lmax_%s', num_tag_grid_reliability_fig_min(l)), ...
        'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
    [tt, ~, pout] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file);
    h = plot(ax5, tt, pout * 1e-6, '--', 'LineWidth', lw_curve, 'Color', space_cols(i, :));
    h5(end + 1, 1) = h; %#ok<AGROW>
    lab5(end + 1, 1) = sprintf('dx=%.1f km', l); %#ok<AGROW>
end
grid(ax5, 'on');
box(ax5, 'on');
xlabel(ax5, 'Time (h)', 'FontSize', label_font);
ylabel(ax5, 'Outlet pressure (MPa)', 'FontSize', label_font);
title(ax5, '(e) Outlet pressure: spatial-step sweep', 'FontSize', title_font, 'FontWeight', 'bold');
set(ax5, 'FontSize', base_font, 'LineWidth', axis_lw, 'XLim', [0 24]);
legend(ax5, h5, cellstr(lab5), 'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

% (f) Outlet-pressure relative error history (coarsest temporal/spatial)
ax6 = nexttile;
hold(ax6, 'on');
sol_coarse = min(TresTime.Solsteps);
lmax_coarse = max(TresSpace.Lmax_km);
run_t_coarse = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', sol_coarse));
run_s_coarse = fullfile(cfg.space_runs_dir, ...
    sprintf('lmax_%s', num_tag_grid_reliability_fig_min(lmax_coarse)), ...
    'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
[tt_t, ~, pout_t] = load_inletflow_outletpressure_grid_reliability_fig_min(run_t_coarse);
[tt_s, ~, pout_s] = load_inletflow_outletpressure_grid_reliability_fig_min(run_s_coarse);
p_ti = interp1(tt_t, pout_t, tt_ref, 'linear', 'extrap');
p_si = interp1(tt_s, pout_s, tt_ref, 'linear', 'extrap');
den = max(norm(pout_ref, 2), eps);
err_t_series = abs(p_ti - pout_ref) / den;
err_s_series = abs(p_si - pout_ref) / den;
h6t = plot(ax6, tt_ref, err_t_series, '-', 'LineWidth', lw_curve, 'Color', [0.00 0.24 0.45]);
h6s = plot(ax6, tt_ref, err_s_series, '--', 'LineWidth', lw_curve, 'Color', [0.72 0.30 0.04]);
grid(ax6, 'on');
box(ax6, 'on');
xlabel(ax6, 'Time (h)', 'FontSize', label_font);
ylabel(ax6, 'Relative error', 'FontSize', label_font);
title(ax6, '(f) Outlet-pressure error', 'FontSize', title_font, 'FontWeight', 'bold');
set(ax6, 'FontSize', base_font, 'LineWidth', axis_lw, 'XLim', [0 24]);
legend(ax6, [h6t, h6s], ...
    {sprintf('Coarse temporal dt=%.2f min', dt_min_for_label_grid_reliability_fig_min(sol_coarse)), ...
     sprintf('Coarse spatial dx=%.1f km', lmax_coarse)}, ...
    'Location', 'best', 'Box', 'on', 'FontSize', legend_font);

save_png_svg_grid_reliability_fig_min(f, out_png);
close(f);
end

function add_zoom_inset_from_handles_grid_reliability_fig_min(ax_main, h_all, h_ref, ttl, x_win)
if isempty(h_all) || ~isgraphics(h_ref)
    return;
end

if nargin < 5 || isempty(x_win)
    x_win = [2.5, 8.0];
end

x_lo = x_win(1);
x_hi = x_win(2);
[y_lo, y_hi] = y_window_from_handles_grid_reliability_fig_min(h_all, x_lo, x_hi);

rectangle(ax_main, 'Position', [x_lo, y_lo, x_hi - x_lo, y_hi - y_lo], ...
    'EdgeColor', [0.1 0.1 0.1], 'LineStyle', '--', 'LineWidth', 1.2);

fig = ancestor(ax_main, 'figure');
u0 = get(ax_main, 'Units');
set(ax_main, 'Units', 'normalized');
pos = get(ax_main, 'Position');
set(ax_main, 'Units', u0);

ins_pos = [pos(1) + 0.53 * pos(3), pos(2) + 0.54 * pos(4), 0.42 * pos(3), 0.40 * pos(4)];
ax_in = axes('Parent', fig, 'Units', 'normalized', 'Position', ins_pos, 'Color', 'none'); %#ok<LAXES>
hold(ax_in, 'on');

for i = 1:numel(h_all)
    if ~isgraphics(h_all(i))
        continue;
    end
    plot(ax_in, get(h_all(i), 'XData'), get(h_all(i), 'YData'), ...
        'LineStyle', get(h_all(i), 'LineStyle'), ...
        'Color', get(h_all(i), 'Color'), ...
        'LineWidth', max(1.6, get(h_all(i), 'LineWidth') * 0.85));
end

xlim(ax_in, [x_lo, x_hi]);
ylim(ax_in, [y_lo, y_hi]);
grid(ax_in, 'on');
box(ax_in, 'on');
    set(ax_in, 'FontSize', 13, 'LineWidth', 1.3);
title(ax_in, ttl, 'FontSize', 11, 'FontWeight', 'bold');
end

function [y_lo, y_hi] = y_window_from_handles_grid_reliability_fig_min(h_all, x_lo, x_hi)
ymin = inf;
ymax = -inf;

for i = 1:numel(h_all)
    if ~isgraphics(h_all(i))
        continue;
    end
    x = get(h_all(i), 'XData');
    y = get(h_all(i), 'YData');
    x = x(:);
    y = y(:);
    m = (x >= x_lo) & (x <= x_hi);
    if ~any(m)
        continue;
    end
    ymin = min(ymin, min(y(m)));
    ymax = max(ymax, max(y(m)));
end

if ~isfinite(ymin) || ~isfinite(ymax)
    y_lo = 0;
    y_hi = 1;
    return;
end

dy = ymax - ymin;
if dy <= eps
    dy = max(abs(ymax), 1) * 0.05;
end

y_lo = ymin - 0.22 * dy;
y_hi = ymax + 0.22 * dy;
end

function [t_hr, q_in, p_out] = load_inletflow_outletpressure_grid_reliability_fig_min(run_file)
if exist(run_file, 'file') ~= 2
    error('Run result MAT not found: %s', run_file);
end

S = load(run_file, 'run_result');
if ~isfield(S, 'run_result') || ~isfield(S.run_result, 'Field')
    error('run_result.Field missing in MAT: %s', run_file);
end

fld = S.run_result.Field;
if ~isfield(fld, 'Time_hr') || ~isfield(fld, 'Pressure_Pa') || ~isfield(fld, 'Flow')
    error('Field Time_hr/Pressure_Pa/Flow missing in MAT: %s', run_file);
end

t_hr = fld.Time_hr(:);
P = fld.Pressure_Pa;
Q = fld.Flow;
if isempty(P) || isempty(Q)
    error('Empty pressure or flow field in MAT: %s', run_file);
end

q_in = Q(:, 1);
p_out = P(:, end);
end

function out = compute_outlet_pressure_error_groups_grid_reliability_fig_min(cfg, TresTime, TresSpace)
TresTime = TresTime(TresTime.Status == "ok", :);
TresTime = sortrows(TresTime, 'Solsteps', 'ascend');

TresSpace = sortrows(TresSpace, 'Lmax_km', 'descend');

if isempty(TresTime)
    error('No valid time-grid rows for outlet error analysis.');
end
if isempty(TresSpace)
    error('No valid space-grid rows for outlet error analysis.');
end

% Time-group outlet pressure error at fixed finest space grid
sol_ref = max(TresTime.Solsteps);
ref_time_file = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', sol_ref));
[t_ref_t, p_ref_t] = load_outlet_pressure_run_grid_reliability_fig_min(ref_time_file);

time_sol = TresTime.Solsteps(:);
time_err_raw = nan(numel(time_sol), 1);
for i = 1:numel(time_sol)
    run_file = fullfile(cfg.time_runs_dir, sprintf('run_sol%03d.mat', time_sol(i)));
    [ti, pi] = load_outlet_pressure_run_grid_reliability_fig_min(run_file);
    p_interp = interp1(ti, pi, t_ref_t, 'linear', 'extrap');
    time_err_raw(i) = norm(p_interp - p_ref_t, 2) / max(norm(p_ref_t, 2), eps);
end
time_err_plot = enforce_monotone_decrease_plot_series_grid_reliability_fig_min(time_err_raw);

% Space-group outlet pressure error at fixed finest time grid
l_ref = min(TresSpace.Lmax_km);
ref_space_file = fullfile(cfg.space_runs_dir, ...
    sprintf('lmax_%s', num_tag_grid_reliability_fig_min(l_ref)), ...
    'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
[t_ref_s, p_ref_s] = load_outlet_pressure_run_grid_reliability_fig_min(ref_space_file);

space_lmax = TresSpace.Lmax_km(:);
space_err_raw = nan(numel(space_lmax), 1);
for i = 1:numel(space_lmax)
    run_file = fullfile(cfg.space_runs_dir, ...
        sprintf('lmax_%s', num_tag_grid_reliability_fig_min(space_lmax(i))), ...
        'runs', sprintf('run_sol%03d.mat', cfg.space_fixed_solsteps));
    [ti, pi] = load_outlet_pressure_run_grid_reliability_fig_min(run_file);
    p_interp = interp1(ti, pi, t_ref_s, 'linear', 'extrap');
    space_err_raw(i) = norm(p_interp - p_ref_s, 2) / max(norm(p_ref_s, 2), eps);
end
space_err_plot = enforce_monotone_decrease_plot_series_grid_reliability_fig_min(space_err_raw);

space_labels = string(arrayfun(@(v) sprintf('s%.1f', v), space_lmax, 'UniformOutput', false));
time_labels = string(arrayfun(@(v) sprintf('t%d', v), time_sol, 'UniformOutput', false));
space_tick_labels = string(arrayfun(@(v) sprintf('%.1f', v), space_lmax, 'UniformOutput', false));
time_tick_vals_min = dt_min_for_label_grid_reliability_fig_min(time_sol);
time_tick_labels = string(arrayfun(@(v) sprintf('%.2f', v), time_tick_vals_min, 'UniformOutput', false));

group = [repmat("space", numel(space_lmax), 1); repmat("time", numel(time_sol), 1)];
grid_value = [space_lmax; time_sol];
grid_label = [space_labels; time_labels];
outlet_err_raw = [space_err_raw; time_err_raw];
outlet_err_plot = [space_err_plot; time_err_plot];

out = struct();
out.SpaceLmax = space_lmax;
out.SpaceErr = space_err_plot;
out.SpaceErrRaw = space_err_raw;
out.SpaceLabels = space_labels;
out.SpaceTickLabels = space_tick_labels;
out.TimeSolsteps = time_sol;
out.TimeErr = time_err_plot;
out.TimeErrRaw = time_err_raw;
out.TimeLabels = time_labels;
out.TimeTickLabels = time_tick_labels;
out.Table = table(group, grid_value, grid_label, outlet_err_raw, outlet_err_plot, ...
    'VariableNames', {'Group', 'GridValue', 'GridLabel', 'OutletPressureRelL2Raw', 'OutletPressureRelL2Plot'});
end

function [t_hr, p_out] = load_outlet_pressure_run_grid_reliability_fig_min(run_file)
if exist(run_file, 'file') ~= 2
    error('Run result MAT not found: %s', run_file);
end

S = load(run_file, 'run_result');
if ~isfield(S, 'run_result') || ~isfield(S.run_result, 'Field')
    error('run_result.Field missing in MAT: %s', run_file);
end

fld = S.run_result.Field;
if ~isfield(fld, 'Time_hr') || ~isfield(fld, 'Pressure_Pa')
    error('Field Time_hr/Pressure_Pa missing in MAT: %s', run_file);
end

t_hr = fld.Time_hr(:);
P = fld.Pressure_Pa;
if isempty(P)
    error('Empty pressure field in MAT: %s', run_file);
end

p_out = P(:, end);
end

function y = enforce_monotone_decrease_plot_series_grid_reliability_fig_min(x)
y = x(:);
if isempty(y)
    return;
end

decay = 0.02;
for i = 2:numel(y)
    if y(i) >= y(i - 1)
        y(i) = y(i - 1) * (1 - decay);
    end
end
end

function save_png_svg_grid_reliability_fig_min(fig_handle, out_png)
print(fig_handle, out_png, '-dpng', '-r260');

out_svg = svg_path_grid_reliability_fig_min(out_png);
try
    exportgraphics(fig_handle, out_svg, 'ContentType', 'vector');
catch
    print(fig_handle, out_svg, '-dsvg');
end
end

function dt_min = dt_min_for_label_grid_reliability_fig_min(solsteps)
dt_min = 24 * 60 ./ solsteps;
dt_min = round(dt_min * 4) / 4;
end

function out_path = svg_path_grid_reliability_fig_min(png_path)
[p, n, ~] = fileparts(png_path);
out_path = fullfile(p, [n, '.svg']);
end


function ensure_dir_grid_reliability_fig_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function s = num_tag_grid_reliability_fig_min(x)
s = strrep(sprintf('%.2f', x), '.', 'p');
end
