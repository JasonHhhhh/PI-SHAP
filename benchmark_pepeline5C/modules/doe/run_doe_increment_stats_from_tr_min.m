function out = run_doe_increment_stats_from_tr_min()
root_dir = fullfile('shap_src_min', 'tr');
cost_dir = fullfile(root_dir, 'cost');
mix_dir = fullfile(root_dir, 'cost_supply');

if exist(cost_dir, 'dir') ~= 7 || exist(mix_dir, 'dir') ~= 7
    error('Expected folders not found: %s and %s', cost_dir, mix_dir);
end

out_dir = fullfile('shap_src_min', 'doe', 'increment_stats_reference');
plot_dir = fullfile(out_dir, 'plots');

ensure_dir_min(out_dir);
reset_dir_contents_min(out_dir);
ensure_dir_min(plot_dir);

cost_files = dir(fullfile(cost_dir, 'case_cost_dt_*.mat'));
mix_files = dir(fullfile(mix_dir, 'case_w*.mat'));

if isempty(cost_files) || isempty(mix_files)
    error('No case MAT files found under cost or cost_supply folders.');
end

rows = [];
rows = [rows; collect_case_rows_min(cost_files, 'cost', cost_dir)]; %#ok<AGROW>
rows = [rows; collect_case_rows_min(mix_files, 'cost_supply', mix_dir)]; %#ok<AGROW>

case_tbl = struct2table(rows);
case_tbl = sortrows(case_tbl, {'Source', 'ActionDt_hr', 'WSupply'});

writetable(case_tbl, fullfile(out_dir, 'case_increment_stats.csv'));

quant_tbl = compute_quantile_table_min(case_tbl);
writetable(quant_tbl, fullfile(out_dir, 'source_quantiles.csv'));

[rec_low, rec_mid, rec_high] = reference_band_min(quant_tbl);

plot_increment_reference_min(case_tbl, quant_tbl, plot_dir);
write_reference_md_min(out_dir, case_tbl, quant_tbl, rec_low, rec_mid, rec_high);

out = struct();
out.out_dir = out_dir;
out.plot_dir = plot_dir;
out.case_tbl = case_tbl;
out.quant_tbl = quant_tbl;
out.reference_band = [rec_low rec_mid rec_high];

disp(case_tbl);
disp(quant_tbl);
fprintf('Reference |Delta c|/h band (exclude terminal): [%.6f, %.6f, %.6f]\n', rec_low, rec_mid, rec_high);
end

function rows = collect_case_rows_min(files, source_name, folder)
row_template = struct( ...
    'Source', "", ...
    'CaseFile', "", ...
    'ActionDt_hr', nan, ...
    'WSupply', nan, ...
    'IpoptStatus', nan, ...
    'NActions', nan, ...
    'NComp', nan, ...
    'NIncrementsNoTerminal', nan, ...
    'MaxAbsIncNoTerminal', nan, ...
    'P95AbsIncNoTerminal', nan, ...
    'MeanAbsIncNoTerminal', nan, ...
    'MaxAbsIncTerminal', nan, ...
    'MaxAbsIncAll', nan, ...
    'MaxAbsIncNoTerminalPerHour', nan, ...
    'P95AbsIncNoTerminalPerHour', nan, ...
    'MeanAbsIncNoTerminalPerHour', nan);

