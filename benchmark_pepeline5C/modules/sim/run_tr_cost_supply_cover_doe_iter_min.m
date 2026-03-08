function out = run_tr_cost_supply_cover_doe_iter_min(max_iters)
if nargin < 1 || isempty(max_iters)
    max_iters = 4;
end

sim_dir = fileparts(mfilename('fullpath'));
addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);
addpath(fullfile('shap_src_min', 'plots'));

cfg = struct();
cfg.action_dt_hr = 1.0;
cfg.parallel_worker_ratio = 0.90;
cfg.force_pool_size = true;
cfg.batch_size = 30;
cfg.target_p90 = 0.12;
cfg.target_max = 0.22;
cfg.doe_manifest = fullfile('shap_src_min', 'doe', 'try1', 'sim_outputs', 'full_all_samples_90pct', 'manifest.csv');
cfg.root_dir = fullfile('shap_src_min', 'tr', 'cost_supply', 'cover_doe');

ensure_dir_min(cfg.root_dir);
reset_dir_contents_min(cfg.root_dir);

Tdoe = readtable(cfg.doe_manifest);
if ismember('OK', Tdoe.Properties.VariableNames)
    Tdoe = Tdoe(Tdoe.OK == 1, :);
end
Tdoe = Tdoe(abs(Tdoe.ActionDt_hr - cfg.action_dt_hr) < 1e-9, :);
ok = isfinite(Tdoe.Jcost) & isfinite(Tdoe.Jsupp);
Tdoe = Tdoe(ok, :);

doe_p_mask = pareto_front_costmin_suppmax_min(Tdoe.Jcost, Tdoe.Jsupp);
Tdoe_p = sortrows(Tdoe(doe_p_mask, :), 'Jcost');
writetable(Tdoe_p, fullfile(cfg.root_dir, 'doe_pareto_1h.csv'));

all_tbl = table();
hist_tbl = table();
used_weights = [];

for iter = 1:max_iters
    weights = propose_weights_min(iter, used_weights, all_tbl, Tdoe_p, cfg.batch_size);
    used_weights = unique(round([used_weights(:); weights(:)], 12));

    run_cfg = struct();
    run_cfg.try_name = fullfile('cover_doe', sprintf('iter%02d', iter));
    run_cfg.supp_obj_sign = -1;
    run_cfg.auto_scale_from_extremes = false;
    run_cfg.cost_scale = 1;
    run_cfg.supp_scale = 1;
    run_cfg.parallel_worker_ratio = cfg.parallel_worker_ratio;
    run_cfg.force_pool_size = cfg.force_pool_size;
    run_cfg.make_plots = false;
    run_cfg.clear_stage_dir = true;
    run_cfg.supply_weights = weights;

    fprintf('\n===== COVER DOE ITER %d / %d =====\n', iter, max_iters);
    fprintf('Batch weight count: %d\n', numel(weights));
    out_i = run_tr_cost_supply_min([], cfg.action_dt_hr, true, run_cfg);

    Ti = out_i.summary_tbl;
    Ti.Iteration = repmat(iter, height(Ti), 1);
    Ti.TryName = repmat(string(sprintf('iter%02d', iter)), height(Ti), 1);

    if isempty(all_tbl)
        all_tbl = Ti;
    else
        all_tbl = [all_tbl; Ti]; %#ok<AGROW>
    end

    [pareto_all, cov_stats] = evaluate_coverage_min(all_tbl, Tdoe_p);

    hist_row = table(iter, height(Ti), height(all_tbl), height(pareto_all), ...
        cov_stats.mean, cov_stats.p50, cov_stats.p90, cov_stats.p95, cov_stats.max, ...
        'VariableNames', {'Iteration', 'BatchPoints', 'TotalPoints', 'ParetoPoints', ...
        'DistMean', 'DistP50', 'DistP90', 'DistP95', 'DistMax'});

    if isempty(hist_tbl)
        hist_tbl = hist_row;
    else
        hist_tbl = [hist_tbl; hist_row]; %#ok<AGROW>
    end

    writetable(all_tbl, fullfile(cfg.root_dir, 'summary_all.csv'));
    writetable(pareto_all, fullfile(cfg.root_dir, 'pareto_all.csv'));
    writetable(hist_tbl, fullfile(cfg.root_dir, 'coverage_history.csv'));

    save(fullfile(cfg.root_dir, 'cover_doe_iter_results.mat'), ...
        'cfg', 'Tdoe_p', 'all_tbl', 'pareto_all', 'hist_tbl', 'used_weights', '-v7.3');

    fprintf('Coverage dist: mean=%.4f, p90=%.4f, p95=%.4f, max=%.4f\n', ...
        cov_stats.mean, cov_stats.p90, cov_stats.p95, cov_stats.max);

    if cov_stats.p90 <= cfg.target_p90 && cov_stats.max <= cfg.target_max
        fprintf('Stop early: coverage target reached at iteration %d.\n', iter);
        break;
    end
