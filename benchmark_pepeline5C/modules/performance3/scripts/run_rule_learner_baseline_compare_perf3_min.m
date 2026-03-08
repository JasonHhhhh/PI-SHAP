function out = run_rule_learner_baseline_compare_perf3_min(cfg)
% Compare PI-SHAP rule learners on performance3 dataset (seed 11/23/37, dt=1h)

if nargin < 1 || isempty(cfg)
    cfg = struct();
end
cfg = fill_cfg_defaults_rulecmp_perf3(cfg);

ensure_dir_rulecmp_perf3(cfg.out_dir);
ensure_dir_rulecmp_perf3(cfg.table_dir);
ensure_dir_rulecmp_perf3(cfg.plot_dir);
ensure_dir_rulecmp_perf3(cfg.model_dir);

[D, idx_train, idx_test] = load_perf3_case_bundle_rulecmp(cfg);

learner_names = string(cfg.learner_list(:));
n_learner = numel(learner_names);
n_obj = 3;
n_comp = cfg.n_comp;

all_topk = table();
all_corr = table();
all_complexity = table();
all_summary = table();

for li = 1:n_learner
    learner = learner_names(li);
    fprintf('\n[RuleCmp] learner %d/%d: %s\n', li, n_learner, learner);

    [models, reliability, wmap, complexity_tbl] = train_rule_models_for_learner_rulecmp(D, idx_train, idx_test, learner, cfg);

    learner_pack = struct();
    learner_pack.learner = learner;
    learner_pack.models = models;
    learner_pack.reliability = reliability;
    learner_pack.weight_map = wmap;
    learner_pack.complexity = complexity_tbl;
    learner_pack.cfg = cfg;
    save(fullfile(cfg.model_dir, sprintf('learner_models_%s.mat', lower(char(learner)))), 'learner_pack', '-v7.3');

    score_rule = score_rule_models_rulecmp(D, models, reliability, wmap, cfg);

    prior_pi = compute_prior_scores_rulecmp(D.pi_maps, D.obj, cfg);
    score_mix = blend_rule_prior_scores_rulecmp(score_rule, prior_pi, idx_train, cfg);
    [score_cal, calib] = calibrate_scores_rulecmp(score_mix, D.obj, idx_train, cfg); %#ok<NASGU>

    corr_vec = nan(1, n_obj);
    for j = 1:n_obj
        corr_vec(j) = corr(score_cal(:, j), D.obj(:, j), 'Type', 'Pearson', 'Rows', 'complete');
    end

    corr_tbl = table(repmat(learner, n_obj, 1), ["Jcost"; "Jsupp"; "Jvar"], corr_vec(:), ...
        'VariableNames', {'Learner', 'Objective', 'PearsonCorr'});
    all_corr = [all_corr; corr_tbl]; %#ok<AGROW>

    topk_tbl = evaluate_topk_rulecmp(D.obj, score_cal, corr_vec, learner, cfg);
    all_topk = [all_topk; topk_tbl]; %#ok<AGROW>

    complexity_tbl.Learner(:) = learner;
    all_complexity = [all_complexity; complexity_tbl]; %#ok<AGROW>

    case_tbl = table(D.sample_file(:), D.seed(:), D.raw_case_idx(:), D.case_idx(:), ...
        D.obj(:, 1), D.obj(:, 2), D.obj(:, 3), ...
        score_cal(:, 1), score_cal(:, 2), score_cal(:, 3), ...
        'VariableNames', {'SampleFile', 'Seed', 'RawCaseIndex', 'CaseIndex', ...
        'Jcost', 'Jsupp', 'Jvar', 'ScoreJcost', 'ScoreJsupp', 'ScoreJvar'});
    writetable(case_tbl, fullfile(cfg.table_dir, sprintf('learner_case_scores_%s.csv', lower(char(learner)))));

    summary_i = summarize_learner_rulecmp(topk_tbl, complexity_tbl, learner);
    all_summary = [all_summary; summary_i]; %#ok<AGROW>
end

topk_csv = fullfile(cfg.table_dir, 'rule_learner_topk_eval.csv');
corr_csv = fullfile(cfg.table_dir, 'rule_learner_corr.csv');
complexity_csv = fullfile(cfg.table_dir, 'rule_learner_complexity.csv');
summary_csv = fullfile(cfg.table_dir, 'rule_learner_summary.csv');

writetable(all_topk, topk_csv);
writetable(all_corr, corr_csv);
writetable(all_complexity, complexity_csv);
writetable(all_summary, summary_csv);

[bar_png, bar_svg] = plot_topk_regret_rulecmp(all_topk, cfg.plot_dir);

report_md = fullfile(cfg.out_dir, 'RULE_LEARNER_BASELINE_REPORT.md');
write_rulecmp_report(report_md, all_summary, topk_csv, corr_csv, complexity_csv, bar_png, bar_svg, cfg);

out = struct();
out.topk_csv = topk_csv;
out.corr_csv = corr_csv;
out.complexity_csv = complexity_csv;
out.summary_csv = summary_csv;
out.report_md = report_md;
out.bar_png = bar_png;
out.bar_svg = bar_svg;

fprintf('\n[RuleCmp] done. report: %s\n', report_md);
end

function [D, idx_train, idx_test] = load_perf3_case_bundle_rulecmp(cfg)
if exist(cfg.map_cache_file, 'file') ~= 2
    error('Map cache not found: %s', cfg.map_cache_file);
end

S = load(cfg.map_cache_file, 'cache');
C = S.cache;

if ~isfield(C, 'sample_file') || ~isfield(C, 'maps_pi') || ~isfield(C, 'idx_train') || ~isfield(C, 'idx_test')
    error('Invalid cache structure in %s', cfg.map_cache_file);