rows = repmat(row_template, 0, 1);
for i = 1:numel(files)
    fp = fullfile(folder, files(i).name);
    S = load(fp);

    if ~isfield(S, 'cc_policy')
        continue;
    end
    cc = S.cc_policy;
    if isempty(cc)
        continue;
    end

    dt_hr = parse_dt_from_struct_or_name_min(S, files(i).name, source_name);
    w_s = parse_weight_from_struct_or_name_min(S, files(i).name, source_name);
    ip_status = nan;
    if isfield(S, 'solve_meta') && isfield(S.solve_meta, 'status')
        ip_status = S.solve_meta.status;
    end

    delta_all = diff(cc, 1, 1);
    if isempty(delta_all)
        continue;
    end

    if size(delta_all, 1) >= 2
        delta_no_term = delta_all(1:end-1, :);
    else
        delta_no_term = zeros(0, size(delta_all, 2));
    end

    abs_all = abs(delta_all(:));
    abs_no_term = abs(delta_no_term(:));
    if isempty(abs_no_term)
        max_no_term = nan;
        p95_no_term = nan;
        mean_no_term = nan;
        n_no_term = 0;
    else
        max_no_term = max(abs_no_term);
        p95_no_term = prctile(abs_no_term, 95);
        mean_no_term = mean(abs_no_term);
        n_no_term = numel(abs_no_term);
    end

    row = row_template;
    row.Source = string(source_name);
    row.CaseFile = string(files(i).name);
    row.ActionDt_hr = dt_hr;
    row.WSupply = w_s;
    row.IpoptStatus = ip_status;
    row.NActions = size(cc, 1);
    row.NComp = size(cc, 2);
    row.NIncrementsNoTerminal = n_no_term;
    row.MaxAbsIncNoTerminal = max_no_term;
    row.P95AbsIncNoTerminal = p95_no_term;
    row.MeanAbsIncNoTerminal = mean_no_term;
    row.MaxAbsIncTerminal = max(abs(delta_all(end, :)));
    row.MaxAbsIncAll = max(abs_all);
    row.MaxAbsIncNoTerminalPerHour = max_no_term / dt_hr;
    row.P95AbsIncNoTerminalPerHour = p95_no_term / dt_hr;
    row.MeanAbsIncNoTerminalPerHour = mean_no_term / dt_hr;

    rows(end+1, 1) = row; %#ok<AGROW>
end
end

function dt_hr = parse_dt_from_struct_or_name_min(S, name, source_name)
dt_hr = nan;
if isfield(S, 'dt_hr')
    dt_hr = double(S.dt_hr);
elseif isfield(S, 'action_dt_hr')
    dt_hr = double(S.action_dt_hr);
end

if ~isnan(dt_hr)
    return;
end

if strcmp(source_name, 'cost')
    m = regexp(name, 'case_cost_dt_(\d+)p(\d+)\.mat', 'tokens', 'once');
else
    m = regexp(name, 'case_w\d+p\d+\.mat', 'tokens', 'once'); %#ok<NASGU>
end

if strcmp(source_name, 'cost')
    m = regexp(name, 'case_cost_dt_(\d+)p(\d+)\.mat', 'tokens', 'once');
    if ~isempty(m)
        dt_hr = str2double([m{1} '.' m{2}]);
    else
        dt_hr = 1.0;
    end
else
    dt_hr = 1.0;
end
end

function w_s = parse_weight_from_struct_or_name_min(S, name, source_name)
if strcmp(source_name, 'cost')
    w_s = 0.0;
    return;
end

w_s = nan;
if isfield(S, 'w_s')
    w_s = double(S.w_s);
end
if ~isnan(w_s)
    return;
end

m = regexp(name, 'case_w(\d+)p(\d+)\.mat', 'tokens', 'once');
if ~isempty(m)
    w_s = str2double([m{1} '.' m{2}]);
else
    w_s = nan;
end
end

function quant_tbl = compute_quantile_table_min(case_tbl)
q = [10 25 50 75 90 95 99];
groups = ["cost" "cost_supply" "all"];

