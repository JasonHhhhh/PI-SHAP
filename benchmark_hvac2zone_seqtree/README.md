# HVAC 2-Zone Sequential Planning Benchmark

This case is a readable, public-friendly multivariable time-series benchmark for:

- simulation,
- DOE,
- single-objective scheduling,
- multi-objective scheduling,
- SHAP-based ranking and planning comparison.

It is structured in a modular way so each stage is auditable.

---

## 1) Folder organization

### Main entry

- `run_benchmark_hvac2zone_seqtree.m`
  - Orchestrates all modules in order.

### Code modules (`src/`)

- `src/hvac_default_cfg.m`
  - Problem parameters, weights, and SHAP experiment settings.

- `src/hvac_setup_io.m`
  - Output folder setup (`outputs/figures`, `outputs/tables`).

- `src/hvac_build_scenarios.m`
  - Base scenario and DOE generation.

- `src/hvac_run_planning.m`
  - Full discrete candidate evaluation,
  - single-objective comparison,
  - multi-objective Pareto extraction,
  - robustness evaluation,
  - non-SHAP figures.

- `src/hvac_run_shap.m`
  - SHAP score computation for Ori/Cond/PI variants,
  - correlation and scheduling metrics,
  - multi-split fairness experiments,
  - SHAP figures.

- `src/hvac_write_summary.m`
  - Writes `outputs/SUMMARY.md` from generated tables.

### Outputs (`outputs/`)

- `outputs/tables/`: all numeric experiment tables.
- `outputs/figures/`: all generated figures (`figure_01` ... `figure_09`).
- `outputs/SUMMARY.md`: run summary and SHAP conclusions.
- `outputs/workspace.mat`: saved run workspace.

---

## 2) Mathematical problem definition

### 2.1 States, controls, disturbances

- States: zone temperatures `T1_t`, `T2_t`
- Controls: cooling command `u1_t`, `u2_t`, with `0 <= uz_t <= 1`
- Disturbances: outdoor temperature `Tout_t`, solar `S_t`, occupancy `Occz_t`, electricity price `Price_t`
- Horizon: `T=24` with `dt=1 h`

### 2.2 Dynamics

`T1_{t+1} = T1_t + dt * [ k_out1*(Tout_t - T1_t) + k_cross*(T2_t - T1_t) + k_solar1*S_t + k_occ1*Occ1_t - k_cool1*u1_t ]`

`T2_{t+1} = T2_t + dt * [ k_out2*(Tout_t - T2_t) + k_cross*(T1_t - T2_t) + k_solar2*S_t + k_occ2*Occ2_t - k_cool2*u2_t ]`

State bounds:

`T_floor <= Tz_t <= T_ceil`

### 2.3 Single-objective scheduling

Energy cost:

`J_cost = sum_t Price_t * (P1_t + P2_t) * dt`

where `Pz_t = Pz_max * uz_t`.

Comfort penalty:

`J_disc = sum_t sum_z max(0, |Tz_t - T_set| - deadband)^2 + w_terminal*terminal_penalty`

Smoothness penalty:

`J_smooth = sum_t ||u_t - u_{t-1}||_2^2`

Optimization:

`min_u J_single = J_cost + w_disc*J_disc + w_smooth*J_smooth`

### 2.4 Multi-objective scheduling

`min_u [ J_cost(u), J_disc(u) ]`

Pareto front is extracted from the discrete pool and representative plans are selected:

- minimum cost,
- knee point,
- minimum discomfort.

### 2.5 Planning granularity and constraints

Decision variables are blockwise constant controls:

- 4 blocks,
- 6 hours per block,
- 4 action levels per block-zone variable,
- 8 decision variables total (2 zones x 4 blocks),
- `4^8 = 65536` candidates.

This exact granularity is reused in SHAP scheduling experiments to keep fairness.

---

## 3) SHAP evaluation setup

Methods:

- Ori-SHAP
- Cond-SHAP
- PI-SHAP

For each objective (single and multi-balanced):

1. fit a common surrogate on train split,
2. compute SHAP-style scores on test split,
3. evaluate:
   - Spearman/Pearson with `-objective`,
   - top1 regret,
   - top5 regret.

Additional fairness study:

- multiple random train/test splits,
- identical sample counts per method,
- summary by mean/std of regrets and correlations.

---

## 4) Run

```matlab
run_benchmark_hvac2zone_seqtree
```

If your environment has OpenGL instability in headless mode, run with software OpenGL:

```bash
MATLAB_DISABLE_HARDWARE_OPENGL=1 matlab -batch "run_benchmark_hvac2zone_seqtree"
```

---

## 5) Key result files

### Planning

- `outputs/tables/single_objective_comparison.csv`
- `outputs/tables/multi_objective_selected_plans.csv`
- `outputs/tables/robustness_summary.csv`

### SHAP

- `outputs/tables/shap_correlation_single.csv`
- `outputs/tables/shap_correlation_multi.csv`
- `outputs/tables/shap_schedule_compare_single.csv`
- `outputs/tables/shap_schedule_compare_multi.csv`
- `outputs/tables/shap_fairness_experiments_summary.csv`
- `outputs/tables/shap_conclusion_summary.csv`

### Figures

- `outputs/figures/figure_03_multi_objective_pareto.png`
- `outputs/figures/figure_05_shap_correlations.png`
- `outputs/figures/figure_06_shap_schedule_compare_single.png`
- `outputs/figures/figure_07_shap_schedule_compare_multi.png`
- `outputs/figures/figure_09_shap_fairness_summary.png`

---

## 6) What to read first

1. `outputs/SUMMARY.md`
2. `outputs/tables/shap_conclusion_summary.csv`
3. `outputs/tables/shap_fairness_experiments_summary.csv`
4. `outputs/figures/figure_05_shap_correlations.png`
5. `outputs/figures/figure_09_shap_fairness_summary.png`
