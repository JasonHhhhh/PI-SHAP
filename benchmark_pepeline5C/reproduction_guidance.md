# benchmark_pepeline5C Reproduction Guidance

## 1) Reproduction Scope

This package is organized to reproduce and audit one core claim family:

1. **Single-objective scenario (`Jcost`)**: PI-SHAP-based policy selection vs optimization baselines.
2. **Multi-objective scenario (`WCost`/`WSupply` weight sweep)**: PI-SHAP vs Ori-SHAP vs Cond-SHAP on Pareto quality metrics.

The most important result files are:

- `modules/performance3/curated/single_objective_cost/tables/single_cost_table_top1_s020_baseline.csv`
- `modules/performance3/curated/multi_objective_cost_var/tables/multi_branch_table_top1_s020_baseline.csv`
- `modules/performance3/curated/multi_objective_cost_var/tables/multi_branch_table_summary.csv`

Method/object reference mapping for this guide is listed in:

- `../REFERENCES.md`

## 1.1 Mathematical objective expressions

Single-objective branch:

$$
\min_u J_{\mathrm{cost}}(u)=\sum_{t=0}^{T-1} c_tE_t(u_t,x_t)
$$

Multi-objective branch:

$$
\min_u\big[J_{\mathrm{cost}}(u),J_{\mathrm{supply}}(u)\big]
$$

Weight-sweep scalarization used for reviewer outputs:

$$
\min_u J_w(u)=W_{\mathrm{Cost}}J_{\mathrm{cost}}(u)+W_{\mathrm{Supply}}J_{\mathrm{supply}}(u).
$$

## 1.2 Dynamic constraints and boundaries (compact form)

The transient network model is represented as a constrained evolution system:

$$
g(x_{t+1},x_t,u_t,d_t)=0,\qquad t=0,\dots,T-1.
$$

with core feasibility constraints:

$$
Aq_t+s_t-d_t=0
$$

$$
p_{\min}\le p_{i,t}\le p_{\max},\qquad q_{\min}\le q_{ij,t}\le q_{\max}
$$

$$
u_{\min}\le u_t\le u_{\max},\qquad \lVert u_t-u_{t-1}\rVert_\infty\le \Delta u_{\max}
$$

$$
x_0=x_{\mathrm{init}},\qquad x_T\in\mathcal X_{\mathrm{terminal}}.
$$

## 1.3 SHAP score-quality metrics used in this package

For each SHAP method score $s_i$ and objective value $J_i$ on evaluation set:

$$
\rho_s=\mathrm{corr}_{\mathrm{Spearman}}(s,-J),\qquad
\rho_p=\mathrm{corr}_{\mathrm{Pearson}}(s,-J)
$$

Top-$k$ regret convention:

$$
\mathrm{Regret}_{\mathrm{Top}k}(\%)=\left(\frac{\min_{i\in\mathrm{Top}k}J_i}{\min_i J_i}-1\right)\times 100.
$$

## 2) Project Layout and Folder Responsibilities

### Root-level files and folders

- `setup_paths_benchmark_pepeline5C.m`
  - Adds `code/` and `modules/` recursively to MATLAB path.
  - First command to run in any MATLAB session.

- `smoke_check_benchmark_pepeline5C.m`
  - Structural integrity check (required files/directories exist).
  - Quick pass/fail gate before running heavy scripts.

- `code/`
  - Core simulation libraries and minimal wrappers.

- `modules/`
  - Experimental workflows (DOE, simulation studies, SHAP-vs-NN, PI-SHAP performance comparisons).

- `release/`
  - Publication-facing, renamed figure/table views.

- `docs/`
  - Mapping/audit CSV files for provenance and traceability.

- `tools/`
  - Packaging utilities (refreshing release views, path sanitization).

## 3) Detailed Folder-by-Folder Functional Map

### 3.1 `code/`

#### `code/core_sim/src/`

Low-level gas-network model and solver components used by simulation and optimization workflows, including:

