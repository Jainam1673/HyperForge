# M22 — AutoML, complete monolithic implementation

This milestone implements the **full declared AutoML inventory** in one pass,
per the owner's monolithic-per-tech strategy. The inventory is in
`EXPANSION_ROADMAP.md`; every item below has a real first-party Mojo execution
path and tests.

## Algorithms (18 declared kinds)

| Family | Kinds |
|---|---|
| Linear / regularized | `mean_baseline`, `linear_gd`, `ridge_gd`, `lasso_gd` (L1 subgradient), `elastic_net_gd`, `huber_gd` (robust loss) |
| Non-linear / basis | `polynomial_regression` (degree-2 expansion), `pca_regressor` (power-iteration leading component) |
| Instance | `knn_regressor`, `knn_classifier` |
| Trees / ensembles | `decision_tree_regressor`, `random_forest_regressor`, `gradient_boosting_regressor`, `decision_tree_classifier`, `random_forest_classifier` |
| Probabilistic | `gaussian_naive_bayes`, `logistic_regression` |
| Unsupervised | `kmeans` |

All training uses only the supplied training rows; preprocessing statistics are
train-fitted. Decision trees use greedy squared-error CART splits with a
configured depth; forests use seeded bootstrap samples; boosting fits
residual trees with a learning rate. No external ML library is used.

## Metrics

Regression: MAE, MSE, RMSE, R², MAPE (with explicit zero-target handling).
Classification: accuracy, precision, recall, F1, confusion matrix, log loss,
ROC-AUC (pairwise with 0.5 for ties). Non-finite predictions are rejected.

## Validation and search

- Task type is detected from the target (`0/1` codes → classification).
- `kfold_plans` produces deterministic seeded folds; training indices are the
  complement of each validation fold. Cross-validation touches **only** the
  training partition.
- Candidate generation covers every declared kind: random candidates guarantee
  coverage of the full kind list, and `grid` mode emits two configurations per
  kind.
- Selection uses validation plus k-fold; the test split is evaluated **once**
  after selection. `is_classification_kind` prevents continuous regression
  outputs from winning a classification selection.

## CLI

```bash
./hyperforge automl full <csv> <target> [budget] [seed] [folds] [grid]
```

Example results (budget 12, seed 42, 3 folds):

| Task | Winner | Test metric |
|---|---|---|
| `examples/regression_linear.csv` | `linear_gd` | RMSE 0.00269 |
| `examples/classification_binary.csv` | `logistic_regression` | accuracy 0.667, F1 0.5, AUC 1.0 |

Every trial is appended as a `full_trial` record (candidate, kind, task, seed,
score, validity); a `full_summary` record stores the winner and test metrics.

## Boundaries

- "Complete" means the declared inventory, not an infinite algorithm space.
- No XGBoost/LightGBM, deep tabular networks, multi-class>2, ranking, DBSCAN,
  or time-series forecasting — those are outside the declared M22 inventory
  and remain available for a future expansion of this same tech.
- ROC-AUC is pairwise and O(n²); fine for the bounded fixture sizes used here,
  not for large datasets.
- The legacy `automl run` regression slice remains for backward compatibility;
  `automl full` is the complete surface.
