# Mathematical Formulation: HVAC 2-Zone Benchmark

## 1) Variables and horizon

- States: $T_{1,t},T_{2,t}$
- Controls: $u_{1,t},u_{2,t}$
- Disturbances: $T_{\mathrm{out},t},S_t,\mathrm{Occ}_{1,t},\mathrm{Occ}_{2,t},\mathrm{Price}_t$

$$
t=0,\dots,T-1,\qquad T=24,\quad \Delta t=1\,\mathrm{h}.
$$

## 2) Dynamics

$$
T_{1,t+1}=T_{1,t}+\Delta t\Big[k_{\mathrm{out},1}(T_{\mathrm{out},t}-T_{1,t})
+k_{\mathrm{cross}}(T_{2,t}-T_{1,t})+k_{\mathrm{solar},1}S_t
+k_{\mathrm{occ},1}\,\mathrm{Occ}_{1,t}-k_{\mathrm{cool},1}u_{1,t}\Big]
$$

$$
T_{2,t+1}=T_{2,t}+\Delta t\Big[k_{\mathrm{out},2}(T_{\mathrm{out},t}-T_{2,t})
+k_{\mathrm{cross}}(T_{1,t}-T_{2,t})+k_{\mathrm{solar},2}S_t
+k_{\mathrm{occ},2}\,\mathrm{Occ}_{2,t}-k_{\mathrm{cool},2}u_{2,t}\Big]
$$

## 3) Constraints and boundaries

$$
0\le u_{z,t}\le 1,\qquad z\in\{1,2\}
$$

$$
T_{\min}\le T_{z,t}\le T_{\max}
$$

Comfort-band notion:

$$
|T_{z,t}-T_{\mathrm{set}}|\le \delta
$$

(enforced softly through discomfort penalty).

## 4) Single-objective optimization

Power model:

$$
P_{z,t}=P_z^{\max}u_{z,t}
$$

Cost term:

$$
J_{\mathrm{cost}}=\sum_t \mathrm{Price}_t\,(P_{1,t}+P_{2,t})\,\Delta t
$$

Discomfort term:

$$
J_{\mathrm{disc}}=\sum_t\sum_{z\in\{1,2\}}\max\big(0,|T_{z,t}-T_{\mathrm{set}}|-\delta\big)^2 + w_T\phi_T
$$

Smoothness term:

$$
J_{\mathrm{smooth}}=\sum_t\lVert u_t-u_{t-1}\rVert_2^2
$$

Objective:

$$
\min_u J_{\mathrm{single}}=J_{\mathrm{cost}}+w_dJ_{\mathrm{disc}}+w_sJ_{\mathrm{smooth}}
$$

## 5) Multi-objective optimization

$$
\min_u \big[J_{\mathrm{cost}}(u),\,J_{\mathrm{disc}}(u)\big]
$$

with Pareto extraction over the full discrete candidate set.

## 6) SHAP evaluation metrics

For score $s_i$ and objective $J_i$:

$$
\rho_s=\mathrm{corr}_{\mathrm{Spearman}}(s,-J),\qquad
\rho_p=\mathrm{corr}_{\mathrm{Pearson}}(s,-J)
$$

Top1 regret:

$$
\mathrm{Regret}_{\mathrm{Top1}}(\%)=\left(\frac{J(\hat u_{\mathrm{Top1}})}{\min_i J_i}-1\right)\times 100
$$

Top5 regret:

$$
\mathrm{Regret}_{\mathrm{Top5}}(\%)=\left(\frac{\min_{i\in\mathrm{Top5}}J_i}{\min_i J_i}-1\right)\times 100
$$