end

sample_file = string(C.sample_file(:));
n_case = numel(sample_file);

obj = nan(n_case, 3);
policy = nan(cfg.n_time_nn, cfg.n_comp, n_case);
dv = nan(cfg.n_time_shap, cfg.n_comp, n_case);
seed = nan(n_case, 1);
raw_case_idx = nan(n_case, 1);
case_idx = nan(n_case, 1);

for i = 1:n_case
    fp = char(sample_file(i));
    try
        P = load(fp, 'payload');
        p = P.payload;
    catch
        error('Failed loading payload: %s', fp);
    end

    cc = fix_policy_shape_rulecmp(p.inputs.cc_policy, cfg.n_time_nn, cfg.n_comp);
    policy(:, :, i) = cc;
    dv(:, :, i) = diff(cc, 1, 1);
    obj(i, :) = [p.outputs.objective.Jcost, p.outputs.objective.Jsupp, p.outputs.objective.Jvar];

    sd = parse_seed_rulecmp(p, fp);
    rid = parse_case_idx_rulecmp(p, fp);
    seed(i) = sd;
    raw_case_idx(i) = rid;
    case_idx(i) = compose_case_uid_rulecmp(sd, rid, i);
end

D = struct();
D.sample_file = sample_file;
D.seed = seed;
D.raw_case_idx = raw_case_idx;
D.case_idx = case_idx;
D.obj = obj;
D.policy = policy;
D.dv = dv;
D.pi_maps = C.maps_pi;
D.n_case = n_case;

idx_train = C.idx_train(:)';
idx_test = C.idx_test(:)';
end

function [models, reliability, wmap, complexity_tbl] = train_rule_models_for_learner_rulecmp(D, idx_train, idx_test, learner, cfg)
n_obj = 3;
n_comp = cfg.n_comp;
goal_sign = [-1, +1, -1];
obj_names = ["Jcost", "Jsupp", "Jvar"];

models = cell(n_obj, n_comp);
reliability = zeros(n_obj, n_comp);
wmap = zeros(cfg.n_time_shap, n_comp, n_obj);

rows_obj = strings(0, 1);
rows_comp = zeros(0, 1);
rows_nsplit = nan(0, 1);
rows_nleaf = nan(0, 1);
rows_depth = nan(0, 1);
rows_ntree = nan(0, 1);
rows_testacc = nan(0, 1);

for j = 1:n_obj
    [labels, label_w] = build_labels_rulecmp(D.pi_maps(:, :, j, :), D.dv, goal_sign(j), idx_train, cfg);

    wj = mean(abs(D.pi_maps(:, :, j, idx_train)), 4);
    sw = sum(wj, 'all');
    if ~isfinite(sw) || sw <= eps
        wj = ones(size(wj)) / numel(wj);
    else
        wj = wj / sw;
    end
    wmap(:, :, j) = wj;

    for c = 1:n_comp
        [Xtr, Ytr, Wtr] = build_tree_rows_rulecmp(D.policy, D.dv, labels, label_w, c, idx_train, cfg);
        [Xte, Yte, ~] = build_tree_rows_rulecmp(D.policy, D.dv, labels, label_w, c, idx_test, cfg);

        [mdl, meta] = train_one_model_rulecmp(Xtr, Ytr, Wtr, learner, cfg);
        models{j, c} = mdl;

        pred = predict_label_only_rulecmp(mdl, Xte);
        acc_te = balanced_acc_rulecmp(Yte, pred);
        reliability(j, c) = reliability_from_acc_rulecmp(acc_te, cfg);

        rows_obj(end + 1, 1) = obj_names(j); %#ok<AGROW>
        rows_comp(end + 1, 1) = c; %#ok<AGROW>
        rows_nsplit(end + 1, 1) = meta.num_splits; %#ok<AGROW>
        rows_nleaf(end + 1, 1) = meta.num_leaf; %#ok<AGROW>
        rows_depth(end + 1, 1) = meta.max_depth; %#ok<AGROW>
        rows_ntree(end + 1, 1) = meta.num_trees; %#ok<AGROW>
        rows_testacc(end + 1, 1) = acc_te; %#ok<AGROW>
    end
end

complexity_tbl = table(rows_obj, rows_comp, rows_nsplit, rows_nleaf, rows_depth, rows_ntree, rows_testacc, ...
    'VariableNames', {'Objective', 'Compressor', 'NumSplits', 'NumLeaves', 'MaxDepth', 'NumTrees', 'TestBalancedAcc'});
complexity_tbl.Learner = repmat(learner, height(complexity_tbl), 1);
complexity_tbl = movevars(complexity_tbl, 'Learner', 'Before', 'Objective');
end

function [mdl, meta] = train_one_model_rulecmp(Xtr, Ytr, Wtr, learner, cfg)
meta = struct('num_splits', NaN, 'num_leaf', NaN, 'max_depth', NaN, 'num_trees', NaN);

if isempty(Xtr)
    mdl = struct('kind', 'constant', 'const_class', 1);
    meta.num_splits = 0;
    meta.num_leaf = 1;
    meta.max_depth = 0;
    meta.num_trees = 1;
    return;
end

y_str = string(Ytr(:));
u = unique(y_str);
if numel(u) < 2
    if isempty(u)
        cst = 1;
    else
        cst = str2double(u(1));
        if ~isfinite(cst)
            cst = 1;
        end
    end
    mdl = struct('kind', 'constant', 'const_class', cst);
    meta.num_splits = 0;
    meta.num_leaf = 1;
    meta.max_depth = 0;
    meta.num_trees = 1;
    return;
end

