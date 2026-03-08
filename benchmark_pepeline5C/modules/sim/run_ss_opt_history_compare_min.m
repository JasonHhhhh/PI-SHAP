function out = run_ss_opt_history_compare_min()
sim_dir = fileparts(mfilename('fullpath'));
stage_dir = fullfile('shap_src_min', 'sim', 'ss_opt_stage');

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

if exist(fullfile(stage_dir, 'cc_start_end.mat'), 'file') ~= 2
    run_ss_opt_stage_min();
end

cur = load(fullfile(stage_dir, 'cc_start_end.mat'));
cc_cur_start = cur.cc_start(:)';
cc_cur_end = cur.cc_end(:)';

refs = {};

if exist(fullfile('shap_src', 'par_baseline_opt.mat'), 'file') == 2
    B = load(fullfile('shap_src', 'par_baseline_opt.mat'), 'par');
    refs{end+1} = build_ref_from_par_min('par_baseline_opt.mat', B.par); %#ok<AGROW>
end

if exist(fullfile('shap_src', 'par_ss_opt.mat'), 'file') == 2
    S = load(fullfile('shap_src', 'par_ss_opt.mat'), 'par');
    refs{end+1} = build_ref_from_par_min('par_ss_opt.mat', S.par); %#ok<AGROW>
end

if exist(fullfile('data', 'model_mine', 'output_ss_start_comp-ratios.csv'), 'file') == 2 && ...
        exist(fullfile('data', 'model_mine', 'output_ss_terminal_comp-ratios.csv'), 'file') == 2
    refs{end+1} = build_ref_from_csv_min( ...
        'data/model_mine/output_ss_*_comp-ratios.csv', ...
        fullfile('data', 'model_mine', 'output_ss_start_comp-ratios.csv'), ...
        fullfile('data', 'model_mine', 'output_ss_terminal_comp-ratios.csv')); %#ok<AGROW>
end

n_ref = numel(refs);
name_col = strings(n_ref, 1);
max_diff_start = nan(n_ref, 1);
max_diff_end = nan(n_ref, 1);
mean_diff_start = nan(n_ref, 1);
mean_diff_end = nan(n_ref, 1);
pslack_range = strings(n_ref, 1);

for i = 1:n_ref
    name_col(i) = refs{i}.name;
    max_diff_start(i) = max(abs(cc_cur_start - refs{i}.cc_start));
    max_diff_end(i) = max(abs(cc_cur_end - refs{i}.cc_end));
    mean_diff_start(i) = mean(abs(cc_cur_start - refs{i}.cc_start));
    mean_diff_end(i) = mean(abs(cc_cur_end - refs{i}.cc_end));
    pslack_range(i) = refs{i}.pslack_note;
end

cmp_tbl = table(name_col, max_diff_start, max_diff_end, mean_diff_start, mean_diff_end, pslack_range, ...
    'VariableNames', {'Reference', 'MaxAbsDiffStart', 'MaxAbsDiffEnd', 'MeanAbsDiffStart', 'MeanAbsDiffEnd', 'PslackNote'});

writetable(cmp_tbl, fullfile(stage_dir, 'history_compare_table.csv'));
write_compare_md_min(stage_dir, cmp_tbl, cc_cur_start, cc_cur_end, refs);
plot_file = plot_history_compare_min(stage_dir, cc_cur_start, cc_cur_end, refs, cmp_tbl);

out = struct();
out.compare_table = cmp_tbl;
out.stage_dir = stage_dir;
out.plot_file = plot_file;

disp(cmp_tbl);
end

function ref = build_ref_from_par_min(name, par)
if ~isfield(par, 'ss_start') || ~isfield(par, 'ss_terminal')
    error('Reference MAT %s does not contain ss_start/ss_terminal.', name);
end

ref = struct();
ref.name = string(name);
ref.cc_start = par.ss_start.cc0(:,2)';
ref.cc_end = par.ss_terminal.cc0(:,2)';

if isfield(par, 'ss') && isfield(par.ss, 'm') && isfield(par.ss.m, 'Pslack')
    p = full(par.ss.m.Pslack(:));
    ref.pslack_note = sprintf('[%.6g, %.6g]', min(p), max(p));
else
    ref.pslack_note = 'n/a';
end
end

function ref = build_ref_from_csv_min(name, start_csv, end_csv)
s = readmatrix(start_csv);
t = readmatrix(end_csv);

ref = struct();
ref.name = string(name);
ref.cc_start = s(2,:);
ref.cc_end = t(2,:);
ref.pslack_note = 'unknown (csv only)';
end

function write_compare_md_min(stage_dir, cmp_tbl, cc_cur_start, cc_cur_end, refs)
md_file = fullfile(stage_dir, 'history_compare_summary.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write compare summary markdown: %s', md_file);
end

fprintf(fid, '# SS Opt History Comparison\n\n');
fprintf(fid, 'Current run reference: `shap_src_min/sim/ss_opt_stage/cc_start_end.mat`\n\n');

