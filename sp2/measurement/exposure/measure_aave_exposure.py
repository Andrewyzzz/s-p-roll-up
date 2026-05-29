"""
measure_aave_exposure.py
========================
C3: Empirical exposure measurement for "Included but Not Saved"

Measures the value-at-risk (VaR) for DeFi users on Aave V3 across
force-inclusion-vulnerable L2s. The core metric:

    VaR = TVL in positions with HF ∈ [1.0, HF_MAX]

where HF_MAX = 1.0 + (adversary's max price-move capability in window).

For a 20% price drop (as demonstrated in Part 2):
    HF < 1.0 after drop iff HF_initial < 1.0 / (1 - 0.20) = 1.25
So we use HF_MAX = 1.25 as the "attackable" threshold.

Methodology:
1. Use Aave V3 subgraph to enumerate all active borrowers
2. Batch-call AaveProtocolDataProvider.getUserAccountData() via RPC
3. Filter for HF ∈ [1.0, 1.25] — the "window-exploitable" range
4. Sum totalDebtBase → value-at-risk per chain

Chains measured:
- Base       (OptimismPortal, 12h window)  — attack demonstrated in Part 2
- Arbitrum   (SequencerInbox, 24h window)  — ordering-freedom attack
- Optimism   (OptimismPortal, 12h window)  — same architecture as Base

Usage:
    pip install requests web3
    python measure_aave_exposure.py [--rpc-base URL] [--rpc-arb URL] [--rpc-op URL]

Output:
    results/aave_exposure.json   — per-chain breakdown
    results/aave_exposure.csv    — tabular summary for paper
"""

import json
import csv
import time
import argparse
import os
from dataclasses import dataclass, asdict, field
from typing import Optional

import requests
from web3 import Web3

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# HF thresholds
HF_LIQUIDATABLE   = 1.0    # below this = liquidatable NOW
HF_ATTACKABLE_20  = 1.25   # HF < this → liquidatable after 20% price drop
HF_ATTACKABLE_15  = 1.18   # HF < this → liquidatable after 15% price drop
HF_ATTACKABLE_10  = 1.11   # HF < this → liquidatable after 10% price drop

CHAINS = {
    "base": {
        "rpc":        os.environ.get("BASE_RPC", "https://base.publicnode.com"),
        "data_provider": "0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A",
        "pool":          "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5",
        "fi_window_h":   12,
        "fi_type":       "delay_window",
        "subgraph_url":  "https://gateway.thegraph.com/api/subgraphs/id/GQFbb95cE6d8mV989mL5figjaGaKCQB3xqYrr1bRyXqF",
        "chain_id":      8453,
    },
    "arbitrum": {
        "rpc":        os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc"),
        "data_provider": "0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654",
        "pool":          "0x794a61358D6845594F94dc1DB02A252b5b4814aD",
        "fi_window_h":   24,
        "fi_type":       "ordering_freedom",
        "subgraph_url":  "https://gateway.thegraph.com/api/subgraphs/id/DLuE98kEb5pQNXAcKFQGQgfSQ57Xdou4jnVbAEqMfy3B",
        "chain_id":      42161,
    },
    "optimism": {
        "rpc":        os.environ.get("OP_RPC", "https://mainnet.optimism.io"),
        "data_provider": "0x243Aa95cAC2a25651eda86e80bEe66114413c43b",
        "pool":          "0x794a61358D6845594F94dc1DB02A252b5b4814aD",
        "fi_window_h":   12,
        "fi_type":       "delay_window",
        "subgraph_url":  "https://gateway.thegraph.com/api/subgraphs/id/DSfLz8oQBUeU5atALgUFQKMTSYV9mZAVYp4noLSXAfvb",
        "chain_id":      10,
    },
}

