#!/usr/bin/env python3
"""
Task 7.3 — Counterfactual Replay Infrastructure
=================================================
Paper §5.3 — Counterfactual Replay

Given the historical block-fee dataset, simulates the A4 violation rate
under hypothetical preconfirmation commitments: for each block, computes
whether the option value V exceeds a given bond B_max, i.e., whether a
rational provider would violate the commitment.

Key computation:
  For each measurement window w:
    V(w) = option_value_eth of block b
    violation(w, B_max) = 1 if V(w) > B_max else 0

  Empirical rate: rho_hat(B_max) = mean(violation(w, B_max) for w in windows)

  Compare with theoretical bound from Theorem 2:
    rho_min(alpha, B_max, w, lambda) = w * lambda * C * B_max^{-alpha}

Usage:
    python3 counterfactual_replay.py [--chain optimism] [--B-max 0.001]

Output:
    measurement/replay/data/processed/<chain>_replay_results.json
    measurement/replay/figures/<chain>_replay_violation_rate.pdf
"""

import json
import argparse
import numpy as np
from pathlib import Path

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_MPL = True
except ImportError:
    HAS_MPL = False

BASE     = Path(__file__).parent
DATA_DIR = BASE / "data" / "raw"
PROC_DIR = BASE / "data" / "processed"
FIG_DIR  = BASE / "figures"

# B_max sweep values (ETH)
B_MAX_SWEEP = [
    1e-7, 2e-7, 5e-7,
    1e-6, 2e-6, 5e-6,
    1e-5, 2e-5, 5e-5,
    1e-4, 2e-4, 5e-4,
    1e-3, 2e-3, 5e-3,
    1e-2, 2e-2, 5e-2,
    0.10, 0.20, 0.50, 1.00,
]


def load_data(chain):
    path = DATA_DIR / f"{chain}_block_fees_12mo.json"
    with open(path) as f:
        d = json.load(f)
    vals = np.array([b["option_value_eth"] for b in d["blocks"]
                     if b.get("option_value_eth") and b["option_value_eth"] > 0])
    return vals, d


def compute_violation_rates(vals, b_max_values):
    """
    Compute empirical violation rate for each B_max threshold.
    violation_rate(B_max) = P(V > B_max) = fraction of windows where V > B_max
    """
    n = len(vals)
    rates = {}
    for b in b_max_values:
        n_viol = np.sum(vals > b)
        rates[b] = float(n_viol) / n
    return rates


def compute_theorem2_bound(alpha_hat, C_hat, b_max_values, lam=1.0):
    """
    Theorem 2 lower bound on violation rate per window:
      rho_min = lambda * C * B_max^{-alpha}
    (per-window, w=1, without the (1-eps) factor)
    """
    bounds = {}
    for b in b_max_values:
        bounds[b] = lam * C_hat * (b ** (-alpha_hat))
    return bounds


def estimate_C(vals, alpha_hat, x_min=None):
    """
    Estimate scale constant C from empirical tail fraction:
      C = (n_tail / n) * x_min^alpha
    """
    n = len(vals)
    if x_min is None:
        x_min = np.percentile(vals, 80)
    n_tail = np.sum(vals >= x_min)
    C = (n_tail / n) * (x_min ** alpha_hat)
    return float(C), float(x_min), int(n_tail)


