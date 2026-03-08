function out = run_s_sweep_seedsplit_perf3_min(cfg)
% Sweep tree_max_splits (S) under fixed seed-wise split:
% train seed 11, test seeds 23+37, dt=1h.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end
cfg = fill_cfg_defaults_s_sweep_perf3(cfg);

ensure_dir_s_sweep(cfg.sweep_root);
ensure_dir_s_sweep(cfg.table_dir);
ensure_dir_s_sweep(cfg.plot_dir);

pool_info = ensure_parallel_pool_s_sweep(cfg);
if pool_info.enabled
    fprintf('[S-sweep] parallel pool workers=%d\n', pool_info.n_workers);
else
    fprintf('[S-sweep] parallel pool disabled.\n');
end

S_list = cfg.s_list(:)';
nS = numel(S_list);

rows = table();

shared_cache = fullfile(cfg.sweep_root, 'shared_holdout_shap_maps_cache_seedwise_dt1p0.mat');

for i = 1:nS
    Sval = S_list(i);
    tag = sprintf('S%03d', Sval);
    run_dir = fullfile(cfg.sweep_root, tag);
    ensure_dir_s_sweep(run_dir);

    fprintf('\n[S-sweep] (%d/%d) Running %s\n', i, nS, tag);

    run_cfg = struct();
    run_cfg.work_dir = run_dir;

    score_cfg = struct();
    score_cfg.repo_dir = cfg.repo_dir;
    score_cfg.eval_seed_list = cfg.eval_seed_list;
    score_cfg.eval_dt_hr = cfg.eval_dt_hr;
    score_cfg.split_mode = 'seed';
    score_cfg.train_seed_list = cfg.train_seed_list;
    score_cfg.test_seed_list = cfg.test_seed_list;
    score_cfg.filter_use_train_only = true;
    score_cfg.tree_refit_all = false;
    score_cfg.tree_max_splits = Sval;
    score_cfg.rule_prior_blend = 1.0;
    score_cfg.label_class_levels = cfg.label_class_levels;
    score_cfg.label_level_quantiles = cfg.label_level_quantiles;
    score_cfg.parallel_workers = cfg.parallel_workers;
    score_cfg.shap_use_parallel = true;
    score_cfg.use_map_cache = true;
    score_cfg.map_cache_file = shared_cache;
    run_cfg.score_cfg = score_cfg;

    review_cfg = struct();
    if isfield(cfg, 'review_cfg') && isstruct(cfg.review_cfg)
        review_cfg = cfg.review_cfg;
    end
    run_cfg.review_cfg = review_cfg;

    run_reviewer_single_multi_perf3_min(run_cfg);

    tdir = fullfile(run_dir, 'reviewer_outputs', 'tables');
    js_cost = readtable(fullfile(tdir, 'single_target_metric_single_jcost.csv'));
    js_supp = readtable(fullfile(tdir, 'single_target_metric_single_jsupp.csv'));
    js_var = readtable(fullfile(tdir, 'single_target_metric_single_jvar.csv'));
    mo = readtable(fullfile(tdir, 'multi_mo_metrics.csv'));

    [w_jc, pi_jc, ori_jc, cond_jc] = pi_win_single_s_sweep(js_cost, 'min');
    [w_js, pi_js, ori_js, cond_js] = pi_win_single_s_sweep(js_supp, 'max');
    [w_jv, pi_jv, ori_jv, cond_jv] = pi_win_single_s_sweep(js_var, 'min');

    [w_hv, pi_hv, ori_hv, cond_hv] = pi_win_mo_s_sweep(mo, 'HVRelToRef', 'max');
    [w_igd, pi_igd, ori_igd, cond_igd] = pi_win_mo_s_sweep(mo, 'IGD', 'min');
    [w_eps, pi_eps, ori_eps, cond_eps] = pi_win_mo_s_sweep(mo, 'EpsilonAdd', 'min');
    [w_md, pi_md, ori_md, cond_md] = pi_win_mo_s_sweep(mo, 'MeanFrontDist', 'min');
    [w_p90, pi_p90, ori_p90, cond_p90] = pi_win_mo_s_sweep(mo, 'P90FrontDist', 'min');

    total = w_jc + w_js + w_jv + w_hv + w_igd + w_eps + w_md + w_p90;

    row = table(Sval, ...
        w_jc, w_js, w_jv, w_hv, w_igd, w_eps, w_md, w_p90, total, total / 8, ...
        pi_jc, ori_jc, cond_jc, pi_js, ori_js, cond_js, pi_jv, ori_jv, cond_jv, ...
        pi_hv, ori_hv, cond_hv, pi_igd, ori_igd, cond_igd, pi_eps, ori_eps, cond_eps, ...
        pi_md, ori_md, cond_md, pi_p90, ori_p90, cond_p90, ...
        'VariableNames', {'S', ...
        'PIWinSingleJcost', 'PIWinSingleJsupp', 'PIWinSingleJvar', ...
        'PIWinMOHV', 'PIWinMOIGD', 'PIWinMOEps', 'PIWinMOMeanDist', 'PIWinMOP90Dist', 'PIWinTotal', 'PIWinRate', ...
        'PI_Jcost', 'Ori_Jcost', 'Cond_Jcost', ...
        'PI_Jsupp', 'Ori_Jsupp', 'Cond_Jsupp', ...
        'PI_Jvar', 'Ori_Jvar', 'Cond_Jvar', ...
        'PI_HV', 'Ori_HV', 'Cond_HV', ...
        'PI_IGD', 'Ori_IGD', 'Cond_IGD', ...
        'PI_Eps', 'Ori_Eps', 'Cond_Eps', ...
        'PI_MeanDist', 'Ori_MeanDist', 'Cond_MeanDist', ...
        'PI_P90Dist', 'Ori_P90Dist', 'Cond_P90Dist'});
    rows = [rows; row]; %#ok<AGROW>
