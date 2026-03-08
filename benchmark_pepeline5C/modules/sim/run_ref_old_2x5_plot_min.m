function out = run_ref_old_2x5_plot_min()
addpath('shap_src_min');

ref_dir = fullfile('shap_src_min', 'tr', 'ss_opt', 'ref-old');
if exist(ref_dir, 'dir') ~= 7
    mkdir(ref_dir);
end

cc_tr = load_tr_cost_policy_min();
cc_ss = read_action_sequence_min(fullfile('shap_src_min', 'tr', 'ss_opt', 'action_sequence.csv'));
cc_3 = read_action_sequence_min(fullfile('shap_src_min', 'tr', 'ss-3stage', 'action_sequence.csv'));
cc_7 = read_action_sequence_min(fullfile('shap_src_min', 'tr', 'ss-7stage', 'action_sequence.csv'));
cc_13 = read_action_sequence_min(fullfile('shap_src_min', 'tr', 'ss-13stage', 'action_sequence.csv'));

n_actions = size(cc_tr, 1);
n_comp = size(cc_tr, 2);
if n_comp ~= 5
    error('Expected 5 compressors, got %d', n_comp);
end

t_hr = linspace(0, 24, n_actions)';
t_sec = t_hr * 3600;

seqs = cat(3, cc_tr, cc_ss, cc_3, cc_7, cc_13);
n_methods = size(seqs, 3);
drdt = zeros(size(seqs));
for m = 1:n_methods
    for i = 1:n_comp
        drdt(:, i, m) = gradient(seqs(:, i, m), t_sec);
    end
end

method_names = {'tr-opt', 'ss-opt', 'ss-3stage', 'ss-7stage', 'ss-13stage'};
line_styles = {'-', '-', '--', '--', '--'};
colors = [ ...
    0.0000, 0.4470, 0.7410; ...
    0.8500, 0.3250, 0.0980; ...
    0.9290, 0.6940, 0.1250; ...
    0.4940, 0.1840, 0.5560; ...
    0.4660, 0.6740, 0.1880];
lw_curve = 2.4;

f = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 2200 980]);
tl = tiledlayout(2, 5, 'TileSpacing', 'loose', 'Padding', 'loose'); %#ok<NASGU>

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

png_file = fullfile(ref_dir, 'old_2x5.png');
svg_file = fullfile(ref_dir, 'old_2x5.svg');
set(f, 'Renderer', 'painters');
print(f, svg_file, '-dsvg');
print(f, png_file, '-dpng', '-r260');
close(f);

copyfile(png_file, fullfile(ref_dir, 'old.png'));
copyfile(png_file, fullfile(ref_dir, 'old2.png'));
copyfile(svg_file, fullfile(ref_dir, 'old.svg'));
copyfile(svg_file, fullfile(ref_dir, 'old2.svg'));

md_file = fullfile(ref_dir, 'old_2x5_caption.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write markdown file: %s', md_file);
end
fprintf(fid, '# SS Stage Figure (2x5)\n\n');
fprintf(fid, '![old_2x5](old_2x5.png)\n\n');
fprintf(fid, 'Caption: The top row compares the compressor-ratio trajectories of five units under `tr-opt` (from the cost-objective transient case at $\\Delta t=1$ h), `ss-opt`, `ss-3stage`, `ss-7stage`, and `ss-13stage`. The bottom row presents the corresponding phase portraits in mathematical coordinates $r_i$ and $\\dot{r}_i$ (s$^{-1}$), highlighting the distinct control-movement patterns induced by each strategy.\n');
fclose(fid);

out = struct();
out.png_file = png_file;
out.svg_file = svg_file;
out.md_file = md_file;
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
