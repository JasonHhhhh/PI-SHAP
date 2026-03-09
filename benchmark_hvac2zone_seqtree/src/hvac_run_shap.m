function out = hvac_run_shap(cfg, planning, dirs)
method_names = {'Ori-SHAP', 'Cond-SHAP', 'PI-SHAP'};

w_comp = get_composite_weights_hvac(cfg);

block_tbl = planning.block_tbl;
metrics_tbl = planning.metrics_tbl;

feature_names = block_tbl.Properties.VariableNames(2:end);
X_all = table2array(block_tbl(:, 2:end));
candidate_all = block_tbl.CandidateID;

y_single = metrics_tbl.Jsingle;
y_multi = build_balanced_multi_target_hvac(metrics_tbl);

n = size(X_all, 1);
rng(cfg.seed + 701, 'twister');
perm = randperm(n);

n_train = min(cfg.shap_n_train, n - 1000);
n_test = min(cfg.shap_n_test, n - n_train);

train_idx = perm(1:n_train);
test_idx = perm((n_train + 1):(n_train + n_test));

X_train = X_all(train_idx, :);
X_test = X_all(test_idx, :);
cid_train = candidate_all(train_idx);
cid_test = candidate_all(test_idx);

y_single_train = y_single(train_idx);
y_single_test = y_single(test_idx);
y_multi_train = y_multi(train_idx);
y_multi_test = y_multi(test_idx);

split_tbl = table([cid_train; cid_test], [repmat({'train'}, n_train, 1); repmat({'test'}, n_test, 1)], ...
    'VariableNames', {'CandidateID', 'Split'});
writetable(split_tbl, fullfile(dirs.table_dir, 'shap_split_candidates.csv'));

model_single = fit_ridge_model_hvac(X_train, y_single_train, cfg.shap_ridge_lambda);
model_multi = fit_ridge_model_hvac(X_train, y_multi_train, cfg.shap_ridge_lambda);

yhat_single_train = predict_ridge_model_hvac(model_single, X_train);
yhat_single_test = predict_ridge_model_hvac(model_single, X_test);
yhat_multi_train = predict_ridge_model_hvac(model_multi, X_train);
yhat_multi_test = predict_ridge_model_hvac(model_multi, X_test);

fit_tbl = table( ...
    {'single'; 'multi_balanced'}, ...
    [rmse_hvac(y_single_train, yhat_single_train); rmse_hvac(y_multi_train, yhat_multi_train)], ...
    [rmse_hvac(y_single_test, yhat_single_test); rmse_hvac(y_multi_test, yhat_multi_test)], ...
    [r2_hvac(y_single_train, yhat_single_train); r2_hvac(y_multi_train, yhat_multi_train)], ...
    [r2_hvac(y_single_test, yhat_single_test); r2_hvac(y_multi_test, yhat_multi_test)], ...
    'VariableNames', {'Objective', 'TrainRMSE', 'TestRMSE', 'TrainR2', 'TestR2'});
writetable(fit_tbl, fullfile(dirs.table_dir, 'shap_model_fit_summary.csv'));

contrib_single = cell(numel(method_names), 1);
contrib_multi = cell(numel(method_names), 1);

fprintf('  [SHAP] computing contributions for single-objective...\n');
for m = 1:numel(method_names)
    fprintf('    method: %s\n', method_names{m});
    contrib_single{m} = compute_shap_contrib_hvac(method_names{m}, model_single, X_train, X_test, cfg, cfg.shap_mc_draws, cfg.shap_cond_k);
end

fprintf('  [SHAP] computing contributions for multi-objective...\n');
for m = 1:numel(method_names)
    fprintf('    method: %s\n', method_names{m});
    contrib_multi{m} = compute_shap_contrib_hvac(method_names{m}, model_multi, X_train, X_test, cfg, cfg.shap_mc_draws, cfg.shap_cond_k);
end

