function hvac_write_summary(file_path, cfg, planning, shap_out)
fid = fopen(file_path, 'w');
if fid < 0
    error('Cannot write summary file: %s', file_path);
end

single_tbl = planning.single_tbl;
selected_tbl = planning.selected_tbl;
robust_summary_tbl = planning.robust_summary_tbl;
metrics_tbl = planning.metrics_tbl;
pareto_tbl = planning.pareto_tbl;

fprintf(fid, '# HVAC 2-zone benchmark summary\n\n');

fprintf(fid, '## Problem configuration\n\n');
fprintf(fid, '- Horizon: `%d` hours (`dt=%.1f h`)\n', cfg.horizon, cfg.dt_hr);
fprintf(fid, '- Zones/controls: `%d`\n', cfg.n_zones);
fprintf(fid, '- Decision granularity: `%d` blocks x `%d` hours/block\n', cfg.n_blocks, cfg.block_hours);
fprintf(fid, '- Action levels per zone-block: `%s`\n', mat2str(cfg.action_levels));
fprintf(fid, '- Search space size: `%d` candidates\n', height(metrics_tbl));
fprintf(fid, '- DOE scenario count: `%d`\n\n', cfg.n_doe);

fprintf(fid, '## Single-objective scheduling\n\n');
best_row = single_tbl(1, :);
fprintf(fid, '- Best method: `%s`\n', best_row.Method{1});
fprintf(fid, '- Best Jsingle: `%.4f`\n', best_row.Jsingle);
fprintf(fid, '- Cost / Discomfort / Smoothness: `%.4f / %.4f / %.4f`\n', ...
    best_row.Cost, best_row.Discomfort, best_row.Smoothness);
fprintf(fid, '- Comfort violation hours: `%.1f`\n\n', best_row.ComfortViolationHours);

fprintf(fid, '## Multi-objective scheduling\n\n');
fprintf(fid, '- Pareto points found: `%d`\n', height(pareto_tbl));
for i = 1:height(selected_tbl)
    fprintf(fid, '- `%s`: cost `%.4f`, discomfort `%.4f`, Jsingle `%.4f`\n', ...
        selected_tbl.Selection{i}, selected_tbl.Cost(i), selected_tbl.Discomfort(i), selected_tbl.Jsingle(i));
end
fprintf(fid, '\n');

fprintf(fid, '## DOE robustness (mean Jsingle ranking)\n\n');
for i = 1:height(robust_summary_tbl)
    fprintf(fid, '%d. `%s`: mean Jsingle `%.4f` (std `%.4f`), mean cost `%.4f`, mean discomfort `%.4f`\n', ...
        robust_summary_tbl.RankByMeanJsingle(i), robust_summary_tbl.Method{i}, ...
        robust_summary_tbl.MeanJsingle(i), robust_summary_tbl.StdJsingle(i), ...
        robust_summary_tbl.MeanCost(i), robust_summary_tbl.MeanDiscomfort(i));
end

fprintf(fid, '\n## SHAP comparison on train/test split\n\n');
fprintf(fid, '- Train/Test candidates: `%d / %d`\n', shap_out.n_train, shap_out.n_test);
fprintf(fid, '- Same planning granularity and sampling are used for Ori-SHAP, Cond-SHAP, and PI-SHAP\n\n');

fprintf(fid, '### Single-objective SHAP scheduling\n\n');
for i = 1:height(shap_out.single_schedule_tbl)
    fprintf(fid, '- `%s`: top1 metric `%.4f`, top1 regret `%.4f %%`, top5 regret `%.4f %%`, Spearman `%.4f`\n', ...
        shap_out.single_schedule_tbl.Method{i}, ...
        shap_out.single_schedule_tbl.Top1Metric(i), ...
        shap_out.single_schedule_tbl.RegretTop1Pct(i), ...
        shap_out.single_schedule_tbl.RegretTop5Pct(i), ...
        shap_out.single_schedule_tbl.SpearmanScoreVsNegMetric(i));
end