end

[pareto_all, cov_stats] = evaluate_coverage_min(all_tbl, Tdoe_p);
plot_dir = fullfile(cfg.root_dir, 'plots');
ensure_dir_min(plot_dir);
plot_cover_results_min(plot_dir, Tdoe_p, all_tbl, pareto_all, hist_tbl);

plot_cfg = struct();
plot_cfg.out_dir = fullfile(plot_dir, 'doe_overlay');
plot_cfg.doe_manifest = cfg.doe_manifest;
plot_cfg.tr_cost_summary = fullfile('shap_src_min', 'tr', 'cost', 'summary.csv');
plot_cfg.tr_cost_supply_summary = fullfile(cfg.root_dir, 'summary_all.csv');
plot_cfg.tr_cost_supply_pareto = fullfile(cfg.root_dir, 'pareto_all.csv');
plot_cfg.target_dt_hr = cfg.action_dt_hr;
try
    run_plot_doe_and_pareto_1h_min(plot_cfg);
catch ME
    warning('DOE overlay plotting skipped: %s', ME.message);
end

write_cover_readme_min(cfg.root_dir, cfg, Tdoe, Tdoe_p, all_tbl, pareto_all, hist_tbl, cov_stats);

out = struct();
out.root_dir = cfg.root_dir;
out.summary_all = fullfile(cfg.root_dir, 'summary_all.csv');
out.pareto_all = fullfile(cfg.root_dir, 'pareto_all.csv');
out.coverage_history = fullfile(cfg.root_dir, 'coverage_history.csv');
out.final_cov = cov_stats;
out.n_total = height(all_tbl);
out.n_pareto = height(pareto_all);
out.n_doe_pareto = height(Tdoe_p);
end