# Minimal ABI for getUserAccountData
DATA_PROVIDER_ABI = [
    {
        "name": "getUserAccountData",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "user", "type": "address"}],
        "outputs": [
            {"name": "totalCollateralBase",          "type": "uint256"},
            {"name": "totalDebtBase",                 "type": "uint256"},
            {"name": "availableBorrowsBase",          "type": "uint256"},
            {"name": "currentLiquidationThreshold",   "type": "uint256"},
            {"name": "ltv",                           "type": "uint256"},
            {"name": "healthFactor",                  "type": "uint256"},
        ],
    }
]

# ---------------------------------------------------------------------------
# Subgraph query for active borrowers
# ---------------------------------------------------------------------------

BORROWERS_QUERY = """
query GetBorrowers($skip: Int!) {
  users(
    first: 1000
    skip: $skip
    where: { borrowedReservesCount_gt: 0 }
    orderBy: id
  ) {
    id
    borrowedReservesCount
  }
}
"""

def fetch_borrowers_from_subgraph(subgraph_url: str, max_users: int = 5000) -> list[str]:
    """
    Fetch all active borrowers from Aave V3 subgraph.
    Returns list of user addresses.
    """
    addresses = []
    skip = 0
    headers = {"Content-Type": "application/json"}

    print(f"  Fetching borrowers from subgraph (max {max_users})...")
    while len(addresses) < max_users:
        payload = {
            "query": BORROWERS_QUERY,
            "variables": {"skip": skip}
        }
        try:
            resp = requests.post(subgraph_url, json=payload, headers=headers, timeout=30)
            data = resp.json()
            if "errors" in data:
                print(f"  Subgraph error: {data['errors']}")
                break
            users = data.get("data", {}).get("users", [])
            if not users:
                break
            addresses.extend([u["id"] for u in users])
            skip += 1000
            if len(users) < 1000:
                break
            time.sleep(0.5)  # rate limit
        except Exception as e:
            print(f"  Subgraph fetch failed: {e}")
            break

    print(f"  Found {len(addresses)} active borrowers")
    return addresses[:max_users]


def fetch_borrowers_from_events(w3: Web3, pool_address: str,
                                 from_block: int = 0) -> list[str]:
    """
    Fallback: fetch borrowers from Borrow events on-chain.
    Uses limited block range for speed.
    """
    # Borrow(address,address,address,uint256,uint256,uint256,uint16)
    # topic0 = keccak256("Borrow(address,address,address,uint256,uint256,uint256,uint16)")
    BORROW_TOPIC = "0xc6a898309e823ee50bac64e45ca8adba6690e99e7841c45d754e2a38e9019d9b"

    latest = w3.eth.block_number
    # Sample last 7 days (~302400 blocks at 2s/block for Base, ~50400 at 12s for Arb)
    sample_from = max(from_block, latest - 300_000)

    print(f"  Fetching Borrow events from block {sample_from} to {latest}...")
    try:
        logs = w3.eth.get_logs({
            "fromBlock": sample_from,
            "toBlock":   latest,
            "address":   Web3.to_checksum_address(pool_address),
            "topics":    [BORROW_TOPIC],
        })
        # The onBehalfOf field is topic[3] (3rd indexed param)
        addresses = set()
        for log in logs:
            if len(log["topics"]) >= 3:
                addr = "0x" + log["topics"][2].hex()[-40:]
                addresses.add(addr)
        result = list(addresses)
        print(f"  Found {len(result)} unique borrowers from events")
        return result
    except Exception as e:
        print(f"  Event fetch failed: {e}")
        return []


# ---------------------------------------------------------------------------
# Batch HF measurement
# ---------------------------------------------------------------------------

@dataclass
class PositionStats:
    chain: str
    fi_window_h: int
    fi_type: str
    users_sampled: int
    users_with_debt: int
    # Near-liquidation buckets
    liquidatable_now_debt_usd: float = 0.0     # HF < 1.0
    attackable_10pct_debt_usd: float = 0.0    # HF ∈ [1.0, 1.11)
    attackable_15pct_debt_usd: float = 0.0    # HF ∈ [1.0, 1.18)
    attackable_20pct_debt_usd: float = 0.0    # HF ∈ [1.0, 1.25)
    total_debt_usd: float = 0.0
    # Counts
    n_liquidatable_now: int = 0
    n_attackable_10pct: int = 0
    n_attackable_15pct: int = 0
    n_attackable_20pct: int = 0
    # Block info
    block_number: int = 0
    timestamp: str = ""
    # Sample fraction
    sample_fraction: float = 1.0