[corr_single_tbl, score_single_map, imp_single_tbl] = analyze_shap_outputs_hvac(method_names, contrib_single, y_single_test, feature_names);
[corr_multi_tbl, score_multi_map, imp_multi_tbl] = analyze_shap_outputs_hvac(method_names, contrib_multi, y_multi_test, feature_names);

writetable(corr_single_tbl, fullfile(dirs.table_dir, 'shap_correlation_single.csv'));
writetable(corr_multi_tbl, fullfile(dirs.table_dir, 'shap_correlation_multi.csv'));
writetable(imp_single_tbl, fullfile(dirs.table_dir, 'shap_feature_importance_single.csv'));
writetable(imp_multi_tbl, fullfile(dirs.table_dir, 'shap_feature_importance_multi.csv'));

schedule_single_tbl = build_shap_schedule_table_hvac(method_names, score_single_map, y_single_test, cid_test);
schedule_multi_tbl = build_shap_schedule_table_hvac(method_names, score_multi_map, y_multi_test, cid_test);

writetable(schedule_single_tbl, fullfile(dirs.table_dir, 'shap_schedule_compare_single.csv'));
writetable(schedule_multi_tbl, fullfile(dirs.table_dir, 'shap_schedule_compare_multi.csv'));

plot_shap_correlations_hvac(corr_single_tbl, corr_multi_tbl, ...
    fullfile(dirs.figure_dir, 'figure_05_shap_correlations.png'), ...
    fullfile(dirs.figure_dir, 'figure_05_shap_correlations.svg'));

plot_shap_schedule_compare_hvac(schedule_single_tbl, 'Single-objective scheduling (SHAP score ranking)', ...
    fullfile(dirs.figure_dir, 'figure_06_shap_schedule_compare_single.png'), ...
    fullfile(dirs.figure_dir, 'figure_06_shap_schedule_compare_single.svg'));

plot_shap_schedule_compare_hvac(schedule_multi_tbl, 'Multi-objective scheduling (balanced score)', ...
    fullfile(dirs.figure_dir, 'figure_07_shap_schedule_compare_multi.png'), ...
    fullfile(dirs.figure_dir, 'figure_07_shap_schedule_compare_multi.svg'));

plot_shap_importance_hvac(imp_single_tbl, imp_multi_tbl, ...
    fullfile(dirs.figure_dir, 'figure_08_shap_feature_importance.png'), ...
    fullfile(dirs.figure_dir, 'figure_08_shap_feature_importance.svg'));

[fair_long_tbl, fair_summary_tbl] = run_shap_fairness_experiments_hvac(cfg, X_all, y_single, y_multi, method_names);
writetable(fair_long_tbl, fullfile(dirs.table_dir, 'shap_fairness_experiments_long.csv'));
writetable(fair_summary_tbl, fullfile(dirs.table_dir, 'shap_fairness_experiments_summary.csv'));

plot_shap_fairness_hvac(fair_summary_tbl, ...
    fullfile(dirs.figure_dir, 'figure_09_shap_fairness_summary.png'), ...
    fullfile(dirs.figure_dir, 'figure_09_shap_fairness_summary.svg'));

conclusion_tbl = build_shap_conclusion_table_hvac(schedule_single_tbl, schedule_multi_tbl, fair_summary_tbl);
writetable(conclusion_tbl, fullfile(dirs.table_dir, 'shap_conclusion_summary.csv'));

out = struct();
out.n_train = n_train;
out.n_test = n_test;
out.single_corr_tbl = corr_single_tbl;
out.multi_corr_tbl = corr_multi_tbl;
out.single_schedule_tbl = schedule_single_tbl;
out.multi_schedule_tbl = schedule_multi_tbl;
out.fit_tbl = fit_tbl;
out.fair_long_tbl = fair_long_tbl;
out.fair_summary_tbl = fair_summary_tbl;
out.conclusion_tbl = conclusion_tbl;
end

