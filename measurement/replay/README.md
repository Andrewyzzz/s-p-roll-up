# Counterfactual Replay Infrastructure (§5.3)

Given 12-month historical transaction traces, computes counterfactual option value V
for hypothetical sequencing commitments.

## Chains

- Optimism (12 months)
- Base (12 months)
- Arbitrum (12 months)
- Polygon zkEVM (12 months)

## Pipeline

```
raw traces → filter commitment-eligible txs → compute counterfactual V → aggregate
```

## Run

```bash
# TODO: fill after Task 7.3
python replay.py --chain op --trace-dir data/raw/op/ --output data/processed/op_replay.parquet
```

## Sensitivity Sweep

Reactive-market sensitivity (Task 7.5):
```bash
python replay.py --theta 0 0.25 0.5 1.0 --output data/processed/sensitivity/
```

## Output

- `data/processed/{chain}_replay.parquet` — Per-chain counterfactual V series
- `data/processed/sensitivity/` — θ-sensitivity sweep results
- `figures/calibration.pdf` — Main calibration figure for §5.3
