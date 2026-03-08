# PI-SHAP Benchmark Collection

This repository currently contains two benchmark systems with reproducible
simulation, DOE, single-objective optimization, multi-objective scheduling,
and SHAP-based policy analysis workflows.

## 1) System A: Gas Pipeline Case (`benchmark_pepeline5C`)

Focus:

- DOE + transient simulation support chain
- Single-objective branch (`Jcost`) comparison
- Multi-objective branch comparison (`WCost` / `WSupply`)
- PI-SHAP / Ori-SHAP / Cond-SHAP style method outputs and reviewer-ready tables

Main entry docs:

- `benchmark_pepeline5C/PROJECT_SUMMARY_EN.md`
- `benchmark_pepeline5C/PROJECT_SUMMARY_CN.md`
- `benchmark_pepeline5C/reproduction_guidance.md`

Example figures:

![Gas single-objective metric](benchmark_pepeline5C/release/figures/perf3_top1/perf3_top1__fig1b_metric_jcost_s020_baseline.png)

![Gas multi-objective Pareto](benchmark_pepeline5C/release/figures/perf3_top1/perf3_top1__fig4_multi_pareto_s020_baseline.png)

## 2) System B: HVAC 2-Zone Case (`benchmark_hvac2zone_seqtree`)

Focus:

- Public-friendly multivariable time-series benchmark
- Two-zone thermal simulation with coupled dynamics
- DOE scenarios for weather/occupancy/price
- Single-objective planning and multi-objective Pareto planning
- Train/test SHAP study with same planning granularity and sampling:
  - Ori-SHAP
  - Cond-SHAP
  - PI-SHAP
- Correlation against objective metric and schedule-selection comparison

Run:

```matlab
run_benchmark_hvac2zone_seqtree
```

Main outputs:

- `benchmark_hvac2zone_seqtree/outputs/tables/single_objective_comparison.csv`
- `benchmark_hvac2zone_seqtree/outputs/tables/multi_objective_selected_plans.csv`
- `benchmark_hvac2zone_seqtree/outputs/tables/shap_correlation_single.csv`
- `benchmark_hvac2zone_seqtree/outputs/tables/shap_correlation_multi.csv`
- `benchmark_hvac2zone_seqtree/outputs/tables/shap_schedule_compare_single.csv`
- `benchmark_hvac2zone_seqtree/outputs/tables/shap_schedule_compare_multi.csv`
- `benchmark_hvac2zone_seqtree/outputs/SUMMARY.md`

Example figures:

![HVAC multi-objective Pareto](benchmark_hvac2zone_seqtree/outputs/figures/figure_03_multi_objective_pareto.png)

![HVAC SHAP correlations](benchmark_hvac2zone_seqtree/outputs/figures/figure_05_shap_correlations.png)

## Quick Notes

- Both systems are organized to keep code, figures, and tables together.
- Both systems include objective-level comparison outputs that show different
  planning strategies producing different outcomes.
