# SHAP Results and Conclusions (HVAC 2-Zone)

This document provides the SHAP experiment definition, fairness protocol, and
interpretable conclusions for `benchmark_hvac2zone_seqtree`.

It is designed as an appendix-style note: symbol table, equations, metrics,
protocol, and final evidence path.

---

## 1) Symbols and setup

- Candidate control plan: $u^{(i)}$
- Objective value for candidate $i$: $J_i$
- SHAP-derived ranking score for candidate $i$: $s_i$
- Test candidate set: $\mathcal U_{\mathrm{test}}$
- Set of top-$k$ candidates ranked by score: $\mathrm{Top}k(s)$

Objectives used in SHAP ranking experiments:

- Single-objective target: $J_{\mathrm{single}}$
- Multi-objective balanced target: $J_{\mathrm{multi,bal}}$

All methods use the same plan parameterization and same split sizes.

---

## 2) Method definitions used in code

Methods compared:

- Ori-SHAP
- Cond-SHAP
- PI-SHAP

Reference mapping:

- Ori-SHAP: [R1]
- Cond-SHAP: [R2]
- PI-SHAP: repository-defined label in this project (N/A external one-to-one paper)

Given a surrogate model $f(\cdot)$ and candidate feature vector $x$:

### 2.1 Ori-SHAP perturbation

For feature $j$, replace $x_j$ by Monte-Carlo draws from marginal training data.

$$
\phi^{\mathrm{ori}}_j(x) \approx \mathbb E_{\tilde x_j\sim p(x_j)}\big[f(x_{-j},\tilde x_j)\big]-f(x)
$$

### 2.2 Cond-SHAP perturbation

For feature $j$, replace $x_j$ with samples from a conditional neighbor set
(nearest rows under $x_{-j}$ distance):

$$
\phi^{\mathrm{cond}}_j(x) \approx \mathbb E_{\tilde x_j\sim p(x_j\mid x_{-j})}\big[f(x_{-j},\tilde x_j)\big]-f(x)
$$

### 2.3 PI-SHAP perturbation

For feature $j$, jointly perturb the paired feature $p(j)$ (same time block,
other zone control), then split pair effect:

$$
\phi^{\mathrm{pi}}_j(x) \approx \frac{1}{2}\Big(\mathbb E\big[f(x_{-(j,p(j))},\tilde x_j,\tilde x_{p(j)})\big]-f(x)\Big)
$$

Candidate score is the sum of contributions:

$$
s_i = \sum_j \phi_j(x^{(i)})
$$

Higher $s_i$ indicates better candidate rank (because quality is measured against
$-J$).

---

## 3) Evaluation metrics

### 3.1 Correlation metrics

$$
\rho_s = \mathrm{corr}_{\mathrm{Spearman}}(s,-J),\qquad
\rho_p = \mathrm{corr}_{\mathrm{Pearson}}(s,-J)
$$

Higher is better.

### 3.2 Scheduling regrets

Top1 regret:

$$
\mathrm{Regret}_{\mathrm{Top1}}(\%)
=\left(\frac{J(\hat u_{\mathrm{Top1}})}{\min_{u\in\mathcal U_{\mathrm{test}}}J(u)}-1\right)\times 100
$$

Top5 regret:

$$
\mathrm{Regret}_{\mathrm{Top5}}(\%)
=\left(\frac{\min_{u\in\mathrm{Top5}(s)}J(u)}{\min_{u\in\mathcal U_{\mathrm{test}}}J(u)}-1\right)\times 100
$$

Lower is better.

### 3.3 Fairness composite metric

From multi-split summaries (per objective), normalized terms are combined as:

$$
\mathrm{Composite}=0.20\,\overline R_{\mathrm{Top1}}^{\mathrm{norm}}
+0.50\,\overline R_{\mathrm{Top5}}^{\mathrm{norm}}
+0.30\,(1-\overline\rho_s^{\mathrm{norm}})
$$

Lower composite is better.

---

## 4) Experimental protocol (fairness + reproducibility)

Base split protocol:

- fixed train/test split sizes,
- same surrogate class,
- same candidate representation,
- same objective target,
- only SHAP perturbation rule changes.

Fairness protocol:

- random split seeds: `[11, 23, 37, 53, 71]`
- each seed runs all methods with same train/test counts
- objective-specific summary reports:
  - mean/std top1 regret
  - mean/std top5 regret
  - mean/std Spearman
  - rank by top1 and rank by composite

---

## 5) Base split evidence and conclusions

Evidence files:

- `outputs/tables/shap_correlation_single.csv`
- `outputs/tables/shap_correlation_multi.csv`
- `outputs/tables/shap_schedule_compare_single.csv`
- `outputs/tables/shap_schedule_compare_multi.csv`

Observed in current run:

- **Single objective**:
  - PI-SHAP has best top1 regret (`33.20%`) and best Spearman (`0.9340`).
- **Multi objective**:
  - PI-SHAP and Ori-SHAP tie on top1 regret (`2.4831%`),
  - PI-SHAP wins on top5 regret (`1.6529%` vs `2.4831%`) and Spearman (`0.9732`).

Base-split conclusion:

- PI-SHAP is best under the primary schedule selection criteria used in this case.

---

## 6) Multi-split fairness evidence and conclusions

Evidence files:

- `outputs/tables/shap_fairness_experiments_summary.csv`
- `outputs/tables/shap_conclusion_summary.csv`

Two fairness views are intentionally reported:

1. **Top1-priority ranking** (strictly favors top1 selection)
2. **Composite ranking** (balances top1/top5 retrieval and correlation)

Observed behavior in current run:

- PI-SHAP has strongest mean Spearman in both objectives.
- PI-SHAP has strongest top5 retrieval (especially clear in single-objective fairness table).
- Top1-only ranking can favor Cond-SHAP in this parameterization.
- Composite ranking selects PI-SHAP for both single and multi objectives.

Interpretation:

- If a deployment values only first pick quality, Top1 view is stricter.
- If deployment values shortlist quality + score consistency, Composite view is
  more decision-relevant.

---

## 7) Figures to inspect

- Correlation comparison: `outputs/figures/figure_05_shap_correlations.png`
- Single-objective schedule comparison: `outputs/figures/figure_06_shap_schedule_compare_single.png`
- Multi-objective schedule comparison: `outputs/figures/figure_07_shap_schedule_compare_multi.png`
- Fairness summary: `outputs/figures/figure_09_shap_fairness_summary.png`

---

## 8) Practical takeaway for this benchmark

- PI-SHAP is the most stable choice when combining ranking quality and
  score-objective consistency across objectives.
- Reporting both Top1 and Composite fairness views is important and more honest
  than a single metric narrative.

---

## 9) Reference keys used in this note

- [R1], [R2] are defined in `../REFERENCES.md`.