fprintf(fid, '## 1) Difference table\n\n');
fprintf(fid, '| Reference | MaxAbsDiffStart | MaxAbsDiffEnd | MeanAbsDiffStart | MeanAbsDiffEnd | PslackNote |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---|\n');
for i = 1:height(cmp_tbl)
    fprintf(fid, '| %s | %.10g | %.10g | %.10g | %.10g | %s |\n', ...
        cmp_tbl.Reference(i), ...
        cmp_tbl.MaxAbsDiffStart(i), ...
        cmp_tbl.MaxAbsDiffEnd(i), ...
        cmp_tbl.MeanAbsDiffStart(i), ...
        cmp_tbl.MeanAbsDiffEnd(i), ...
        cmp_tbl.PslackNote(i));
end

fprintf(fid, '\n## 2) Current run compressor ratios\n\n');
fprintf(fid, '- start: `%s`\n', mat2str(cc_cur_start, 12));
fprintf(fid, '- end: `%s`\n\n', mat2str(cc_cur_end, 12));

fprintf(fid, '## 3) Reference vectors\n\n');
for i = 1:numel(refs)
    fprintf(fid, '- %s start: `%s`\n', refs{i}.name, mat2str(refs{i}.cc_start, 12));
    fprintf(fid, '- %s end: `%s`\n', refs{i}.name, mat2str(refs{i}.cc_end, 12));
end

fclose(fid);
end

function plot_file = plot_history_compare_min(stage_dir, cc_cur_start, cc_cur_end, refs, cmp_tbl)
n_comp = numel(cc_cur_start);
comp_id = 1:n_comp;

plot_file = fullfile(stage_dir, 'history_compare_plot.png');

f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1550 500]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
h1 = gobjects(0);
l1 = {};
h1(end+1) = plot(comp_id, cc_cur_start, 'ko-', 'LineWidth', 2.2, 'MarkerSize', 7); hold on;
l1{end+1} = 'current';
for i = 1:numel(refs)
    if numel(refs{i}.cc_start) == n_comp
        h1(end+1) = plot(comp_id, refs{i}.cc_start, '--', 'LineWidth', 1.8, 'MarkerSize', 6);
        l1{end+1} = short_ref_name_min(refs{i}.name); %#ok<AGROW>
    end
end
xlabel('Compressor ID');
ylabel('Compression ratio');
title('Start ratios: current vs history');
grid on;
lg1 = legend(ax1, h1, l1, 'Interpreter', 'none', 'Location', 'northwest');
set(lg1, 'FontSize', 9, 'Box', 'on');
set(ax1, 'FontSize', 11, 'LineWidth', 1.1);

ax2 = nexttile;
h2 = gobjects(0);
l2 = {};
h2(end+1) = plot(comp_id, cc_cur_end, 'ko-', 'LineWidth', 2.2, 'MarkerSize', 7); hold on;
l2{end+1} = 'current';
for i = 1:numel(refs)
    if numel(refs{i}.cc_end) == n_comp
        h2(end+1) = plot(comp_id, refs{i}.cc_end, '--', 'LineWidth', 1.8, 'MarkerSize', 6);
        l2{end+1} = short_ref_name_min(refs{i}.name); %#ok<AGROW>
    end
end
xlabel('Compressor ID');
ylabel('Compression ratio');
title('End ratios: current vs history');
grid on;
lg2 = legend(ax2, h2, l2, 'Interpreter', 'none', 'Location', 'northwest');
set(lg2, 'FontSize', 9, 'Box', 'on');
set(ax2, 'FontSize', 11, 'LineWidth', 1.1);

ax3 = nexttile;
b = bar([cmp_tbl.MaxAbsDiffStart, cmp_tbl.MaxAbsDiffEnd], 0.8, 'grouped');
b(1).FaceColor = [0.00 0.45 0.74];
b(2).FaceColor = [0.85 0.33 0.10];
xticks(1:height(cmp_tbl));
xticklabels(arrayfun(@short_ref_name_min, cmp_tbl.Reference, 'UniformOutput', false));
xtickangle(20);
ylabel('Max absolute difference');
title('Difference summary');
lg3 = legend({'Start diff', 'End diff'}, 'Location', 'northwest');
set(lg3, 'FontSize', 9, 'Box', 'on');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.1);
set(ax3, 'TickLabelInterpreter', 'none');

sgtitle('SS start/end ratio historical comparison', 'FontSize', 14, 'FontWeight', 'bold');
print(f, plot_file, '-dpng', '-r260');
close(f);
end

function label = short_ref_name_min(name)
name_char = char(name);
if contains(name_char, 'par_baseline_opt.mat')
    label = 'baseline_mat';
elseif contains(name_char, 'par_ss_opt.mat')
    label = 'ss_opt_mat';
elseif contains(name_char, 'output_ss_*_comp-ratios.csv')
    label = 'old_csv';
else
    label = name_char;
end
end