def measure_positions(chain_name: str, cfg: dict,
                      max_users: int = 3000) -> PositionStats:
    """
    Measure near-liquidation positions for a single chain.
    """
    print(f"\n[{chain_name.upper()}] Measuring positions...")
    print(f"  RPC: {cfg['rpc']}")

    w3 = Web3(Web3.HTTPProvider(cfg["rpc"]))
    if not w3.is_connected():
        print(f"  Cannot connect to {cfg['rpc']}")
        return PositionStats(chain=chain_name, fi_window_h=cfg["fi_window_h"],
                             fi_type=cfg["fi_type"], users_sampled=0, users_with_debt=0)

    block = w3.eth.block_number
    print(f"  Connected. Block: {block}")

    dp = w3.eth.contract(
        address=Web3.to_checksum_address(cfg["data_provider"]),
        abi=DATA_PROVIDER_ABI,
    )

    # Get borrowers: try subgraph first, fall back to events
    addresses = fetch_borrowers_from_subgraph(cfg["subgraph_url"], max_users)
    if len(addresses) < 100:
        addresses = fetch_borrowers_from_events(w3, cfg["pool"])
    if not addresses:
        print(f"  No borrowers found for {chain_name}")
        return PositionStats(chain=chain_name, fi_window_h=cfg["fi_window_h"],
                             fi_type=cfg["fi_type"], users_sampled=0, users_with_debt=0)

    stats = PositionStats(
        chain=chain_name,
        fi_window_h=cfg["fi_window_h"],
        fi_type=cfg["fi_type"],
        users_sampled=len(addresses),
        users_with_debt=0,
        block_number=block,
        timestamp=str(int(time.time())),
    )

    print(f"  Querying {len(addresses)} users for HF data...")
    BATCH = 50
    for i in range(0, len(addresses), BATCH):
        batch = addresses[i:i+BATCH]
        for addr in batch:
            try:
                result = dp.functions.getUserAccountData(
                    Web3.to_checksum_address(addr)
                ).call()
                (totalCollateral, totalDebt, _, _, _, hf_raw) = result

                if totalDebt == 0:
                    continue
                stats.users_with_debt += 1

                # Convert from base currency (8 dec) to USD
                debt_usd = totalDebt / 1e8
                stats.total_debt_usd += debt_usd

                # Health factor: raw is 1e18 scale
                hf = hf_raw / 1e18

                if hf < HF_LIQUIDATABLE:
                    stats.liquidatable_now_debt_usd += debt_usd
                    stats.n_liquidatable_now += 1

                if HF_LIQUIDATABLE <= hf < HF_ATTACKABLE_10:
                    stats.attackable_10pct_debt_usd += debt_usd
                    stats.n_attackable_10pct += 1

                if HF_LIQUIDATABLE <= hf < HF_ATTACKABLE_15:
                    stats.attackable_15pct_debt_usd += debt_usd
                    stats.n_attackable_15pct += 1

                if HF_LIQUIDATABLE <= hf < HF_ATTACKABLE_20:
                    stats.attackable_20pct_debt_usd += debt_usd
                    stats.n_attackable_20pct += 1

            except Exception:
                pass  # skip failed lookups

        if i % 500 == 0 and i > 0:
            print(f"  Progress: {i}/{len(addresses)} users, "
                  f"at-risk (20% drop): ${stats.attackable_20pct_debt_usd:,.0f}")
            time.sleep(0.2)

    return stats


# ---------------------------------------------------------------------------
# Value-at-risk calculation
# ---------------------------------------------------------------------------

