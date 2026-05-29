"""
fi_classifier.py
Force-Inclusion Robustness Classifier for Deployed L2s

For each L2 in the inventory, this script:
1. Checks whether the FI entry-point function exists and is callable (on-chain)
2. Counts historical calls to the FI function (proxy for real usage)
3. Checks for known decorative indicators
4. Outputs a classification: functional / decorative_partial / decorative_full /
   economically_infeasible / no_mechanism

Usage:
    pip install web3 eth_abi requests
    export ETH_RPC=https://mainnet.infura.io/v3/YOUR_KEY
    python fi_classifier.py

Output: results/classification_report.json + results/fi_call_history.csv
"""

import json
import csv
import os
import time
from dataclasses import dataclass, asdict
from typing import Optional
from web3 import Web3
from web3.middleware import ExtraDataToPOAMiddleware

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ETH_RPC = os.environ.get("ETH_RPC", "https://eth.llamarpc.com")
ETHERSCAN_API_KEY = os.environ.get("ETHERSCAN_API_KEY", "")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "results")

# Minimal ABIs — only the FI-relevant functions
INBOX_ABI = [
    {
        "name": "forceInclusion",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "_totalDelayedMessagesRead", "type": "uint256"},
            {"name": "kind", "type": "uint8"},
            {"name": "l1BlockAndTime", "type": "uint64[2]"},
            {"name": "baseFeeL1", "type": "uint256"},
            {"name": "sender", "type": "address"},
            {"name": "messageDataHash", "type": "bytes32"},
        ],
        "outputs": [],
    },
    {
        "name": "maxTimeVariation",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [
            {"name": "delayBlocks", "type": "uint256"},
            {"name": "futureBlocks", "type": "uint256"},
            {"name": "delaySeconds", "type": "uint256"},
            {"name": "futureSeconds", "type": "uint256"},
        ],
    },
]

OPTIMISM_PORTAL_ABI = [
    {
        "name": "depositTransaction",
        "type": "function",
        "stateMutability": "payable",
        "inputs": [
            {"name": "_to", "type": "address"},
            {"name": "_value", "type": "uint256"},
            {"name": "_gasLimit", "type": "uint64"},
            {"name": "_isCreation", "type": "bool"},
            {"name": "_data", "type": "bytes"},
        ],
        "outputs": [],
    }
]

ZKSYNC_MAILBOX_ABI = [
    {
        "name": "requestL2Transaction",
        "type": "function",
        "stateMutability": "payable",
        "inputs": [
            {"name": "_contractL2", "type": "address"},
            {"name": "_l2Value", "type": "uint256"},
            {"name": "_calldata", "type": "bytes"},
            {"name": "_l2GasLimit", "type": "uint256"},
            {"name": "_l2GasPerPubdataByteLimit", "type": "uint256"},
            {"name": "_factoryDeps", "type": "bytes[]"},
            {"name": "_refundRecipient", "type": "address"},
        ],
        "outputs": [{"name": "canonicalTxHash", "type": "bytes32"}],
    }
]


# ---------------------------------------------------------------------------
# L2 Definitions
# ---------------------------------------------------------------------------

@dataclass
class L2Config:
    name: str
    chain_id: int
    fi_contract: str
    fi_function_sig: str
    abi: list
    delay_blocks: Optional[int]
    delay_seconds: Optional[int]
    permissionless: bool
    known_decorative: bool        # confirmed by prior work (L2BEAT etc.)
    known_decorative_source: str
    notes: str


