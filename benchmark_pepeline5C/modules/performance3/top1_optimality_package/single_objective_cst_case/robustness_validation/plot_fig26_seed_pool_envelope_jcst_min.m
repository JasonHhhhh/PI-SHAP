function out = plot_fig26_seed_pool_envelope_jcst_min()
% Seed-pool robustness envelope under a fixed TOP1-best selection rule.

base_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(fileparts(fileparts(base_dir)))));

sources = struct([]);
sources(1).name = "BaselinePool";
sources(1).score_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', 'tables', 'holdout_case_scores.csv');
sources(1).corr_csv = fullfile(repo_dir, 'shap_src_min', 'performance3', ...
    's20_fast_refine_round2', 'C1_costGuard_thr035_noFill_bal', 'tables', 'holdout_score_correlation.csv');

for i = 1:numel(sources)
    if exist(sources(i).score_csv, 'file') ~= 2
        error('Score table not found: %s', sources(i).score_csv);
    end
    if exist(sources(i).corr_csv, 'file') ~= 2
        error('Correlation table not found: %s', sources(i).corr_csv);
    end
end

methods = ["Ori-SHAP", "Cond-SHAP", "PI-SHAP"];
score_cols = ["OriScoreJcost", "CondScoreJcost", "PIScoreJcost"];
method_colors = [0.85 0.37 0.01; 0.00 0.45 0.70; 0.00 0.62 0.45];
method_markers = {'o', 's', '^'};

topn = 40;
proxy_w = 0.20;
pool_frac = 0.60:0.05:1.00;
n_rep = 120;
seed0 = 260306;

n_m = numel(methods);
n_f = numel(pool_frac);
n_s = numel(sources);

Tsrc = cell(n_s, 1);
Csrc = cell(n_s, 1);
Nsrc = zeros(n_s, 1);
best_src = zeros(n_s, 1);
for s = 1:n_s
    Tsrc{s} = readtable(sources(s).score_csv);
    Csrc{s} = readtable(sources(s).corr_csv);
    Nsrc(s) = height(Tsrc{s});
    best_src(s) = min(Tsrc{s}.Jcost);
end

n_rows = n_s * n_f * n_rep * n_m;
raw_rows = repmat(struct('SourcePool', "", 'PoolFrac', nan, 'PoolSize', nan, ...
    'RepID', nan, 'Method', "", 'Top1BestJcost', nan, ...
    'SourceGlobalBestJcost', nan, 'Top1BestRegretPct', nan), n_rows, 1);
rid = 0;

for s = 1:n_s
    T = Tsrc{s};
    C = Csrc{s};
    n_total = Nsrc(s);
    for f = 1:n_f
        n_sub = max(topn + 20, round(pool_frac(f) * n_total));
        n_sub = min(n_sub, n_total);
        for r = 1:n_rep
            rng(seed0 + 100000 * s + 1000 * f + r, 'twister');
            idx = randperm(n_total, n_sub);
            Tb = T(idx, :);
            for m = 1:n_m
                best_v = eval_top1best_jcst(Tb, C, methods(m), score_cols(m), topn, proxy_w);
                rid = rid + 1;
                raw_rows(rid).SourcePool = sources(s).name;
                raw_rows(rid).PoolFrac = pool_frac(f);
                raw_rows(rid).PoolSize = n_sub;
                raw_rows(rid).RepID = r;
                raw_rows(rid).Method = methods(m);
                raw_rows(rid).Top1BestJcost = best_v;
                raw_rows(rid).SourceGlobalBestJcost = best_src(s);
                raw_rows(rid).Top1BestRegretPct = (best_v / best_src(s) - 1) * 100;
            end
        end
    end
end

raw_rows = raw_rows(1:rid);
R = struct2table(raw_rows);

mean_v = nan(n_m, n_f);
med_v = nan(n_m, n_f);
lo_v = nan(n_m, n_f);
hi_v = nan(n_m, n_f);
for m = 1:n_m
    for f = 1:n_f
        idx = (R.Method == methods(m)) & abs(R.PoolFrac - pool_frac(f)) < 1e-12;
        vv = R.Top1BestJcost(idx);
        mean_v(m, f) = mean(vv, 'omitnan');
        med_v(m, f) = quantile_linear(vv, 0.50);
        n_eff = sum(isfinite(vv));
        if n_eff <= 1
            lo_v(m, f) = mean_v(m, f);
            hi_v(m, f) = mean_v(m, f);
        else
            sd = std(vv, 0, 'omitnan');
            se = sd / sqrt(n_eff);
            z = 1.96;
            lo_v(m, f) = mean_v(m, f) - z * se;
            hi_v(m, f) = mean_v(m, f) + z * se;
        end
    end
end

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [90 90 1180 700]);
ax = axes(fig);
hold(ax, 'on');