function y_multi = build_balanced_multi_target_hvac(metrics_tbl)
cost_n = normalize01_hvac(metrics_tbl.Cost);
disc_n = normalize01_hvac(metrics_tbl.Discomfort);
smooth_n = normalize01_hvac(metrics_tbl.Smoothness);
y_multi = 0.55 * cost_n + 0.40 * disc_n + 0.05 * smooth_n;
end

function model = fit_ridge_model_hvac(X, y, lambda)
Phi = build_poly_features_hvac(X);
p = size(Phi, 2);
reg = lambda * eye(p);
reg(1, 1) = 0;
beta = (Phi' * Phi + reg) \ (Phi' * y);

model = struct();
model.beta = beta;
model.n_feat = size(X, 2);
end

function yhat = predict_ridge_model_hvac(model, X)
Phi = build_poly_features_hvac(X);
yhat = Phi * model.beta;
end

function Phi = build_poly_features_hvac(X)
n = size(X, 1);
p = size(X, 2);

Phi = [ones(n, 1), X, X .^ 2];
for i = 1:p
    for j = (i + 1):p
        Phi = [Phi, X(:, i) .* X(:, j)]; %#ok<AGROW>
    end
end
end

function contrib = compute_shap_contrib_hvac(method_name, model, X_train, X_test, cfg, n_draws, cond_k)
n_test = size(X_test, 1);
n_feat = size(X_test, 2);
n_train = size(X_train, 1);

contrib = zeros(n_test, n_feat);
fx = predict_ridge_model_hvac(model, X_test);

for i = 1:n_test
    x = X_test(i, :);

    for j = 1:n_feat
        switch method_name
            case 'Ori-SHAP'
                ridx = randi(n_train, n_draws, 1);
                Xp = repmat(x, n_draws, 1);
                Xp(:, j) = X_train(ridx, j);
                fp = mean(predict_ridge_model_hvac(model, Xp));
                contrib(i, j) = fp - fx(i);

            case 'Cond-SHAP'
                mask = true(1, n_feat);
                mask(j) = false;
                ridx = sample_conditional_rows_hvac(X_train, x, mask, cond_k, n_draws);
                Xp = repmat(x, n_draws, 1);
                Xp(:, j) = X_train(ridx, j);
                fp = mean(predict_ridge_model_hvac(model, Xp));
                contrib(i, j) = fp - fx(i);

            case 'PI-SHAP'
                jp = paired_feature_index_hvac(j, cfg.n_blocks);
                ridx = randi(n_train, n_draws, 1);
                Xp = repmat(x, n_draws, 1);
                Xp(:, [j, jp]) = X_train(ridx, [j, jp]);
                fp = mean(predict_ridge_model_hvac(model, Xp));
                contrib(i, j) = 0.5 * (fp - fx(i));

            otherwise
                error('Unknown SHAP method: %s', method_name);
        end
    end

    if mod(i, 100) == 0
        fprintf('      %s progress: %d / %d\n', method_name, i, n_test);
    end
end
end

function ridx = sample_conditional_rows_hvac(X_train, x, mask, cond_k, n_draws)
d2 = sum((X_train(:, mask) - x(mask)) .^ 2, 2);
[~, ord] = sort(d2, 'ascend');
k = min(cond_k, numel(ord));
pool = ord(1:k);
ridx = pool(randi(k, n_draws, 1));
end

function jp = paired_feature_index_hvac(j, n_blocks)
if j <= n_blocks
    jp = j + n_blocks;
else
    jp = j - n_blocks;
end
end

function [corr_tbl, score_map, imp_tbl] = analyze_shap_outputs_hvac(method_names, contrib_cell, y_test, feature_names)
n_m = numel(method_names);
n_feat = numel(feature_names);

score_map = struct();
mean_abs = zeros(n_m, 1);
sp = zeros(n_m, 1);
pe = zeros(n_m, 1);