row_template = struct( ...
    'Source', "", ...
    'CaseCount', nan, ...
    'MaxPerHour_Q10', nan, ...
    'MaxPerHour_Q25', nan, ...
    'MaxPerHour_Q50', nan, ...
    'MaxPerHour_Q75', nan, ...
    'MaxPerHour_Q90', nan, ...
    'MaxPerHour_Q95', nan, ...
    'MaxPerHour_Q99', nan, ...
    'P95PerHour_Q10', nan, ...
    'P95PerHour_Q25', nan, ...
    'P95PerHour_Q50', nan, ...
    'P95PerHour_Q75', nan, ...
    'P95PerHour_Q90', nan, ...
    'P95PerHour_Q95', nan, ...
    'P95PerHour_Q99', nan, ...
    'MeanPerHour_Q50', nan, ...
    'MeanPerHour_Q75', nan);

rows = repmat(row_template, 0, 1);
for i = 1:numel(groups)
    g = groups(i);
    if g == "all"
        idx = true(height(case_tbl), 1);
    else
        idx = case_tbl.Source == g;
    end

    vec_max = case_tbl.MaxAbsIncNoTerminalPerHour(idx);
    vec_p95 = case_tbl.P95AbsIncNoTerminalPerHour(idx);
    vec_mean = case_tbl.MeanAbsIncNoTerminalPerHour(idx);

    r = row_template;
    r.Source = g;
    r.CaseCount = sum(idx);
    r.MaxPerHour_Q10 = prctile(vec_max, q(1));
    r.MaxPerHour_Q25 = prctile(vec_max, q(2));
    r.MaxPerHour_Q50 = prctile(vec_max, q(3));
    r.MaxPerHour_Q75 = prctile(vec_max, q(4));
    r.MaxPerHour_Q90 = prctile(vec_max, q(5));
    r.MaxPerHour_Q95 = prctile(vec_max, q(6));
    r.MaxPerHour_Q99 = prctile(vec_max, q(7));
    r.P95PerHour_Q10 = prctile(vec_p95, q(1));
    r.P95PerHour_Q25 = prctile(vec_p95, q(2));
    r.P95PerHour_Q50 = prctile(vec_p95, q(3));
    r.P95PerHour_Q75 = prctile(vec_p95, q(4));
    r.P95PerHour_Q90 = prctile(vec_p95, q(5));
    r.P95PerHour_Q95 = prctile(vec_p95, q(6));
    r.P95PerHour_Q99 = prctile(vec_p95, q(7));
    r.MeanPerHour_Q50 = prctile(vec_mean, 50);
    r.MeanPerHour_Q75 = prctile(vec_mean, 75);
    rows(end+1,1) = r; %#ok<AGROW>
end

quant_tbl = struct2table(rows);
end

function [rec_low, rec_mid, rec_high] = reference_band_min(quant_tbl)
idx_all = quant_tbl.Source == "all";
if ~any(idx_all)
    rec_low = nan; rec_mid = nan; rec_high = nan;
    return;
end

rec_low = quant_tbl.P95PerHour_Q25(idx_all);
rec_mid = quant_tbl.P95PerHour_Q50(idx_all);
rec_high = quant_tbl.P95PerHour_Q75(idx_all);
end

function plot_increment_reference_min(case_tbl, quant_tbl, plot_dir)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 70 1300 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
g = categorical(case_tbl.Source);
boxchart(g, case_tbl.P95AbsIncNoTerminalPerHour);
ylabel('P95 |Delta c|/h (NoTerminal)');
title('By source');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
dt_labels = categorical(string(case_tbl.ActionDt_hr));
boxchart(dt_labels, case_tbl.P95AbsIncNoTerminalPerHour);
xlabel('dt (h)');
ylabel('P95 |Delta c|/h (NoTerminal)');
title('By action dt');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
scatter(case_tbl.ActionDt_hr, case_tbl.MaxAbsIncNoTerminalPerHour, 45, 'filled'); hold on;
scatter(case_tbl.ActionDt_hr, case_tbl.P95AbsIncNoTerminalPerHour, 45, 'filled');
xlabel('dt (h)');
ylabel('|Delta c|/h');
title('Per-case max and p95 (NoTerminal)');
legend({'Max/h', 'P95/h'}, 'Location', 'best');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
x = 1:height(quant_tbl);
bar(x, [quant_tbl.P95PerHour_Q25 quant_tbl.P95PerHour_Q50 quant_tbl.P95PerHour_Q75], 'grouped');
xticks(x);
xticklabels(cellstr(quant_tbl.Source));
ylabel('|Delta c|/h');
title('Reference band from P95(NoTerminal)/h');
legend({'Q25', 'Q50', 'Q75'}, 'Location', 'best');
grid on;
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('Increment statistics reference from cost and cost\_supply', 'FontSize', 14, 'FontWeight', 'bold');
print(f, fullfile(plot_dir, 'increment_reference.png'), '-dpng', '-r260');
close(f);
end

