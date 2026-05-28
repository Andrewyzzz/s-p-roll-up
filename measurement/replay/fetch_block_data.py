#!/usr/bin/env python3
"""
Task 7.1 — Mainnet Block Data Acquisition
==========================================
Fetches 12 months of block-level fee data from four L2 chains for the
counterfactual replay study (§5.3) and tail-index estimation (§5.3.1).

The "option value" proxy for each block is the total transaction fee revenue:
    V(block) = sum_i (gasUsed_i * effectiveGasPrice_i)
             ≈ baseFeePerGas * gasUsed + sum(priorityFees)

This is a lower bound on the true option value (does not include MEV).
For the paper, we use this distribution to estimate the tail index α
in Theorem 2.

Usage:
    python3 fetch_block_data.py [--chain all|optimism|base|arbitrum|polygon_zkevm]
                                [--samples 5000]
                                [--output data/raw/]

Output:
    data/raw/<chain>_block_fees_12mo.json  — per-block fee data
    data/processed/<chain>_option_values.parquet — processed for replay
"""

import json
import time
import random
import argparse
import os
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timezone

# ── Chain configuration ──────────────────────────────────────────────────────

CHAINS = {
    "optimism": {
        "rpc":        "https://mainnet.optimism.io",
        "block_time": 2.0,    # seconds per block
        "chain_id":   10,
    },
    "base": {
        "rpc":        "https://base-pokt.nodies.app",
        "block_time": 2.0,
        "chain_id":   8453,
    },
    "arbitrum": {
        "rpc":        "https://arb-pokt.nodies.app",
        "block_time": 0.25,   # ~250ms Nitro blocks
        "chain_id":   42161,
    },
    "polygon_zkevm": {
        "rpc":        "https://polygon-zkevm.drpc.org",
        "block_time": 2.0,
        "chain_id":   1101,
    },
}

SECONDS_PER_YEAR = 365 * 24 * 3600
BASE = Path(__file__).parent


# ── RPC helpers ───────────────────────────────────────────────────────────────

def rpc_call(rpc_url, method, params, retries=3, timeout=15):
    """Single JSON-RPC call with retry."""
    payload = json.dumps({
        "jsonrpc": "2.0",
        "method":  method,
        "params":  params,
        "id":      1,
    }).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                rpc_url, data=payload,
                headers={"Content-Type": "application/json"})
            resp = json.loads(
                urllib.request.urlopen(req, timeout=timeout).read())
            if "error" in resp:
                raise ValueError(f"RPC error: {resp['error']}")
            return resp["result"]
        except (urllib.error.URLError, ValueError) as e:
            if attempt == retries - 1:
                raise
            time.sleep(0.5 * (attempt + 1))


def rpc_batch(rpc_url, calls, timeout=30):
    """Batch JSON-RPC call (up to 20 at once)."""
    payload = json.dumps([
        {"jsonrpc": "2.0", "method": m, "params": p, "id": i}
        for i, (m, p) in enumerate(calls)
    ]).encode()
    req = urllib.request.Request(
        rpc_url, data=payload,
        headers={"Content-Type": "application/json"})
    results = json.loads(
        urllib.request.urlopen(req, timeout=timeout).read())
    # Sort by id and return results
    return [r["result"] for r in sorted(results, key=lambda x: x["id"])]


def get_latest_block(rpc_url):
    return int(rpc_call(rpc_url, "eth_blockNumber", []), 16)


def get_block(rpc_url, block_number):
    """Fetch block with full transaction details.

    Using True to get all transaction objects, which are needed to compute
    the correct option value proxy: Σ gasUsed_i × effectiveGasPrice_i.
    effectiveGasPrice = baseFee + priorityFee, where priorityFee is the
    sequencer's actual income (baseFee is burned in EIP-1559).

    Speed: ~1-2s per block. For 300 samples: ~5-10 min per chain.
    For 2000 samples: 30-60 min per chain (use --samples 300 for speed).
    """
    return rpc_call(
        rpc_url, "eth_getBlockByNumber",
        [hex(block_number), True])    # True = full transactions


# ── Option value computation ──────────────────────────────────────────────────

def compute_block_option_value(block):
    """
    Compute the option value proxy: Σ gasUsed_i × effectiveGasPrice_i.

    effectiveGasPrice = baseFee + min(maxPriorityFee, maxFee - baseFee)
    This captures both the base fee and the priority fee (tip) that goes
    to the sequencer/validator. For Theorem 2, this is the economically
    correct proxy: it represents what the sequencer could earn by optimizing
    block composition.

    Conservative: excludes MEV (sandwich, liquidations, arbitrage).
    Returns value in ETH (float).
    """
    if block is None:
        return None

    base_fee = int(block.get("baseFeePerGas", "0x0"), 16)  # wei
    total_fees_wei = 0

    for tx in block.get("transactions", []):
        gas_used = int(tx.get("gas", "0x0"), 16)

        if "maxFeePerGas" in tx:
            max_fee      = int(tx["maxFeePerGas"], 16)
            max_priority = int(tx.get("maxPriorityFeePerGas", "0x0"), 16)
            effective    = min(max_fee, base_fee + max_priority)
        else:
            effective = int(tx.get("gasPrice", "0x0"), 16)

        total_fees_wei += gas_used * effective

    return total_fees_wei / 1e18


# ── Main acquisition loop ─────────────────────────────────────────────────────

