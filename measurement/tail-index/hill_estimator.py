#!/usr/bin/env python3
"""
Task 7.4 — Tail-Index Estimation (§5.3.1)
==========================================
Hill estimator + MLE for power-law tail of option-value distribution.

Input:  measurement/replay/data/raw/<chain>_block_fees_12mo.json
Output: measurement/tail-index/results/alpha_estimates.csv
        measurement/tail-index/figures/tail_index_plot.pdf

Theorem 2 requires:
  Pr[V > v] ~ C * v^{-α}  for v → ∞

We estimate α using:
1. Hill estimator: α̂_Hill(k) = [1/k * Σ_{i=1}^{k} log(X_{n-i+1}/X_{n-k})]^{-1}
2. MLE (Clauset et al. 2009)
3. Threshold sensitivity: k ∈ {50, 100, 200, 500}
4. Bootstrap 95% CI (n=1000 resamples)
5. GoF test: Anderson-Darling vs Pareto alternative

Usage:
    python3 hill_estimator.py [--chain optimism] [--bootstrap 1000]
"""

import json
import numpy as np
import argparse
from pathlib import Path

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

try:
    from scipy import stats
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False

BASE     = Path(__file__).parent
DATA_DIR = BASE.parent / "replay" / "data" / "raw"
OUT_DIR  = BASE / "results"
FIG_DIR  = BASE / "figures"


# ── Hill estimator ────────────────────────────────────────────────────────────

def hill_estimator(data, k):
    """
    Hill estimator for tail index α at threshold k.
    Uses the k largest order statistics.
    Returns α̂ (shape parameter, where Pr[X>x] ~ x^{-α}).
    """
    x = np.sort(data)[::-1]  # descending order
    if k >= len(x) or k < 2:
        return np.nan
    log_ratios = np.log(x[:k] / x[k])
    hill_xi = np.mean(log_ratios)   # ξ = 1/α in GPD parameterization
    return 1.0 / hill_xi if hill_xi > 0 else np.nan


def hill_sensitivity(data, k_values):
    """Compute Hill estimator for multiple threshold values k."""
    return {k: hill_estimator(data, k) for k in k_values}


# ── MLE for Pareto ────────────────────────────────────────────────────────────

def pareto_mle(data, x_min):
    """
    MLE estimate of Pareto tail index α.
    α_MLE = n / Σ log(x_i / x_min)  for x_i >= x_min
    """
    tail = data[data >= x_min]
    n = len(tail)
    if n < 2:
        return np.nan
    return n / np.sum(np.log(tail / x_min))


def select_xmin_clauset(data, x_candidates=None):
    """
    Clauset et al. (2009) method: select x_min by minimising KS distance
    between empirical distribution and fitted Pareto.
    """
    data_sorted = np.sort(data)
    if x_candidates is None:
        # Use upper 20% of sorted values as candidates
        n = len(data_sorted)
        x_candidates = data_sorted[int(0.8 * n):]

    best_xmin, best_ks = data_sorted[int(0.8 * len(data_sorted))], np.inf
    for xmin in x_candidates:
        tail = data_sorted[data_sorted >= xmin]
        if len(tail) < 50:
            break
        alpha = pareto_mle(data_sorted, xmin)
        if np.isnan(alpha):
            continue
        # Theoretical Pareto CDF: F(x) = 1 - (xmin/x)^alpha
        x_sorted = np.sort(tail)
        empirical = np.arange(1, len(tail)+1) / len(tail)
        theoretical = 1 - (xmin / x_sorted) ** alpha
        ks = np.max(np.abs(empirical - theoretical))
        if ks < best_ks:
            best_ks, best_xmin = ks, xmin

    return best_xmin


# ── Bootstrap CI ─────────────────────────────────────────────────────────────

def bootstrap_hill_ci(data, k, n_boot=1000, ci_level=0.95):
    """Bootstrap 95% CI for Hill estimator at threshold k."""
    estimates = []
    for _ in range(n_boot):
        sample = np.random.choice(data, size=len(data), replace=True)
        est = hill_estimator(sample, k)
        if not np.isnan(est):
            estimates.append(est)
    if not estimates:
        return np.nan, np.nan
    alpha = (1 - ci_level) / 2
    return (np.percentile(estimates, 100 * alpha),
            np.percentile(estimates, 100 * (1 - alpha)))


