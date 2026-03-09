# Repository Integrity Check

This checklist verifies that the repository contains both benchmark systems,
their runnable entry points, and reproducible outputs.

## 1) Top-level structure

- [x] `README.md`
- [x] `benchmark_pepeline5C/`
- [x] `benchmark_hvac2zone_seqtree/`

## 2) Gas benchmark presence

- [x] `benchmark_pepeline5C/README.md`
- [x] `benchmark_pepeline5C/reproduction_guidance.md`
- [x] `benchmark_pepeline5C/code/`
- [x] `benchmark_pepeline5C/modules/`
- [x] `benchmark_pepeline5C/release/`

## 3) HVAC benchmark code modules

- [x] `benchmark_hvac2zone_seqtree/run_benchmark_hvac2zone_seqtree.m`
- [x] `benchmark_hvac2zone_seqtree/src/hvac_default_cfg.m`
- [x] `benchmark_hvac2zone_seqtree/src/hvac_setup_io.m`
- [x] `benchmark_hvac2zone_seqtree/src/hvac_build_scenarios.m`
- [x] `benchmark_hvac2zone_seqtree/src/hvac_run_planning.m`
- [x] `benchmark_hvac2zone_seqtree/src/hvac_run_shap.m`
- [x] `benchmark_hvac2zone_seqtree/src/hvac_write_summary.m`

## 4) HVAC benchmark outputs

- [x] `benchmark_hvac2zone_seqtree/outputs/tables/single_objective_comparison.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/multi_objective_selected_plans.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/shap_correlation_single.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/shap_correlation_multi.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/shap_schedule_compare_single.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/shap_schedule_compare_multi.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/shap_fairness_experiments_summary.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/tables/shap_conclusion_summary.csv`
- [x] `benchmark_hvac2zone_seqtree/outputs/figures/figure_09_shap_fairness_summary.png`
- [x] `benchmark_hvac2zone_seqtree/outputs/SUMMARY.md`

## 5) Notes

- The repository is complete for both benchmark tracks and includes generated
  tables/figures for immediate inspection.
- MATLAB may show an exit-time graphics crash in this environment, but outputs
  are fully written before exit (validated by file checks above).