- Model readers/reconstruction (`gas_model_reader_*`, `gas_model_reconstruct_new*`)
- Economic/model specs (`econ_spec.m`, `model_spec.m`)
- Transient/static routines (`tran_opt_base.m`, `tran_sim_base.m`, `static_opt_base.m`)
- Constraint/Jacobian/objective kernels (`pipe_constraints_*`, `pipe_jacobian_*`, `pipe_obj_*`)

#### `code/core_sim/shap_src/`

SHAP-coupled transient processing and helper scripts, including:

- `tran_sim_base_flat_noextd.m`
- `tran_sim_setup_0.m`
- `process_output_tr_nofd_sim.m`

#### `code/shap_src_min_core/`

Minimal wrappers/utilities used across modules:

- `load_ss_reference_min.m`: unified steady-state boundary anchors
- `simulate_policy_min.m`: reusable policy simulation entry
- `score_policy_tree_min.m`: rule-score helper
- `tran_sim_setup_0_min.m`: lightweight setup adapter

### 3.2 `modules/doe/`

DOE generation and DOE-to-simulation bridge.

- `run_doe_try1_generate_actions_min.m`
  - Generates action trajectories (`cc_policy`) for seeds and `dt` list.
  - Writes dataset-level metadata and summary curves.

- `try1/run_doe_try1_sim_batch_min.m`
  - Batch transient simulation driver for selected DOE actions.
  - Writes:
    - `manifest.csv`
    - `summary_by_dataset.csv`
    - per-case payload files under `cases/...` when available

- `try1/sim_outputs/full_all_samples_90pct/`
  - Packaged metadata snapshot (`manifest.csv`, `summary_by_dataset.csv`, `run_config.mat`, `run_output.mat`).

### 3.3 `modules/sim/`

System simulation studies and numerical convergence analysis.

Key scripts:

- `run_tr_sim_grid_independence_min.m`
  - Internal time/space grid sweep (`solsteps`, `lmax`) on a fixed policy.
  - Outputs run summaries, curve errors, heatmaps, and sweep plots.

- `run_grid_residual_field_study_min.m`
  - Residual field diagnostics for simulation grid studies.

- `run_tr_opt_granularity_min.m`, `run_tr_opt_granularity_singleobj_min.m`
  - Control/simulation granularity experiments.

- `run_ss_opt_stage_min.m`, `run_ss_opt_history_compare_min.m`
  - Steady-state plan/stage-level baselines for comparison.

### 3.4 `modules/shap_vs_nn/`

NN surrogate training and SHAP method comparison.

- `scripts/export_seed11_dt1_dataset_min.m`
  - Builds NN-ready dataset from DOE/simulation records.

- `scripts/run_seed11_dt1_light_min.m`
  - Lightweight baseline surrogate run.

- `scripts/run_seed11_dt1_light_plus_min.m`
  - Main surrogate pipeline:
    - scalar target models
    - curve models (PCA + NN coefficients)
    - SHAP interventional/conditional maps
    - case-level evaluation outputs

Main output folders:

- `modules/shap_vs_nn/data/`
- `modules/shap_vs_nn/models/`
- `modules/shap_vs_nn/plots/`
- `modules/shap_vs_nn/reports/`

### 3.5 `modules/performance_shared/`

Common implementation used by performance3 wrappers.

- `run_performance_compare_top1_min.m`
  - Core holdout scoring engine:
    - load/compute maps
    - train sequential rule trees
    - blend and calibrate scores
    - produce case score tables and correlation tables

- `run_reviewer_single_multi_min.m`
  - Reviewer-style postprocessing:
    - single-objective action + metric plots
    - multi-objective weight sweep candidate selection
    - Pareto metrics (`HVRelToRef`, `IGD`, `EpsilonAdd`, etc.)

### 3.6 `modules/performance3/`

Main branch for this package’s core reproduction target.

#### `modules/performance3/scripts/`

- `run_performance_compare_top1_perf3_min.m`
  - Performance3 wrapper calling shared top1 compare engine.

- `run_reviewer_single_multi_perf3_min.m`
  - One-stop script for single + multi reviewer outputs.