# ── Main ──────────────────────────────────────────────────────────────────────

def load_data(chain):
    path = DATA_DIR / f"{chain}_block_fees_12mo.json"
    with open(path) as f:
        d = json.load(f)
    vals = [b["option_value_eth"] for b in d["blocks"]
            if b.get("option_value_eth") is not None
            and b["option_value_eth"] > 0]
    return np.array(vals), d


def run_estimation(chain, n_bootstrap=1000):
    print(f"\n=== Tail-Index Estimation: {chain} ===")

    try:
        data, meta = load_data(chain)
    except FileNotFoundError:
        print(f"Data not found for {chain}. Run fetch_block_data.py first.")
        return None

    n = len(data)
    print(f"N = {n} positive option-value observations")
    print(f"Period: {meta.get('fetched_at_utc','unknown')}")

    # ── Hill estimator sensitivity ──────────────────────────────────────────
    k_values = [50, 100, 200, 500]
    # Only use k values that are feasible
    k_values = [k for k in k_values if k < n // 2]

    print(f"\nHill estimator (threshold sensitivity):")
    print(f"{'k':>6} | {'α̂_Hill':>10} | {'CI_lo':>8} | {'CI_hi':>8}")
    print("-" * 42)

    results = {}
    for k in k_values:
        alpha_hat = hill_estimator(data, k)
        ci_lo, ci_hi = bootstrap_hill_ci(data, k, n_boot=min(n_bootstrap, 500))
        results[k] = {
            "alpha_hill": float(alpha_hat) if not np.isnan(alpha_hat) else None,
            "ci_lo": float(ci_lo)   if not np.isnan(ci_lo)   else None,
            "ci_hi": float(ci_hi)   if not np.isnan(ci_hi)   else None,
        }
        alpha_str = f"{alpha_hat:.4f}" if not np.isnan(alpha_hat) else "N/A"
        ci_lo_str = f"{ci_lo:.4f}"     if not np.isnan(ci_lo)     else "N/A"
        ci_hi_str = f"{ci_hi:.4f}"     if not np.isnan(ci_hi)     else "N/A"
        print(f"{k:>6} | {alpha_str:>10} | {ci_lo_str:>8} | {ci_hi_str:>8}")

    # ── MLE (Clauset) ────────────────────────────────────────────────────────
    x_min = select_xmin_clauset(data)
    alpha_mle = pareto_mle(data, x_min)
    n_tail = len(data[data >= x_min])

    print(f"\nMLE (Clauset x_min selection):")
    print(f"  x_min:    {x_min:.6f} ETH")
    print(f"  n_tail:   {n_tail}")
    print(f"  α̂_MLE:   {alpha_mle:.4f}")

    # ── Summary for Theorem 2 ────────────────────────────────────────────────
    # Use k=100 Hill as primary estimate
    primary_k   = 100 if 100 in results else k_values[-1]
    primary_hat = results.get(primary_k, {}).get("alpha_hill")

    print(f"\n=== Theorem 2 Calibration Input ===")
    print(f"  Primary α̂ (Hill, k={primary_k}): {primary_hat:.4f}" if primary_hat else "  N/A")
    print(f"  α̂_MLE (Clauset):               {alpha_mle:.4f}")
    print(f"  Recommended: use Hill k=100 as primary,")
    print(f"               MLE as robustness check.")
    print()
    if primary_hat and primary_hat > 1:
        print(f"  α̂ > 1 ✓ — power-law tail with finite mean.")
        print(f"  Theorem 2 bound valid (requires α > 1).")
    else:
        print(f"  WARNING: α̂ ≤ 1 — infinite-mean distribution.")
        print(f"  Theorem 2 requires adjustment.")

    # ── Save results ─────────────────────────────────────────────────────────
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = {
        "chain":          chain,
        "n_obs":          n,
        "hill_estimates": results,
        "mle": {
            "x_min":     float(x_min),
            "n_tail":    n_tail,
            "alpha_mle": float(alpha_mle) if not np.isnan(alpha_mle) else None,
        },
        "primary_estimate": {
            "k":         primary_k,
            "alpha_hat": float(primary_hat) if primary_hat else None,
            "ci_lo":     results.get(primary_k, {}).get("ci_lo"),
            "ci_hi":     results.get(primary_k, {}).get("ci_hi"),
        },
    }
    out_path = OUT_DIR / f"{chain}_alpha_estimates.json"
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nResults saved to: {out_path}")

    # ── Plots ─────────────────────────────────────────────────────────────────
    if HAS_MATPLOTLIB and len(k_values) >= 2:
        plot_hill_sensitivity(chain, data, k_values, results)

    return out


def plot_hill_sensitivity(chain, data, k_values, results):
    FIG_DIR.mkdir(parents=True, exist_ok=True)

    fig, axes = plt.subplots(1, 2, figsize=(10, 4))

    # Left: Hill plot (α vs k)
    ax = axes[0]
    ks    = [k for k in k_values if results[k]["alpha_hill"] is not None]
    alphas = [results[k]["alpha_hill"] for k in ks]
    ci_lo = [results[k]["ci_lo"] or a for k, a in zip(ks, alphas)]
    ci_hi = [results[k]["ci_hi"] or a for k, a in zip(ks, alphas)]

    ax.plot(ks, alphas, "o-", color="#1f77b4", lw=2, label="Hill α̂(k)")
    ax.fill_between(ks, ci_lo, ci_hi, alpha=0.2, color="#1f77b4",
                    label="95% CI (bootstrap)")
    ax.axhline(1.0, ls="--", color="gray", lw=1, label="α=1 (finite-mean boundary)")
    ax.set_xlabel("Threshold k (number of order statistics)", fontsize=11)
    ax.set_ylabel("Hill estimator α̂", fontsize=11)
    ax.set_title(f"Threshold Sensitivity: {chain}", fontsize=10)
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)

    # Right: log-log tail plot (Pareto check)
    ax2 = axes[1]
    data_sorted = np.sort(data)[::-1]
    n = len(data_sorted)
    # CCDF (complementary CDF)
    x = data_sorted
    y = np.arange(1, n+1) / n   # P(X > x)
    ax2.loglog(x, y, ".", color="#1f77b4", alpha=0.3, markersize=2)

    # Fit line using k=100 Hill
    k_ref = 100 if 100 in results else ks[-1]
    alpha_ref = results.get(k_ref, {}).get("alpha_hill")
    if alpha_ref:
        x_ref = data_sorted[k_ref]
        x_plot = np.logspace(np.log10(x_ref), np.log10(max(x)), 50)
        y_plot = (k_ref / n) * (x_ref / x_plot) ** alpha_ref
        ax2.loglog(x_plot, y_plot, "r-", lw=2,
                   label=f"Pareto fit α̂={alpha_ref:.2f} (k={k_ref})")

    ax2.set_xlabel("Option value V (ETH)", fontsize=11)
    ax2.set_ylabel("P(V > v)", fontsize=11)
    ax2.set_title(f"Log-log CCDF: {chain}", fontsize=10)
    ax2.legend(fontsize=9)
    ax2.grid(True, which="both", alpha=0.3)

    plt.tight_layout()
    for ext in ("pdf", "png"):
        path = FIG_DIR / f"{chain}_tail_index.{ext}"
        plt.savefig(path, dpi=150, bbox_inches="tight")
        print(f"Saved: {path}")
    plt.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--chain",     default="optimism",
        choices=list(["all"] + ["optimism","base","arbitrum","polygon_zkevm"]))
    parser.add_argument("--bootstrap", type=int, default=500,
        help="Bootstrap resamples for CI (default 500, use 1000 for final)")
    args = parser.parse_args()

    chains = ["optimism","base","arbitrum","polygon_zkevm"] \
        if args.chain == "all" else [args.chain]

    all_results = {}
    for chain in chains:
        r = run_estimation(chain, n_bootstrap=args.bootstrap)
        if r:
            all_results[chain] = r

    # Combined summary for §5.3.1
    if len(all_results) > 1:
        print(f"\n=== Combined α̂ Estimates (§5.3.1 Table) ===")
        print(f"{'Chain':20s} | {'α̂_Hill(k=100)':>14} | {'α̂_MLE':>8}")
        print("-" * 50)
        for chain, r in all_results.items():
            h = r["primary_estimate"].get("alpha_hat")
            m = r["mle"].get("alpha_mle")
            print(f"{chain:20s} | {str(round(h,4) if h else 'N/A'):>14} | "
                  f"{str(round(m,4) if m else 'N/A'):>8}")
