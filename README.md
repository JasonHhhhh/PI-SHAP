# PI-SHAP Benchmark Repository

This repository contains two reproducible, time-series optimization benchmarks:

1. `benchmark_pepeline5C` (gas-network control case from the PI-SHAP pipeline)
2. `benchmark_hvac2zone_seqtree` (public-friendly two-zone HVAC case)

Both benchmarks include simulation, DOE, single-objective planning, multi-objective
planning, and SHAP-based scheduling analysis.

---

## Repository completeness check

Current top-level contents:

- `benchmark_pepeline5C/`
- `benchmark_hvac2zone_seqtree/`
- `README.md`
- `.gitignore`

Core run entry for case B:

- `benchmark_hvac2zone_seqtree/run_benchmark_hvac2zone_seqtree.m`

Core run/reproduction entry for case A:

- `benchmark_pepeline5C/reproduction_guidance.md`

Note: the gas case intentionally excludes one oversized binary (`>100MB`) via
`.gitignore` for GitHub compatibility.

---

## System A: Gas Pipeline Case (`benchmark_pepeline5C`)

### A.1 Mathematical formulation (single objective)

Let `x_t` be transient gas-network state, `u_t` control actions (compressor and
operational policy variables), and `d_t` disturbances/boundary demand.

Discrete-time dynamics (compact form):

`g(x_{t+1}, x_t, u_t, d_t) = 0,   t = 0, ..., T-1`

Single-objective optimization (cost branch):

`min_u J_cost(u) = sum_{t=0}^{T-1} c_t * E_t(u_t, x_t)`

Subject to physical and operational constraints:

- Nodal balance: `A*q_t + s_t - d_t = 0`
- Pressure bounds: `p_min <= p_{i,t} <= p_max`
- Flow bounds: `q_min <= q_{ij,t} <= q_max`
- Control bounds/ramp: `u_min <= u_t <= u_max`, `|u_t-u_{t-1}| <= Delta_u_max`
- Initial and terminal consistency: `x_0 = x_init`, terminal feasibility constraints.

### A.2 Mathematical formulation (multi objective)

Two-objective representation:

`min_u [ J_cost(u), J_supply(u) ]`

with weight-sweep scalarization used in reviewer pipelines:

`min_u J_w(u) = WCost * J_cost(u) + WSupply * J_supply(u)`

where `(WCost, WSupply)` are scanned to produce Pareto candidates and compute
front-quality metrics (HV, IGD, epsilon-type distances).

### A.3 Main code/doc entry points

- Reproduction guide: `benchmark_pepeline5C/reproduction_guidance.md`
- Curated single-objective tables:
  - `benchmark_pepeline5C/modules/performance3/curated/single_objective_cost/tables/`
- Curated multi-objective tables:
  - `benchmark_pepeline5C/modules/performance3/curated/multi_objective_cost_var/tables/`

### A.4 Example figures

![Gas single-objective metric](benchmark_pepeline5C/release/figures/perf3_top1/perf3_top1__fig1b_metric_jcost_s020_baseline.png)

![Gas multi-objective Pareto](benchmark_pepeline5C/release/figures/perf3_top1/perf3_top1__fig4_multi_pareto_s020_baseline.png)

---

## System B: HVAC 2-Zone Case (`benchmark_hvac2zone_seqtree`)

### B.1 State/control/disturbance definition

- States: indoor temperatures `T1_t`, `T2_t`
- Controls: cooling command `u1_t`, `u2_t`, each bounded in `[0,1]`
- Disturbances: outdoor temperature `Tout_t`, solar `S_t`, occupancy `Occ1_t, Occ2_t`, price `Price_t`
- Time grid: `dt = 1 h`, horizon `T = 24 h`
- Planning granularity: 4 control blocks x 6 hours (same granularity used in SHAP scheduling)

### B.2 Dynamic equations

For each hour `t`:

`T1_{t+1} = T1_t + dt * [ k_out1*(Tout_t - T1_t) + k_cross*(T2_t - T1_t) + k_solar1*S_t + k_occ1*Occ1_t - k_cool1*u1_t ]`

`T2_{t+1} = T2_t + dt * [ k_out2*(Tout_t - T2_t) + k_cross*(T1_t - T2_t) + k_solar2*S_t + k_occ2*Occ2_t - k_cool2*u2_t ]`

Boundary and box constraints:

- `0 <= u1_t, u2_t <= 1`
- `T_floor <= Tz_t <= T_ceil` (used as model bounds)
- Comfort band around setpoint: `|Tz_t - T_set| <= deadband` (soft-constrained via penalty)

### B.3 Single-objective optimization

Daily energy cost:

`J_cost = sum_t Price_t * (P1_t + P2_t) * dt`, with `Pz_t = Pz_max * uz_t`

Comfort penalty:

`J_disc = sum_t sum_{z in {1,2}} max(0, |Tz_t - T_set| - deadband)^2 + w_T * terminal_penalty`

Control smoothness:

`J_smooth = sum_t ||u_t - u_{t-1}||_2^2`

Scalar objective:

`min_u J_single = J_cost + w_disc*J_disc + w_smooth*J_smooth`

### B.4 Multi-objective optimization

Bi-objective form:

`min_u [ J_cost(u), J_disc(u) ]`

Pareto set is extracted from the full discrete policy pool. Representative plans:

- Min-cost point
- Knee point
- Min-discomfort point

### B.5 SHAP scheduling evaluation protocol

For each objective (`single`, `multi_balanced`), using same split and same planning
granularity:

- Train/test split over candidate plans
- Fit common surrogate model
- Compute method scores for:
  - Ori-SHAP
  - Cond-SHAP
  - PI-SHAP

Metrics reported:

- Correlation: Spearman/Pearson between SHAP score and `-objective`
- Scheduling quality: top1 and top5 regret
- Multi-split fairness experiment summary

### B.6 Main entry points

- Run: `benchmark_hvac2zone_seqtree/run_benchmark_hvac2zone_seqtree.m`
- Case details: `benchmark_hvac2zone_seqtree/README.md`
- Auto summary: `benchmark_hvac2zone_seqtree/outputs/SUMMARY.md`

### B.7 Example figures

![HVAC multi-objective Pareto](benchmark_hvac2zone_seqtree/outputs/figures/figure_03_multi_objective_pareto.png)

![HVAC SHAP correlations](benchmark_hvac2zone_seqtree/outputs/figures/figure_05_shap_correlations.png)

![HVAC SHAP fairness](benchmark_hvac2zone_seqtree/outputs/figures/figure_09_shap_fairness_summary.png)

---

## How to run

### Case A (gas)

Follow: `benchmark_pepeline5C/reproduction_guidance.md`

### Case B (HVAC)

From MATLAB:

```matlab
run_benchmark_hvac2zone_seqtree
```

Outputs are written to:

- `benchmark_hvac2zone_seqtree/outputs/tables/`
- `benchmark_hvac2zone_seqtree/outputs/figures/`
- `benchmark_hvac2zone_seqtree/outputs/SUMMARY.md`
