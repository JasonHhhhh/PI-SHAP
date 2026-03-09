function out = run_benchmark_hvac2zone_seqtree()
root_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(root_dir, 'src'));

cfg = hvac_default_cfg();
dirs = hvac_setup_io(root_dir);

fprintf('\n[HVAC-2Zone] 1/6 scenario + DOE module...\n');
[base, doe_tbl, doe_scenarios] = hvac_build_scenarios(cfg, dirs);

fprintf('[HVAC-2Zone] 2/6 simulation + planning module...\n');
planning = hvac_run_planning(cfg, base, doe_scenarios, dirs);

fprintf('[HVAC-2Zone] 3/6 SHAP module (single + multi)...\n');
shap_out = hvac_run_shap(cfg, planning, dirs);

fprintf('[HVAC-2Zone] 4/6 summary writing...\n');
summary_file = fullfile(dirs.output_dir, 'SUMMARY.md');
hvac_write_summary(summary_file, cfg, planning, shap_out);

fprintf('[HVAC-2Zone] 5/6 save workspace...\n');
save(fullfile(dirs.output_dir, 'workspace.mat'), ...
    'cfg', 'base', 'doe_tbl', 'doe_scenarios', 'planning', 'shap_out', '-v7.3');

fprintf('[HVAC-2Zone] 6/6 done.\n');

out = struct();
out.root_dir = root_dir;
out.output_dir = dirs.output_dir;
out.table_dir = dirs.table_dir;
out.figure_dir = dirs.figure_dir;
out.summary_file = summary_file;
out.single_table = fullfile(dirs.table_dir, 'single_objective_comparison.csv');
out.multi_table = fullfile(dirs.table_dir, 'multi_objective_selected_plans.csv');
out.robust_table = fullfile(dirs.table_dir, 'robustness_summary.csv');
out.shap_single_table = fullfile(dirs.table_dir, 'shap_schedule_compare_single.csv');
out.shap_multi_table = fullfile(dirs.table_dir, 'shap_schedule_compare_multi.csv');

fprintf('HVAC 2-zone benchmark done: %s\n', summary_file);
end
