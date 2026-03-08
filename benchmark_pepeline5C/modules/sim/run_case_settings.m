function out = run_case_settings()
cfg = case_config_sim();
sim_dir = fileparts(mfilename('fullpath'));

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

try
    opengl('software');
catch
end

ensure_dir_min(cfg.settings_dir);
ensure_dir_min(cfg.plot_dir);
ensure_dir_min(cfg.output_dir);

if exist(cfg.baseline_mat, 'file') ~= 2
    error('Baseline MAT not found: %s', cfg.baseline_mat);
end

S = load(cfg.baseline_mat, 'par');
par = S.par;
ss_ref = load_ss_reference_min();
n0 = gas_model_reader_new(cfg.model_folder);

node_tbl = build_node_table_min(n0);
edge_tbl = build_edge_table_min(n0);
comp_tbl = build_comp_table_min(n0);
gnode_tbl = build_gnode_table_min(n0);

writetable(node_tbl, cfg.topology_nodes_csv);
writetable(edge_tbl, cfg.topology_edges_csv);
writetable(comp_tbl, cfg.topology_compressors_csv);
writetable(gnode_tbl, cfg.topology_gnodes_csv);

boundary = load_boundary_min(cfg.model_folder);
[boundary_ts_tbl, boundary_stats_tbl] = build_boundary_tables_min(boundary);

writetable(boundary_ts_tbl, cfg.boundary_ts_csv);
writetable(boundary_stats_tbl, cfg.boundary_stats_csv);

case_snapshot = build_case_snapshot_min(par, n0, boundary, ss_ref);
write_snapshot_json_min(case_snapshot, cfg.case_snapshot_json);

plot_boundary_min(boundary, cfg.boundary_plot_png);
plot_topology_min(n0, cfg.topology_plot_png);
write_case_markdown_min(case_snapshot, boundary, cfg);

out = struct();
out.case_snapshot = case_snapshot;
out.topology_nodes_csv = cfg.topology_nodes_csv;
out.topology_edges_csv = cfg.topology_edges_csv;
out.topology_compressors_csv = cfg.topology_compressors_csv;
out.topology_gnodes_csv = cfg.topology_gnodes_csv;
out.boundary_ts_csv = cfg.boundary_ts_csv;
out.boundary_stats_csv = cfg.boundary_stats_csv;
out.boundary_plot_png = cfg.boundary_plot_png;
out.topology_plot_png = cfg.topology_plot_png;
out.settings_md = cfg.settings_md;

disp(['Case settings summary generated under ' cfg.settings_dir '.']);
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function tbl = build_node_table_min(n0)
psi_per_pa = 1 / 6894.757293168;

tbl = table();
tbl.NodeID = (1:n0.nv)';
tbl.NodeName = string(n0.node_name(:));
tbl.Xcoord = n0.xcoord(:);
tbl.Ycoord = n0.ycoord(:);
tbl.Pmin_Pa = n0.p_min(:);
tbl.Pmax_Pa = n0.p_max(:);
tbl.Pmin_psi = tbl.Pmin_Pa * psi_per_pa;
tbl.Pmax_psi = tbl.Pmax_Pa * psi_per_pa;
tbl.Qmin = n0.q_min(:);
tbl.Qmax = n0.q_max(:);
tbl.IsSlack = logical(n0.isslack(:));
end

function tbl = build_edge_table_min(n0)
is_comp = false(n0.ne, 1);
is_comp(n0.to_edge(:)) = true;

edge_type = repmat("pipe", n0.ne, 1);
edge_type(is_comp) = "compressor";

tbl = table();
tbl.EdgeID = (1:n0.ne)';
tbl.EdgeName = string(n0.pipe_name(:));
tbl.EdgeType = edge_type;
tbl.FromNode = n0.from_id(:);
tbl.ToNode = n0.to_id(:);
tbl.Length_km = n0.pipe_length(:);
tbl.Diameter_m = n0.diameter(:);
tbl.Lambda = n0.lambda(:);
tbl.DiscSeg = n0.disc_seg(:);
tbl.IsCompressorEdge = is_comp;
end

