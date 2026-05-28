# Sequencing Commitment Atomicity: Free Options in Rollup Preconfirmation

Anonymous submission artifact repository.

## Repository Structure

```
.
├── paper/              # LaTeX source
├── poc/                # Proof-of-concept implementations
│   ├── peo/            # Attack 1: Preconfirmation Exercise Option
│   ├── pefo-devnet/    # Attack 2: PEFO on framework devnet
│   └── pefo-testnet/   # Attack 2: PEFO on application testnet
├── measurement/        # Empirical measurement study
│   ├── timing/         # Real-stack timing (§5.1)
│   ├── replay/         # Counterfactual replay infrastructure (§5.3)
│   └── tail-index/     # Tail-index estimation (§5.3.1)
├── survey/             # Cross-rollup application survey
│   ├── codebook/       # Pre-registered survey codebook
│   └── candidates/     # Candidate protocol documentation
├── disclosure/         # Responsible disclosure records
│   ├── attempts/       # Per-attempt timestamped records
│   └── disclosure_commitments.json
└── artifacts/          # SHA-256 manifest and aggregated artifacts
```

## Reproducibility

Each PoC directory contains a `README.md` with setup and run instructions.

Measurement scripts are self-contained with pinned dependencies.

## Disclosure

Disclosure records in `disclosure/` are independently verifiable via OpenTimestamps proofs.

## Ethics

See `paper/appendix/ethics.tex`.