fprintf(fid, '\n### Multi-objective SHAP scheduling\n\n');
for i = 1:height(shap_out.multi_schedule_tbl)
    fprintf(fid, '- `%s`: top1 metric `%.4f`, top1 regret `%.4f %%`, top5 regret `%.4f %%`, Spearman `%.4f`\n', ...
        shap_out.multi_schedule_tbl.Method{i}, ...
        shap_out.multi_schedule_tbl.Top1Metric(i), ...
        shap_out.multi_schedule_tbl.RegretTop1Pct(i), ...
        shap_out.multi_schedule_tbl.RegretTop5Pct(i), ...
        shap_out.multi_schedule_tbl.SpearmanScoreVsNegMetric(i));
end

fprintf(fid, '\n## SHAP fairness study (multiple random splits)\n\n');
fprintf(fid, '- Split seeds: `%s`\n', mat2str(cfg.shap_fair_split_seeds));
fprintf(fid, '- Per split train/test: `%d / %d`\n\n', cfg.shap_fair_n_train, cfg.shap_fair_n_test);

if ~isempty(shap_out.fair_summary_tbl)
    if all(ismember({'CompositeWTop1', 'CompositeWTop5', 'CompositeWSpearman'}, shap_out.fair_summary_tbl.Properties.VariableNames))
        w1 = shap_out.fair_summary_tbl.CompositeWTop1(1);
        w5 = shap_out.fair_summary_tbl.CompositeWTop5(1);
        ws = shap_out.fair_summary_tbl.CompositeWSpearman(1);
    else
        w1 = 0.20;
        w5 = 0.50;
        ws = 0.30;
        if isfield(cfg, 'shap_composite_weights')
            c = cfg.shap_composite_weights;
            if isstruct(c) && isfield(c, 'top1') && isfield(c, 'top5') && isfield(c, 'spearman')
                vv = [c.top1, c.top5, c.spearman];
                if all(isfinite(vv)) && sum(vv) > eps
                    vv = vv / sum(vv);
                    w1 = vv(1);
                    w5 = vv(2);
                    ws = vv(3);
                end
            end
        end
    end
    fprintf(fid, '- Composite ranking uses pre-set weights (fixed before result inspection): top1=`%.2f`, top5=`%.2f`, spearman=`%.2f`.\n', w1, w5, ws);
    fprintf(fid, '- Composite ranking is criterion-specific and does not replace the Top1 ranking view.\n\n');
end

for obj = {'single', 'multi'}
    idx = strcmp(shap_out.fair_summary_tbl.Objective, obj{1});
    part = shap_out.fair_summary_tbl(idx, :);
    part_top1 = sortrows(part, {'MeanRegretTop1Pct', 'MeanRegretTop5Pct'}, {'ascend', 'ascend'});
    part_comp = sortrows(part, 'CompositeScore', 'ascend');
    fprintf(fid, '### %s objective\n\n', obj{1});
    fprintf(fid, '- Top1-ranking winner: `%s`\n', part_top1.Method{1});
    fprintf(fid, '- Composite-ranking winner: `%s`\n', part_comp.Method{1});
    for i = 1:height(part_top1)
        fprintf(fid, '- `%s`: mean top1 regret `%.4f %%` (std `%.4f`), mean top5 regret `%.4f %%`, mean Spearman `%.4f`, composite `%.4f`\n', ...
            part_top1.Method{i}, part_top1.MeanRegretTop1Pct(i), part_top1.StdRegretTop1Pct(i), ...
            part_top1.MeanRegretTop5Pct(i), part_top1.MeanSpearman(i), part_top1.CompositeScore(i));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## SHAP conclusions\n\n');
fprintf(fid, '- Each line below is winner-under-criterion; these are not claimed as universal winners across all criteria.\n');
for i = 1:height(shap_out.conclusion_tbl)
    fprintf(fid, '- `%s`: `%s`\n', shap_out.conclusion_tbl.Evaluation{i}, shap_out.conclusion_tbl.BestMethod{i});
end

fclose(fid);
end
