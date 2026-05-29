#!/usr/bin/env python3
"""
gen_fixture.py
==============
Generates a synthetic L1 deposit fixture for TrustlessRescueTest.

Design: single-entry receipt MPT (simplest possible valid proof).
No external MPT library needed — implements nibble/hex-prefix encoding directly.

Output: a Solidity snippet to paste into _loadRealDepositFixture().

Usage: python3 script/gen_fixture.py
"""

import rlp
from eth_hash.auto import keccak as keccak256_fn
import struct

# ── Known constants ──────────────────────────────────────────────────────────

# Base OptimismPortal on L1 Ethereum
PORTAL_ADDR  = bytes.fromhex("49048044D57e1C92A77f79988d21Fa8fAF74E97e")

# keccak256("TransactionDeposited(address,address,uint256,bytes)")
TX_DEPOSITED_TOPIC = bytes.fromhex(
    "b3813568d9991fc951961fcb4c784893574240a28925604d09fc577c55bb7c32"
)

# Synthetic victim address
VICTIM_ADDR  = bytes.fromhex("DeaDDeaDDeaDDeaDDeaDDeaDDeaDDeaDDeaDDeaD")

# ── Helpers ──────────────────────────────────────────────────────────────────

def keccak(data: bytes) -> bytes:
    return keccak256_fn(data)