def fetch_chain(chain_name, num_samples=5000, output_dir=None):
    cfg = CHAINS[chain_name]
    rpc = cfg["rpc"]

    print(f"\n{'='*60}")
    print(f"Chain: {chain_name} (chain_id={cfg['chain_id']})")
    print(f"RPC:   {rpc}")
    print(f"Target samples: {num_samples}")

    # Determine block range (last 12 months)
    latest  = get_latest_block(rpc)
    blocks_per_year = int(SECONDS_PER_YEAR / cfg["block_time"])
    start   = max(0, latest - blocks_per_year)
    interval = max(1, (latest - start) // num_samples)

    print(f"Latest block: {latest:,}")
    print(f"Start block:  {start:,}  (~12 months ago)")
    print(f"Sampling every {interval} blocks → ~{(latest-start)//interval} samples")

    # Build sample list (uniform + small random jitter to avoid alignment artifacts)
    sample_blocks = list(range(start, latest, interval))
    # Add ±5% jitter
    jittered = []
    for b in sample_blocks:
        jitter = random.randint(-interval//20, interval//20)
        jittered.append(max(start, min(latest-1, b + jitter)))
    sample_blocks = sorted(set(jittered))

    print(f"Sampling {len(sample_blocks)} blocks...")

    results = []
    errors  = 0
    t_start = time.time()

    BATCH       = 5    # conservative: full-tx blocks are large
    RATE_DELAY  = 0.1  # 10 req/s — respectful of public RPCs with full block data

    for i in range(0, len(sample_blocks), BATCH):
        batch = sample_blocks[i:i+BATCH]

        for bn in batch:
            try:
                block = get_block(rpc, bn)
                if block is None:
                    continue

                timestamp   = int(block.get("timestamp",    "0x0"), 16)
                gas_used    = int(block.get("gasUsed",       "0x0"), 16)
                base_fee    = int(block.get("baseFeePerGas", "0x0"), 16) / 1e9  # gwei
                # tx_count not available in header-only response (transactions=[])
                option_val  = compute_block_option_value(block)

                results.append({
                    "block":            bn,
                    "timestamp":        timestamp,
                    "date":             datetime.fromtimestamp(
                                            timestamp, tz=timezone.utc
                                        ).isoformat(),
                    "gas_used":         gas_used,
                    "base_fee_gwei":    base_fee,
                    "option_value_eth": option_val,
                })
                time.sleep(RATE_DELAY)

            except Exception as e:
                errors += 1

        # Progress report every 200 blocks
        if (i // BATCH) % 10 == 0:
            elapsed = time.time() - t_start
            done    = i + len(batch)
            rate    = done / elapsed if elapsed > 0 else 0
            eta     = (len(sample_blocks) - done) / rate if rate > 0 else 0
            print(f"  [{done:5d}/{len(sample_blocks)}] "
                  f"errors={errors}  "
                  f"rate={rate:.1f}/s  "
                  f"ETA={eta/60:.1f}min")

    elapsed = time.time() - t_start
    print(f"\nFetched {len(results)} blocks in {elapsed/60:.1f} min "
          f"({errors} errors)")

    # Save raw data (incremental: write after each successful batch)
    if output_dir:
        out_dir = Path(output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{chain_name}_block_fees_12mo.json"
        with open(out_path, "w") as f:
            json.dump({
                "chain":          chain_name,
                "chain_id":       cfg["chain_id"],
                "latest_block":   latest,
                "start_block":    start,
                "interval":       interval,
                "num_samples":    len(results),
                "fetch_errors":   errors,
                "fetched_at_utc": datetime.now(tz=timezone.utc).isoformat(),
                "blocks":         results,
            }, f)
        print(f"Saved: {out_path}")

    return results


def print_summary(chain_name, results):
    vals = [r["option_value_eth"] for r in results
            if r.get("option_value_eth") is not None and r["option_value_eth"] > 0]

    if not vals:
        print(f"{chain_name}: no valid option values")
        return

    import statistics
    vals_sorted = sorted(vals)
    n = len(vals_sorted)

    print(f"\n=== {chain_name} Option Value Summary ===")
    print(f"  N:       {n}")
    print(f"  Min:     {min(vals):.6f} ETH")
    print(f"  P50:     {statistics.median(vals):.6f} ETH")
    print(f"  P95:     {vals_sorted[int(0.95*n)]:.6f} ETH")
    print(f"  P99:     {vals_sorted[int(0.99*n)]:.6f} ETH")
    print(f"  Max:     {max(vals):.6f} ETH")
    print(f"  Mean:    {statistics.mean(vals):.6f} ETH")
    print(f"  (used for tail-index estimation in §5.3.1)")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Fetch 12-month block fee data for §5.3 measurement study")
    parser.add_argument("--chain",   default="optimism",
        choices=["all"] + list(CHAINS.keys()),
        help="Which chain(s) to fetch")
    parser.add_argument("--samples", type=int, default=2000,
        help="Target number of samples per chain (default: 2000)")
    parser.add_argument("--output",  default=None,
        help="Output directory (default: measurement/replay/data/raw/)")
    args = parser.parse_args()

    out = args.output or str(
        BASE / "data" / "raw")

    targets = list(CHAINS.keys()) if args.chain == "all" else [args.chain]

    for chain in targets:
        try:
            results = fetch_chain(chain, num_samples=args.samples,
                                  output_dir=out)
            print_summary(chain, results)
        except Exception as e:
            print(f"ERROR fetching {chain}: {e}")
            import traceback; traceback.print_exc()