- `run_rule_learner_baseline_compare_perf3_min.m`
  - Learner benchmark (`CART_Gini`, `CART_Entropy`, `RF_Bag`, `AdaBoost_Stump`).

- `run_s_sweep_seedsplit_perf3_min.m`
  - Sweeps tree split budget `S` with fixed seed split.

- `run_s20_fast_refine_perf3_min.m`
  - Fast local variant refinement around `S=20`.

#### `modules/performance3/curated/`

Release-ready subsets aligned to the two main storyline branches.

- `curated/single_objective_cost/`
  - Figures:
    - `single_cost_action_top1_s020_baseline.png/.svg`
    - `single_cost_metric_top1_s020_baseline.png/.svg`
  - Tables:
    - `single_cost_table_top1_s020_baseline.csv`
    - `single_cost_table_source_reviewer.csv`
    - `single_cost_table_extended_baselines.csv`
    - `single_cost_table_physical_audit.csv`

- `curated/multi_objective_cost_var/`
  - Figures:
    - `multi_branch_pareto_top1_s020_baseline.png/.svg`
  - Tables:
    - `multi_branch_table_top1_s020_baseline.csv`
    - `multi_branch_table_source_metrics.csv`
    - `multi_branch_table_source_weight_selection.csv`
    - `multi_branch_table_summary.csv`

#### `modules/performance3/source_runs/`

Raw reviewer output snapshots used as provenance links:

- `single_cost_s020_abs_reviewer/`
- `single_cost_s020_fontfix_reviewer/`
- `multi_objective_s020_reviewer/`

Each run contains `plots/` and `tables/` with files such as:

- `single_target_metric_single_jcost.csv`
- `single_plot_summary.csv`
- `multi_weight_selection_shap.csv`
- `multi_weight_topk_candidates.csv`
- `multi_mo_metrics.csv`

#### `modules/performance3/rule_learner_compare/`

Rule-learner comparison results:

- `tables/`: per-learner case scores, top-k eval, complexity, summary
- `plots/`: learner comparison visuals
- `models/`: serialized learner bundles

#### `modules/performance3/method_runs/`

SHAP map cache for accelerated reruns:

- `holdout_shap_maps_cache_seed11_23_37_dt1p0.mat`

#### `modules/performance3/top1_optimality_package/`

Original packaged top1 assets used for cross-checking and source traceability.

### 3.7 `release/`

Auto-generated public-facing views with normalized naming.

- `release/figures/` groups:
  - `doe/`, `sim/`, `shap_vs_nn/`, `rule_compare/`, `perf3_top1/`, `single_cost_action/`, `single_cost_metric/`, `multi_objective/`

- `release/tables/` groups:
  - `doe_tables/`, `sim_convergence_tables/`, `nn_reports_tables/`, `rule_compare_tables/`, `perf3_top1_tables/`, `single_cost_source_tables/`, `multi_objective_source_tables/`

- `release/tables_sanitized/`
  - Same structure as `release/tables/`, but file path fields normalized to `${REPO_ROOT}/...` where applicable.

### 3.8 `docs/`

Audit/provenance maps:

- `SOURCE_IMPORT_MANIFEST.csv`: where each imported block came from
- `FIGURE_RENAME_MAP.csv`: source figure to release figure mapping
- `TABLE_RENAME_MAP.csv`: source table to release table mapping
- `CURATED_RENAME_MAP.csv`: curated branch file renaming map
- `PATH_SANITIZE_REPORT.csv`: per-file sanitize statistics

### 3.9 `tools/`

- `tools/refresh_release_views.py`
  - Rebuilds `release/figures` and `release/tables` from module/source directories.

- `tools/normalize_sample_paths.py`
  - Rebuilds `release/tables_sanitized` by replacing absolute local prefixes with `${REPO_ROOT}/`.

## 4) Script Responsibilities (Operational Quick Index)

