# HVAC 2-Zone Sequential Planning Benchmark

This benchmark is a modular, readable multivariable time-series case for:

- thermal simulation,
- DOE scenario generation,
- single-objective optimization,
- multi-objective optimization,
- SHAP-based schedule ranking.

---

## 1) Mathematical definition

### 1.1 Variables

- States: $T_{1,t}, T_{2,t}$
- Controls: $u_{1,t},u_{2,t}$
- Disturbances: $T_{\mathrm{out},t}$, solar $S_t$, occupancy $\mathrm{Occ}_{z,t}$,
  and price $\mathrm{Price}_t$

Time setting:

$$
t=0,\dots,23,\quad \Delta t=1\,\mathrm{h}.
$$

Planning granularity:

- 4 blocks,
- 6 hours per block,
- 4 action levels per block-zone variable,
- total candidates: $4^8=65536$.

### 1.2 Dynamics

$$
T_{1,t+1}=T_{1,t}+\Delta t\Big[k_{\mathrm{out},1}(T_{\mathrm{out},t}-T_{1,t})
+k_{\mathrm{cross}}(T_{2,t}-T_{1,t})
+k_{\mathrm{solar},1}S_t
+k_{\mathrm{occ},1}\,\mathrm{Occ}_{1,t}
-k_{\mathrm{cool},1}u_{1,t}\Big]
$$

$$
T_{2,t+1}=T_{2,t}+\Delta t\Big[k_{\mathrm{out},2}(T_{\mathrm{out},t}-T_{2,t})
+k_{\mathrm{cross}}(T_{1,t}-T_{2,t})
+k_{\mathrm{solar},2}S_t
+k_{\mathrm{occ},2}\,\mathrm{Occ}_{2,t}
-k_{\mathrm{cool},2}u_{2,t}\Big]
$$

### 1.3 Constraints and boundaries

$$
0\le u_{z,t}\le 1,\qquad z\in\{1,2\}
$$

$$
T_{\min}\le T_{z,t}\le T_{\max}
$$

Comfort band (soft-constrained through objective penalties):

$$
|T_{z,t}-T_{\mathrm{set}}|\le \delta.
$$

---

## 2) Optimization formulations

### 2.1 Single-objective problem

Power and cost:

$$
P_{z,t}=P_z^{\max}u_{z,t},\qquad
J_{\mathrm{cost}}=\sum_t \mathrm{Price}_t\,(P_{1,t}+P_{2,t})\,\Delta t
$$

Comfort exceedance:

$$
J_{\mathrm{disc}}=\sum_t\sum_{z\in\{1,2\}}
\max(0,|T_{z,t}-T_{\mathrm{set}}|-\delta)^2 + w_T\phi_T
$$

Smoothness:

$$
J_{\mathrm{smooth}}=\sum_t\lVert u_t-u_{t-1}\rVert_2^2
$$

Single objective:

$$
\min_u J_{\mathrm{single}} = J_{\mathrm{cost}} + w_dJ_{\mathrm{disc}} + w_sJ_{\mathrm{smooth}}.
$$

### 2.2 Multi-objective problem

$$
\min_u \big[J_{\mathrm{cost}}(u),\,J_{\mathrm{disc}}(u)\big].
$$

Pareto points are extracted from the evaluated candidate pool.

---

## 3) SHAP evaluation protocol

Methods compared under identical data split and granularity:

- Ori-SHAP
- Cond-SHAP
- PI-SHAP

Reported metrics:

- correlation with negative objective (Spearman/Pearson),
- Top1 regret,
- Top5 regret,
- multi-split fairness summary.

Additional fairness split study uses multiple random seeds and reports both:

- Top1-priority ranking,
- composite ranking (Top1 + Top5 + correlation).

---

## 4) Modular code layout

- `run_benchmark_hvac2zone_seqtree.m`: global orchestrator
- `src/hvac_default_cfg.m`: parameters and experiment config
- `src/hvac_setup_io.m`: output folder management
- `src/hvac_build_scenarios.m`: base day + DOE
- `src/hvac_run_planning.m`: simulation/planning modules
- `src/hvac_run_shap.m`: SHAP and fairness modules
- `src/hvac_write_summary.m`: summary writer

---

## 5) Run commands

MATLAB:

```matlab
run_benchmark_hvac2zone_seqtree
```

Headless/OpenGL-safe CLI run:

```bash
MATLAB_DISABLE_HARDWARE_OPENGL=1 matlab -batch "run_benchmark_hvac2zone_seqtree"
```

---

## 6) Key outputs

Tables:

- `outputs/tables/single_objective_comparison.csv`
- `outputs/tables/multi_objective_selected_plans.csv`
- `outputs/tables/shap_correlation_single.csv`
- `outputs/tables/shap_correlation_multi.csv`
- `outputs/tables/shap_schedule_compare_single.csv`
- `outputs/tables/shap_schedule_compare_multi.csv`
- `outputs/tables/shap_fairness_experiments_summary.csv`
- `outputs/tables/shap_conclusion_summary.csv`

Figures:

- `outputs/figures/figure_03_multi_objective_pareto.png`
- `outputs/figures/figure_05_shap_correlations.png`
- `outputs/figures/figure_06_shap_schedule_compare_single.png`
- `outputs/figures/figure_07_shap_schedule_compare_multi.png`
- `outputs/figures/figure_09_shap_fairness_summary.png`

Auto summary:

- `outputs/SUMMARY.md`