switch char(learner)
    case 'CART_Gini'
        [tmdl, leaf] = train_cart_rulecmp(Xtr, Ytr, Wtr, 'gdi', cfg); %#ok<ASGLU>
        mdl = struct('kind', 'cart', 'obj', tmdl, 'score_mode', 'posterior');
        [ns, nl, md] = tree_complexity_rulecmp(tmdl);
        meta.num_splits = ns; meta.num_leaf = nl; meta.max_depth = md; meta.num_trees = 1;

    case 'CART_Entropy'
        [tmdl, leaf] = train_cart_rulecmp(Xtr, Ytr, Wtr, 'deviance', cfg); %#ok<ASGLU>
        mdl = struct('kind', 'cart', 'obj', tmdl, 'score_mode', 'posterior');
        [ns, nl, md] = tree_complexity_rulecmp(tmdl);
        meta.num_splits = ns; meta.num_leaf = nl; meta.max_depth = md; meta.num_trees = 1;

    case 'RF_Bag'
        y_cell = cellstr(string(Ytr));
        n_pred = max(1, round(sqrt(size(Xtr, 2))));
        bag = TreeBagger(cfg.rf_num_trees, Xtr, y_cell, ...
            'Method', 'classification', ...
            'MinLeafSize', cfg.rf_min_leaf, ...
            'NumPredictorsToSample', n_pred, ...
            'Weights', Wtr, ...
            'Surrogate', 'off', ...
            'OOBPrediction', 'off');
        mdl = struct('kind', 'treebagger', 'obj', bag, 'score_mode', 'posterior');
        [ns, nl, md] = treebagger_complexity_rulecmp(bag);
        meta.num_splits = ns; meta.num_leaf = nl; meta.max_depth = md; meta.num_trees = bag.NumTrees;

    case 'AdaBoost_Stump'
        tpl = templateTree('MaxNumSplits', 1, 'MinLeafSize', cfg.boost_min_leaf, 'PredictorSelection', 'allsplits');
        ens = fitcensemble(Xtr, Ytr, ...
            'Method', 'AdaBoostM1', ...
            'Learners', tpl, ...
            'NumLearningCycles', cfg.boost_cycles, ...
            'Weights', Wtr);
        mdl = struct('kind', 'ensemble', 'obj', ens, 'score_mode', 'softmax');
        [ns, nl, md, nt] = ensemble_complexity_rulecmp(ens);
        meta.num_splits = ns; meta.num_leaf = nl; meta.max_depth = md; meta.num_trees = nt;

    otherwise
        error('Unknown learner: %s', learner);
end
end

function [mdl, best_leaf] = train_cart_rulecmp(Xtr, Ytr, Wtr, split_criterion, cfg)
leaf_grid = cfg.tree_leaf_grid(:)';
best_leaf = leaf_grid(1);
best_acc = -inf;

for i = 1:numel(leaf_grid)
    leaf = leaf_grid(i);
    mdl_i = fitctree(Xtr, Ytr, ...
        'MinLeafSize', leaf, ...
        'MaxNumSplits', cfg.tree_max_splits, ...
        'SplitCriterion', split_criterion, ...
        'PredictorSelection', 'allsplits', ...
        'Weights', Wtr);
    acc_i = cv_acc_rulecmp(mdl_i, numel(Ytr), cfg);
    if acc_i > best_acc
        best_acc = acc_i;
        best_leaf = leaf;
    end
end

mdl = fitctree(Xtr, Ytr, ...
    'MinLeafSize', best_leaf, ...
    'MaxNumSplits', cfg.tree_max_splits, ...
    'SplitCriterion', split_criterion, ...
    'PredictorSelection', 'allsplits', ...
    'Weights', Wtr);
end

function acc = cv_acc_rulecmp(mdl, n_obs, cfg)
if n_obs < 2
    acc = NaN;
    return;
end
kfold = min(cfg.tree_cvfold, max(2, floor(n_obs / max(cfg.tree_cv_min_obs_per_fold, 1))));
kfold = min(kfold, n_obs);
if kfold < 2
    acc = 1 - resubLoss(mdl, 'LossFun', 'classiferror');
    return;
end
try
    cv_i = crossval(mdl, 'KFold', kfold);
    acc = 1 - kfoldLoss(cv_i, 'LossFun', 'classiferror');
catch
    acc = 1 - resubLoss(mdl, 'LossFun', 'classiferror');
end
end

function pred = predict_label_only_rulecmp(mdl, X)
if isempty(X)
    pred = categorical([], [-1 1], {'-1', '1'});
    return;
end

switch mdl.kind
    case 'constant'
        pred_num = mdl.const_class * ones(size(X, 1), 1);
        pred = categorical(pred_num, [-1 1], {'-1', '1'});

    case 'cart'
        pred = predict(mdl.obj, X);

    case 'ensemble'
        pred = predict(mdl.obj, X);

    case 'treebagger'
        [p, ~] = predict(mdl.obj, X);
        pred_num = str2double(string(p));
        bad = ~isfinite(pred_num);
        pred_num(bad) = 1;
        pred = categorical(pred_num, [-1 1], {'-1', '1'});

    otherwise
        error('Unknown model kind: %s', mdl.kind);
end
end

function [p_pos, p_neg] = predict_proba_rulecmp(mdl, X)
n = size(X, 1);
p_pos = 0.5 * ones(n, 1);
p_neg = 0.5 * ones(n, 1);

if n < 1
    return;
end