imp_mat = zeros(n_feat, n_m);

for m = 1:n_m
    C = contrib_cell{m};
    score = sum(C, 2);
    score_map.(valid_field_name_hvac(method_names{m})) = score;

    mean_abs(m) = mean(abs(C(:)));
    sp(m) = spearman_simple_hvac(score, -y_test);
    pe(m) = pearson_simple_hvac(score, -y_test);
    imp_mat(:, m) = mean(abs(C), 1)';
end

corr_tbl = table(method_names(:), sp, pe, mean_abs, ...
    'VariableNames', {'Method', 'SpearmanScoreVsNegMetric', 'PearsonScoreVsNegMetric', 'MeanAbsContribution'});

imp_tbl = table(feature_names(:), 'VariableNames', {'Feature'});
for m = 1:n_m
    vn = strrep(method_names{m}, '-', '_');
    imp_tbl.(vn) = imp_mat(:, m);
end
end

function tbl = build_shap_schedule_table_hvac(method_names, score_map, y_test, candidate_id)
n_m = numel(method_names);

method = cell(n_m, 1);
top1_id = zeros(n_m, 1);
top1_metric = zeros(n_m, 1);
top5_metric = zeros(n_m, 1);
regret1 = zeros(n_m, 1);
regret5 = zeros(n_m, 1);
sp = zeros(n_m, 1);
pe = zeros(n_m, 1);

best_true = min(y_test);

for m = 1:n_m
    method{m} = method_names{m};
    score = score_map.(valid_field_name_hvac(method_names{m}));

    [~, ord] = sort(score, 'descend');
    k = min(5, numel(ord));

    top1_id(m) = candidate_id(ord(1));
    top1_metric(m) = y_test(ord(1));
    top5_metric(m) = min(y_test(ord(1:k)));

    regret1(m) = (top1_metric(m) / best_true - 1) * 100;
    regret5(m) = (top5_metric(m) / best_true - 1) * 100;

    sp(m) = spearman_simple_hvac(score, -y_test);
    pe(m) = pearson_simple_hvac(score, -y_test);
end

tbl = table(method, top1_id, top1_metric, top5_metric, regret1, regret5, sp, pe, ...
    'VariableNames', {'Method', 'Top1CandidateID', 'Top1Metric', 'Top5BestMetric', ...
    'RegretTop1Pct', 'RegretTop5Pct', 'SpearmanScoreVsNegMetric', 'PearsonScoreVsNegMetric'});

tbl = sortrows(tbl, {'RegretTop1Pct', 'RegretTop5Pct'}, {'ascend', 'ascend'});
tbl.RankByTop1Regret = (1:height(tbl))';
tbl = movevars(tbl, 'RankByTop1Regret', 'Before', 1);
end

function [long_tbl, summary_tbl] = run_shap_fairness_experiments_hvac(cfg, X_all, y_single, y_multi, method_names)
seeds = cfg.shap_fair_split_seeds(:);
n = size(X_all, 1);

objectives = {'single', 'multi'};
rows = [];

