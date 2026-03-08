function out = run_ref_old_2x5_pi_plot_min()
addpath('shap_src_min');

ref_dir = fullfile('shap_src_min', 'tr', 'ss_opt', 'ref-old');
if exist(ref_dir, 'dir') ~= 7
    mkdir(ref_dir);
end

cc_tr = load_tr_cost_policy_min();
cc_ss = read_action_sequence_min(fullfile('shap_src_min', 'tr', 'ss_opt', 'action_sequence.csv'));
[cc_w02, cc_w05, cc_w08] = load_pi_weight_policies_min();

n_actions = size(cc_tr, 1);
n_comp = size(cc_tr, 2);
if n_comp ~= 5
    error('Expected 5 compressors, got %d', n_comp);
end

t_hr = linspace(0, 24, n_actions)';
t_sec = t_hr * 3600;

seqs = cat(3, cc_tr, cc_ss, cc_w02, cc_w05, cc_w08);
n_methods = size(seqs, 3);
drdt = zeros(size(seqs));
for m = 1:n_methods
    for i = 1:n_comp
        drdt(:, i, m) = gradient(seqs(:, i, m), t_sec);
    end
end

method_names = {'tr-opt', 'ss-opt', 'PI-SHAP(w=0.2)', 'PI-SHAP(w=0.5)', 'PI-SHAP(w=0.8)'};
line_styles = {'-', '-', '--', '--', '--'};
colors = [ ...
    0.0000, 0.4470, 0.7410; ...
    0.8500, 0.3250, 0.0980; ...
    0.9290, 0.6940, 0.1250; ...
    0.4940, 0.1840, 0.5560; ...
    0.4660, 0.6740, 0.1880];
lw_curve = 2.4;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 2200 860]);
tiledlayout(2, 5, 'TileSpacing', 'compact', 'Padding', 'compact');

h_first = gobjects(n_methods, 1);

for i = 1:n_comp
    ax = nexttile(i);
    hold(ax, 'on');
    for m = 1:n_methods
        h = plot(ax, t_hr, seqs(:, i, m), ...
            'LineStyle', line_styles{m}, ...
            'Color', colors(m, :), ...
            'LineWidth', lw_curve);
        if i == 1
            h_first(m) = h;
        end
    end

    y_all = reshape(seqs(:, i, :), [], 1);
    y_min = min(y_all);
    y_max = max(y_all);
    y_pad = max(0.01, 0.08 * (y_max - y_min));
    xlim(ax, [0, 24]);
    xticks(ax, [0, 6, 12, 18, 24]);
    ylim(ax, [y_min - y_pad, y_max + y_pad]);

    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.45);
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 20, 'TickLabelInterpreter', 'latex', 'Box', 'on', 'LineWidth', 1.4);
    xlabel(ax, '$t\,(\mathrm{h})$', 'Interpreter', 'latex', 'FontSize', 24);
    ylabel(ax, sprintf('$r_{%d}$', i), 'Interpreter', 'latex', 'FontSize', 24);
    title(ax, sprintf('#%d', i), 'FontName', 'Times New Roman', 'FontSize', 24, 'FontWeight', 'bold');
end

for i = 1:n_comp
    ax = nexttile(5 + i);
    hold(ax, 'on');
    for m = 1:n_methods
        plot(ax, seqs(:, i, m), drdt(:, i, m), ...
            'LineStyle', line_styles{m}, ...
            'Color', colors(m, :), ...
            'LineWidth', lw_curve);
    end

    x_all = reshape(seqs(:, i, :), [], 1);
    y_all = reshape(drdt(:, i, :), [], 1);
    x_min = min(x_all);
    x_max = max(x_all);
    y_min = min(y_all);
    y_max = max(y_all);
    x_pad = max(0.01, 0.08 * (x_max - x_min));
    y_pad = max(1e-6, 0.12 * (y_max - y_min));
    xlim(ax, [x_min - x_pad, x_max + x_pad]);
    ylim(ax, [y_min - y_pad, y_max + y_pad]);

    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.45);
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 20, 'TickLabelInterpreter', 'latex', 'Box', 'on', 'LineWidth', 1.4);
    xlabel(ax, sprintf('$r_{%d}$', i), 'Interpreter', 'latex', 'FontSize', 24);
    ylabel(ax, sprintf('$\\dot{r}_{%d}\\,(\\mathrm{s}^{-1})$', i), 'Interpreter', 'latex', 'FontSize', 24);
    title(ax, sprintf('#%d', i), 'FontName', 'Times New Roman', 'FontSize', 24, 'FontWeight', 'bold');
end

lgd = legend(h_first, method_names, 'Orientation', 'horizontal', ...
    'Interpreter', 'none', 'FontName', 'Times New Roman', 'FontSize', 24, 'Box', 'on');
lgd.Layout.Tile = 'north';

png_file = fullfile(ref_dir, 'old_2x5_pi.png');
svg_file = fullfile(ref_dir, 'old_2x5_pi.svg');
set(f, 'Renderer', 'painters');
print(f, svg_file, '-dsvg');
print(f, png_file, '-dpng', '-r260');
close(f);

out = struct();
out.png_file = png_file;
out.svg_file = svg_file;
end


function [cc_w02, cc_w05, cc_w08] = load_pi_weight_policies_min()
tbl_file = fullfile('shap_src_min', 'performance3', 's020_multilevel_fix_v2', 'reviewer_outputs', 'tables', 'multi_weight_selection_shap.csv');
if exist(tbl_file, 'file') ~= 2
    error('Missing table: %s', tbl_file);
end

T = readtable(tbl_file, 'TextType', 'string');

cc_w02 = load_one_weight_policy_min(T, 0.2);
cc_w05 = load_one_weight_policy_min(T, 0.5);
cc_w08 = load_one_weight_policy_min(T, 0.8);
end


function cc = load_one_weight_policy_min(T, w)
mask = strcmp(T.Method, 'PI-SHAP') & abs(T.WSupply - w) < 1e-9;
idx = find(mask, 1, 'first');
if isempty(idx)
    error('PI-SHAP row not found for w=%.3f', w);
end

sample_file = char(T.SampleFile(idx));
if exist(sample_file, 'file') ~= 2
    error('Sample file missing: %s', sample_file);
end

S = load(sample_file, 'payload');
if ~isfield(S, 'payload') || ~isfield(S.payload, 'inputs') || ~isfield(S.payload.inputs, 'cc_policy')
    error('cc_policy not found in payload of %s', sample_file);
end

cc = S.payload.inputs.cc_policy;
if size(cc, 2) ~= 5
    error('cc_policy compressor dimension mismatch in %s', sample_file);
end
end


function cc = read_action_sequence_min(csv_file)
if exist(csv_file, 'file') ~= 2
    error('Missing action sequence csv: %s', csv_file);
end
T = readtable(csv_file);
if width(T) < 2
    error('Invalid action sequence csv format: %s', csv_file);
end
cc = table2array(T(:, 2:end));
end


function cc_tr = load_tr_cost_policy_min()
cost_file = fullfile('shap_src_min', 'tr', 'cost', 'case_cost_dt_1p00.mat');
if exist(cost_file, 'file') ~= 2
    error('Missing TR cost policy file: %s', cost_file);
end

S = load(cost_file, 'cc_policy');
if ~isfield(S, 'cc_policy')
    error('Field cc_policy not found in %s', cost_file);
end
cc_tr = S.cc_policy;
if size(cc_tr, 2) ~= 5
    error('TR cost policy compressor dimension mismatch: expected 5, got %d', size(cc_tr, 2));
end
end