L2_CONFIGS = [
    L2Config(
        name="Arbitrum One",
        chain_id=42161,
        fi_contract="0x1c479675ad559DC151F6Ec7ed3FbF8ceE79582B6",  # SequencerInbox
        fi_function_sig="forceInclusion(uint256,uint8,uint64[2],uint256,address,bytes32)",
        abi=INBOX_ABI,
        delay_blocks=5760,
        delay_seconds=86400,
        permissionless=True,
        known_decorative=False,
        known_decorative_source="",
        notes="FI callable by anyone after 24h; NO ordering constraint on included tx",
    ),
    L2Config(
        name="Optimism",
        chain_id=10,
        fi_contract="0x97cEbbf8959e2A5476fbe9B98A21806Ec234609B",  # OptimismPortal2
        fi_function_sig="depositTransaction(address,uint256,uint64,bool,bytes)",
        abi=OPTIMISM_PORTAL_ABI,
        delay_blocks=None,
        delay_seconds=43200,
        permissionless=True,
        known_decorative=True,
        known_decorative_source="Contract only emits event; no on-chain enforcement",
        notes="Event-only; enforcement in rollup node",
    ),
    L2Config(
        name="Base",
        chain_id=8453,
        fi_contract="0xC54cb22944F2bE476E02dECfCD7e3E7d3e15A8Fb",
        fi_function_sig="depositTransaction(address,uint256,uint64,bool,bytes)",
        abi=OPTIMISM_PORTAL_ABI,
        delay_blocks=None,
        delay_seconds=43200,
        permissionless=True,
        known_decorative=True,
        known_decorative_source="Inherits OP Stack event-only pattern",
        notes="Coinbase operated; same structural weakness as Optimism",
    ),
    L2Config(
        name="zkSync Era",
        chain_id=324,
        fi_contract="0x1800c60e4B916c4E8E1B122c70c80e95c9bF1C9D",  # DiamondProxy (Mailbox)
        fi_function_sig="requestL2Transaction(address,uint256,bytes,uint256,uint256,bytes[],address)",
        abi=ZKSYNC_MAILBOX_ABI,
        delay_blocks=None,
        delay_seconds=None,
        permissionless=True,
        known_decorative=True,
        known_decorative_source="L2BEAT: 'no mechanism that forces L2 Sequencer to include transactions from the queue'",
        notes="ITransactionFilterer can block queued txs; no timeout enforcement",
    ),
    # TODO: Add StarkNet, Linea, Scroll, Taiko, Polygon zkEVM, Mantle
]


# ---------------------------------------------------------------------------
# Classification Logic
# ---------------------------------------------------------------------------

@dataclass
class ClassificationResult:
    name: str
    classification: str              # functional | decorative_partial | decorative_full | economically_infeasible | no_mechanism
    fi_function_exists: bool
    delay_enforced_on_chain: bool
    ordering_constraint: bool
    permissionless: bool
    historical_fi_calls: Optional[int]
    delay_seconds: Optional[int]
    kill_switch_a: bool              # satisfies condition (a)?
    notes: str


def classify_l2(w3: Web3, config: L2Config) -> ClassificationResult:
    """
    Classify a single L2's force-inclusion mechanism.
    """
    print(f"\n[*] Classifying {config.name}...")

    # 1. Check if FI function exists in contract ABI (bytecode check)
    fi_function_exists = _check_function_exists(w3, config)

    # 2. Determine on-chain delay enforcement
    delay_enforced = _check_delay_enforced(w3, config)

    # 3. Ordering constraint — currently manual (requires reading sequencer logic)
    ordering_constraint = _check_ordering_constraint(config)

    # 4. Count historical calls
    historical_calls = _count_historical_fi_calls(config)

    # 5. Determine classification
    classification = _determine_classification(config, fi_function_exists, delay_enforced)

    # Kill-switch condition (a): decorative or no mechanism
    kill_switch_a = classification in ("decorative_full", "no_mechanism", "decorative_partial")

    return ClassificationResult(
        name=config.name,
        classification=classification,
        fi_function_exists=fi_function_exists,
        delay_enforced_on_chain=delay_enforced,
        ordering_constraint=ordering_constraint,
        permissionless=config.permissionless,
        historical_fi_calls=historical_calls,
        delay_seconds=config.delay_seconds,
        kill_switch_a=kill_switch_a,
        notes=config.notes,
    )


def _check_function_exists(w3: Web3, config: L2Config) -> bool:
    """
    Check if the FI function selector exists in the contract's bytecode.
    A more robust check than just calling the function.
    """
    try:
        addr = Web3.to_checksum_address(config.fi_contract)
        bytecode = w3.eth.get_code(addr)
        if len(bytecode) < 10:
            print(f"  [!] Contract at {config.fi_contract} has no bytecode (EOA or not deployed)")
            return False

        # Compute function selector
        from eth_hash.auto import keccak
        selector = keccak(config.fi_function_sig.encode())[:4].hex()
        print(f"  [+] Function selector: 0x{selector}")

        exists = selector in bytecode.hex()
        print(f"  [+] Selector in bytecode: {exists}")
        return exists
    except Exception as e:
        print(f"  [!] Error checking function existence: {e}")
        return False


