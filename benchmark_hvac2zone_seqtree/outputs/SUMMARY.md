# HVAC 2-zone benchmark summary

## Configuration

- Horizon: `24` hours (`dt=1.0 h`)
- Controls: `2` zones
- Blocked control variables: `4` blocks x 2 zones = `8` decision variables
- Action levels per variable: `4` ([0 0.35 0.7 1])
- Candidate pool size: `65536`
- DOE scenario count: `48`

## Single-objective result

- Best method: `Opt-Exhaustive`
- Best Jsingle: `56.7747`
- Cost / Discomfort / Smoothness: `38.4160 / 7.9576 / 2.1300`
- Comfort violation hours: `15.0`

## Multi-objective result

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

## SHAP method comparison (train/test split)

- Train/Test candidates: `2400 / 800`
- Time granularity for planning and SHAP: `4` blocks x `6` hours/block

### Single-objective scheduling

- `Model-Pred`: top1 metric `141.1510`, top1 regret `0.0000 %`, Spearman(score,-metric)=`0.9970`
- `PI-SHAP`: top1 metric `188.0125`, top1 regret `33.1995 %`, Spearman(score,-metric)=`0.9340`
- `Ori-SHAP`: top1 metric `336.3416`, top1 regret `138.2849 %`, Spearman(score,-metric)=`0.9189`
- `Cond-SHAP`: top1 metric `513.6531`, top1 regret `263.9032 %`, Spearman(score,-metric)=`0.9185`

### Multi-objective scheduling (balanced score)

- `Model-Pred`: top1 metric `0.2349`, top1 regret `1.6529 %`, Spearman(score,-metric)=`0.9992`
- `Ori-SHAP`: top1 metric `0.2368`, top1 regret `2.4831 %`, Spearman(score,-metric)=`0.9589`
- `PI-SHAP`: top1 metric `0.2368`, top1 regret `2.4831 %`, Spearman(score,-metric)=`0.9732`
- `Cond-SHAP`: top1 metric `0.2414`, top1 regret `4.4891 %`, Spearman(score,-metric)=`0.9545`