function write_reference_md_min(out_dir, case_tbl, quant_tbl, rec_low, rec_mid, rec_high)
md_file = fullfile(out_dir, 'REFERENCE.md');
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write reference markdown.');
end

fprintf(fid, '# Increment Statistics Reference (cost + cost_supply)\n\n');
fprintf(fid, '- sources used: `shap_src_min/tr/cost`, `shap_src_min/tr/cost_supply`\n');
fprintf(fid, '- statistic focus: increments excluding terminal step (`NoTerminal`)\n');
fprintf(fid, '- per-hour normalization: `|Delta c| / dt_hr`\n\n');

fprintf(fid, '## Case-level summary\n\n');
fprintf(fid, '| Source | File | dt(h) | w_s | IPOPT | P95 |Delta c|/h (NoTerminal) | Max |Delta c|/h (NoTerminal) |\n');
fprintf(fid, '|---|---|---:|---:|---:|---:|---:|\n');
for i = 1:height(case_tbl)
    fprintf(fid, '| %s | %s | %.2f | %.2f | %g | %.6f | %.6f |\n', ...
        case_tbl.Source(i), case_tbl.CaseFile(i), case_tbl.ActionDt_hr(i), ...
        case_tbl.WSupply(i), case_tbl.IpoptStatus(i), ...
        case_tbl.P95AbsIncNoTerminalPerHour(i), ...
        case_tbl.MaxAbsIncNoTerminalPerHour(i));
end

fprintf(fid, '\n## Quantile summary\n\n');
fprintf(fid, '| Source | Cases | P95/h Q25 | P95/h Q50 | P95/h Q75 | Max/h Q50 | Max/h Q75 |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(quant_tbl)
    fprintf(fid, '| %s | %d | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
        quant_tbl.Source(i), quant_tbl.CaseCount(i), ...
        quant_tbl.P95PerHour_Q25(i), quant_tbl.P95PerHour_Q50(i), quant_tbl.P95PerHour_Q75(i), ...
        quant_tbl.MaxPerHour_Q50(i), quant_tbl.MaxPerHour_Q75(i));
end

fprintf(fid, '\n## Suggested DOE reference band\n\n');
fprintf(fid, '- Suggested `|Delta c|/h` band from ALL cases (NoTerminal, P95 quantiles):\n');
fprintf(fid, '  - low (Q25): `%.6f`\n', rec_low);
fprintf(fid, '  - mid (Q50): `%.6f`\n', rec_mid);
fprintf(fid, '  - high (Q75): `%.6f`\n\n', rec_high);

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `case_increment_stats.csv`\n');
fprintf(fid, '- `source_quantiles.csv`\n');
fprintf(fid, '- `plots/increment_reference.png`\n');

fclose(fid);
end

function ensure_dir_min(path_str)
if exist(path_str, 'dir') ~= 7
    mkdir(path_str);
end
end

function reset_dir_contents_min(path_str)
if exist(path_str, 'dir') ~= 7
    return;
end
items = dir(path_str);
for i = 1:numel(items)
    name = items(i).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue;
    end
    fp = fullfile(path_str, name);
    if items(i).isdir
        rmdir(fp, 's');
    else
        delete(fp);
    end
end
end
