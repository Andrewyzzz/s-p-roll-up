# Tail-Index Estimation (§5.3.1)

Estimates power-law tail index $\hat{\alpha}$ of option value distribution
to calibrate Theorem 2 bound $\rho_{\min}(\hat{\alpha}, B_{\max}, w, \lambda, L)$.

## Estimators

- Hill estimator
- MLE
- Threshold sensitivity: k ∈ {50, 100, 200, 500}

## Goodness-of-Fit

Anderson-Darling test vs alternatives:
- Stretched exponential
- Generalized Pareto

## Bootstrap CI

95% confidence interval via bootstrap (n=1000 resamples).

## Regime Analysis

$\hat{\alpha}$ estimated separately per volatility regime.

## Run

```bash
# TODO: fill after Task 7.4
python tail_index.py --input data/processed/combined_V.parquet --output results/
```

## Output

- `results/alpha_estimates.csv` — Hill + MLE estimates across k thresholds
- `results/bootstrap_ci.csv` — 95% CI
- `figures/tail_index_plot.pdf` — Threshold sensitivity plot for §5.3.1

## Milestone

**Milestone 2b** (Week 16): $\hat{\alpha}$ + $\rho_{\min}$ calibrated.

## External Review

Results sent to quant finance reviewer before Theorem 2 finalization (Task 8.3).
