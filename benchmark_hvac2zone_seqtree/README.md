# HVAC 2-Zone MIMO Benchmark

This benchmark is a public-friendly multivariable time-series case for
simulation + DOE + single-objective optimization + multi-objective planning.

## Problem setting

- System: two thermal zones in one building
- Controls: two cooling commands (`u_zone1`, `u_zone2`) in `[0, 1]`
- Horizon: 24 hours (`dt = 1 h`)
- Disturbances: outdoor temperature, solar gain, occupancy, time-of-use price
- Dynamics: coupled first-order thermal model with heat gains and cooling removal

## What is reproduced

1. DOE generation of weather/occupancy/price scenarios
2. Single-objective planning (`cost + comfort penalty + smoothness`)
3. Multi-objective trade-off front (`cost` vs `discomfort`)
4. Robustness check of selected plans across DOE scenarios
5. SHAP train/test study with the same planning granularity and sampling setup:
   - Ori-SHAP
   - Cond-SHAP
   - PI-SHAP
   - Correlation against objective metrics and schedule-selection comparison

## Run

```matlab
run_benchmark_hvac2zone_seqtree
```

## Main outputs

Generated under `outputs/`:

- `tables/doe_scenarios.csv`
- `tables/candidate_metrics.csv`
- `tables/single_objective_comparison.csv`
- `tables/multi_objective_pareto_points.csv`
- `tables/multi_objective_selected_plans.csv`
- `tables/robustness_long.csv`
- `tables/robustness_summary.csv`
- `tables/planning_schedule_blocks.csv`
- `figures/figure_01_scenario_profiles.png`
- `figures/figure_02_single_objective_trajectories.png`
- `figures/figure_03_multi_objective_pareto.png`
- `figures/figure_04_doe_robustness.png`
- `tables/shap_model_fit_summary.csv`
- `tables/shap_correlation_single.csv`
- `tables/shap_correlation_multi.csv`
- `tables/shap_schedule_compare_single.csv`
- `tables/shap_schedule_compare_multi.csv`
- `tables/shap_feature_importance_single.csv`
- `tables/shap_feature_importance_multi.csv`
- `figures/figure_05_shap_correlations.png`
- `figures/figure_06_shap_schedule_compare_single.png`
- `figures/figure_07_shap_schedule_compare_multi.png`
- `figures/figure_08_shap_feature_importance.png`
- `SUMMARY.md`
