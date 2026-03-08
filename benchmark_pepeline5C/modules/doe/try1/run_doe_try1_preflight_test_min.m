function out = run_doe_try1_preflight_test_min()
addpath('shap_src_min/doe/try1');

cfg = doe_try1_sim_config_min();
cfg.run_name = 'preflight_parallel_test';
cfg.clean_run_dir = true;
cfg.use_parallel = true;
cfg.parallel_worker_ratio = 0.90;
cfg.sample_mode = 'first_n';
cfg.first_n = 3;
cfg.seeds = [11 23 37];
cfg.dt_list = [1.0 2.0];
cfg.save.save_system_state_all = true;
cfg.save.save_outputs_quick = true;
cfg.save.save_full_par_struct = false;

run_out = run_doe_try1_sim_batch_min(cfg);

manifest_tbl = run_out.manifest_tbl;
summary_tbl = run_out.summary_tbl;
size_stats = estimate_storage_from_manifest_min(manifest_tbl, cfg);

ok_idx = find(manifest_tbl.OK, 1, 'first');
if isempty(ok_idx)
    error('Preflight test has no successful case to reconstruct.');
end

case_file = char(manifest_tbl.CaseFile(ok_idx));
recon_opts = struct();
recon_opts.save_to_file = true;
recon_opts.output_file = fullfile(run_out.run_dir, 'reconstruct_first_case_from_saved.mat');
recon_opts.compare_with_payload = true;
recon_out = reconstruct_case_from_saved_min(case_file, recon_opts);

plot_file = fullfile(run_out.run_dir, 'plotonlyfortest.png');
plotonly_for_test_min(summary_tbl, recon_out, plot_file);

write_precheck_md_min(run_out.run_dir, cfg, run_out, manifest_tbl, summary_tbl, case_file, recon_out, plot_file, size_stats);

out = struct();
out.run_out = run_out;
out.reconstruct = recon_out;
out.plot_file = plot_file;
out.size_stats = size_stats;

fprintf('Preflight done. Run dir: %s\n', run_out.run_dir);
end

function plotonly_for_test_min(summary_tbl, recon_out, plot_file)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1400 900]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

if isempty(summary_tbl)
    nexttile;
    text(0.5, 0.5, 'No summary rows', 'HorizontalAlignment', 'center');
    axis off;
    exportgraphics(f, plot_file, 'Resolution', 220, 'BackgroundColor', 'white');
    close(f);
    return;
end

labels = arrayfun(@(s,dt) sprintf('s%03d-dt%.1f', s, dt), summary_tbl.Seed, summary_tbl.ActionDt_hr, 'UniformOutput', false);
x = 1:height(summary_tbl);

ax1 = nexttile;
bar(x, summary_tbl.OKRate, 0.7, 'FaceColor', [0.25 0.55 0.82]);
ylim([0 1.05]);
xticks(x);
xticklabels(labels);
xtickangle(35);
ylabel('OK rate');
title('Preflight: solver success by dataset');
grid on;
set(ax1, 'FontSize', 10, 'LineWidth', 1.0);

ax2 = nexttile;
bar(x, summary_tbl.MeanSimSec, 0.7, 'FaceColor', [0.84 0.43 0.12]);
xticks(x);
xticklabels(labels);
xtickangle(35);
ylabel('Mean sim sec');
title('Preflight: runtime by dataset');
grid on;
set(ax2, 'FontSize', 10, 'LineWidth', 1.0);

ax3 = nexttile;
scatter(summary_tbl.MedianJcost, summary_tbl.MedianJsupp, 85, [0.78 0.15 0.15], 'filled');
hold on;
for i = 1:height(summary_tbl)
    text(summary_tbl.MedianJcost(i), summary_tbl.MedianJsupp(i), [' ' labels{i}], 'FontSize', 9);
end
xlabel('Median Jcost');
ylabel('Median Jsupp');
title('Preflight: objective map');
grid on;
set(ax3, 'FontSize', 10, 'LineWidth', 1.0);

ax4 = nexttile;
yyaxis left;
plot(recon_out.reconstructed.t_hr, recon_out.reconstructed.derived.mean_m_cc, '-', 'Color', [0.16 0.35 0.75], 'LineWidth', 1.8);
ylabel('mean(m\_cc)');
yyaxis right;
plot(recon_out.reconstructed.t_hr, recon_out.reconstructed.process.m_supp, '-', 'Color', [0.75 0.22 0.10], 'LineWidth', 1.8);
ylabel('m\_supp');
xlabel('Time (h)');
title('Saved-state reconstruction: process traces');
grid on;
set(ax4, 'FontSize', 10, 'LineWidth', 1.0);