for s = 1:numel(seeds)
    split_seed = seeds(s);
    rng(split_seed, 'twister');
    perm = randperm(n);

    n_train = min(cfg.shap_fair_n_train, n - 1000);
    n_test = min(cfg.shap_fair_n_test, n - n_train);

    tr = perm(1:n_train);
    te = perm((n_train + 1):(n_train + n_test));

    X_train = X_all(tr, :);
    X_test = X_all(te, :);

    for o = 1:numel(objectives)
        if strcmp(objectives{o}, 'single')
            y_tr = y_single(tr);
            y_te = y_single(te);
        else
            y_tr = y_multi(tr);
            y_te = y_multi(te);
        end

        mdl = fit_ridge_model_hvac(X_train, y_tr, cfg.shap_ridge_lambda);

        contrib = cell(numel(method_names), 1);
        for m = 1:numel(method_names)
            contrib{m} = compute_shap_contrib_hvac(method_names{m}, mdl, X_train, X_test, cfg, cfg.shap_fair_mc_draws, cfg.shap_fair_cond_k);
        end

        [~, score_map, ~] = analyze_shap_outputs_hvac(method_names, contrib, y_te, strcat('f', string(1:size(X_test, 2))'));
        schedule_tbl = build_shap_schedule_table_hvac(method_names, score_map, y_te, te(:));

        for m = 1:height(schedule_tbl)
            rows = [rows; {split_seed, objectives{o}, schedule_tbl.Method{m}, ...
                schedule_tbl.RegretTop1Pct(m), schedule_tbl.RegretTop5Pct(m), ...
                schedule_tbl.SpearmanScoreVsNegMetric(m), schedule_tbl.PearsonScoreVsNegMetric(m)}]; %#ok<AGROW>
        end
    end
end

long_tbl = cell2table(rows, 'VariableNames', ...
    {'SplitSeed', 'Objective', 'Method', 'RegretTop1Pct', 'RegretTop5Pct', 'Spearman', 'Pearson'});

[G, objective, method] = findgroups(long_tbl.Objective, long_tbl.Method);
mean_r1 = splitapply(@mean, long_tbl.RegretTop1Pct, G);
std_r1 = splitapply(@std, long_tbl.RegretTop1Pct, G);
mean_r5 = splitapply(@mean, long_tbl.RegretTop5Pct, G);
std_r5 = splitapply(@std, long_tbl.RegretTop5Pct, G);
mean_sp = splitapply(@mean, long_tbl.Spearman, G);
std_sp = splitapply(@std, long_tbl.Spearman, G);

summary_tbl = table(objective, method, mean_r1, std_r1, mean_r5, std_r5, mean_sp, std_sp, ...
    'VariableNames', {'Objective', 'Method', 'MeanRegretTop1Pct', 'StdRegretTop1Pct', ...
    'MeanRegretTop5Pct', 'StdRegretTop5Pct', 'MeanSpearman', 'StdSpearman'});

summary_tbl.RankByMeanTop1 = nan(height(summary_tbl), 1);
summary_tbl.CompositeScore = nan(height(summary_tbl), 1);
summary_tbl.RankByComposite = nan(height(summary_tbl), 1);
summary_tbl.CompositeWTop1 = repmat(w_comp.top1, height(summary_tbl), 1);
summary_tbl.CompositeWTop5 = repmat(w_comp.top5, height(summary_tbl), 1);
summary_tbl.CompositeWSpearman = repmat(w_comp.spearman, height(summary_tbl), 1);

for o = 1:numel(objectives)
    idx = strcmp(summary_tbl.Objective, objectives{o});
    part = summary_tbl(idx, :);
    [~, ord] = sortrows(part, {'MeanRegretTop1Pct', 'MeanRegretTop5Pct'}, {'ascend', 'ascend'});
    rank_local = zeros(height(part), 1);
    rank_local(ord) = (1:height(part))';
    summary_tbl.RankByMeanTop1(idx) = rank_local;

    top1_n = normalize01_hvac(part.MeanRegretTop1Pct);
    top5_n = normalize01_hvac(part.MeanRegretTop5Pct);
    sp_n = normalize01_hvac(part.MeanSpearman);
    comp = w_comp.top1 * top1_n + w_comp.top5 * top5_n + w_comp.spearman * (1 - sp_n);

    summary_tbl.CompositeScore(idx) = comp;

    [~, ord2] = sort(comp, 'ascend');
    rank_comp = zeros(height(part), 1);
    rank_comp(ord2) = (1:height(part))';
    summary_tbl.RankByComposite(idx) = rank_comp;
end
end

function plot_shap_correlations_hvac(corr_single_tbl, corr_multi_tbl, png_file, svg_file)
methods = corr_single_tbl.Method;
x = 1:numel(methods);

fig = figure('Color', 'w', 'Position', [160, 110, 980, 480]);

subplot(1, 2, 1);
vals = [corr_single_tbl.SpearmanScoreVsNegMetric, corr_multi_tbl.SpearmanScoreVsNegMetric];
bar(x, vals, 0.75);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Spearman correlation');
title('SHAP score correlation with objective');
legend({'Single objective', 'Multi balanced objective'}, 'Location', 'northwest');
grid on;

subplot(1, 2, 2);
vals2 = [corr_single_tbl.PearsonScoreVsNegMetric, corr_multi_tbl.PearsonScoreVsNegMetric];
bar(x, vals2, 0.75);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Pearson correlation');
title('Linear correlation check');
legend({'Single objective', 'Multi balanced objective'}, 'Location', 'northwest');
grid on;

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function plot_shap_schedule_compare_hvac(schedule_tbl, ttl, png_file, svg_file)
fig = figure('Color', 'w', 'Position', [200, 140, 900, 480]);

methods = schedule_tbl.Method;
x = 1:height(schedule_tbl);
bar(x, schedule_tbl.RegretTop1Pct, 0.70, 'FaceColor', [0.20, 0.58, 0.75]);
set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 20);
ylabel('Top1 regret (%)');
title(ttl);
grid on;

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function plot_shap_importance_hvac(imp_single_tbl, imp_multi_tbl, png_file, svg_file)
method_cols = imp_single_tbl.Properties.VariableNames(2:end);

A = table2array(imp_single_tbl(:, 2:end));
B = table2array(imp_multi_tbl(:, 2:end));

fig = figure('Color', 'w', 'Position', [100, 100, 1200, 540]);

subplot(1, 2, 1);
imagesc(A);
colorbar;
title('Mean |contribution| (single objective)');
set(gca, 'XTick', 1:numel(method_cols), 'XTickLabel', method_cols, ...
    'YTick', 1:height(imp_single_tbl), 'YTickLabel', imp_single_tbl.Feature, ...
    'XTickLabelRotation', 20);

subplot(1, 2, 2);
imagesc(B);
colorbar;
title('Mean |contribution| (multi balanced objective)');
set(gca, 'XTick', 1:numel(method_cols), 'XTickLabel', method_cols, ...
    'YTick', 1:height(imp_multi_tbl), 'YTickLabel', imp_multi_tbl.Feature, ...
    'XTickLabelRotation', 20);

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function plot_shap_fairness_hvac(summary_tbl, png_file, svg_file)
fig = figure('Color', 'w', 'Position', [80, 80, 1200, 760]);

obj = {'single', 'multi'};
for k = 1:2
    idx = strcmp(summary_tbl.Objective, obj{k});
    part = summary_tbl(idx, :);
    [~, ord] = sort(part.RankByComposite, 'ascend');
    part = part(ord, :);

    x = 1:height(part);

    subplot(2, 2, 2 * k - 1);
    bar(x, part.MeanRegretTop1Pct, 0.70, 'FaceColor', [0.24, 0.60, 0.82]); hold on;
    errorbar(x, part.MeanRegretTop1Pct, part.StdRegretTop1Pct, 'k.', 'LineWidth', 1.1);
    set(gca, 'XTick', x, 'XTickLabel', part.Method, 'XTickLabelRotation', 20);
    ylabel('Top1 regret (%)');
    title(sprintf('Fairness study (%s): mean Top1 regret', obj{k}));
    grid on;

    subplot(2, 2, 2 * k);
    bar(x, part.MeanSpearman, 0.70, 'FaceColor', [0.87, 0.48, 0.18]); hold on;
    errorbar(x, part.MeanSpearman, part.StdSpearman, 'k.', 'LineWidth', 1.1);
    set(gca, 'XTick', x, 'XTickLabel', part.Method, 'XTickLabelRotation', 20);
    ylabel('Spearman');
    title(sprintf('Fairness study (%s): mean Spearman', obj{k}));
    grid on;
end

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end

function tbl = build_shap_conclusion_table_hvac(schedule_single_tbl, schedule_multi_tbl, fair_summary_tbl)
base_single_best = schedule_single_tbl.Method{1};
base_multi_best = schedule_multi_tbl.Method{1};

idx_s = strcmp(fair_summary_tbl.Objective, 'single');
idx_m = strcmp(fair_summary_tbl.Objective, 'multi');

part_s = sortrows(fair_summary_tbl(idx_s, :), {'MeanRegretTop1Pct', 'MeanRegretTop5Pct'}, {'ascend', 'ascend'});
part_m = sortrows(fair_summary_tbl(idx_m, :), {'MeanRegretTop1Pct', 'MeanRegretTop5Pct'}, {'ascend', 'ascend'});

part_s_comp = sortrows(fair_summary_tbl(idx_s, :), 'CompositeScore', 'ascend');
part_m_comp = sortrows(fair_summary_tbl(idx_m, :), 'CompositeScore', 'ascend');

fair_single_best = part_s.Method{1};
fair_multi_best = part_m.Method{1};
fair_single_comp = part_s_comp.Method{1};
fair_multi_comp = part_m_comp.Method{1};

tbl = table( ...
    {'BaseSplitSingle'; 'BaseSplitMulti'; 'FairnessTop1Single'; 'FairnessTop1Multi'; 'FairnessCompositeSingle'; 'FairnessCompositeMulti'}, ...
    {base_single_best; base_multi_best; fair_single_best; fair_multi_best; fair_single_comp; fair_multi_comp}, ...
    'VariableNames', {'Evaluation', 'BestMethod'});
end

function w = get_composite_weights_hvac(cfg)
w = struct('top1', 0.20, 'top5', 0.50, 'spearman', 0.30);
if isfield(cfg, 'shap_composite_weights') && isstruct(cfg.shap_composite_weights)
    c = cfg.shap_composite_weights;
    if isfield(c, 'top1') && isfield(c, 'top5') && isfield(c, 'spearman')
        vv = [c.top1, c.top5, c.spearman];
        if all(isfinite(vv)) && all(vv >= 0)
            s = sum(vv);
            if s > eps
                w.top1 = vv(1) / s;
                w.top5 = vv(2) / s;
                w.spearman = vv(3) / s;
            end
        end
    end
end
end

function v = valid_field_name_hvac(name)
v = strrep(name, '-', '_');
v = strrep(v, ' ', '_');
end

function x = normalize01_hvac(x)
lo = min(x);
hi = max(x);
if hi - lo < 1e-12
    x = zeros(size(x));
else
    x = (x - lo) / (hi - lo);
end
end

function r = rmse_hvac(y, yhat)
r = sqrt(mean((y - yhat) .^ 2));
end

function r = r2_hvac(y, yhat)
den = sum((y - mean(y)) .^ 2);
if den < 1e-12
    r = NaN;
else
    r = 1 - sum((y - yhat) .^ 2) / den;
end
end

function rho = spearman_simple_hvac(x, y)
rx = tied_rank_hvac(x);
ry = tied_rank_hvac(y);
rho = pearson_simple_hvac(rx, ry);
end

function rho = pearson_simple_hvac(x, y)
x = x(:);
y = y(:);
if std(x) < 1e-12 || std(y) < 1e-12
    rho = NaN;
    return;
end
c = corrcoef(x, y);
rho = c(1, 2);
end

function r = tied_rank_hvac(v)
v = v(:);
n = numel(v);
[sv, ord] = sort(v, 'ascend');
r = zeros(n, 1);

i = 1;
while i <= n
    j = i;
    while j < n && sv(j + 1) == sv(i)
        j = j + 1;
    end
    rk = (i + j) / 2;
    r(ord(i:j)) = rk;
    i = j + 1;
end
end