x = pool_frac * 100;
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
xticklabels(string(round(x)) + "%");

grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 21, 'LineWidth', 1.6);

xlabel(ax, 'Candidate-pool size ratio', 'FontSize', 25);
ylabel(ax, 'TOP1-best true $J_{cst}$ ($\times 10^{11}$)', 'Interpreter', 'latex', 'FontSize', 25);
title(ax, 'Seed Robustness (95% CI)', 'FontSize', 28, 'FontWeight', 'bold');
legend(ax, 'Location', 'northeast', 'FontSize', 19, 'Box', 'on');

plot_dir = fullfile(base_dir, 'plots');
fig_dir = fullfile(fileparts(fileparts(base_dir)), 'figures');
if exist(plot_dir, 'dir') ~= 7
    mkdir(plot_dir);
end
if exist(fig_dir, 'dir') ~= 7
    mkdir(fig_dir);
end

svg_a = fullfile(plot_dir, 'Fig26_seed_pool_envelope_jcst_robustness.svg');
png_a = fullfile(plot_dir, 'Fig26_seed_pool_envelope_jcst_robustness.png');
svg_b = fullfile(fig_dir, 'Fig26_seed_pool_envelope_jcst_robustness.svg');
png_b = fullfile(fig_dir, 'Fig26_seed_pool_envelope_jcst_robustness.png');

print(fig, svg_a, '-dsvg');
exportgraphics(fig, png_a, 'Resolution', 300, 'BackgroundColor', 'white');
print(fig, svg_b, '-dsvg');
exportgraphics(fig, png_b, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);

sum_rows = repmat(struct('PoolFrac', nan, 'Method', "", 'NSamples', nan, ...
    'Top1Best_Mean', nan, 'Top1Best_Median', nan, ...
    'Top1Best_CI95_Low', nan, 'Top1Best_CI95_High', nan), n_m * n_f, 1);
sid = 0;
for m = 1:n_m
    for f = 1:n_f
        sid = sid + 1;
        idx = (R.Method == methods(m)) & abs(R.PoolFrac - pool_frac(f)) < 1e-12;
        sum_rows(sid).PoolFrac = pool_frac(f);
        sum_rows(sid).Method = methods(m);
        sum_rows(sid).NSamples = sum(idx);
        sum_rows(sid).Top1Best_Mean = mean_v(m, f);
        sum_rows(sid).Top1Best_Median = med_v(m, f);
        sum_rows(sid).Top1Best_CI95_Low = lo_v(m, f);
        sum_rows(sid).Top1Best_CI95_High = hi_v(m, f);
    end
end
S = struct2table(sum_rows);

raw_csv = fullfile(base_dir, 'tables', 'fig26_seed_pool_envelope_jcst_raw.csv');
sum_csv = fullfile(base_dir, 'tables', 'fig26_seed_pool_envelope_jcst_summary.csv');
writetable(R, raw_csv);
writetable(S, sum_csv);

out = struct();
out.raw_csv = raw_csv;
out.summary_csv = sum_csv;
out.svg_plot = svg_a;
out.png_plot = png_a;
out.svg_fig = svg_b;
out.png_fig = png_b;
fprintf('Fig26 envelope generated: %s\n', out.svg_fig);
fprintf('Raw table: %s\n', out.raw_csv);
fprintf('Summary table: %s\n', out.summary_csv);
end

function best = eval_top1best_jcst(T, C, method_name, score_col, topn, proxy_w)
sc = T.(score_col);
corr = lookup_corr(C, method_name, "Jcost");
sgn = 1;
if corr < 0
    sgn = -1;
end
proxy = normalize01(sgn * sc);
[~, ord] = sort(proxy, 'ascend');
k = min(topn, numel(ord));
sel = ord(1:k);

target_loss = normalize01(T.Jcost(sel));
proxy_loss = normalize01(proxy(sel));
comp = target_loss + proxy_w * proxy_loss;
[~, ord2] = sort(comp, 'ascend');
y = T.Jcost(sel(ord2));
best = min(y);
end

function c = lookup_corr(T, method_name, obj_name)
idx = strcmp(string(T.Method), string(method_name)) & strcmp(string(T.Objective), string(obj_name));
if any(idx)
    c = T.PearsonCorr(find(idx, 1, 'first'));
else
    c = 1;
end
if ~isfinite(c)
    c = 1;
end
end

function y = normalize01(x)
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

function qv = quantile_linear(x, q)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    qv = nan;
    return;
end
x = sort(x, 'ascend');
if numel(x) == 1
    qv = x(1);
    return;
end
q = min(max(q, 0), 1);
pos = 1 + (numel(x) - 1) * q;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    qv = x(lo);
else
    t = pos - lo;
    qv = x(lo) * (1 - t) + x(hi) * t;
end
end
