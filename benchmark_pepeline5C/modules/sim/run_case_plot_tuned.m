function out = run_case_plot_tuned(style)
if nargin < 1
    style = default_style_min();
end

addpath('src');
addpath('shap_src_min');
addpath(fileparts(mfilename('fullpath')));

cfg = case_config_sim();
if exist(cfg.plot_dir, 'dir') ~= 7
    mkdir(cfg.plot_dir);
end

try
    opengl('software');
catch
end

n0 = gas_model_reader_new(cfg.model_folder);
boundary = load_boundary_min(cfg.model_folder);

out = struct();
out.boundary_png = fullfile(cfg.plot_dir, 'boundary_conditions_tuned.png');
out.topology_png = fullfile(cfg.plot_dir, 'network_topology_tuned.png');

plot_boundary_tuned_min(boundary, out.boundary_png, style);
plot_topology_tuned_min(n0, out.topology_png, style);

disp(['Saved tuned boundary plot: ' out.boundary_png]);
disp(['Saved tuned topology plot: ' out.topology_png]);
end

function style = default_style_min()
style = struct();
style.font_name = 'Times New Roman';
style.font_size = 12;
style.axis_linewidth = 1.2;
style.linewidth_main = 2.3;
style.linewidth_aux = 1.6;
style.marker_size = 40;
style.output_dpi = 280;

style.color_q_total = [0.05 0.05 0.05];
style.color_q_active = [0.00 0.45 0.74];
style.color_pslack = [0.00 0.45 0.74];
style.color_pslack_dy = [0.85 0.33 0.10];
style.color_cslack = [0.49 0.18 0.56];
style.color_dmax = [0.15 0.50 0.15];
style.color_smax = [0.30 0.75 0.93];

style.color_pipe = [0.00 0.45 0.74];
style.color_comp = [0.85 0.33 0.10];
style.color_node = [0.10 0.10 0.10];
style.color_slack = [0.75 0.00 0.00];
style.color_gnode = [0.00 0.60 0.20];
end

function boundary = load_boundary_min(model_folder)
boundary = struct();

boundary.t_hr = readmatrix(fullfile(model_folder, 'input_ts_tpts.csv'));

qbar_raw = readmatrix(fullfile(model_folder, 'input_ts_qbar.csv'));
boundary.qbar_nodes = qbar_raw(1,:);
boundary.qbar = qbar_raw(2:end,:);

pslack = readmatrix(fullfile(model_folder, 'input_ts_pslack.csv'));
pslack_dy = readmatrix(fullfile(model_folder, 'input_ts_pslack-dy.csv'));
cslack = readmatrix(fullfile(model_folder, 'input_ts_cslack.csv'));

boundary.pslack = pslack(2:end,:);
boundary.pslack_dy = pslack_dy(2:end,:);
boundary.cslack = cslack(2:end,:);

boundary.dmax = readmatrix(fullfile(model_folder, 'input_ts_dmax.csv'));
boundary.smax = readmatrix(fullfile(model_folder, 'input_ts_smax.csv'));
if isvector(boundary.dmax)
    boundary.dmax = boundary.dmax(:);
end
if isvector(boundary.smax)
    boundary.smax = boundary.smax(:);
end
end

function plot_boundary_tuned_min(boundary, out_png, style)
t_hr = boundary.t_hr(:);
q_total = sum(boundary.qbar, 2);
active_mask = max(abs(boundary.qbar), [], 1) > 1e-12;
active_nodes = boundary.qbar_nodes(active_mask);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1300 900]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>

ax1 = nexttile;
plot(t_hr, q_total, '-', 'Color', style.color_q_total, 'LineWidth', style.linewidth_main); hold on;
for i = 1:numel(active_nodes)
    idx = find(boundary.qbar_nodes == active_nodes(i), 1);
    plot(t_hr, boundary.qbar(:,idx), '--', 'Color', style.color_q_active, 'LineWidth', style.linewidth_aux);
end
title('qbar boundary (total and active node)');
xlabel('Time (h)');
ylabel('qbar');
grid on;
legend_labels = [{'qbar total'}, arrayfun(@(x) sprintf('qbar@node%d', x), active_nodes, 'UniformOutput', false)];
legend(legend_labels, 'Location', 'best');
style_axis_min(ax1, style);

ax2 = nexttile;
plot(t_hr, boundary.pslack(:,1), '-', 'Color', style.color_pslack, 'LineWidth', style.linewidth_main); hold on;
plot(t_hr, boundary.pslack_dy(:,1), '--', 'Color', style.color_pslack_dy, 'LineWidth', style.linewidth_aux);
title('Slack pressure profiles');
xlabel('Time (h)');
ylabel('pslack');
grid on;
legend({'pslack (const)', 'pslack-dy'}, 'Location', 'best');
style_axis_min(ax2, style);

