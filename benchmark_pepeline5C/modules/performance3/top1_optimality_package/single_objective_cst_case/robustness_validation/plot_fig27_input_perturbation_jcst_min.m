function out = plot_fig27_input_perturbation_jcst_min()
% 6.4.3 Input perturbation robustness (fixed pool, fixed TOP1-best rule).
% Perturbation is injected on action sequence cc_policy:
% cc_pert = cc .* (1 + sigma * N(0,1)).

base_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(fileparts(fileparts(base_dir)))));

addpath(fullfile(repo_dir, 'src'));
addpath(fullfile(repo_dir, 'shap_src'));
addpath(fullfile(repo_dir, 'shap_src_min'));

score_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', 's20_fast_refine_round2', ...
    'C1_costGuard_thr035_noFill_bal', 'tables', 'holdout_case_scores.csv');
if exist(score_csv, 'file') ~= 2
    error('Score table not found: %s', score_csv);
end

methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
score_cols = ["OriScoreJcost", "CondScoreJcost", "PIScoreJcost"];
method_colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
method_markers = {'o', 's', '^'};

topn = 40;
proxy_w = 0.20;
sigma_list = 0:0.02:0.20;     % 0% to 20%
n_rep = 8;
rand_seed = 20260308;

T = readtable(score_csv);
n_m = numel(methods);
n_s = numel(sigma_list);

% Select one base policy per method under fixed TOP1-best rule.
pick_idx = zeros(n_m, 1);
pick_case = strings(n_m, 1);
pick_pol = cell(n_m, 1);
for m = 1:n_m
    sc = T.(score_cols(m));
    [~, ord] = sort(sc, 'ascend');
    k = min(topn, numel(ord));
    sel = ord(1:k);

    y = T.Jcost(sel);
    p = sc(sel);
    t_loss = normalize01_ip_min(y);
    p_loss = normalize01_ip_min(p);
    comp = t_loss + proxy_w * p_loss;
    [~, best_pos] = min(comp);
    idx = sel(best_pos);

    pick_idx(m) = idx;
    pick_case(m) = string(T.SampleFile(idx));
    pick_pol{m} = read_cc_policy_ip_min(char(T.SampleFile(idx)), 25, 5);
end

% Build clip bounds from union of method stage-1 top40 pools.
pool_idx = [];
for m = 1:n_m
    sc = T.(score_cols(m));
    [~, ord] = sort(sc, 'ascend');
    pool_idx = [pool_idx; ord(1:min(topn, numel(ord)))]; %#ok<AGROW>
end
pool_idx = unique(pool_idx, 'stable');

stack = zeros(25, 5, numel(pool_idx));
for i = 1:numel(pool_idx)
    stack(:, :, i) = read_cc_policy_ip_min(char(T.SampleFile(pool_idx(i))), 25, 5);
end
cc_lb = min(stack, [], 3);
cc_ub = max(stack, [], 3);

% Simulation baseline config
sim_cfg = config_model_mine_min();
sim_cfg.baseline_mat = fullfile(repo_dir, 'shap_src', 'par_baseline_opt.mat');
sim_cfg.model_folder = fullfile(repo_dir, 'data', 'model_mine');
par_base = load_baseline_min(sim_cfg);

rows_n = n_m * n_s * n_rep;
raw_rows = repmat(struct('Method', "", 'Sigma', nan, 'RepID', nan, ...
    'SelectedCaseFile', "", 'SelectedCaseIndex', nan, 'JcostPert', nan), rows_n, 1);
rid = 0;

for m = 1:n_m
    cc0 = pick_pol{m};
    for s = 1:n_s
        sig = sigma_list(s);
        for r = 1:n_rep
            rng(rand_seed + 10000 * m + 100 * s + r, 'twister');
            if sig <= 0
                cc = cc0;
            else
                cc = cc0 .* (1 + sig * randn(size(cc0)));
                cc = min(max(cc, cc_lb), cc_ub);
            end

            sim_name = sprintf('IP_%s_sig%.3f_rep%02d', methods(m), sig, r);
            sim_res = simulate_policy_min(par_base, cc, sim_cfg, sim_name);

            rid = rid + 1;
            raw_rows(rid).Method = methods(m);
            raw_rows(rid).Sigma = sig;
            raw_rows(rid).RepID = r;
            raw_rows(rid).SelectedCaseFile = pick_case(m);
            raw_rows(rid).SelectedCaseIndex = T.CaseIndex(pick_idx(m));
            raw_rows(rid).JcostPert = sim_res.metrics.Jcost;
        end
    end
end

raw_rows = raw_rows(1:rid);
R = struct2table(raw_rows);

mean_v = nan(n_m, n_s);
lo_v = nan(n_m, n_s);
hi_v = nan(n_m, n_s);
for m = 1:n_m
    for s = 1:n_s
        idx = (R.Method == methods(m)) & abs(R.Sigma - sigma_list(s)) < 1e-12;
        vv = R.JcostPert(idx);
        mean_v(m, s) = mean(vv, 'omitnan');
        n_eff = sum(isfinite(vv));
        if n_eff <= 1
            lo_v(m, s) = mean_v(m, s);
            hi_v(m, s) = mean_v(m, s);
        else
            sd = std(vv, 0, 'omitnan');
            se = sd / sqrt(n_eff);
            lo_v(m, s) = mean_v(m, s) - 1.96 * se;
            hi_v(m, s) = mean_v(m, s) + 1.96 * se;
        end
    end