def _check_delay_enforced(w3: Web3, config: L2Config) -> bool:
    """
    For Arbitrum: call maxTimeVariation() and verify delay params.
    For others: return False if no on-chain enforcement is known.
    """
    if config.name == "Arbitrum One":
        try:
            contract = w3.eth.contract(
                address=Web3.to_checksum_address(config.fi_contract),
                abi=INBOX_ABI,
            )
            result = contract.functions.maxTimeVariation().call()
            delay_blocks, future_blocks, delay_seconds, future_seconds = result
            print(f"  [+] maxTimeVariation: delayBlocks={delay_blocks}, delaySeconds={delay_seconds}")
            # Enforce: must be non-zero
            return delay_blocks > 0 and delay_seconds > 0
        except Exception as e:
            print(f"  [!] maxTimeVariation() failed: {e}")
            return False
    elif config.known_decorative:
        print(f"  [-] Known decorative — delay enforcement: False")
        return False
    else:
        # Default to unknown — requires manual audit
        return False


def _check_ordering_constraint(config: L2Config) -> bool:
    """
    Currently determined manually from contract audit.
    Returns True ONLY if we have confirmed on-chain ordering constraints.
    All currently surveyed L2s: False.
    """
    # No surveyed L2 has a confirmed on-chain ordering constraint for FI txs
    return False


def _count_historical_fi_calls(config: L2Config) -> Optional[int]:
    """
    Use Etherscan API to count historical calls to the FI function.
    Returns None if API key not available.
    """
    if not ETHERSCAN_API_KEY:
        print(f"  [!] No Etherscan API key — skipping historical call count")
        return None

    try:
        import requests
        # Compute function selector
        from eth_hash.auto import keccak
        selector = "0x" + keccak(config.fi_function_sig.encode())[:4].hex()

        url = (
            f"https://api.etherscan.io/api"
            f"?module=account&action=txlist"
            f"&address={config.fi_contract}"
            f"&startblock=0&endblock=99999999"
            f"&sort=asc&apikey={ETHERSCAN_API_KEY}"
        )
        resp = requests.get(url, timeout=10)
        data = resp.json()

        if data.get("status") != "1":
            print(f"  [!] Etherscan error: {data.get('message')}")
            return None

        txs = data.get("result", [])
        fi_calls = [tx for tx in txs if tx.get("input", "").startswith(selector)]
        count = len(fi_calls)
        print(f"  [+] Historical FI calls: {count}")
        return count
    except Exception as e:
        print(f"  [!] Etherscan query failed: {e}")
        return None


def _determine_classification(
    config: L2Config, fi_function_exists: bool, delay_enforced: bool
) -> str:
    if not fi_function_exists:
        return "no_mechanism"
    if config.known_decorative and not delay_enforced:
        return "decorative_full"
    if config.delay_seconds and config.delay_seconds > 7 * 24 * 3600:  # >1 week
        return "economically_infeasible"
    if delay_enforced:
        return "functional"
    return "decorative_partial"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"[*] Connecting to Ethereum RPC: {ETH_RPC}")
    w3 = Web3(Web3.HTTPProvider(ETH_RPC))
    w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)

    if not w3.is_connected():
        print("[!] Cannot connect to Ethereum RPC. Set ETH_RPC env variable.")
        return

    print(f"[+] Connected. Latest block: {w3.eth.block_number}")

    results = []
    for config in L2_CONFIGS:
        result = classify_l2(w3, config)
        results.append(asdict(result))
        time.sleep(0.5)  # rate limit

    # Write JSON report
    json_path = os.path.join(OUTPUT_DIR, "classification_report.json")
    with open(json_path, "w") as f:
        json.dump(
            {
                "generated": "2026-05-29",
                "kill_switch_condition_a": any(r["kill_switch_a"] for r in results),
                "results": results,
            },
            f,
            indent=2,
        )
    print(f"\n[+] JSON report written to {json_path}")

    # Write CSV
    csv_path = os.path.join(OUTPUT_DIR, "fi_call_history.csv")
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=asdict(results[0]).keys() if results else [])
        writer.writeheader()
        writer.writerows(results)
    print(f"[+] CSV written to {csv_path}")

    # Print kill-switch verdict
    print("\n" + "=" * 60)
    print("KILL-SWITCH CONDITION (a) STATUS:")
    decorative = [r["name"] for r in results if r["kill_switch_a"]]
    if decorative:
        print(f"  SATISFIED — {len(decorative)} L2(s) with decorative/non-functional FI:")
        for name in decorative:
            print(f"    - {name}")
    else:
        print("  NOT SATISFIED — all tested L2s have functional FI (unexpected)")
    print("=" * 60)


if __name__ == "__main__":
    main()