function tbl = build_comp_table_min(n0)
tbl = table();
tbl.CompID = (1:n0.nc)';
tbl.CompName = string(n0.comp_name(:));
tbl.LocNode = n0.loc_node(:);
tbl.ToEdge = n0.to_edge(:);
tbl.Cmin = n0.c_min(:);
tbl.Cmax = n0.c_max(:);
tbl.HPmax = n0.hp_max(:);
tbl.FlowMin = n0.flow_min(:);
tbl.FlowMax = n0.flow_max(:);
end

function tbl = build_gnode_table_min(n0)
tbl = table();
tbl.GNodeID = (1:n0.ng)';
tbl.GNodeName = string(n0.gnode_name(:));
tbl.PhysNode = n0.phys_node(:);
end

function boundary = load_boundary_min(model_folder)
boundary = struct();

boundary.t_hr = readmatrix(fullfile(model_folder, 'input_ts_tpts.csv'));

qbar_raw = readmatrix(fullfile(model_folder, 'input_ts_qbar.csv'));
boundary.qbar_nodes = qbar_raw(1,:);
boundary.qbar = qbar_raw(2:end,:);

boundary.gbar = readmatrix(fullfile(model_folder, 'input_ts_gbar.csv'));
if isvector(boundary.gbar)
    boundary.gbar = boundary.gbar(:);
end

pslack = readmatrix(fullfile(model_folder, 'input_ts_pslack.csv'));
pslack_dy = readmatrix(fullfile(model_folder, 'input_ts_pslack-dy.csv'));
cslack = readmatrix(fullfile(model_folder, 'input_ts_cslack.csv'));

boundary.pslack_id = pslack(1,:);
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

n_t = numel(boundary.t_hr);
assert(size(boundary.qbar,1) == n_t, 'qbar time length mismatch.');
assert(size(boundary.gbar,1) == n_t, 'gbar time length mismatch.');
assert(size(boundary.pslack,1) == n_t, 'pslack time length mismatch.');
assert(size(boundary.pslack_dy,1) == n_t, 'pslack-dy time length mismatch.');
assert(size(boundary.cslack,1) == n_t, 'cslack time length mismatch.');
assert(size(boundary.dmax,1) == n_t, 'dmax time length mismatch.');
assert(size(boundary.smax,1) == n_t, 'smax time length mismatch.');
end

function [ts_tbl, stats_tbl] = build_boundary_tables_min(boundary)
t_hr = boundary.t_hr(:);
q_total = sum(boundary.qbar, 2);
g_total = sum(boundary.gbar, 2);

ts_tbl = table();
ts_tbl.t_hr = t_hr;
ts_tbl.qbar_total = q_total;
ts_tbl.gbar_total = g_total;
ts_tbl.pslack_const = boundary.pslack(:,1);
ts_tbl.pslack_dy = boundary.pslack_dy(:,1);
ts_tbl.cslack = boundary.cslack(:,1);
ts_tbl.dmax = boundary.dmax(:,1);
ts_tbl.smax = boundary.smax(:,1);

for i = 1:numel(boundary.qbar_nodes)
    var_name = sprintf('qbar_node_%d', boundary.qbar_nodes(i));
    ts_tbl.(var_name) = boundary.qbar(:,i);
end

series_names = { ...
    'qbar_total', 'gbar_total', 'pslack_const', 'pslack_dy', 'cslack', 'dmax', 'smax'};
series_values = [ ...
    q_total, g_total, boundary.pslack(:,1), boundary.pslack_dy(:,1), ...
    boundary.cslack(:,1), boundary.dmax(:,1), boundary.smax(:,1)];

