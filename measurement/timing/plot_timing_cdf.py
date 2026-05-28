#!/usr/bin/env python3
"""
§5.1 Real-Stack Timing CDF
===========================
Generates the timing CDF figure for Section 5.1 of the paper.

Input:  measurement/timing/data/processed/astria_devnet_timing.json
Output: measurement/timing/figures/timing_cdf.pdf
        measurement/timing/figures/timing_cdf.png

Usage:
    python3 plot_timing_cdf.py
"""

import json
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path

BASE = Path(__file__).parent

def load_timing_data():
    path = BASE / "data/processed/astria_devnet_timing.json"
    with open(path) as f:
        return json.load(f)

def plot_cdf(gaps_ms, chain_id, out_prefix):
    """
    Plot empirical CDF of the commitment-to-observation gap.
    This is the §5.1 figure: the window available to an attacker between
    sequencer commitment and rollup execution.
    """
    gaps = np.array(sorted(gaps_ms))
    n    = len(gaps)
    cdf  = np.arange(1, n+1) / n

    fig, axes = plt.subplots(1, 2, figsize=(10, 4))

    # --- Left: CDF ---
    ax = axes[0]
    ax.step(gaps, cdf, where="post", color="#1f77b4", lw=2)
    ax.axvline(np.mean(gaps), color="red", ls="--", lw=1.2,
               label=f"Mean = {np.mean(gaps):.0f} ms")
    ax.axvline(np.percentile(gaps, 5), color="orange", ls=":", lw=1.2,
               label=f"P5 = {np.percentile(gaps, 5):.0f} ms")
    ax.set_xlabel("$t_{\\mathrm{observed}} - t_{\\mathrm{commit}}$ (ms)", fontsize=11)
    ax.set_ylabel("Empirical CDF", fontsize=11)
    ax.set_title(f"Commitment-to-Observation Gap\n(Chain: {chain_id})", fontsize=10)
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.set_ylim(0, 1.05)

    # --- Right: Histogram ---
    ax2 = axes[1]
    ax2.hist(gaps, bins=20, color="#1f77b4", alpha=0.7, edgecolor="white")
    ax2.axvline(np.mean(gaps), color="red", ls="--", lw=1.2,
                label=f"Mean = {np.mean(gaps):.0f} ms")
    ax2.set_xlabel("$t_{\\mathrm{observed}} - t_{\\mathrm{commit}}$ (ms)", fontsize=11)
    ax2.set_ylabel("Count", fontsize=11)
    ax2.set_title("Distribution of Timing Gap", fontsize=10)
    ax2.legend(fontsize=9)
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()

    out_dir = BASE / "figures"
    out_dir.mkdir(parents=True, exist_ok=True)

    for ext in ("pdf", "png"):
        path = out_dir / f"{out_prefix}.{ext}"
        plt.savefig(path, dpi=150, bbox_inches="tight")
        print(f"Saved: {path}")

    plt.close()

    # --- Stats summary ---
    print(f"\n=== §5.1 Timing Statistics ({chain_id}) ===")
    print(f"  N blocks:      {n}")
    print(f"  Min gap:       {np.min(gaps):.1f} ms")
    print(f"  P5 gap:        {np.percentile(gaps, 5):.1f} ms")
    print(f"  Median gap:    {np.median(gaps):.1f} ms")
    print(f"  Mean gap:      {np.mean(gaps):.1f} ms")
    print(f"  P95 gap:       {np.percentile(gaps, 95):.1f} ms")
    print(f"  Max gap:       {np.max(gaps):.1f} ms")
    print(f"  Std dev:       {np.std(gaps):.1f} ms")
    print()
    print(f"  Interpretation for §5.1:")
    print(f"  The mean {np.mean(gaps):.0f}ms gap is the window in which an attacker")
    print(f"  can observe τ₁'s execution outcome and front-run τ₂.")
    print(f"  Even the minimum observed gap ({np.min(gaps):.0f}ms) exceeds typical")
    print(f"  mempool monitoring latency (~10-50ms for MEV searchers).")

    return {
        "n": n,
        "min_ms": float(np.min(gaps)),
        "p5_ms": float(np.percentile(gaps, 5)),
        "median_ms": float(np.median(gaps)),
        "mean_ms": float(np.mean(gaps)),
        "p95_ms": float(np.percentile(gaps, 95)),
        "max_ms": float(np.max(gaps)),
        "std_ms": float(np.std(gaps)),
    }

if __name__ == "__main__":
    data = load_timing_data()
    gaps_ms = [b["gap_ms"] for b in data["blocks"]]
    chain_id = data.get("chain_id", "astria-devnet")

    stats = plot_cdf(gaps_ms, chain_id, "timing_cdf")

    # Save stats as JSON for §5.1 LaTeX table
    import json
    stats_path = BASE / "data/processed/timing_stats.json"
    with open(stats_path, "w") as f:
        json.dump({"chain_id": chain_id, "stats": stats}, f, indent=2)
    print(f"\nStats saved to: {stats_path}")
    print("Use these numbers in §5.1 text and the timing CDF figure.")