switch mdl.kind
    case 'constant'
        if mdl.const_class >= 0
            p_pos = ones(n, 1);
            p_neg = zeros(n, 1);
        else
            p_pos = zeros(n, 1);
            p_neg = ones(n, 1);
        end

    case 'cart'
        [~, score] = predict(mdl.obj, X);
        [p_pos, p_neg] = scores_to_posneg_rulecmp(score, mdl.obj.ClassNames, mdl.score_mode);

    case 'ensemble'
        [~, score] = predict(mdl.obj, X);
        [p_pos, p_neg] = scores_to_posneg_rulecmp(score, mdl.obj.ClassNames, mdl.score_mode);

    case 'treebagger'
        [~, score] = predict(mdl.obj, X);
        [p_pos, p_neg] = scores_to_posneg_rulecmp(score, mdl.obj.ClassNames, mdl.score_mode);

    otherwise
        error('Unknown model kind: %s', mdl.kind);
end
end

function [p_pos, p_neg] = scores_to_posneg_rulecmp(score, class_names, score_mode)
if isempty(score)
    p_pos = [];
    p_neg = [];
    return;
end

S = double(score);
if size(S, 2) < 2
    if strcmp(score_mode, 'softmax')
        p1 = 1 ./ (1 + exp(-S(:, 1)));
    else
        p1 = min(max(S(:, 1), 0), 1);
    end
    p_pos = p1;
    p_neg = 1 - p1;
    return;
end

if strcmp(score_mode, 'softmax')
    S = softmax_rows_rulecmp(S);
end

cn = string(class_names(:));
id_pos = find(cn == "1", 1, 'first');
id_neg = find(cn == "-1", 1, 'first');
if isempty(id_pos)
    id_pos = 2;
end
if isempty(id_neg)
    id_neg = 1;
end

p_pos = S(:, id_pos);
p_neg = S(:, id_neg);

p_pos = min(max(p_pos, 0), 1);
p_neg = min(max(p_neg, 0), 1);
s = p_pos + p_neg;
bad = ~isfinite(s) | s <= eps;
p_pos(~bad) = p_pos(~bad) ./ s(~bad);
p_neg(~bad) = p_neg(~bad) ./ s(~bad);
p_pos(bad) = 0.5;
p_neg(bad) = 0.5;
end

function P = softmax_rows_rulecmp(S)
mx = max(S, [], 2);
E = exp(S - mx);
sm = sum(E, 2);
P = E ./ max(sm, eps);
P(~isfinite(P)) = 0;
end

function score = score_rule_models_rulecmp(D, models, reliability, wmap, cfg)
n_case = D.n_case;
n_obj = 3;
n_t = cfg.n_time_shap;
n_comp = cfg.n_comp;

score = zeros(n_case, n_obj);
for j = 1:n_obj
    w = wmap(:, :, j);
    sw = sum(w, 'all');
    if ~isfinite(sw) || sw <= eps
        w = ones(size(w)) / numel(w);
    else
        w = w / sw;
    end

    for n = 1:n_case
        v = D.policy(1:n_t, :, n);
        d = D.dv(:, :, n);
        Xn = [v, d];

        miss = zeros(n_t, n_comp);
        for c = 1:n_comp
            mdl = models{j, c};
            [p_pos, p_neg] = predict_proba_rulecmp(mdl, Xn);
            act = sign(d(:, c));
            act(act == 0) = 1;
            act(~isfinite(act)) = 1;

            pm = zeros(n_t, 1);
            m_pos = act >= 0;
            pm(m_pos) = p_pos(m_pos);
            pm(~m_pos) = p_neg(~m_pos);
            pm = min(max(pm, 0), 1);

            base_miss = 1 - pm;
            rel = reliability(j, c);
            if ~isfinite(rel)
                rel = 0;
            end
            miss(:, c) = rel .* base_miss + (1 - rel) .* 0.5;
        end

        score(n, j) = sum(sum(w .* miss));
    end
end
end

function topk_tbl = evaluate_topk_rulecmp(obj, score, corr_vec, learner, cfg)
obj_names = ["Jcost", "Jsupp", "Jvar"];
obj_sense = ["min", "max", "min"];

rows = table();
for j = 1:3
    sign_dir = 1;
    if isfinite(corr_vec(j)) && corr_vec(j) < 0
        sign_dir = -1;
    end
    proxy = normalize01_rulecmp(sign_dir * score(:, j));
    [~, ord] = sort(proxy, 'ascend');

    y = obj(:, j);
    if strcmp(obj_sense(j), "min")
        y_oracle = min(y);
    else
        y_oracle = max(y);
    end

    for kk = 1:numel(cfg.topk_list)
        k = cfg.topk_list(kk);
        k = min(k, numel(ord));
        id = ord(1:k);
        ys = y(id);

        if strcmp(obj_sense(j), "min")
            y_best = min(ys);
            y_mean = mean(ys);
            regret_best = (y_best - y_oracle) / max(abs(y_oracle), eps);
            regret_mean = (y_mean - y_oracle) / max(abs(y_oracle), eps);
            hit_oracle = any(abs(ys - y_oracle) <= cfg.tol);
        else
            y_best = max(ys);
            y_mean = mean(ys);
            regret_best = (y_oracle - y_best) / max(abs(y_oracle), eps);
            regret_mean = (y_oracle - y_mean) / max(abs(y_oracle), eps);
            hit_oracle = any(abs(ys - y_oracle) <= cfg.tol);
        end

        row = table(learner, obj_names(j), obj_sense(j), k, corr_vec(j), ...
            y_best, y_mean, y_oracle, regret_best, regret_mean, double(hit_oracle), ...
            'VariableNames', {'Learner', 'Objective', 'Sense', 'TopK', 'ScoreCorr', ...
            'BestInTopK', 'MeanInTopK', 'OracleBest', 'BestRegret', 'MeanRegret', 'HitOracle'});
        rows = [rows; row]; %#ok<AGROW>
    end
end
topk_tbl = rows;
end

function summary_tbl = summarize_learner_rulecmp(topk_tbl, complexity_tbl, learner)
md3 = topk_tbl(topk_tbl.TopK == 3, :);
md5 = topk_tbl(topk_tbl.TopK == 5, :);