for i = 1:numel(boundary.qbar_nodes)
    series_names{end+1} = sprintf('qbar_node_%d', boundary.qbar_nodes(i)); %#ok<AGROW>
    series_values(:,end+1) = boundary.qbar(:,i); %#ok<AGROW>
end

n_series = numel(series_names);
stats_tbl = table();
stats_tbl.Variable = string(series_names(:));
stats_tbl.Min = zeros(n_series, 1);
stats_tbl.Max = zeros(n_series, 1);
stats_tbl.Mean = zeros(n_series, 1);
stats_tbl.Std = zeros(n_series, 1);
stats_tbl.NonzeroRatio = zeros(n_series, 1);

for i = 1:n_series
    x = series_values(:,i);
    stats_tbl.Min(i) = min(x);
    stats_tbl.Max(i) = max(x);
    stats_tbl.Mean(i) = mean(x);
    stats_tbl.Std(i) = std(x);
    stats_tbl.NonzeroRatio(i) = mean(abs(x) > 1e-12);
end
end

function snapshot = build_case_snapshot_min(par, n0, boundary, ss_ref)
q_total = sum(boundary.qbar, 2);
active_q_nodes = boundary.qbar_nodes(max(abs(boundary.qbar), [], 1) > 1e-12);

snapshot = struct();
snapshot.model_folder = 'data/model_mine';
snapshot.units_standard = par.out.units;
snapshot.do_compressibility = par.out.doZ;

snapshot.time_horizon_hr = par.tr.c.T / 3600;
snapshot.boundary_points = numel(boundary.t_hr);
snapshot.boundary_dt_hr = median(diff(boundary.t_hr));

snapshot.transient_optintervals = par.tr.optintervals;
snapshot.transient_Nvec = par.tr.Nvec;
snapshot.lmax_km = par.tr.lmax;

snapshot.ss_reference_source = ss_ref.source;
snapshot.ss_start_cc = ss_ref.cc_start;
snapshot.ss_terminal_cc = ss_ref.cc_end;

snapshot.node_count = n0.nv;
snapshot.edge_count = n0.ne;
snapshot.pipe_count = n0.ne - n0.nc;
snapshot.compressor_count = n0.nc;
snapshot.gnode_count = n0.ng;
snapshot.gnode_phys_nodes = n0.phys_node(:)';

snapshot.qbar_active_nodes = active_q_nodes;
snapshot.qbar_total_min = min(q_total);
snapshot.qbar_total_max = max(q_total);
snapshot.pslack_const_min = min(boundary.pslack(:,1));
snapshot.pslack_const_max = max(boundary.pslack(:,1));
snapshot.pslack_dy_min = min(boundary.pslack_dy(:,1));
snapshot.pslack_dy_max = max(boundary.pslack_dy(:,1));
snapshot.cslack_min = min(boundary.cslack(:,1));
snapshot.cslack_max = max(boundary.cslack(:,1));
end

function write_snapshot_json_min(snapshot, out_file)
fid = fopen(out_file, 'w');
if fid < 0
    error('Cannot write file: %s', out_file);
end
fprintf(fid, '%s\n', jsonencode(snapshot, 'PrettyPrint', true));
fclose(fid);
end

function plot_boundary_min(boundary, out_png)
t_hr = boundary.t_hr(:);
q_total = sum(boundary.qbar, 2);
active_mask = max(abs(boundary.qbar), [], 1) > 1e-12;
active_nodes = boundary.qbar_nodes(active_mask);

f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 900]);

subplot(2,2,1);
plot(t_hr, q_total, 'k-', 'LineWidth', 1.8); hold on;
for i = 1:numel(active_nodes)
    idx = find(boundary.qbar_nodes == active_nodes(i), 1);
    plot(t_hr, boundary.qbar(:,idx), '--', 'LineWidth', 1.4);
end
xlabel('Time (h)'); ylabel('qbar');
title('Withdrawal Boundary');
grid on;
legend_labels = [{'qbar total'}, arrayfun(@(x) sprintf('qbar node %d', x), active_nodes, 'UniformOutput', false)];
legend(legend_labels, 'Location', 'best');

