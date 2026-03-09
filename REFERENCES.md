# Method and Object References (Exact Mapping)

This file maps methods/objects appearing in this repository to literature references.

If a method/object is repository-specific and no external paper is used as its
direct definition in this project, it is marked as **N/A (repository-defined)**.

---

## 1) Exact method/object mapping

| Repository label | Where used | External reference |
|---|---|---|
| `Ori-SHAP` | gas + HVAC SHAP comparisons | [R1] |
| `Cond-SHAP` | gas + HVAC SHAP comparisons | [R2] |
| `PI-SHAP` | gas + HVAC SHAP comparisons | N/A (repository-defined method label in this project) |
| `CART_Gini`, `CART_Entropy` | gas rule-learner compare | [R4] |
| `RF_Bag` | gas rule-learner compare | [R5] |
| `AdaBoost_Stump` | gas rule-learner compare | [R6] |
| DOE Latin-hypercube style sampling | HVAC DOE generation | [R3] |
| Gas transient optimization object | `benchmark_pepeline5C` | [R7], [R8], [R9] |
| HVAC 2-zone benchmark object | `benchmark_hvac2zone_seqtree` | N/A (repository-defined benchmark object) |
| `tr-opt`, `ss-opt`, `ss-3stage`, `ss-7stage`, `ss-13stage` | gas single-objective baselines | N/A (repository-defined baseline naming) |

---

## 2) Bibliography

**[R1]** Lundberg, S. M., and Lee, S.-I. (2017). *A Unified Approach to Interpreting Model Predictions*. Advances in Neural Information Processing Systems (NeurIPS 2017).

**[R2]** Aas, K., Jullum, M., and Loland, A. (2021). *Explaining individual predictions when features are dependent: More accurate approximations to Shapley values*. Artificial Intelligence, 298, 103502.

**[R3]** McKay, M. D., Beckman, R. J., and Conover, W. J. (1979). *A Comparison of Three Methods for Selecting Values of Input Variables in the Analysis of Output from a Computer Code*. Technometrics, 21(2), 239-245.

**[R4]** Breiman, L., Friedman, J. H., Olshen, R. A., and Stone, C. J. (1984). *Classification and Regression Trees*. Wadsworth.

**[R5]** Breiman, L. (2001). *Random Forests*. Machine Learning, 45, 5-32.

**[R6]** Freund, Y., and Schapire, R. E. (1997). *A Decision-Theoretic Generalization of On-Line Learning and an Application to Boosting*. Journal of Computer and System Sciences, 55(1), 119-139.

**[R7]** Zlotnik, A., Chertkov, M., and Backhaus, S. (2015). *Optimal control of transient flow in natural gas networks*. 54th IEEE Conference on Decision and Control (CDC), 4563-4570.

**[R8]** Zlotnik, A., Roald, L., Backhaus, S., Chertkov, M., and Andersson, G. (2017). *Coordinated scheduling for interdependent electric power and natural gas infrastructures*. IEEE Transactions on Power Systems, 32(1), 600-610.

**[R9]** Sundar, K., and Zlotnik, A. (2018). *State and Parameter Estimation for Natural Gas Pipeline Networks using Transient State Data*. arXiv:1803.07156.