summary_tbl = table(learner, ...
    mean(md3.BestRegret, 'omitnan'), mean(md3.MeanRegret, 'omitnan'), ...
    mean(md5.BestRegret, 'omitnan'), mean(md5.MeanRegret, 'omitnan'), ...
    mean(md3.HitOracle, 'omitnan'), mean(md5.HitOracle, 'omitnan'), ...
    mean(complexity_tbl.NumTrees, 'omitnan'), ...
    mean(complexity_tbl.NumSplits, 'omitnan'), ...
    mean(complexity_tbl.NumLeaves, 'omitnan'), ...
    mean(complexity_tbl.MaxDepth, 'omitnan'), ...
    mean(complexity_tbl.TestBalancedAcc, 'omitnan'), ...
    'VariableNames', {'Learner', ...
    'AvgBestRegretTop3', 'AvgMeanRegretTop3', ...
    'AvgBestRegretTop5', 'AvgMeanRegretTop5', ...
    'AvgHitOracleTop3', 'AvgHitOracleTop5', ...
    'AvgNumTrees', 'AvgNumSplits', 'AvgNumLeaves', 'AvgMaxDepth', 'AvgTestBalancedAcc'});
end

function [png_file, svg_file] = plot_topk_regret_rulecmp(T, plot_dir)
obj_names = unique(T.Objective, 'stable');
learners = unique(T.Learner, 'stable');

f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 90 1760 740], 'Renderer', 'painters');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for ti = 1:2
    if ti == 1
        k = 3;
    else
        k = 5;
    end

    ax = nexttile(ti);
    hold(ax, 'on');

    M = nan(numel(obj_names), numel(learners));
    for oi = 1:numel(obj_names)
        for li = 1:numel(learners)
            m = T.Objective == obj_names(oi) & T.Learner == learners(li) & T.TopK == k;
            if any(m)
                M(oi, li) = mean(T.BestRegret(m), 'omitnan');
            end
        end
    end

    b = bar(ax, M, 'grouped'); %#ok<NASGU>
    xticks(ax, 1:numel(obj_names));
    xticklabels(ax, cellstr(obj_names));
    ylabel(ax, 'Best regret (lower is better)', 'FontSize', 19);
    title(ax, sprintf('Top-%d target regret by learner', k), 'FontSize', 22, 'FontWeight', 'bold');
    grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontSize', 16, 'LineWidth', 1.3);

    if ti == 1
        legend(ax, cellstr(learners), 'Location', 'best', 'FontSize', 14, 'Box', 'on');
    end
end

png_file = fullfile(plot_dir, 'rule_learner_topk_best_regret.png');
svg_file = fullfile(plot_dir, 'rule_learner_topk_best_regret.svg');
exportgraphics(f, png_file, 'Resolution', 260, 'BackgroundColor', 'white');
print(f, svg_file, '-dsvg');
close(f);
end

function write_rulecmp_report(md_file, summary_tbl, topk_csv, corr_csv, complexity_csv, bar_png, bar_svg, cfg)
fid = fopen(md_file, 'w');
if fid < 0
    error('Cannot write report: %s', md_file);
end

fprintf(fid, '# PI-SHAP Rule Learner Baseline Comparison (performance3)\n\n');
fprintf(fid, '- Seeds: `%s`\n', mat2str(cfg.eval_seed_list));
fprintf(fid, '- dt(h): `%.1f`\n', cfg.eval_dt_hr);
fprintf(fid, '- Top-K evaluated: `%s`\n\n', mat2str(cfg.topk_list));

fprintf(fid, '## Learners\n\n');
for i = 1:numel(cfg.learner_list)
    fprintf(fid, '- `%s`\n', cfg.learner_list{i});
end