ax3 = nexttile;
dqdt = gradient(q_total, t_hr);
plot(t_hr, dqdt, '-', 'Color', style.color_q_active, 'LineWidth', style.linewidth_aux);
yline(0, ':', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.0);
title('qbar slope');
xlabel('Time (h)');
ylabel('dqbar/dt');
grid on;
style_axis_min(ax3, style);

ax4 = nexttile;
yyaxis left;
plot(t_hr, boundary.dmax(:,1), '-', 'Color', style.color_dmax, 'LineWidth', style.linewidth_main); hold on;
plot(t_hr, boundary.smax(:,1), '--', 'Color', style.color_smax, 'LineWidth', style.linewidth_aux);
ylabel('dmax / smax');
yyaxis right;
plot(t_hr, boundary.cslack(:,1), '-', 'Color', style.color_cslack, 'LineWidth', style.linewidth_aux);
ylabel('cslack');
title('Bounds and slack price');
xlabel('Time (h)');
grid on;
legend({'dmax', 'smax', 'cslack'}, 'Location', 'best');
style_axis_min(ax4, style);

sgtitle('model_mine boundary conditions (tuned)', 'FontName', style.font_name, 'FontSize', style.font_size + 2, 'FontWeight', 'bold');
print(f, out_png, '-dpng', ['-r' num2str(style.output_dpi)]);
close(f);
end

function plot_topology_tuned_min(n0, out_png, style)
is_comp = false(n0.ne, 1);
is_comp(n0.to_edge(:)) = true;

gnode_set = unique(n0.phys_node(:));
slack_mask = logical(n0.isslack(:));
gnode_mask = false(n0.nv, 1);
gnode_mask(gnode_set) = true;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1150 650]);
hold on;

for e = 1:n0.ne
    from_id = n0.from_id(e);
    to_id = n0.to_id(e);
    x_pair = [n0.xcoord(from_id), n0.xcoord(to_id)];
    y_pair = [n0.ycoord(from_id), n0.ycoord(to_id)];

    if is_comp(e)
        plot(x_pair, y_pair, '--', 'Color', style.color_comp, 'LineWidth', style.linewidth_main);
    else
        plot(x_pair, y_pair, '-', 'Color', style.color_pipe, 'LineWidth', style.linewidth_main);
    end

    x_mid = mean(x_pair);
    y_mid = mean(y_pair);
    text(x_mid, y_mid, sprintf('E%d', e), 'FontSize', style.font_size - 3, 'Color', [0.25 0.25 0.25]);
end

normal_nodes = ~(slack_mask | gnode_mask);
scatter(n0.xcoord(normal_nodes), n0.ycoord(normal_nodes), style.marker_size, style.color_node, 'filled');
scatter(n0.xcoord(slack_mask), n0.ycoord(slack_mask), style.marker_size + 20, style.color_slack, 'filled', 'd');
scatter(n0.xcoord(gnode_mask), n0.ycoord(gnode_mask), style.marker_size + 30, style.color_gnode, 'filled', '^');

for i = 1:n0.nv
    text(n0.xcoord(i) + 0.012, n0.ycoord(i) + 0.012, sprintf('N%d', i), ...
        'FontSize', style.font_size - 2, 'FontWeight', 'bold', 'Color', [0.08 0.08 0.08]);
end

pipe_h = plot(nan, nan, '-', 'Color', style.color_pipe, 'LineWidth', style.linewidth_main);
comp_h = plot(nan, nan, '--', 'Color', style.color_comp, 'LineWidth', style.linewidth_main);
node_h = scatter(nan, nan, style.marker_size, style.color_node, 'filled');
slack_h = scatter(nan, nan, style.marker_size + 20, style.color_slack, 'filled', 'd');
gnode_h = scatter(nan, nan, style.marker_size + 30, style.color_gnode, 'filled', '^');
legend([pipe_h, comp_h, node_h, slack_h, gnode_h], ...
    {'pipe', 'compressor', 'node', 'slack node', 'gnode phys node'}, ...
    'Location', 'best');

xlabel('X coordinate');
ylabel('Y coordinate');
title('model_mine topology (tuned)', 'FontName', style.font_name, 'FontSize', style.font_size + 2, 'FontWeight', 'bold');
axis equal;
grid on;
set(gca, 'FontName', style.font_name, 'FontSize', style.font_size, 'LineWidth', style.axis_linewidth);

print(f, out_png, '-dpng', ['-r' num2str(style.output_dpi)]);
close(f);
end

function style_axis_min(ax, style)
set(ax, 'FontName', style.font_name, 'FontSize', style.font_size, 'LineWidth', style.axis_linewidth);
end