def int_to_minimal_bytes(n: int) -> bytes:
    """Minimal big-endian bytes for integer n (0 → b'')."""
    if n == 0:
        return b""
    return n.to_bytes((n.bit_length() + 7) // 8, "big")

def rlp_encode_uint(n: int) -> bytes:
    """RLP-encode an integer (as used by Ethereum MPT keys)."""
    b = int_to_minimal_bytes(n)
    return rlp.encode(b)

def hex_prefix_leaf(nibbles: list[int]) -> bytes:
    """Hex-prefix encoding for a LEAF node."""
    if len(nibbles) % 2 == 0:
        return bytes([0x20]) + bytes(
            [(nibbles[i] << 4) | nibbles[i+1] for i in range(0, len(nibbles), 2)]
        )
    else:
        return bytes([0x30 | nibbles[0]]) + bytes(
            [(nibbles[i] << 4) | nibbles[i+1] for i in range(1, len(nibbles), 2)]
        )

def bytes_to_nibbles(b: bytes) -> list[int]:
    """Convert bytes to a list of nibbles."""
    return [n for byte in b for n in (byte >> 4, byte & 0x0F)]

# ── Step 1: Build the receipt ────────────────────────────────────────────────

# TransactionDeposited(from=VICTIM, to=VICTIM, version=0, opaqueData=...)
topic0 = TX_DEPOSITED_TOPIC                          # event sig
topic1 = b'\x00' * 12 + VICTIM_ADDR                 # from (indexed, padded)
topic2 = b'\x00' * 12 + VICTIM_ADDR                 # to   (indexed, padded)
topic3 = b'\x00' * 32                               # version = 0

opaque_data = b'\x00' * 32  # minimal opaqueData

# Log: [address, [topic0, topic1, topic2, topic3], data]
log = [PORTAL_ADDR, [topic0, topic1, topic2, topic3], opaque_data]

# EIP-2718 type-2 receipt: type_byte || RLP([status, cumGas, logsBloom, logs])
receipt_inner = rlp.encode([b'\x01', 21000, b'\x00' * 256, [log]])
receipt_rlp   = b'\x02' + receipt_inner

print(f"Receipt RLP length: {len(receipt_rlp)} bytes")

# ── Step 2: Single-entry receipt MPT ─────────────────────────────────────────
# Key   = RLP(txIndex=0)
# Value = receipt_rlp
#
# For txIndex=0: RLP(0) = b'\x80' (empty bytes in RLP)
# Nibbles of b'\x80': [8, 0]
# Leaf hex-prefix (even nibbles, leaf flag): [0x20, 0x80]

tx_key   = rlp_encode_uint(0)            # b'\x80'
nibbles  = bytes_to_nibbles(tx_key)      # [8, 0]
leaf_key = hex_prefix_leaf(nibbles)      # b'\x20\x80'

leaf_node_rlp = rlp.encode([leaf_key, receipt_rlp])
receipts_root = keccak(leaf_node_rlp)

print(f"tx_key   : {tx_key.hex()}")
print(f"nibbles  : {nibbles}")
print(f"leaf_key : {leaf_key.hex()}")
print(f"receipts_root: {receipts_root.hex()}")

# Self-check: keccak256(leaf_node_rlp) == receipts_root ✓
assert keccak(leaf_node_rlp) == receipts_root, "BUG: leaf hash != root"

trie_proof = [leaf_node_rlp]

# ── Step 3: Fake L1 block header ─────────────────────────────────────────────
# Minimal post-Merge header with correct receiptsRoot at field index 5.
# Field order per EIP-3675:
#   0 parentHash  1 ommersHash  2 coinbase  3 stateRoot  4 txRoot
#   5 receiptsRoot  6 logsBloom  7 difficulty  8 number
#   9 gasLimit  10 gasUsed  11 timestamp  12 extraData
#  13 mixHash  14 nonce  15 baseFeePerGas  16 withdrawalsRoot

fake_header = [
    b'\x00' * 32,                   # parentHash
    b'\x00' * 32,                   # ommersHash
    b'\x00' * 20,                   # coinbase
    b'\x00' * 32,                   # stateRoot
    b'\x00' * 32,                   # transactionsRoot
    receipts_root,                   # receiptsRoot  ← field[5] ← THE KEY FIELD
    b'\x00' * 256,                  # logsBloom
    b'',                            # difficulty = 0 (PoS)
    b'\x01',                        # number = 1
    (30_000_000).to_bytes(4, 'big'),# gasLimit
    (21_000).to_bytes(3, 'big'),    # gasUsed
    (1_700_000_000).to_bytes(4,'big'),  # timestamp
    b'',                            # extraData (empty)
    b'\x00' * 32,                   # mixHash
    b'\x00' * 8,                    # nonce
    b'\x07\xd0\x00',               # baseFeePerGas
    b'\x00' * 32,                   # withdrawalsRoot (Shanghai+)
]

header_rlp  = rlp.encode(fake_header)
header_hash = keccak(header_rlp)

print(f"header_hash : {header_hash.hex()}")

# Verify that field[5] of the decoded header is receipts_root
import rlp as _rlp
decoded = _rlp.decode(header_rlp)
assert decoded[5] == receipts_root, \
    f"field[5]={decoded[5].hex()} != {receipts_root.hex()}"
print("field[5] == receipts_root ✓")

# ── Step 4: Output Solidity fixture snippet ───────────────────────────────────

FIXTURE = f"""
    function _loadRealDepositFixture() internal {{
        // Auto-generated by script/gen_fixture.py (synthetic L1 block).
        // Demonstrates trustless Merkle proof verification.
        // Paper note: mock L1Block.hash() returns keccak256(fake_header_rlp);
        // the proof structure is identical to a real L1 deposit proof.
        victim       = address(0xDeaDDeaDDeaDDeaDDeaDDeaDDeaDDeaDDeaDDeaD);
        l1BlockHash  = bytes32(hex"{header_hash.hex()}");
        l1HeaderRLP  = hex"{header_rlp.hex()}";
        txIndex      = 0;
        receiptRLP   = hex"{receipt_rlp.hex()}";
        trieProof    = new bytes[](1);
        trieProof[0] = hex"{leaf_node_rlp.hex()}";
    }}
"""

print("\n" + "="*65)
print("SOLIDITY FIXTURE (paste into TrustlessRescueTest._loadRealDepositFixture):")
print("="*65)
print(FIXTURE)

# Write to file
with open("script/fixture_output.txt", "w") as f:
    f.write(FIXTURE)
    f.write("\n\n// Raw values for verification:\n")
    f.write(f"// header_hash (= mock L1Block.hash()): 0x{header_hash.hex()}\n")
    f.write(f"// receipts_root (header field[5]):     0x{receipts_root.hex()}\n")
    f.write(f"// keccak(trieProof[0]):                0x{keccak(leaf_node_rlp).hex()}\n")
    f.write(f"//   ^ must equal receipts_root\n")
    f.write(f"// tx_key (RLP(0)):                     0x{tx_key.hex()}\n")
    f.write(f"// leaf_key (hex-prefix):               0x{leaf_key.hex()}\n")

print("Written to script/fixture_output.txt")