fprintf(fid, '\n## Aggregated summary\n\n');
fprintf(fid, '| Learner | AvgBestRegretTop3 | AvgBestRegretTop5 | AvgHitOracleTop3 | AvgHitOracleTop5 | AvgTestBalancedAcc |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary_tbl)
    fprintf(fid, '| %s | %.4f | %.4f | %.3f | %.3f | %.4f |\n', ...
        summary_tbl.Learner(i), ...
        summary_tbl.AvgBestRegretTop3(i), ...
        summary_tbl.AvgBestRegretTop5(i), ...
        summary_tbl.AvgHitOracleTop3(i), ...
        summary_tbl.AvgHitOracleTop5(i), ...
        summary_tbl.AvgTestBalancedAcc(i));
end

fprintf(fid, '\n## Files\n\n');
fprintf(fid, '- Top-K eval table: `%s`\n', topk_csv);
fprintf(fid, '- Correlation table: `%s`\n', corr_csv);
fprintf(fid, '- Complexity table: `%s`\n', complexity_csv);
fprintf(fid, '- Plot PNG: `%s`\n', bar_png);
fprintf(fid, '- Plot SVG: `%s`\n', bar_svg);

fclose(fid);
end

function [labels, label_w] = build_labels_rulecmp(map_obj, dv, goal_sign, idx_train, cfg)
sz = size(map_obj);
if numel(sz) == 4 && sz(3) == 1
    map_obj = reshape(map_obj, sz(1), sz(2), sz(4));
elseif numel(sz) == 2
    map_obj = reshape(map_obj, sz(1), sz(2), 1);
end

d = dv;
d(~isfinite(d)) = 0;
if cfg.label_use_dv_interaction
    A = goal_sign .* map_obj .* d;
else
    A = goal_sign .* map_obj;
end
A(~isfinite(A)) = 0;

agg_mode = lower(string(cfg.label_agg_mode));
n_comp = size(A, 2);
switch agg_mode
    case {"per_variable", "per-variable", "pervariable"}
        A_use = A;

    case "mean"
        A_ag = mean(A, 2, 'omitnan');
        A_use = repmat(A_ag, [1, n_comp, 1]);

    case {"weighted_mean", "weighted-mean", "wmean"}
        W_ag = abs(d);
        W_ag(~isfinite(W_ag)) = 0;
        den = sum(W_ag, 2);
        A_ag = sum(A .* W_ag, 2);
        A_ag = A_ag ./ max(den, eps);
        m_ag = mean(A, 2, 'omitnan');
        z = den <= eps;
        A_ag(z) = m_ag(z);
        A_use = repmat(A_ag, [1, n_comp, 1]);

    case "median"
        A_ag = median(A, 2, 'omitnan');
        A_use = repmat(A_ag, [1, n_comp, 1]);

    otherwise
        warning('Unknown label_agg_mode=%s; fallback to per_variable.', char(agg_mode));
        A_use = A;
end

atr = abs(A_use(:, :, idx_train));
atr = atr(:);
atr = atr(isfinite(atr));
if isempty(atr)
    tau = cfg.label_neutral_abs_floor;
else
    tau = quantile(atr, cfg.label_neutral_abs_quantile);
    tau = max(tau, cfg.label_neutral_abs_floor);
end

labels = zeros(size(A));
labels(A_use > tau) = 1;
labels(A_use < -tau) = -1;

if cfg.label_fill_from_dv
    s = sign(dv);
    s(~isfinite(s)) = 0;
    m = (labels == 0) & (s ~= 0);
    labels(m) = s(m);
end

label_w = abs(A_use);
if cfg.label_weight_cap_pct > 0
    cap = prctile(label_w(:), cfg.label_weight_cap_pct);
    if isfinite(cap) && cap > 0
        label_w = min(label_w, cap);
    end
end

label_w(~isfinite(label_w)) = 0;
if tau > 0
    label_w = label_w ./ (tau + label_w);
end
label_w(labels == 0) = 0;
end

function [X, Y, W] = build_tree_rows_rulecmp(policy, dv, labels, label_w, comp_idx, sample_idx, cfg)
n_t = size(dv, 1);
n_s = numel(sample_idx);
n_max = n_t * n_s;

X = zeros(n_max, 10);
Ynum = zeros(n_max, 1);
W = zeros(n_max, 1);
r = 0;

for ii = 1:n_s
    k = sample_idx(ii);
    v = policy(1:n_t, :, k);
    d = dv(:, :, k);
    y = labels(:, comp_idx, k);
    w = label_w(:, comp_idx, k);
    for t = 1:n_t
        yt = y(t);
        if yt == 0 || ~isfinite(yt)
            continue;
        end
        r = r + 1;
        row_x = [v(t, :), d(t, :)];
        row_x(~isfinite(row_x)) = 0;
        X(r, :) = row_x;
        Ynum(r) = yt;

        wt = w(t);
        if ~isfinite(wt) || wt <= 0
            wt = cfg.tree_min_sample_weight;
        end
        W(r) = wt;
    end
end

if r < 1
    X = zeros(0, 10);
    Y = categorical([], [-1 1], {'-1', '1'});
    W = zeros(0, 1);
    return;
end

X = X(1:r, :);
Ynum = Ynum(1:r);
W = W(1:r);

if cfg.tree_use_sample_weights
    W = W ./ max(mean(W), eps);
else
    W = ones(size(W));
end

Y = categorical(Ynum, [-1 1], {'-1', '1'});
end

function prior = compute_prior_scores_rulecmp(maps, obj, cfg)
n_case = size(maps, 4);
prior = zeros(n_case, 3);

for j = 1:3
    ssum = squeeze(sum(sum(maps(:, :, j, :), 1), 2));
    if numel(ssum) ~= n_case
        ssum = reshape(ssum, [n_case, 1]);
    end

    if cfg.prior_scale_to_objective
        den = obj(:, j);
        ok = isfinite(ssum) & isfinite(den) & abs(den) > eps;
        alpha = 1;
        if any(ok)
            a = median(ssum(ok) ./ den(ok));
            if isfinite(a) && abs(a) > cfg.prior_alpha_floor
                alpha = a;
            end
        end
        ssum = ssum ./ alpha;
    end

    prior(:, j) = ssum;
end
end

function mix = blend_rule_prior_scores_rulecmp(score_rule, score_prior, idx_train, cfg)
wr = min(max(cfg.rule_prior_blend, 0), 1);
wp = 1 - wr;

if wp <= eps
    mix = score_rule;
    return;
end

mix = zeros(size(score_rule));
for j = 1:3
    zr = robust_z_with_train_rulecmp(score_rule(:, j), idx_train);
    zp = robust_z_with_train_rulecmp(score_prior(:, j), idx_train);
    mix(:, j) = wr * zr + wp * zp;
end
end

function z = robust_z_with_train_rulecmp(x, idx_train)
x = x(:);
xt = x(idx_train);
xt = xt(isfinite(xt));
if isempty(xt)
    z = zeros(size(x));
    return;
end

med = median(xt);
iq = iqr(xt);
if ~isfinite(iq) || iq <= eps
    iq = std(xt);
end
if ~isfinite(iq) || iq <= eps
    iq = 1;
end

z = (x - med) / iq;
z(~isfinite(z)) = 0;
end

function [score_out, calib] = calibrate_scores_rulecmp(score_in, obj, idx_train, cfg)
score_out = score_in;
calib = struct('a', ones(1, 3), 'b', zeros(1, 3));

if ~cfg.score_calibrate_linear
    return;
end

for j = 1:3
    x = score_in(idx_train, j);
    y = obj(idx_train, j);
    ok = isfinite(x) & isfinite(y);
    if sum(ok) < cfg.score_calib_min_samples
        continue;
    end

    p = polyfit(x(ok), y(ok), 1);
    if any(~isfinite(p))
        continue;
    end

    a = p(1);
    b = p(2);
    score_out(:, j) = a * score_in(:, j) + b;
    calib.a(j) = a;
    calib.b(j) = b;
end
end

function acc = balanced_acc_rulecmp(y_true, y_pred)
if isempty(y_true)
    acc = NaN;
    return;
end
cls = unique(string(y_true));
rec = zeros(0, 1);
for i = 1:numel(cls)
    m = string(y_true) == cls(i);
    if any(m)
        rec(end + 1, 1) = mean(string(y_pred(m)) == cls(i)); %#ok<AGROW>
    end
end
if isempty(rec)
    acc = NaN;
else
    acc = mean(rec);
end
end

function r = reliability_from_acc_rulecmp(acc_te, cfg)
x = acc_te;
if ~isfinite(x)
    r = 0;
    return;
end
r = (x - cfg.score_reliability_baseline) / max(1 - cfg.score_reliability_baseline, eps);
r = max(0, min(1, r));
end

function [nsplit, nleaf, maxdepth] = tree_complexity_rulecmp(mdl)
children = mdl.Children;
if isprop(mdl, 'IsBranchNode')
    nsplit = sum(mdl.IsBranchNode);
else
    nsplit = sum(children(:, 1) > 0 | children(:, 2) > 0);
end
n_nodes = size(children, 1);
leaf_mask = children(:, 1) == 0 & children(:, 2) == 0;
nleaf = sum(leaf_mask);

depth = zeros(n_nodes, 1);
for i = 1:n_nodes
    cl = children(i, 1);
    cr = children(i, 2);
    if cl > 0
        depth(cl) = depth(i) + 1;
    end
    if cr > 0
        depth(cr) = depth(i) + 1;
    end
end
maxdepth = max(depth);
end

function [nsplit, nleaf, maxdepth] = treebagger_complexity_rulecmp(bag)
nt = bag.NumTrees;
sp = nan(nt, 1);
lf = nan(nt, 1);
dp = nan(nt, 1);
for i = 1:nt
    t = bag.Trees{i};
    [sp(i), lf(i), dp(i)] = tree_complexity_rulecmp(t);
end
nsplit = mean(sp, 'omitnan');
nleaf = mean(lf, 'omitnan');
maxdepth = mean(dp, 'omitnan');
end

function [nsplit, nleaf, maxdepth, ntrees] = ensemble_complexity_rulecmp(ens)
ntrees = ens.NumTrained;
sp = nan(ntrees, 1);
lf = nan(ntrees, 1);
dp = nan(ntrees, 1);
for i = 1:ntrees
    t = ens.Trained{i};
    if isa(t, 'CompactClassificationTree') || isa(t, 'ClassificationTree')
        [sp(i), lf(i), dp(i)] = tree_complexity_rulecmp(t);
    end
end
nsplit = mean(sp, 'omitnan');
nleaf = mean(lf, 'omitnan');
maxdepth = mean(dp, 'omitnan');
end

function y = normalize01_rulecmp(x)
x = x(:);
xmin = min(x);
xmax = max(x);
if ~isfinite(xmin) || ~isfinite(xmax) || xmax <= xmin + eps
    y = zeros(size(x));
else
    y = (x - xmin) ./ (xmax - xmin);
end
end

function cc = fix_policy_shape_rulecmp(cc_in, n_t, n_c)
cc = cc_in;
if size(cc, 2) ~= n_c && size(cc, 1) == n_c
    cc = cc';
end
if size(cc, 1) ~= n_t
    t_in = linspace(0, 1, size(cc, 1));
    t_out = linspace(0, 1, n_t);
    cc2 = zeros(n_t, n_c);
    for c = 1:n_c
        cc2(:, c) = interp1(t_in, cc(:, c), t_out, 'linear', 'extrap');
    end
    cc = cc2;
end
end

function seed = parse_seed_rulecmp(p, fp)
seed = NaN;
if isfield(p, 'meta') && isfield(p.meta, 'seed') && isfinite(p.meta.seed)
    seed = double(p.meta.seed);
else
    tk = regexp(fp, 'seed_(\d+)', 'tokens', 'once');
    if ~isempty(tk)
        seed = str2double(tk{1});
    end
end
if ~isfinite(seed)
    seed = 0;
end
seed = round(seed);
end

function idx = parse_case_idx_rulecmp(p, fp)
idx = NaN;
if isfield(p, 'meta') && isfield(p.meta, 'sample_id') && isfinite(p.meta.sample_id)
    idx = double(p.meta.sample_id);
else
    [~, fn, ext] = fileparts(fp);
    fname = [fn, ext];
    tk = regexp(fname, 'sample_(\d+)\.mat', 'tokens', 'once');
    if ~isempty(tk)
        idx = str2double(tk{1});
    end
end
if ~isfinite(idx)
    idx = 0;
end
idx = round(idx);
end

function uid = compose_case_uid_rulecmp(seed, raw_idx, serial_idx)
uid = round(seed) * 1e6 + round(raw_idx);
if ~isfinite(uid) || uid <= 0
    uid = serial_idx;
end
end

function cfg = fill_cfg_defaults_rulecmp_perf3(cfg)
this_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(fileparts(this_dir)));