end

rows = sortrows(rows, 'S', 'ascend');
summary_csv = fullfile(cfg.table_dir, 's_sweep_summary.csv');
writetable(rows, summary_csv);

plot_png = fullfile(cfg.plot_dir, 's_sweep_pi_winrate.png');
plot_svg = fullfile(cfg.plot_dir, 's_sweep_pi_winrate.svg');
plot_sweep_winrate_s_sweep(rows, plot_png, plot_svg);

report_md = fullfile(cfg.sweep_root, 'S_SWEEP_REPORT.md');
write_s_sweep_report(report_md, rows, summary_csv, plot_png, plot_svg, cfg);

out = struct();
out.summary_csv = summary_csv;
out.report_md = report_md;
out.plot_png = plot_png;
out.plot_svg = plot_svg;

fprintf('\n[S-sweep] done: %s\n', report_md);
end

function [win, pi_v, ori_v, cond_v] = pi_win_single_s_sweep(T, sense)
T = T(ismember(string(T.Method), ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"]), :);
ori_v = T.TargetMetricAbs(string(T.Method) == "Ori-SHAP");
cond_v = T.TargetMetricAbs(string(T.Method) == "Cond-SHAP");
pi_v = T.TargetMetricAbs(string(T.Method) == "PI-SHAP");
vals = [ori_v; cond_v; pi_v];
if strcmpi(sense, 'min')
    best = min(vals);
else
    best = max(vals);
end
win = abs(pi_v - best) <= 1e-12;
end

function [win, pi_v, ori_v, cond_v] = pi_win_mo_s_sweep(T, var_name, sense)
ori_v = T.(var_name)(string(T.Method) == "Ori-SHAP");
cond_v = T.(var_name)(string(T.Method) == "Cond-SHAP");
pi_v = T.(var_name)(string(T.Method) == "PI-SHAP");
vals = [ori_v; cond_v; pi_v];
if strcmpi(sense, 'min')
    best = min(vals);
else
    best = max(vals);
end
win = abs(pi_v - best) <= 1e-12;
end

function plot_sweep_winrate_s_sweep(T, png_file, svg_file)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 120 1200 640], 'Renderer', 'painters');
ax = axes(f);
plot(ax, T.S, T.PIWinRate, '-o', 'LineWidth', 2.8, 'MarkerSize', 9, 'Color', [0.00 0.62 0.45], 'MarkerFaceColor', [0.00 0.62 0.45]);
grid(ax, 'on'); box(ax, 'on');
xlabel(ax, 'S (tree max splits)', 'FontSize', 18);
ylabel(ax, 'PI win/tie rate across 8 metrics', 'FontSize', 18);
title(ax, 'PI consistency vs tree complexity S', 'FontSize', 22, 'FontWeight', 'bold');
ylim(ax, [0 1]);
set(ax, 'FontSize', 15, 'LineWidth', 1.2);