def compute_var(stats: PositionStats) -> dict:
    """
    Compute value-at-risk metrics for the paper.

    VaR for a single-event attack = attackable TVL * P(adversary acts)
    For a conservative lower bound, assume P=1 when position is exploitable.
    """
    return {
        "chain":                   stats.chain,
        "fi_window_h":             stats.fi_window_h,
        "fi_type":                 stats.fi_type,
        "users_sampled":           stats.users_sampled,
        "users_with_debt":         stats.users_with_debt,
        "total_debt_usd":          round(stats.total_debt_usd, 2),
        "var_10pct_drop_usd":      round(stats.attackable_10pct_debt_usd, 2),
        "var_15pct_drop_usd":      round(stats.attackable_15pct_debt_usd, 2),
        "var_20pct_drop_usd":      round(stats.attackable_20pct_debt_usd, 2),
        "n_positions_10pct":       stats.n_attackable_10pct,
        "n_positions_15pct":       stats.n_attackable_15pct,
        "n_positions_20pct":       stats.n_attackable_20pct,
        "pct_tvl_at_risk_20pct":   round(
            stats.attackable_20pct_debt_usd / max(stats.total_debt_usd, 1) * 100, 2
        ),
        "block_number":            stats.block_number,
        "timestamp":               stats.timestamp,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--chains",     default="base,arbitrum,optimism",
                        help="Comma-separated chains to measure")
    parser.add_argument("--max-users",  type=int, default=3000,
                        help="Max users to sample per chain")
    parser.add_argument("--output-dir", default="results")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    chains_to_measure = [c.strip() for c in args.chains.split(",")]

    all_results = []
    for chain_name in chains_to_measure:
        if chain_name not in CHAINS:
            print(f"Unknown chain: {chain_name}")
            continue
        cfg = CHAINS[chain_name]
        stats = measure_positions(chain_name, cfg, args.max_users)
        var = compute_var(stats)
        all_results.append(var)

        print(f"\n  [{chain_name.upper()}] Summary:")
        print(f"    Users sampled:         {var['users_sampled']:,}")
        print(f"    Users with debt:       {var['users_with_debt']:,}")
        print(f"    Total debt TVL:        ${var['total_debt_usd']:>14,.0f}")
        print(f"    VaR (10% drop):        ${var['var_10pct_drop_usd']:>14,.0f}  "
              f"({var['n_positions_10pct']} positions)")
        print(f"    VaR (15% drop):        ${var['var_15pct_drop_usd']:>14,.0f}  "
              f"({var['n_positions_15pct']} positions)")
        print(f"    VaR (20% drop):        ${var['var_20pct_drop_usd']:>14,.0f}  "
              f"({var['n_positions_20pct']} positions)")
        print(f"    % TVL at risk (20%):   {var['pct_tvl_at_risk_20pct']:.1f}%")

    # Write JSON
    json_path = os.path.join(args.output_dir, "aave_exposure.json")
    with open(json_path, "w") as f:
        json.dump({"generated": int(time.time()), "results": all_results}, f, indent=2)
    print(f"\nJSON written to {json_path}")

    # Write CSV
    csv_path = os.path.join(args.output_dir, "aave_exposure.csv")
    if all_results:
        with open(csv_path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=all_results[0].keys())
            w.writeheader()
            w.writerows(all_results)
    print(f"CSV  written to {csv_path}")

    # Print paper table
    print("\n" + "="*70)
    print("PAPER TABLE — Value-at-Risk by Chain")
    print("="*70)
    print(f"{'Chain':<12} {'FI Window':<12} {'Attack Type':<20} "
          f"{'VaR 20% drop':>14} {'% of TVL':>10}")
    print("-"*70)
    total_var = 0
    for r in all_results:
        print(f"{r['chain']:<12} {r['fi_window_h']}h{'':9} {r['fi_type']:<20} "
              f"${r['var_20pct_drop_usd']:>13,.0f} {r['pct_tvl_at_risk_20pct']:>9.1f}%")
        total_var += r['var_20pct_drop_usd']
    print("-"*70)
    print(f"{'TOTAL':<12} {'':12} {'':20} ${total_var:>13,.0f}")
    print("="*70)


if __name__ == "__main__":
    main()
