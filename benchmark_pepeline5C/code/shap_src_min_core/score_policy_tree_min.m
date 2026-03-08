function score_result = score_policy_tree_min(sim_result, cfg)
X = sim_result.features.x;
dX = sim_result.features.dx;

if size(X, 1) ~= numel(cfg.tree_ids)
    error('Expected %d decision steps, got %d', numel(cfg.tree_ids), size(X, 1));
end

scores = zeros(1, 3);
scores_weighted = zeros(1, 3);
labels = nan(numel(cfg.tree_ids), 3);

for metric_id = 1:3
    for t = cfg.tree_ids
        tree_file = fullfile(cfg.tree_root, sprintf('ctree_%d_m%d_ls%d.mat', t, metric_id, cfg.tree_k));
        if exist(tree_file, 'file') ~= 2
            error('Tree file not found: %s', tree_file);
        end

        T = load(tree_file, 'tree');
        pred = predict(T.tree, [X(t,:) dX(t,:)]);
        label = parse_tree_label_min(pred);

        labels(t, metric_id) = label;
        scores(metric_id) = scores(metric_id) + label;
        scores_weighted(metric_id) = scores_weighted(metric_id) + label * mean(X(t,:));
    end
end

score_result = struct();
score_result.score_sum = scores;
score_result.score_weighted = scores_weighted;
score_result.labels = labels;
end

function label = parse_tree_label_min(pred)
if iscell(pred)
    label = str2double(pred{1});
elseif isstring(pred)
    label = str2double(char(pred(1)));
elseif ischar(pred)
    label = str2double(pred(1,:));
else
    label = double(pred(1));
end

if ~isfinite(label)
    error('Tree prediction label is not numeric.');
end
end