exportgraphics(f, png_file, 'Resolution', 260, 'BackgroundColor', 'white');
print(f, svg_file, '-dsvg');
close(f);
end

function write_s_sweep_report(md_file, T, summary_csv, plot_png, plot_svg, cfg)
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write report: %s', md_file);
end

fprintf(fid, '# S Sweep Report (seed-wise split, 8-level labels)\n\n');
fprintf(fid, '- Train seed: `%s`\n', mat2str(cfg.train_seed_list));
fprintf(fid, '- Test seeds: `%s`\n', mat2str(cfg.test_seed_list));
fprintf(fid, '- dt(h): `%.1f`\n', cfg.eval_dt_hr);
fprintf(fid, '- Label levels: `%s`\n', mat2str(cfg.label_class_levels));
fprintf(fid, '- B fixed to rule-only: `rule_prior_blend = 1.0`\n\n');

fprintf(fid, '## PI win/tie summary\n\n');
fprintf(fid, '| S | PIWinTotal | PIWinRate | PIWinSingleJsupp | PIWinMOHV | PIWinMOIGD | PIWinMOEps |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(T)
    fprintf(fid, '| %d | %d | %.3f | %d | %d | %d | %d |\n', ...
        T.S(i), T.PIWinTotal(i), T.PIWinRate(i), T.PIWinSingleJsupp(i), ...
        T.PIWinMOHV(i), T.PIWinMOIGD(i), T.PIWinMOEps(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- Summary CSV: `%s`\n', summary_csv);
fprintf(fid, '- Sweep plot PNG: `%s`\n', plot_png);
fprintf(fid, '- Sweep plot SVG: `%s`\n', plot_svg);

fclose(fid);
end

function info = ensure_parallel_pool_s_sweep(cfg)
info = struct('enabled', false, 'n_workers', 0);

if ~cfg.use_parallel
    return;
end
if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2
    return;
end

try
    p = gcp('nocreate');
    if isempty(p)
        p = parpool('local', cfg.parallel_workers);
    end
    info.enabled = true;
    info.n_workers = p.NumWorkers;
catch
    info.enabled = false;
    info.n_workers = 0;
end
end

function cfg = fill_cfg_defaults_s_sweep_perf3(cfg)
this_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(this_dir)));

if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end
if ~isfield(cfg, 'sweep_root') || isempty(cfg.sweep_root)
    cfg.sweep_root = fullfile(this_dir, 's_sweep_seedsplit');
end
if ~isfield(cfg, 'table_dir') || isempty(cfg.table_dir)
    cfg.table_dir = fullfile(cfg.sweep_root, 'tables');
end
if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.sweep_root, 'plots');
end

if ~isfield(cfg, 's_list') || isempty(cfg.s_list)
    cfg.s_list = [10, 20, 40, 60];
end

if ~isfield(cfg, 'eval_seed_list') || isempty(cfg.eval_seed_list)
    cfg.eval_seed_list = [11, 23, 37];
end
if ~isfield(cfg, 'train_seed_list') || isempty(cfg.train_seed_list)
    cfg.train_seed_list = 11;
end
if ~isfield(cfg, 'test_seed_list') || isempty(cfg.test_seed_list)
    cfg.test_seed_list = [23, 37];
end
if ~isfield(cfg, 'eval_dt_hr') || isempty(cfg.eval_dt_hr)
    cfg.eval_dt_hr = 1.0;
end

if ~isfield(cfg, 'label_class_levels') || isempty(cfg.label_class_levels)
    cfg.label_class_levels = [-4, -3, -2, -1, 1, 2, 3, 4];
end
if ~isfield(cfg, 'label_level_quantiles') || isempty(cfg.label_level_quantiles)
    cfg.label_level_quantiles = [0.25, 0.50, 0.75];
end

if ~isfield(cfg, 'use_parallel') || isempty(cfg.use_parallel)
    cfg.use_parallel = true;
end
if ~isfield(cfg, 'parallel_workers') || isempty(cfg.parallel_workers)
    n = 1;
    try
        n = feature('numcores');
    catch
    end
    cfg.parallel_workers = max(1, floor(0.9 * n));
end
end

function ensure_dir_s_sweep(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end
