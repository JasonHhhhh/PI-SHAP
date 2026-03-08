function out = run_tr_cost_supply_try1_min()
sim_dir = fileparts(mfilename('fullpath'));
addpath('src');
addpath('shap_src');
addpath('shap_src_min');
addpath(sim_dir);

cfg = struct();
cfg.try_name = 'try1';
cfg.supp_obj_sign = -1;
cfg.auto_scale_from_extremes = true;
cfg.parallel_worker_ratio = 0.90;
cfg.force_pool_size = true;

u = linspace(0, 1, 31);
w_linear = u;
w_dense_low = u.^2;
w_dense_high = 1 - (1-u).^2;
weights = unique([w_linear w_dense_low w_dense_high], 'stable');
weights = sort(weights);
weights = unique(round(weights, 12), 'stable');
cfg.supply_weights = weights;

action_dt_hr = 1.0;
use_parallel = true;

out = run_tr_cost_supply_min([], action_dt_hr, use_parallel, cfg);
write_try1_readme_min(out.stage_dir, cfg, weights);
end

function write_try1_readme_min(stage_dir, cfg, weights)
md = fullfile(stage_dir, 'TRY1_SETUP.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write try1 setup markdown: %s', md);
end

fprintf(fid, '# TR cost+supply try1 setup\n\n');
fprintf(fid, '- objective direction: `cost min + supply max`\n');
fprintf(fid, '- implemented by setting `supp_obj_sign = -1` in optimization objective\n');
fprintf(fid, '- action granularity: `1.0 h`\n');
fprintf(fid, '- try folder: `shap_src_min/tr/cost_supply/try1`\n');
fprintf(fid, '- parallel worker policy: `90%% of detected CPU cores`\n');
fprintf(fid, '- auto objective scaling: `%d` (from anchor runs at w=0 and w=1)\n', cfg.auto_scale_from_extremes);
fprintf(fid, '- weight count: `%d`\n\n', numel(weights));

fprintf(fid, '## Initial weight strategy\n\n');
fprintf(fid, '- Build dense initial set using three grids merged and sorted:\n');
fprintf(fid, '  - linear grid\n');
fprintf(fid, '  - low-end dense grid (`u^2`)\n');
fprintf(fid, '  - high-end dense grid (`1-(1-u)^2`)\n');
fprintf(fid, '- This gives better initial Pareto coverage near both extremes.\n\n');

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `weights.csv`\n');
fprintf(fid, '- `anchors.csv`\n');
fprintf(fid, '- `summary.csv`\n');
fprintf(fid, '- `pareto.csv`\n');
fprintf(fid, '- `results.mat`\n');
fprintf(fid, '- `summary.md`\n');
fprintf(fid, '- `TRY1_SETUP.md`\n');
fprintf(fid, '- `plots/{action.png,transient.png,metrics.png,pareto.png}`\n');

fclose(fid);
end