sgtitle('DOE try1 preflight test (parallel + simulation + saved-state reconstruction)', 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(f, plot_file, 'Resolution', 220, 'BackgroundColor', 'white');
close(f);
end

function write_precheck_md_min(run_dir, cfg, run_out, manifest_tbl, summary_tbl, case_file, recon_out, plot_file, size_stats)
md = fullfile(run_dir, 'PRECHECK_TEST.md');
fid = fopen(md, 'w');
if fid < 0
    error('Cannot write precheck md: %s', md);
end

fprintf(fid, '# try1 preflight test report\n\n');
fprintf(fid, '- run name: `%s`\n', cfg.run_name);
fprintf(fid, '- seeds tested: `%s`\n', mat2str(cfg.seeds));
fprintf(fid, '- dt tested: `%s` h\n', mat2str(cfg.dt_list));
fprintf(fid, '- sample mode: `%s`, first_n=%d\n', cfg.sample_mode, cfg.first_n);
fprintf(fid, '- detected cores: `%d`\n', run_out.n_cpu);
fprintf(fid, '- target workers (90%%): `%d`\n', run_out.target_workers);
fprintf(fid, '- actual parallel used: `%d`, workers=%d\n\n', run_out.pool_used, run_out.n_workers);

fprintf(fid, '## Simulation status\n\n');
fprintf(fid, '- total rows: `%d`\n', height(manifest_tbl));
fprintf(fid, '- success rows: `%d`\n', sum(manifest_tbl.OK));
fprintf(fid, '- failed rows: `%d`\n\n', sum(~manifest_tbl.OK));

if ~isempty(summary_tbl)
    fprintf(fid, '| seed | dt(h) | n | ok_rate | mean_sec | median Jcost | median Jsupp | median Jvar |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary_tbl)
        fprintf(fid, '| %d | %.2f | %d | %.4f | %.4f | %.10g | %.10g | %.10g |\n', ...
            summary_tbl.Seed(i), summary_tbl.ActionDt_hr(i), summary_tbl.NSamples(i), ...
            summary_tbl.OKRate(i), summary_tbl.MeanSimSec(i), ...
            summary_tbl.MedianJcost(i), summary_tbl.MedianJsupp(i), summary_tbl.MedianJvar(i));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## Reconstruction check\n\n');
fprintf(fid, '- case used: `%s`\n', case_file);
fprintf(fid, '- abs(Jcost diff): `%.6e`\n', recon_out.compare.abs_Jcost);
fprintf(fid, '- abs(Jsupp diff): `%.6e`\n', recon_out.compare.abs_Jsupp);
fprintf(fid, '- abs(Jvar diff): `%.6e`\n', recon_out.compare.abs_Jvar);
fprintf(fid, '- max |mean(m_cc) diff|: `%.6e`\n', recon_out.compare.max_abs_mean_m_cc);
fprintf(fid, '- reconstruction uses saved system-state bundle only (no second simulation).\n\n');

fprintf(fid, '## Storage estimate\n\n');
fprintf(fid, '- tested cases bytes: `%d`\n', size_stats.tested_total_bytes);
fprintf(fid, '- average bytes per case: `%.1f`\n', size_stats.avg_case_bytes);
fprintf(fid, '- estimated bytes for selected full set (current seed/dt with all samples): `%.0f`\n', size_stats.estimated_selected_full_bytes);
fprintf(fid, '- estimated bytes for all try1 samples (6900): `%.0f`\n', size_stats.estimated_all_try1_bytes);
fprintf(fid, '- estimated all-try1 size (GB): `%.3f`\n\n', size_stats.estimated_all_try1_gb);

fprintf(fid, '## Files\n\n');
fprintf(fid, '- `manifest.csv`\n');
fprintf(fid, '- `summary_by_dataset.csv`\n');
fprintf(fid, '- `RUN_SUMMARY.md`\n');
fprintf(fid, '- `PRECHECK_TEST.md`\n');
fprintf(fid, '- `plotonlyfortest.png`\n');
fprintf(fid, '- `reconstruct_first_case_from_saved.mat`\n');
fprintf(fid, '- `cases/seed_*/dataset_dt_*/sample_*.mat`\n');
fprintf(fid, '- `cases` folders are organized as seed -> dt -> sample id for direct lookup\n');

fclose(fid);

fprintf('plotonlyfortest: %s\n', plot_file);
end

function st = estimate_storage_from_manifest_min(manifest_tbl, cfg)
case_files = string(manifest_tbl.CaseFile);
case_files = case_files(strlength(case_files) > 0);

bytes = zeros(numel(case_files), 1);
for i = 1:numel(case_files)
    info = dir(case_files(i));
    if ~isempty(info)
        bytes(i) = info(1).bytes;
    end
end

tested_total = sum(bytes);
avg_case = mean(bytes(bytes > 0));
if isempty(avg_case) || ~isfinite(avg_case)
    avg_case = 0;
end

idx_tbl = readtable(cfg.dataset_index_file);

sel_seed = ismember(idx_tbl.Seed, cfg.seeds);
sel_dt = false(height(idx_tbl), 1);
for i = 1:numel(cfg.dt_list)
    sel_dt = sel_dt | abs(idx_tbl.ActionDt_hr - cfg.dt_list(i)) < 1e-9;
end

n_selected_full = sum(idx_tbl.NSamples(sel_seed & sel_dt));
n_all_try1 = sum(idx_tbl.NSamples);

st = struct();
st.tested_total_bytes = tested_total;
st.avg_case_bytes = avg_case;
st.estimated_selected_full_bytes = avg_case * n_selected_full;
st.estimated_all_try1_bytes = avg_case * n_all_try1;
st.estimated_all_try1_gb = st.estimated_all_try1_bytes / 1024 / 1024 / 1024;
end