| Script | Primary responsibility | Main outputs |
|---|---|---|
| `setup_paths_benchmark_pepeline5C.m` | MATLAB path bootstrap | runtime path state |
| `smoke_check_benchmark_pepeline5C.m` | package integrity check | pass/fail log |
| `modules/doe/run_doe_try1_generate_actions_min.m` | action DOE generation | action datasets + DOE summaries |
| `modules/doe/try1/run_doe_try1_sim_batch_min.m` | DOE transient batch simulation | `manifest.csv`, `summary_by_dataset.csv`, case payloads |
| `modules/sim/run_tr_sim_grid_independence_min.m` | internal grid convergence study | `run_summary.csv`, heatmaps, curve sweeps |
| `modules/shap_vs_nn/scripts/run_seed11_dt1_light_plus_min.m` | NN surrogate + SHAP method study | model files, parity/SHAP plots, report CSV/MD |
| `modules/performance3/scripts/run_performance_compare_top1_perf3_min.m` | top1 score engine wrapper | holdout score/correlation/tree tables |
| `modules/performance3/scripts/run_reviewer_single_multi_perf3_min.m` | single+multi reviewer pipeline | single/multi plots and metric tables |
| `modules/performance3/scripts/run_rule_learner_baseline_compare_perf3_min.m` | learner benchmark | top-k eval, complexity, learner plots |
| `modules/performance3/scripts/run_s_sweep_seedsplit_perf3_min.m` | `S` sweep | sweep summary CSV + trend plot |
| `modules/performance3/scripts/run_s20_fast_refine_perf3_min.m` | local `S=20` refinement | variant summary CSV + report |
| `tools/refresh_release_views.py` | release views refresh | `release/figures`, `release/tables` |
| `tools/normalize_sample_paths.py` | path-sanitized table generation | `release/tables_sanitized` + sanitize report |

## 5) Table Responsibilities (What Each Key Table Means)

### Single-objective (`Jcost`) branch tables

- `single_cost_table_top1_s020_baseline.csv`
  - Canonical comparison table used for single-objective claim.
  - Includes optimization baselines + SHAP variants.

- `single_cost_table_source_reviewer.csv`
  - Direct reviewer-source extraction (trace table).

- `single_cost_table_extended_baselines.csv`
  - Pairwise gain percentages for expanded baseline set.

- `single_cost_table_physical_audit.csv`
  - Physical consistency checks for representative policies.

### Multi-objective branch tables

- `multi_branch_table_top1_s020_baseline.csv`
  - Canonical Pareto metric table (`HVRelToRef`, `IGD`, `EpsilonAdd`, `MeanFrontDist`, `P90FrontDist`).

- `multi_branch_table_source_metrics.csv`
  - Reviewer-source metric trace table.

- `multi_branch_table_source_weight_selection.csv`
  - Weight-sweep selected candidates with objective values.

- `multi_branch_table_summary.csv`
  - Method-wise gain summary and “best among three” flags per metric.

### Reviewer run tables (source_runs)

- `single_target_metric_single_jcost.csv`, `single_target_metric_single_jsupp.csv`, `single_target_metric_single_jvar.csv`
  - Single-objective target-specific evaluations.

- `multi_weight_selection_shap.csv`
  - Selected representative point per method under each weight.

- `multi_weight_topk_candidates.csv`
  - Top-k candidates per weight/method before final representative selection.

- `multi_mo_metrics.csv`
  - Final Pareto metric comparison table used by multi-objective figures.

## 6) Metric Semantics Used in the Main Comparison

- **Single-objective (`Jcost`)**
  - Smaller `TargetMetricFinalAbs` is better.

- **Multi-objective quality**
  - `HVRelToRef`: larger is better.
  - `IGD`: smaller is better.
  - `EpsilonAdd`: smaller is better.
  - `MeanFrontDist`: smaller is better.
  - `P90FrontDist`: smaller is better.

## 7) Reproduction Workflows

### Workflow A: Validate packaged final results (fastest)

From `benchmark_pepeline5C/`:

```bash
matlab -batch "setup_paths_benchmark_pepeline5C; smoke_check_benchmark_pepeline5C;"
python3 tools/refresh_release_views.py
python3 tools/normalize_sample_paths.py
```

Then check the two main claims directly:

