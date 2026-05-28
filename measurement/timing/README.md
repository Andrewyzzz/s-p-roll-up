# Real-Stack Timing Measurement (§5.1)

Measures $t_{\text{commit}} \to t_{\text{rollup\_exec}}$ and cross-rollup divergence
across Optimism, Base, Arbitrum, and Polygon zkEVM.

## Output

- `data/processed/timing_cdf.csv` — CDF of commitment-to-execution latency
- `figures/timing_cdf.pdf` — CDF figure for paper
- `figures/cross_rollup_divergence.pdf` — Cross-rollup timing divergence

## Run

```bash
# TODO: fill after Task 7.2
python timing_measurement.py --chains op,base,arb,polygon --output data/processed/
```

## Dependencies

```
# TODO: requirements.txt
```