subplot(2,2,2);
plot(t_hr, boundary.pslack(:,1), 'b-', 'LineWidth', 1.8); hold on;
plot(t_hr, boundary.pslack_dy(:,1), 'r--', 'LineWidth', 1.2);
xlabel('Time (h)'); ylabel('pslack');
title('Slack Pressure Profiles');
grid on;
legend({'pslack', 'pslack-dy'}, 'Location', 'best');

subplot(2,2,3);
plot(t_hr, boundary.cslack(:,1), 'm-', 'LineWidth', 1.8);
xlabel('Time (h)'); ylabel('cslack');
title('Slack Price Profile');
grid on;

subplot(2,2,4);
plot(t_hr, boundary.dmax(:,1), 'g-', 'LineWidth', 1.8); hold on;
plot(t_hr, boundary.smax(:,1), 'c--', 'LineWidth', 1.6);
xlabel('Time (h)'); ylabel('flow bound');
title('Demand/Supply Bound Profiles');
grid on;
legend({'dmax', 'smax'}, 'Location', 'best');

sgtitle('model_mine boundary conditions (input_ts_*)');

print(f, out_png, '-dpng', '-r220');
close(f);
end

function plot_topology_min(n0, out_png)
is_comp = false(n0.ne, 1);
is_comp(n0.to_edge(:)) = true;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 600]);
hold on;

for e = 1:n0.ne
    from_id = n0.from_id(e);
    to_id = n0.to_id(e);
    x_pair = [n0.xcoord(from_id), n0.xcoord(to_id)];
    y_pair = [n0.ycoord(from_id), n0.ycoord(to_id)];

    if is_comp(e)
        plot(x_pair, y_pair, '--', 'Color', [0.85 0.33 0.1], 'LineWidth', 2.0);
    else
        plot(x_pair, y_pair, '-', 'Color', [0.0 0.45 0.74], 'LineWidth', 2.0);
    end

    x_mid = mean(x_pair);
    y_mid = mean(y_pair);
    text(x_mid, y_mid, sprintf('E%d', e), 'FontSize', 8, 'Color', [0.2 0.2 0.2]);
end

slack_mask = logical(n0.isslack(:));
node_ids = (1:n0.nv)';

scatter(n0.xcoord(~slack_mask), n0.ycoord(~slack_mask), 70, [0.1 0.1 0.1], 'filled');
scatter(n0.xcoord(slack_mask), n0.ycoord(slack_mask), 90, [0.8 0.1 0.1], 'filled');

for i = 1:n0.nv
    text(n0.xcoord(i) + 0.01, n0.ycoord(i) + 0.01, sprintf('N%d', node_ids(i)), ...
        'FontSize', 9, 'Color', [0.0 0.0 0.0]);
end

pipe_h = plot(nan, nan, '-', 'Color', [0.0 0.45 0.74], 'LineWidth', 2.0);
comp_h = plot(nan, nan, '--', 'Color', [0.85 0.33 0.1], 'LineWidth', 2.0);
node_h = scatter(nan, nan, 70, [0.1 0.1 0.1], 'filled');
slack_h = scatter(nan, nan, 90, [0.8 0.1 0.1], 'filled');

legend([pipe_h, comp_h, node_h, slack_h], {'pipe edge', 'compressor edge', 'node', 'slack node'}, 'Location', 'best');

xlabel('X coordinate');
ylabel('Y coordinate');
title('model_mine topology map');
axis equal;
grid on;

print(f, out_png, '-dpng', '-r220');
close(f);
end

function write_case_markdown_min(snapshot, boundary, cfg)
md = fopen(cfg.settings_md, 'w');
if md < 0
    error('Cannot write markdown file: %s', cfg.settings_md);
end