if ~isfield(cfg, 'repo_dir') || isempty(cfg.repo_dir)
    cfg.repo_dir = repo_dir;
end
if ~isfield(cfg, 'work_dir') || isempty(cfg.work_dir)
    cfg.work_dir = fullfile(repo_dir, 'modules', 'performance3');
end
if ~isfield(cfg, 'out_dir') || isempty(cfg.out_dir)
    cfg.out_dir = fullfile(cfg.work_dir, 'rule_learner_compare');
end
if ~isfield(cfg, 'table_dir') || isempty(cfg.table_dir)
    cfg.table_dir = fullfile(cfg.out_dir, 'tables');
end
if ~isfield(cfg, 'plot_dir') || isempty(cfg.plot_dir)
    cfg.plot_dir = fullfile(cfg.out_dir, 'plots');
end
if ~isfield(cfg, 'model_dir') || isempty(cfg.model_dir)
    cfg.model_dir = fullfile(cfg.out_dir, 'models');
end

if ~isfield(cfg, 'eval_seed_list') || isempty(cfg.eval_seed_list)
    cfg.eval_seed_list = [11, 23, 37];
end
if ~isfield(cfg, 'eval_dt_hr') || isempty(cfg.eval_dt_hr)
    cfg.eval_dt_hr = 1.0;
