# HVAC 2-zone benchmark summary

## Problem configuration

- Horizon: `24` hours (`dt=1.0 h`)
- Zones/controls: `2`
- Decision granularity: `4` blocks x `6` hours/block
- Action levels per zone-block: `[0 0.35 0.7 1]`
- Search space size: `65536` candidates
- DOE scenario count: `48`

## Single-objective scheduling

- Best method: `Opt-Exhaustive`
- Best Jsingle: `56.7747`
- Cost / Discomfort / Smoothness: `38.4160 / 7.9576 / 2.1300`
- Comfort violation hours: `15.0`

## Multi-objective scheduling

- Pareto points found: `89`
- `Pareto_MinCost`: cost `0.0000`, discomfort `2450.0527`, Jsingle `5390.1660`
- `Pareto_Knee`: cost `15.8270`, discomfort `528.1826`, Jsingle `1178.2707`
- `Pareto_MinDiscomfort`: cost `38.4160`, discomfort `7.9576`, Jsingle `56.7747`
- `SingleObj_Opt`: cost `38.4160`, discomfort `7.9576`, Jsingle `56.7747`

## DOE robustness (mean Jsingle ranking)

1. `Opt-Exhaustive`: mean Jsingle `170.2406` (std `145.6100`), mean cost `41.4561`, mean discomfort `58.1511`
2. `Rule-PriceAware`: mean Jsingle `985.2202` (std `510.4321`), mean cost `31.2183`, mean discomfort `433.5445`
3. `Rule-ComfortFirst`: mean Jsingle `1465.6207` (std `855.6547`), mean cost `62.6318`, mean discomfort `637.5831`
4. `Pareto-Knee`: mean Jsingle `1956.9001` (std `1134.2419`), mean cost `16.8800`, mean discomfort `881.6264`
5. `Pareto-MinCost`: mean Jsingle `6443.8763` (std `1747.2639`), mean cost `0.0000`, mean discomfort `2929.0119`

## SHAP comparison on train/test split

- Train/Test candidates: `2400 / 800`
- Same planning granularity and sampling are used for Ori-SHAP, Cond-SHAP, and PI-SHAP

### Single-objective SHAP scheduling

- `PI-SHAP`: top1 metric `188.0125`, top1 regret `33.1995 %`, top5 regret `0.0000 %`, Spearman `0.9340`
- `Ori-SHAP`: top1 metric `336.3416`, top1 regret `138.2849 %`, top5 regret `0.0000 %`, Spearman `0.9189`
- `Cond-SHAP`: top1 metric `513.6531`, top1 regret `263.9032 %`, top5 regret `124.9713 %`, Spearman `0.9185`

### Multi-objective SHAP scheduling

- `PI-SHAP`: top1 metric `0.2368`, top1 regret `2.4831 %`, top5 regret `1.6529 %`, Spearman `0.9732`
- `Ori-SHAP`: top1 metric `0.2368`, top1 regret `2.4831 %`, top5 regret `2.4831 %`, Spearman `0.9589`
- `Cond-SHAP`: top1 metric `0.2414`, top1 regret `4.4891 %`, top5 regret `1.6529 %`, Spearman `0.9545`

## SHAP fairness study (multiple random splits)

- Split seeds: `[11 23 37 53 71]`
- Per split train/test: `1800 / 320`

### single objective

- Top1-ranking winner: `Cond-SHAP`
- Composite-ranking winner: `PI-SHAP`
- `Cond-SHAP`: mean top1 regret `60.4255 %` (std `56.0819`), mean top5 regret `19.7497 %`, mean Spearman `0.8996`, composite `0.7025`
- `Ori-SHAP`: mean top1 regret `111.0406 %` (std `80.8405`), mean top5 regret `23.8003 %`, mean Spearman `0.9021`, composite `0.8340`
- `PI-SHAP`: mean top1 regret `229.3351 %` (std `206.5124`), mean top5 regret `3.0246 %`, mean Spearman `0.9292`, composite `0.2000`

### multi objective

- Top1-ranking winner: `Cond-SHAP`
- Composite-ranking winner: `PI-SHAP`
- `Cond-SHAP`: mean top1 regret `2.2377 %` (std `3.1643`), mean top5 regret `0.8953 %`, mean Spearman `0.9214`, composite `0.5433`
- `Ori-SHAP`: mean top1 regret `4.5220 %` (std `6.2838`), mean top5 regret `1.2252 %`, mean Spearman `0.9266`, composite `0.8955`
- `PI-SHAP`: mean top1 regret `5.3577 %` (std `5.3554`), mean top5 regret `0.5826 %`, mean Spearman `0.9523`, composite `0.2000`

## SHAP conclusions

- `BaseSplitSingle`: `PI-SHAP`
- `BaseSplitMulti`: `PI-SHAP`
- `FairnessTop1Single`: `Cond-SHAP`
- `FairnessTop1Multi`: `Cond-SHAP`
- `FairnessCompositeSingle`: `PI-SHAP`
- `FairnessCompositeMulti`: `PI-SHAP`
