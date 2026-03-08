# Seed11 dt=1h neural surrogate report (light-plus)

## 1) Scope and objective

- Dataset scope: `seed=11`, `dt=1h`, `OK=1` from DOE try1.
- Goal: build a lightweight NN surrogate that approximates transient simulator outputs under this boundary-condition regime.
- Input: compressor action sequence + inlet-pressure sequence with random noise.
- Outputs: (`Jcost`, `Jsupp`, `Jvar`) + key flow indicators + reconstructed `m_cost(t)` / `m_supp(t)` curves.

## 2) Data and split

- Total samples: `1650`
- Input dimension: `150`
- Output dimension (scalar heads): `11`
- Split: train `1155`, val `247`, test `248`

Input feature construction:

- action features: `cc_{t,c}` for `t=1..25`, `c=1..5`
- pressure features: `p_{in,t}^{noise} = p_{in,t} (1 + \sigma \epsilon_t)`, `\epsilon_t \sim \mathcal{N}(0,1)`
- final feature vector: `x \in \mathbb{R}^{150}`

## 3) Modeling equations

### 3.1 Scalar surrogate

For each scalar target `y_k`, train one NN regressor:

$$\hat{y}_k = f_{\theta_k}(x)$$

Loss (MSE + L2 regularization, implicit in solver settings):

$$\mathcal{L}(\theta_k)=\frac{1}{N}\sum_{n=1}^N\left(y_k^{(n)}-f_{\theta_k}(x^{(n)})\right)^2 + \lambda\|\theta_k\|_2^2$$

For `Jcost`, train in log-space for stability:

$$\tilde{y}_{cost}=\log_{10}(y_{cost}),\quad \hat{y}_{cost}=10^{f_{\theta}(x)}$$

### 3.2 Curve surrogate (PCA + NN coefficients)

For each trajectory `y(t)` (`m_cost`, `m_supp`), use PCA on training curves:

$$y \approx \mu + P_K z,\quad z=[z_1,\dots,z_K]^T$$

Then learn each coefficient with NN:

$$\hat{z}_i = g_{\psi_i}(x),\quad i=1,\dots,K$$

Curve reconstruction:

$$\hat{y}=\mu + P_K \hat{z}$$

## 4) SHAP methods, formulas, and differences

Shapley definition used by all SHAP variants (`M` features):

$$\phi_i(x)=\sum_{S\subseteq N\setminus\{i\}}\frac{|S|!(M-|S|-1)!}{M!}\left[v_x(S\cup\{i\})-v_x(S)\right]$$

Method-specific value functions / estimators:

1. **Interventional SHAP** (this run): feature dependence is cut when integrating missing features.
$$v_x^{int}(S)=\mathbb{E}_{X_{\bar S}}\left[f(x_S, X_{\bar S})\right]$$

2. **Conditional SHAP** (this run): keeps empirical dependence among features.
$$v_x^{cond}(S)=\mathbb{E}\left[f(X)\mid X_S=x_S\right]$$

3. **Kernel SHAP** (model-agnostic estimator): weighted local linear regression around `x`.
$$\min_{\phi_0,\phi}\sum_{u}\pi_x(u)\left(f(h_x(u))-\phi_0-\sum_{i=1}^M\phi_i u_i\right)^2$$

4. **TreeSHAP** (tree-model exact/fast): additive over trees with exact tree expectations.
$$\phi_i(x)=\sum_{t=1}^{T}\phi_i^{(t)}(x),\quad \phi_i^{(t)}\text{ computed exactly on tree }t$$