end

if ~isfield(cfg, 'n_comp') || isempty(cfg.n_comp)
    cfg.n_comp = 5;
end
if ~isfield(cfg, 'n_time_nn') || isempty(cfg.n_time_nn)
    cfg.n_time_nn = 25;
end
if ~isfield(cfg, 'n_time_shap') || isempty(cfg.n_time_shap)
    cfg.n_time_shap = 24;
end

if ~isfield(cfg, 'map_cache_file') || isempty(cfg.map_cache_file)
    cfg.map_cache_file = fullfile(repo_dir, 'modules', 'performance3', 'method_runs', 'holdout_shap_maps_cache_seed11_23_37_dt1p0.mat');
end

if ~isfield(cfg, 'learner_list') || isempty(cfg.learner_list)
    cfg.learner_list = {'CART_Gini', 'CART_Entropy', 'RF_Bag', 'AdaBoost_Stump'};
end
if ~isfield(cfg, 'topk_list') || isempty(cfg.topk_list)
    cfg.topk_list = [3, 5];
end

if ~isfield(cfg, 'tree_leaf_grid') || isempty(cfg.tree_leaf_grid)
    cfg.tree_leaf_grid = [5, 10, 20, 30];
end
if ~isfield(cfg, 'tree_max_splits') || isempty(cfg.tree_max_splits)
    cfg.tree_max_splits = 60;
end
if ~isfield(cfg, 'tree_cvfold') || isempty(cfg.tree_cvfold)
    cfg.tree_cvfold = 5;
end
if ~isfield(cfg, 'tree_cv_min_obs_per_fold') || isempty(cfg.tree_cv_min_obs_per_fold)
    cfg.tree_cv_min_obs_per_fold = 40;
end
if ~isfield(cfg, 'tree_min_sample_weight') || isempty(cfg.tree_min_sample_weight)
    cfg.tree_min_sample_weight = 0.05;
end
if ~isfield(cfg, 'tree_use_sample_weights') || isempty(cfg.tree_use_sample_weights)
    cfg.tree_use_sample_weights = true;
end

if ~isfield(cfg, 'rf_num_trees') || isempty(cfg.rf_num_trees)
    cfg.rf_num_trees = 80;
end
if ~isfield(cfg, 'rf_min_leaf') || isempty(cfg.rf_min_leaf)
    cfg.rf_min_leaf = 10;
end
if ~isfield(cfg, 'boost_cycles') || isempty(cfg.boost_cycles)
    cfg.boost_cycles = 120;
end
if ~isfield(cfg, 'boost_min_leaf') || isempty(cfg.boost_min_leaf)
    cfg.boost_min_leaf = 10;
end

if ~isfield(cfg, 'label_neutral_abs_quantile') || isempty(cfg.label_neutral_abs_quantile)
    cfg.label_neutral_abs_quantile = 0.20;
end
if ~isfield(cfg, 'label_neutral_abs_floor') || isempty(cfg.label_neutral_abs_floor)
    cfg.label_neutral_abs_floor = 1e-8;
end
if ~isfield(cfg, 'label_fill_from_dv') || isempty(cfg.label_fill_from_dv)
    cfg.label_fill_from_dv = true;
end
if ~isfield(cfg, 'label_use_dv_interaction') || isempty(cfg.label_use_dv_interaction)
    cfg.label_use_dv_interaction = false;
end
if ~isfield(cfg, 'label_weight_cap_pct') || isempty(cfg.label_weight_cap_pct)
    cfg.label_weight_cap_pct = 99.0;
end
if ~isfield(cfg, 'label_agg_mode') || isempty(cfg.label_agg_mode)
    cfg.label_agg_mode = 'per_variable';
end

if ~isfield(cfg, 'score_reliability_baseline') || isempty(cfg.score_reliability_baseline)
    cfg.score_reliability_baseline = 0.50;
end
if ~isfield(cfg, 'score_calibrate_linear') || isempty(cfg.score_calibrate_linear)
    cfg.score_calibrate_linear = true;
end
if ~isfield(cfg, 'score_calib_min_samples') || isempty(cfg.score_calib_min_samples)
    cfg.score_calib_min_samples = 25;
end
if ~isfield(cfg, 'rule_prior_blend') || isempty(cfg.rule_prior_blend)
    cfg.rule_prior_blend = 0.65;
end
if ~isfield(cfg, 'prior_scale_to_objective') || isempty(cfg.prior_scale_to_objective)
    cfg.prior_scale_to_objective = true;
end
if ~isfield(cfg, 'prior_alpha_floor') || isempty(cfg.prior_alpha_floor)
    cfg.prior_alpha_floor = 1e-8;
end
if ~isfield(cfg, 'tol') || isempty(cfg.tol)
    cfg.tol = 1e-12;
end
end

function ensure_dir_rulecmp_perf3(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end