def run_replay(chain, alpha_hat=None):
    print(f"\n{'='*60}")
    print(f"Counterfactual Replay: {chain}")
    print(f"{'='*60}")

    try:
        vals, meta = load_data(chain)
    except FileNotFoundError:
        print(f"Data not found for {chain}. Run fetch_block_data.py first.")
        return None

    n = len(vals)
    print(f"N = {n} blocks")
    print(f"Value range: {vals.min()*1e6:.3f} – {vals.max()*1e3:.3f} mETH")

    # Load alpha_hat from results if available
    if alpha_hat is None:
        alpha_path = BASE.parent / "tail-index" / "results" / \
                     f"{chain}_alpha_estimates.json"
        try:
            with open(alpha_path) as f:
                r = json.load(f)
            alpha_hat = r["primary_estimate"]["alpha_hat"]
            if alpha_hat is None:
                alpha_hat = 1.18  # OP+Base combined fallback
            print(f"α̂ = {alpha_hat:.4f} (from Hill estimator)")
        except FileNotFoundError:
            alpha_hat = 1.18
            print(f"α̂ = {alpha_hat:.4f} (default OP+Base combined)")

    # Estimate C
    C_hat, x_min, n_tail = estimate_C(vals, alpha_hat)
    print(f"Ĉ = {C_hat:.4e} (x_min={x_min*1e6:.2f}μETH, n_tail={n_tail})")

    # Empirical violation rates
    emp_rates = compute_violation_rates(vals, B_MAX_SWEEP)

    # Theorem 2 theoretical bounds
    t2_bounds = compute_theorem2_bound(alpha_hat, C_hat, B_MAX_SWEEP)

    # Print comparison table
    print(f"\n{'B_max (ETH)':>14} | {'Empirical':>10} | {'Theorem 2':>10} | {'Ratio':>7}")
    print("-" * 52)
    for b in B_MAX_SWEEP:
        emp = emp_rates[b]
        t2  = t2_bounds[b]
        ratio = emp / t2 if t2 > 0 else float('inf')
        if emp > 0 or t2 < 1:  # skip trivial cases
            print(f"{b:>14.2e} | {emp*100:>9.2f}% | {min(t2,1)*100:>9.2f}% | {ratio:>7.2f}x")

    # A4 verification: what fraction of windows have V > B_max for key thresholds
    b_ref = 0.05  # mev-commit reference scenario
    b_small = np.percentile(vals, 70)  # calibrated to actual distribution
    print(f"\n=== A4 Operational Verification ===")
    print(f"B_ref = {b_ref} ETH (mev-commit worked example)")
    print(f"  Empirical: {emp_rates.get(b_ref, 0)*100:.2f}% of windows have V > B_ref")
    print(f"  T2 bound:  {min(t2_bounds.get(b_ref, 0),1)*100:.2f}%")
    print(f"B_small = {b_small*1e6:.2f} μETH (70th percentile)")
    print(f"  Empirical: {compute_violation_rates(vals, [b_small])[b_small]*100:.1f}%")

    # Save results
    PROC_DIR.mkdir(parents=True, exist_ok=True)
    out = {
        "chain":       chain,
        "n_windows":   n,
        "alpha_hat":   alpha_hat,
        "C_hat":       C_hat,
        "x_min":       x_min,
        "b_max_sweep": [float(b) for b in B_MAX_SWEEP],
        "empirical_violation_rates": {str(b): emp_rates[b] for b in B_MAX_SWEEP},
        "theorem2_bounds":           {str(b): t2_bounds[b] for b in B_MAX_SWEEP},
    }
    out_path = PROC_DIR / f"{chain}_replay_results.json"
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nResults saved to: {out_path}")

    # Plot
    if HAS_MPL:
        _plot_replay(chain, B_MAX_SWEEP, emp_rates, t2_bounds, alpha_hat)

    return out


def _plot_replay(chain, b_values, emp_rates, t2_bounds, alpha_hat):
    FIG_DIR.mkdir(parents=True, exist_ok=True)

    bs = np.array(b_values)
    emp = np.array([emp_rates[b] for b in b_values])
    t2  = np.minimum(np.array([t2_bounds[b] for b in b_values]), 1.0)

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.loglog(bs * 1e3, emp * 100, "o-", color="#1f77b4", lw=2,
              label="Empirical $\\hat{\\rho}(B_{\\max})$")
    ax.loglog(bs * 1e3, t2 * 100, "--", color="red", lw=1.5, alpha=0.7,
              label=f"Theorem 2 bound ($\\hat{{\\alpha}}={alpha_hat:.2f}$)")
    ax.axvline(50, ls=":", color="gray", lw=1, label="$B_{\\max}=0.05$ ETH (mev-commit)")
    ax.set_xlabel("$B_{\\max}$ (mETH)", fontsize=11)
    ax.set_ylabel("Violation rate (%)", fontsize=11)
    ax.set_title(f"A4 Violation Rate vs. Bond: {chain}", fontsize=10)
    ax.legend(fontsize=9)
    ax.grid(True, which="both", alpha=0.3)

    plt.tight_layout()
    for ext in ("pdf", "png"):
        path = FIG_DIR / f"{chain}_replay_violation_rate.{ext}"
        plt.savefig(path, dpi=150, bbox_inches="tight")
        print(f"Saved: {path}")
    plt.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--chain", default="optimism",
        choices=["all", "optimism", "base", "arbitrum"])
    parser.add_argument("--alpha", type=float, default=None,
        help="Override α̂ (default: use from Hill estimator results)")
    args = parser.parse_args()

    chains = ["optimism", "base", "arbitrum"] if args.chain == "all" else [args.chain]
    all_results = {}
    for chain in chains:
        r = run_replay(chain, alpha_hat=args.alpha)
        if r:
            all_results[chain] = r

    if len(all_results) > 1:
        print(f"\n=== Combined §5.4 Summary ===")
        print(f"{'Chain':15s} | {'B_max=1μETH':>12} | {'B_max=0.1mETH':>14} | {'B_max=50mETH':>13}")
        print("-" * 62)
        for chain, r in all_results.items():
            e = r["empirical_violation_rates"]
            print(f"{chain:15s} | {e.get('1e-06',0)*100:>11.1f}% | "
                  f"{e.get('0.0001',0)*100:>13.1f}% | "
                  f"{e.get('0.05',0)*100:>12.1f}%")