5. **DeepSHAP** (deep nets): DeepLIFT-style multipliers averaged over background references.
$$\phi_i(x)\approx\mathbb{E}_{x'\sim B}\left[(x_i-x_i')\,m_i(x,x')\right]$$

6. **Permutation / Sampling SHAP** (Monte Carlo): average marginal contribution over random permutations.
$$\phi_i(x)\approx\frac{1}{K}\sum_{k=1}^{K}\left[f\left(x_{S_i^{\pi_k}\cup\{i\}}\right)-f\left(x_{S_i^{\pi_k}}\right)\right]$$

Practical difference summary:

- Interventional: robust and simple, but can violate realistic feature coupling.
- Conditional: respects dependence, but needs stronger distribution modeling assumptions.
- Kernel/Permutation: model-agnostic, but slower and variance-sensitive.
- TreeSHAP/DeepSHAP: architecture-specific accelerations/approximations for trees/deep nets.

## 5) Scalar metrics (test split)

| Target | R2 | RMSE | MAE |
|---|---:|---:|---:|
| Jcost | 0.9760 | 1.20271e+10 | 8.38253e+09 |
| Jsupp | 0.9959 | 20065.4 | 15785.6 |
| Jvar | 0.9789 | 0.346032 | 0.274763 |
| CostMean | 0.9996 | 45070.2 | 35500.3 |
| CostPeak | 0.9905 | 260562 | 170402 |
| CostP95 | 0.9925 | 244633 | 155486 |
| SuppMean | 0.9974 | 2.21652 | 1.73444 |
| SuppPeak | 0.9850 | 4.20532 | 3.03154 |
| SuppP05 | 0.9685 | 16.2703 | 9.70887 |
| MassFinal | 0.9951 | 0.514298 | 0.401776 |
| MassMin | 0.9863 | 0.716589 | 0.560912 |

## 6) Curve metrics (test split)

| Curve | R2(flat) | RMSE(flat) | MAE(flat) | Mean RMSE/case | PCA K | Explained(%) |
|---|---:|---:|---:|---:|---:|---:|
| m_cost | 0.9982 | 143615 | 105795 | 138266 | 11 | 99.80 |
| m_supp | 0.9908 | 9.72612 | 6.33553 | 8.71326 | 12 | 98.85 |

## 7) 3-case curve check (DOE only)

| Case | Jcost true/pred | Jsupp true/pred | Jvar true/pred | RMSE m_cost | RMSE m_supp |
|---|---:|---:|---:|---:|---:|
| DOE sample 105 | 2.04518e+11 / 2.02893e+11 | 1.45089e+06 / 1.45493e+06 | 6.16101 / 6.31233 | 152437 | 13.5514 |
| DOE sample 512 | 2.85151e+11 / 2.74843e+11 | 1.98512e+06 / 1.97829e+06 | 3.15866 / 3.4818 | 115233 | 5.16467 |
| DOE sample 49 | 4.10144e+11 / 4.13849e+11 | 2.24587e+06 / 2.23745e+06 | 4.45029 / 4.35942 | 105293 | 4.8269 |

## 8) Generated plots

- `shap_src_min/NNs/plots/split_overview.png`
- `shap_src_min/NNs/plots/network_architecture_schematic.png`
- `shap_src_min/NNs/plots/objective_parity_test.png`
- `shap_src_min/NNs/plots/flow_parity_test.png`
- `shap_src_min/NNs/plots/curve_overlay_sampled_test.png`
- `shap_src_min/NNs/plots/curve_case_compare_doe3.png`
- `shap_src_min/NNs/plots/selected_case_objective_compare_doe3.png`
- `shap_src_min/NNs/plots/shap_action_heatmap_interventional.png`
- `shap_src_min/NNs/plots/shap_action_heatmap_conditional.png`
- `shap_src_min/NNs/plots/shap_method_compare_time_profile.png`

## 9) SHAP references

- Shapley value foundation: Shapley, 1953, *A Value for n-Person Games* (`https://doi.org/10.1515/9781400881970-018`).
- SHAP framework and Kernel SHAP: Lundberg and Lee, 2017, *A Unified Approach to Interpreting Model Predictions* (`https://arxiv.org/abs/1705.07874`).
- Conditional/dependence-aware SHAP: Aas, Jullum, and Lolo, 2021, *Artificial Intelligence* (`https://doi.org/10.1016/j.artint.2021.103502`).
- TreeSHAP and global interpretation for trees: Lundberg et al., 2020, *Nature Machine Intelligence* (`https://doi.org/10.1038/s42256-019-0138-9`).
- DeepLIFT basis used by DeepSHAP: Shrikumar, Greenside, and Kundaje, 2017 (`https://proceedings.mlr.press/v70/shrikumar17a.html`).
- Sampling/permutation-style Shapley estimation: Strumbelj and Kononenko, 2014, *Knowledge and Information Systems* (`https://doi.org/10.1007/s10115-013-0679-x`).

## 10) Current limitation

- Scope is intentionally limited to seed11 + 1h + fixed boundary-condition regime.
- Surrogate is light and practical; full PDE-state replacement for all state channels is deferred to next iteration.
- All reported metrics and selected-case checks are DOE-scope only.
