# Mathematical Formulation: benchmark_pepeline5C

This note provides a compact mathematical statement for the gas-network benchmark.

## 1) State evolution and feasibility

Let $x_t$ be the transient state, $u_t$ controls, and $d_t$ disturbances.

$$
g(x_{t+1},x_t,u_t,d_t)=0,\qquad t=0,\dots,T-1.
$$

Core constraints:

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

## 2) Single-objective branch

$$
\min_{u_{0:T-1}} J_{\mathrm{cost}}(u)=\sum_{t=0}^{T-1} c_tE_t(u_t,x_t)
$$

This is the `Jcost` branch in curated single-objective outputs.

## 3) Multi-objective branch

$$
\min_u \big[J_{\mathrm{cost}}(u),\,J_{\mathrm{supply}}(u)\big]
$$

Weight-sweep scalarization:

$$
\min_u J_w(u)=W_{\mathrm{Cost}}J_{\mathrm{cost}}(u)+W_{\mathrm{Supply}}J_{\mathrm{supply}}(u)
$$

used to generate Pareto candidates and reviewer tables.

## 4) Ranking/quality metrics used in SHAP comparisons

For score $s_i$ and objective $J_i$:

$$
\rho_s=\mathrm{corr}_{\mathrm{Spearman}}(s,-J),\qquad
\rho_p=\mathrm{corr}_{\mathrm{Pearson}}(s,-J)
$$

Top-$k$ regret:

$$
\mathrm{Regret}_{\mathrm{Top}k}(\%)=\left(\frac{\min_{i\in\mathrm{Top}k}J_i}{\min_i J_i}-1\right)\times 100.
$$
