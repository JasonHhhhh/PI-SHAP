# SHAP Results and Conclusions (HVAC 2-Zone)

This note summarizes SHAP conclusions for `benchmark_hvac2zone_seqtree`.

## 1) Methods compared

- Ori-SHAP
- Cond-SHAP
- PI-SHAP

All methods are evaluated on the same candidate pool and same planning granularity
(4 blocks x 6 h), under identical train/test split sizes.

## 2) Core metrics

- Correlation between SHAP score and `-objective`:
  - Spearman
  - Pearson
- Scheduling quality:
  - Top1 regret
  - Top5 regret

Metric definitions:

$$
\mathrm{Regret}_{\mathrm{Top1}}(\%) = \left(\frac{J(\hat u_{\mathrm{Top1}})}{\min_{u\in\mathcal U_{\mathrm{test}}}J(u)} - 1\right)\times 100
$$

$$
\mathrm{Regret}_{\mathrm{Top5}}(\%) = \left(\frac{\min_{u\in\mathrm{Top5}}J(u)}{\min_{u\in\mathcal U_{\mathrm{test}}}J(u)} - 1\right)\times 100
$$

$$
\rho_s = \mathrm{corr}_{\mathrm{Spearman}}(\mathrm{Score}_{\mathrm{SHAP}}, -J)
$$

## 3) Base split conclusions

From:

- `outputs/tables/shap_schedule_compare_single.csv`
- `outputs/tables/shap_schedule_compare_multi.csv`
- `outputs/tables/shap_correlation_single.csv`
- `outputs/tables/shap_correlation_multi.csv`

Conclusions:

- Single objective: PI-SHAP ranks first by top1 regret and has highest Spearman.
- Multi objective: PI-SHAP ranks first (top1 tie broken by better top5) and has highest Spearman.

## 4) Multi-split fairness conclusions

From:

- `outputs/tables/shap_fairness_experiments_summary.csv`
- `outputs/tables/shap_conclusion_summary.csv`

Two fairness views are reported:

1. **Top1-first view** (strict top1 regret ranking)
2. **Composite view** (Top1 + Top5 + Spearman; lower composite is better)

Observed behavior:

- PI-SHAP consistently gives stronger score-objective correlation.
- PI-SHAP gives stronger top5 retrieval quality in both single and multi studies.
- Under composite fairness ranking, PI-SHAP is best for both single and multi objectives.

## 5) Figures to inspect

- Correlation comparison: `outputs/figures/figure_05_shap_correlations.png`
- Single-objective schedule comparison: `outputs/figures/figure_06_shap_schedule_compare_single.png`
- Multi-objective schedule comparison: `outputs/figures/figure_07_shap_schedule_compare_multi.png`
- Fairness summary: `outputs/figures/figure_09_shap_fairness_summary.png`