function weights = propose_weights_min(iter, used_weights, all_tbl, Tdoe_p, batch_size)
if iter == 1
    w0 = [0; logspace(-5, -1, 10)'; linspace(0.15, 0.85, 8)'; (1-logspace(-5, -1, 10))'; 1];
    weights = unique(round(w0, 12));
    weights = sort(weights);
    return;
end

if isempty(all_tbl)
    base_seed = [0.01; 0.1; 0.5; 0.9; 0.99];
else
    [~, cov] = evaluate_coverage_min(all_tbl, Tdoe_p);
    top_idx = cov.top_uncovered_idx;
    Td = Tdoe_p(top_idx, :);

    tr_cost = all_tbl.Jcost;
    tr_supp = all_tbl.Jsupp;
    tr_w = all_tbl.WSupply;

    base_seed = [];
    for i = 1:height(Td)
        d = ((tr_cost - Td.Jcost(i))./max(abs(Td.Jcost(i)), 1)).^2 + ...
            ((tr_supp - Td.Jsupp(i))./max(abs(Td.Jsupp(i)), 1)).^2;
        [~, k] = min(d);
        base_seed = [base_seed; tr_w(k)]; %#ok<AGROW>
    end

    conv_mask = all_tbl.IpoptStatus >= 0;
    if any(conv_mask)
        [par_tbl, ~] = evaluate_coverage_min(all_tbl(conv_mask, :), Tdoe_p);
        if ~isempty(par_tbl)
            base_seed = [base_seed; par_tbl.WSupply]; %#ok<AGROW>
        end
    end
end

if iter == 2
    deltas = [0, -0.08, 0.08, -0.04, 0.04, -0.02, 0.02, -0.01, 0.01, -0.005, 0.005, -0.001, 0.001];
else
    deltas = [0, -0.03, 0.03, -0.015, 0.015, -0.007, 0.007, -0.003, 0.003, -0.001, 0.001];
end

weights = [];
for i = 1:numel(base_seed)
    wc = base_seed(i) + deltas;
    wc = min(max(wc, 0), 1);
    weights = [weights; wc(:)]; %#ok<AGROW>
end

edge = [0; 1e-6; 3e-6; 1e-5; 3e-5; 1e-4; 3e-4; 1e-3; 3e-3; 1e-2; 3e-2; 1e-1; 2e-1];
weights = [weights; edge; 1-edge; 1];
weights = unique(round(weights, 12));
weights = min(max(weights, 0), 1);

if ~isempty(used_weights)
    keep = true(size(weights));
    for i = 1:numel(weights)
        keep(i) = all(abs(used_weights - weights(i)) > 1e-9);
    end
    weights = weights(keep);
end

if isempty(weights)
    weights = unique(round(linspace(0, 1, batch_size)', 12));
end

if numel(weights) > batch_size
    if isempty(used_weights)
        weights = weights(1:batch_size);
    else
        nov = zeros(numel(weights), 1);
        for i = 1:numel(weights)
            nov(i) = min(abs(used_weights - weights(i)));
        end
        [~, ord] = sort(nov, 'descend');
        weights = weights(ord(1:batch_size));
    end
end

weights = sort(weights);
weights = unique(round(weights, 12));
weights = [0; weights(:); 1];
weights = unique(round(weights, 12));
end

function [pareto_tbl, cov] = evaluate_coverage_min(tr_tbl, Tdoe_p)
valid = isfinite(tr_tbl.Jcost) & isfinite(tr_tbl.Jsupp);
tr_tbl = tr_tbl(valid, :);
if isempty(tr_tbl)
    pareto_tbl = tr_tbl;
    cov = struct('mean', inf, 'p50', inf, 'p90', inf, 'p95', inf, 'max', inf, 'top_uncovered_idx', (1:min(8, height(Tdoe_p)))');
    return;
end

conv = tr_tbl.IpoptStatus >= 0;
conv_idx = find(conv);
if isempty(conv_idx)
    pareto_tbl = tr_tbl([],:);
else
    p_mask = pareto_front_costmin_suppmax_min(tr_tbl.Jcost(conv_idx), tr_tbl.Jsupp(conv_idx));
    pick = conv_idx(p_mask);
    pareto_tbl = tr_tbl(pick, :);
end

dc = max(max(Tdoe_p.Jcost) - min(Tdoe_p.Jcost), eps);
ds = max(max(Tdoe_p.Jsupp) - min(Tdoe_p.Jsupp), eps);

n_doe = height(Tdoe_p);
dist = nan(n_doe, 1);
for i = 1:n_doe
    d = sqrt(((tr_tbl.Jcost - Tdoe_p.Jcost(i))/dc).^2 + ((tr_tbl.Jsupp - Tdoe_p.Jsupp(i))/ds).^2);
    dist(i) = min(d);
end

dist_sorted = sort(dist);
cov = struct();
cov.mean = mean(dist_sorted);
cov.p50 = percentile_pick_min(dist_sorted, 0.50);
cov.p90 = percentile_pick_min(dist_sorted, 0.90);
cov.p95 = percentile_pick_min(dist_sorted, 0.95);
cov.max = dist_sorted(end);

[~, ord] = sort(dist, 'descend');
cov.top_uncovered_idx = ord(1:min(8, numel(ord)));
end

function v = percentile_pick_min(sorted_vals, q)
n = numel(sorted_vals);
if n == 0
    v = nan;
    return;
end
idx = 1 + floor((n-1) * q);
idx = max(1, min(n, idx));
v = sorted_vals(idx);
end

function keep = pareto_front_costmin_suppmax_min(jcost, jsupp)
n = numel(jcost);
keep = true(n,1);
for i = 1:n
    for j = 1:n
        if i == j
            continue;
        end
        if (jcost(j) <= jcost(i) && jsupp(j) >= jsupp(i)) && ...
                (jcost(j) < jcost(i) || jsupp(j) > jsupp(i))
            keep(i) = false;
            break;
        end
    end
end
end

function plot_cover_results_min(plot_dir, Tdoe_p, all_tbl, pareto_all, hist_tbl)
f1 = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1180 560], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold on;
scatter(Tdoe_p.Jcost/1e11, Tdoe_p.Jsupp/1e6, 32, [0.70 0.70 0.70], 'filled', 'MarkerEdgeColor', [0.55 0.55 0.55]);
scatter(all_tbl.Jcost/1e11, all_tbl.Jsupp/1e6, 36, all_tbl.WSupply, 'filled', 'MarkerEdgeColor', [0.10 0.10 0.10], 'LineWidth', 0.5);
if ~isempty(pareto_all)
    P = sortrows(pareto_all, 'Jcost');
    plot(P.Jcost/1e11, P.Jsupp/1e6, '-', 'Color', [0.05 0.05 0.05], 'LineWidth', 2.0);
    scatter(P.Jcost/1e11, P.Jsupp/1e6, 78, [0 0 0], 'd', 'filled', 'MarkerEdgeColor', [0.95 0.95 0.95], 'LineWidth', 0.8);
end
xlabel('Jcost (x10^{11})');
ylabel('Jsupp (x10^{6})');
title('DOE Pareto vs TR iterative points');
grid on;
cb = colorbar(ax1);
cb.Label.String = 'w_{supply}';
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
hold on;
plot(hist_tbl.Iteration, hist_tbl.DistMean, '-o', 'LineWidth', 1.7, 'MarkerSize', 5, 'DisplayName', 'mean');
plot(hist_tbl.Iteration, hist_tbl.DistP90, '-s', 'LineWidth', 1.7, 'MarkerSize', 5, 'DisplayName', 'p90');
plot(hist_tbl.Iteration, hist_tbl.DistP95, '-d', 'LineWidth', 1.7, 'MarkerSize', 5, 'DisplayName', 'p95');
plot(hist_tbl.Iteration, hist_tbl.DistMax, '-^', 'LineWidth', 1.7, 'MarkerSize', 5, 'DisplayName', 'max');
xlabel('Iteration');
ylabel('Normalized nearest distance');
title('Coverage history (DOE Pareto -> TR points)');
grid on;
legend('Location', 'best');
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('TR weight-iteration coverage diagnostics', 'FontSize', 14, 'FontWeight', 'bold');
save_plot_png_min(f1, fullfile(plot_dir, 'cover_vs_doe_and_history.png'), 250);
close(f1);
end

function write_cover_readme_min(root_dir, cfg, Tdoe, Tdoe_p, all_tbl, pareto_all, hist_tbl, cov_stats)
md = fullfile(root_dir, 'README.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write README: %s', md);
end

fprintf(fid, '# Iterative TR cost+supply coverage of DOE Pareto (1h)\n\n');
fprintf(fid, '- objective direction: `cost min + supply max`\n');
fprintf(fid, '- objective scaling in optimizer: `cost_scale=1`, `supp_scale=1` (no anchor autoscaling)\n');
fprintf(fid, '- action granularity: `%.1f h`\n', cfg.action_dt_hr);
fprintf(fid, '- parallel worker policy: `%.0f%% of CPU cores`\n\n', cfg.parallel_worker_ratio * 100);

fprintf(fid, '## Data\n\n');
fprintf(fid, '- DOE source rows (filtered dt=1h, OK=1): `%d`\n', height(Tdoe));
fprintf(fid, '- DOE Pareto points: `%d`\n', height(Tdoe_p));
fprintf(fid, '- TR total iterative points: `%d`\n', height(all_tbl));
fprintf(fid, '- TR Pareto points (combined): `%d`\n\n', height(pareto_all));

fprintf(fid, '## Final coverage metric\n\n');
fprintf(fid, '- distance uses normalized `(Jcost, Jsupp)` space based on DOE Pareto ranges\n');
fprintf(fid, '- mean: `%.4f`\n', cov_stats.mean);
fprintf(fid, '- p50: `%.4f`\n', cov_stats.p50);
fprintf(fid, '- p90: `%.4f`\n', cov_stats.p90);
fprintf(fid, '- p95: `%.4f`\n', cov_stats.p95);
fprintf(fid, '- max: `%.4f`\n\n', cov_stats.max);

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `doe_pareto_1h.csv`\n');
fprintf(fid, '- `summary_all.csv`\n');
fprintf(fid, '- `pareto_all.csv`\n');
fprintf(fid, '- `coverage_history.csv`\n');
fprintf(fid, '- `cover_doe_iter_results.mat`\n');
fprintf(fid, '- `plots/cover_vs_doe_and_history.png`\n');
fprintf(fid, '- `plots/doe_overlay/doe_tr_pareto_scatter_density_1h.png`\n');
fprintf(fid, '- `plots/doe_overlay/tr_weight_path_nonlinear_1h.png`\n');

fclose(fid);
end

function save_plot_png_min(fig_handle, out_file, dpi)
if nargin < 3 || isempty(dpi)
    dpi = 250;
end
set(fig_handle, 'Renderer', 'painters');
set(fig_handle, 'InvertHardcopy', 'off');
drawnow('nocallbacks');
print(fig_handle, out_file, '-dpng', sprintf('-r%d', dpi), '-painters');
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