end

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [90 90 1180 700]);
ax = axes(fig);
hold(ax, 'on');

x = sigma_list * 100;
scale = 1e11;
for m = 1:n_m
    y = mean_v(m, :) / scale;
    ylo = lo_v(m, :) / scale;
    yhi = hi_v(m, :) / scale;

    xx = [x, fliplr(x)];
    yy = [ylo, fliplr(yhi)];
    p = patch('XData', xx, 'YData', yy, 'FaceColor', method_colors(m, :), ...
        'FaceAlpha', 0.16, 'EdgeColor', 'none', 'Parent', ax);
    p.HandleVisibility = 'off';

    plot(ax, x, y, '-', ...
        'Color', method_colors(m, :), ...
        'LineWidth', 3.6, ...
        'Marker', method_markers{m}, ...
        'MarkerFaceColor', method_colors(m, :), ...
        'MarkerEdgeColor', [0.08 0.08 0.08], ...
        'MarkerSize', 10.5, ...
        'DisplayName', char(methods(m)));
end

xlim(ax, [min(x), max(x)]);
xticks(ax, x);
xticklabels(arrayfun(@(v) sprintf('%.0f%%', v), x, 'UniformOutput', false));

grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 21, 'LineWidth', 1.6);

xlabel(ax, 'Action perturbation level \sigma', 'FontSize', 25);
ylabel(ax, 'TOP1-best perturbed true $J_{cst}$ ($\times 10^{11}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax, 'Input Perturbation Robustness (95% CI)', 'FontSize', 28, 'FontWeight', 'bold');
legend(ax, 'Location', 'northeast', 'FontSize', 19, 'Box', 'on');

plot_dir = fullfile(base_dir, 'plots');
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end
if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end

svg_a = fullfile(plot_dir, 'Fig27_input_perturbation_jcst_robustness.svg');
png_a = fullfile(plot_dir, 'Fig27_input_perturbation_jcst_robustness.png');
svg_b = fullfile(fig_dir, 'Fig27_input_perturbation_jcst_robustness.svg');
png_b = fullfile(fig_dir, 'Fig27_input_perturbation_jcst_robustness.png');

print(fig, svg_a, '-dsvg');
exportgraphics(fig, png_a, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_b, '-dsvg');
exportgraphics(fig, png_b, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

sum_rows = repmat(struct('Sigma', nan, 'Method', "", 'NSamples', nan, ...
    'Top1BestPertJcost_Mean', nan, 'Top1BestPertJcost_CI95_Low', nan, ...
    'Top1BestPertJcost_CI95_High', nan, 'SelectedCaseIndex', nan), n_m * n_s, 1);
sid = 0;
for m = 1:n_m
    for s = 1:n_s
        sid = sid + 1;
        idx = (R.Method == methods(m)) & abs(R.Sigma - sigma_list(s)) < 1e-12;
        sum_rows(sid).Sigma = sigma_list(s);
        sum_rows(sid).Method = methods(m);
        sum_rows(sid).NSamples = sum(idx);
        sum_rows(sid).Top1BestPertJcost_Mean = mean_v(m, s);
        sum_rows(sid).Top1BestPertJcost_CI95_Low = lo_v(m, s);
        sum_rows(sid).Top1BestPertJcost_CI95_High = hi_v(m, s);
        sum_rows(sid).SelectedCaseIndex = T.CaseIndex(pick_idx(m));
    end
end
S = struct2table(sum_rows);

raw_csv = fullfile(base_dir, 'tables', 'fig27_input_perturbation_jcst_raw.csv');
sum_csv = fullfile(base_dir, 'tables', 'fig27_input_perturbation_jcst_summary.csv');
writetable(R, raw_csv);
writetable(S, sum_csv);

out = struct();
out.raw_csv = raw_csv;
out.summary_csv = sum_csv;
out.svg_plot = svg_a;
out.png_plot = png_a;
out.svg_fig = svg_b;
out.png_fig = png_b;
fprintf('Fig27 generated: %s\n', out.svg_fig);
fprintf('Raw table: %s\n', out.raw_csv);
fprintf('Summary table: %s\n', out.summary_csv);
end

function cc = read_cc_policy_ip_min(sample_file, nt, nc)
P = load(sample_file, 'payload');
cc = P.payload.inputs.cc_policy;
if size(cc, 2) ~= nc && size(cc, 1) == nc
    cc = cc';
end
if size(cc, 1) ~= nt
    cc = interp1(linspace(0, 1, size(cc, 1)), cc, linspace(0, 1, nt), 'linear', 'extrap');
end
end

function y = normalize01_ip_min(x)
x = x(:);
good = isfinite(x);
y = zeros(size(x));
if ~any(good)
    return;
end
g = x(good);
mn = min(g);
mx = max(g);
if abs(mx - mn) <= eps
    y(good) = 0;
else
    y(good) = (g - mn) ./ (mx - mn);
end
end
