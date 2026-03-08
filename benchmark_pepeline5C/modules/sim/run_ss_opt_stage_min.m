function out = run_ss_opt_stage_min()
sim_dir = fileparts(mfilename('fullpath'));
stage_dir = fullfile('shap_src_min', 'sim', 'ss_opt_stage');

addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

if exist(stage_dir, 'dir') ~= 7
    mkdir(stage_dir);
end

try
    opengl('software');
catch
end

par = run_case_ss_opt();

if ~isfield(par, 'ss_start') || ~isfield(par, 'ss_terminal')
    error('ss_start or ss_terminal not found in SS optimization result.');
end

cc_start = par.ss_start.cc0(:,2);
cc_end = par.ss_terminal.cc0(:,2);

if numel(cc_start) ~= numel(cc_end)
    error('Start/end compressor ratio length mismatch: %d vs %d.', numel(cc_start), numel(cc_end));
end

comp_id = (1:numel(cc_start))';
abs_diff = abs(cc_start - cc_end);
rel_diff = abs_diff ./ max(abs(cc_start), 1e-12);

compare_tbl = table(comp_id, cc_start, cc_end, abs_diff, rel_diff, ...
    'VariableNames', {'CompID', 'CC_Start', 'CC_End', 'AbsDiff', 'RelDiffToStart'});

max_abs_diff = max(abs_diff);
mean_abs_diff = mean(abs_diff);
is_equal_exact = isequal(cc_start, cc_end);
is_equal_tol_1e6 = max_abs_diff <= 1e-6;
is_equal_tol_1e3 = max_abs_diff <= 1e-3;

status_start = nan;
status_end = nan;
if isfield(par.ss_start, 'ip_info') && isfield(par.ss_start.ip_info, 'status')
    status_start = par.ss_start.ip_info.status;
end
if isfield(par.ss_terminal, 'ip_info') && isfield(par.ss_terminal.ip_info, 'status')
    status_end = par.ss_terminal.ip_info.status;
end

save(fullfile(stage_dir, 'par_ss_opt_stage.mat'), 'par', '-v7.3');
save(fullfile(stage_dir, 'cc_start_end.mat'), ...
    'cc_start', 'cc_end', 'abs_diff', 'rel_diff', ...
    'max_abs_diff', 'mean_abs_diff', ...
    'is_equal_exact', 'is_equal_tol_1e6', 'is_equal_tol_1e3');
writetable(compare_tbl, fullfile(stage_dir, 'cc_start_end_compare.csv'));

plot_start_end_min(comp_id, cc_start, cc_end, stage_dir);
write_summary_min(stage_dir, compare_tbl, status_start, status_end, ...
    max_abs_diff, mean_abs_diff, is_equal_exact, is_equal_tol_1e6, is_equal_tol_1e3);

out = struct();
out.stage_dir = stage_dir;
out.status_start = status_start;
out.status_end = status_end;
out.max_abs_diff = max_abs_diff;
out.mean_abs_diff = mean_abs_diff;
out.is_equal_exact = is_equal_exact;
out.is_equal_tol_1e6 = is_equal_tol_1e6;
out.is_equal_tol_1e3 = is_equal_tol_1e3;
out.compare_table = compare_tbl;

fprintf('SS start/end compressor ratio comparison saved to: %s\n', stage_dir);
fprintf('Max abs diff = %.6g, Mean abs diff = %.6g\n', max_abs_diff, mean_abs_diff);
fprintf('Equal? exact=%d, tol1e-6=%d, tol1e-3=%d\n', ...
    is_equal_exact, is_equal_tol_1e6, is_equal_tol_1e3);
end

function plot_start_end_min(comp_id, cc_start, cc_end, stage_dir)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 980 450]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(comp_id, cc_start, 'o-', 'LineWidth', 1.8, 'MarkerSize', 6); hold on;
plot(comp_id, cc_end, 's--', 'LineWidth', 1.8, 'MarkerSize', 6);
xlabel('Compressor ID');
ylabel('Compression ratio');
title('SS start vs end compression ratios');
legend({'start', 'end'}, 'Location', 'best');
grid on;

nexttile;
bar(comp_id, cc_end - cc_start, 0.6);
xlabel('Compressor ID');
ylabel('End - Start');
title('Difference per compressor');
grid on;

print(f, fullfile(stage_dir, 'cc_start_end_compare.png'), '-dpng', '-r260');
close(f);
end

function write_summary_min(stage_dir, compare_tbl, status_start, status_end, ...
    max_abs_diff, mean_abs_diff, is_equal_exact, is_equal_tol_1e6, is_equal_tol_1e3)
summary_md = fullfile(stage_dir, 'ss_opt_start_end_summary.md');
fid = fopen(summary_md, 'w');
if fid < 0
    error('Cannot write summary file: %s', summary_md);
end

fprintf(fid, '# SS Opt Start/End Compressor Ratio Check\n\n');
fprintf(fid, '- start solve status: `%g`\n', status_start);
fprintf(fid, '- end solve status: `%g`\n', status_end);
fprintf(fid, '- max |end-start|: `%.8g`\n', max_abs_diff);
fprintf(fid, '- mean |end-start|: `%.8g`\n', mean_abs_diff);
fprintf(fid, '- equal (exact): `%d`\n', is_equal_exact);
fprintf(fid, '- equal (tol=1e-6): `%d`\n', is_equal_tol_1e6);
fprintf(fid, '- equal (tol=1e-3): `%d`\n\n', is_equal_tol_1e3);

fprintf(fid, '## Compression Ratios\n\n');
fprintf(fid, '| CompID | Start | End | AbsDiff | RelDiffToStart |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|\n');

for i = 1:height(compare_tbl)
    fprintf(fid, '| %d | %.10g | %.10g | %.10g | %.10g |\n', ...
        compare_tbl.CompID(i), ...
        compare_tbl.CC_Start(i), ...
        compare_tbl.CC_End(i), ...
        compare_tbl.AbsDiff(i), ...
        compare_tbl.RelDiffToStart(i));
end

fprintf(fid, '\nGenerated files:\n');
fprintf(fid, '- `par_ss_opt_stage.mat`\n');
fprintf(fid, '- `cc_start_end.mat`\n');
fprintf(fid, '- `cc_start_end_compare.csv`\n');
fprintf(fid, '- `cc_start_end_compare.png`\n');

fclose(fid);
end