```bash
python3 - <<'PY'
import pandas as pd
t = pd.read_csv('modules/performance3/curated/single_objective_cost/tables/single_cost_table_top1_s020_baseline.csv')
print(t[['Method','TargetMetricFinalAbs']].sort_values('TargetMetricFinalAbs').to_string(index=False))
PY
```

```bash
python3 - <<'PY'
import pandas as pd
t = pd.read_csv('modules/performance3/curated/multi_objective_cost_var/tables/multi_branch_table_top1_s020_baseline.csv').set_index('Method')
rules = {'HVRelToRef':'max','IGD':'min','EpsilonAdd':'min','MeanFrontDist':'min','P90FrontDist':'min'}
for k,v in rules.items():
    best = t[k].idxmax() if v=='max' else t[k].idxmin()
    print(f'{k:14s} {v:3s} -> {best}')
PY
```

### Workflow B: Re-run single+multi comparison pipeline from scripts

This workflow executes `run_reviewer_single_multi_perf3_min.m` with explicit paths.

```bash
matlab -batch "setup_paths_benchmark_pepeline5C; \
cfg=struct(); \
cfg.work_dir=fullfile(pwd,'modules','performance3','repro_runs','s020_reviewer'); \
cfg.score_cfg=struct(); \
cfg.score_cfg.repo_dir=pwd; \
cfg.score_cfg.dataset_file=fullfile(pwd,'modules','shap_vs_nn','data','seed11_dt1_nn_light_dataset.mat'); \
cfg.score_cfg.models_file=fullfile(pwd,'modules','shap_vs_nn','models','seed11_dt1_light_plus_models.mat'); \
cfg.score_cfg.case_root='<FULL_CASES_ROOT>'; \
cfg.score_cfg.map_cache_file=fullfile(pwd,'modules','performance3','method_runs','holdout_shap_maps_cache_seed11_23_37_dt1p0.mat'); \
cfg.score_cfg.use_map_cache=true; \
cfg.score_cfg.split_mode='seed'; \
cfg.score_cfg.train_seed_list=11; \
cfg.score_cfg.test_seed_list=[23 37]; \
cfg.score_cfg.eval_seed_list=[11 23 37]; \
cfg.score_cfg.eval_dt_hr=1.0; \
out=run_reviewer_single_multi_perf3_min(cfg); disp(out);"
```

Expected outputs under:

- `modules/performance3/repro_runs/s020_reviewer/reviewer_outputs/tables/`
- `modules/performance3/repro_runs/s020_reviewer/reviewer_outputs/plots/`

### Workflow C: Rule-learner benchmark extension

```bash
matlab -batch "setup_paths_benchmark_pepeline5C; out=run_rule_learner_baseline_compare_perf3_min(); disp(out);"
```

Outputs:

- `modules/performance3/rule_learner_compare/tables/rule_learner_topk_eval.csv`
- `modules/performance3/rule_learner_compare/tables/rule_learner_complexity.csv`
- `modules/performance3/rule_learner_compare/plots/rule_learner_topk_best_regret.png`

## 8) Release View and Provenance Maintenance

After any rerun or file updates:

1. Rebuild release views: `python3 tools/refresh_release_views.py`
2. Rebuild sanitized tables: `python3 tools/normalize_sample_paths.py`
3. Check mapping CSVs in `docs/`:
   - `FIGURE_RENAME_MAP.csv`
   - `TABLE_RENAME_MAP.csv`
   - `CURATED_RENAME_MAP.csv`

## 9) Practical Reading Order (Recommended)

If you want to understand the project quickly and deeply, use this order:

1. `modules/performance3/curated/.../tables/` (final claims)
2. `modules/performance3/scripts/run_reviewer_single_multi_perf3_min.m` (high-level orchestration)
3. `modules/performance_shared/run_performance_compare_top1_min.m` (core scoring logic)
4. `modules/performance_shared/run_reviewer_single_multi_min.m` (single/multi metrics and plotting)
5. `modules/doe/try1/run_doe_try1_sim_batch_min.m` and `modules/sim/run_tr_sim_grid_independence_min.m` (upstream data/simulation context)