fprintf(md, '# Case Setting Summary: data/model_mine\n\n');
fprintf(md, '## 1) Scope\n');
fprintf(md, '- model folder: `%s`\n', snapshot.model_folder);
fprintf(md, '- this summary is generated for the SHAP baseline workflow and reviewer-focused reruns\n\n');

fprintf(md, '## 2) Topology\n');
fprintf(md, '- nodes: %d\n', snapshot.node_count);
fprintf(md, '- edges: %d (pipes=%d, compressors=%d)\n', snapshot.edge_count, snapshot.pipe_count, snapshot.compressor_count);
fprintf(md, '- gas demand/supply nodes: %d (phys nodes: %s)\n', snapshot.gnode_count, mat2str(snapshot.gnode_phys_nodes));
fprintf(md, '- exported tables:\n');
fprintf(md, '  - `%s`\n', cfg.topology_nodes_csv);
fprintf(md, '  - `%s`\n', cfg.topology_edges_csv);
fprintf(md, '  - `%s`\n', cfg.topology_compressors_csv);
fprintf(md, '  - `%s`\n\n', cfg.topology_gnodes_csv);

fprintf(md, '## 3) Time and Optimization Settings\n');
fprintf(md, '- horizon: %.2f h\n', snapshot.time_horizon_hr);
fprintf(md, '- boundary grid points: %d (dt=%.2f h)\n', snapshot.boundary_points, snapshot.boundary_dt_hr);
fprintf(md, '- transient opt intervals: %d\n', snapshot.transient_optintervals);
fprintf(md, '- transient Nvec: `%s`\n', mat2str(snapshot.transient_Nvec));
fprintf(md, '- lmax: %.2f km\n', snapshot.lmax_km);
fprintf(md, '- units flag in baseline par.out.units: %d\n', snapshot.units_standard);
fprintf(md, '- compressibility enabled (doZ): %d\n', snapshot.do_compressibility);
fprintf(md, '- unified SS reference source: `%s`\n', snapshot.ss_reference_source);
fprintf(md, '- unified SS start cc: `%s`\n', mat2str(snapshot.ss_start_cc, 10));
fprintf(md, '- unified SS terminal cc: `%s`\n\n', mat2str(snapshot.ss_terminal_cc, 10));

fprintf(md, '## 4) Boundary Conditions (input_ts_*)\n');
fprintf(md, '- active qbar nodes: `%s`\n', mat2str(snapshot.qbar_active_nodes));
fprintf(md, '- qbar total range: [%.4f, %.4f]\n', snapshot.qbar_total_min, snapshot.qbar_total_max);
fprintf(md, '- pslack range (const profile): [%.4f, %.4f]\n', snapshot.pslack_const_min, snapshot.pslack_const_max);
fprintf(md, '- pslack range (dy profile): [%.4f, %.4f]\n', snapshot.pslack_dy_min, snapshot.pslack_dy_max);
fprintf(md, '- cslack range: [%.4f, %.4f]\n', snapshot.cslack_min, snapshot.cslack_max);
fprintf(md, '- exported boundary records:\n');
fprintf(md, '  - `%s`\n', cfg.boundary_ts_csv);
fprintf(md, '  - `%s`\n\n', cfg.boundary_stats_csv);

fprintf(md, '## 5) Plots\n');
fprintf(md, '- boundary overview: `%s`\n', cfg.boundary_plot_png);
fprintf(md, '- topology map: `%s`\n\n', cfg.topology_plot_png);

fprintf(md, '## 6) Suggested Execution Order\n');
fprintf(md, '1. steady-state endpoint optimization (`%s`)\n', fullfile(cfg.root_dir, 'run_case_ss_opt.m'));
fprintf(md, '2. transient optimization with fixed endpoints (`%s`)\n', fullfile(cfg.root_dir, 'run_case_tr_opt.m'));
fprintf(md, '3. transient simulation and policy evaluation (`%s`)\n', fullfile(cfg.root_dir, 'run_case_sim.m'));

fclose(md);
end
