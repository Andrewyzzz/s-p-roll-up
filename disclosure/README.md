# Responsible Disclosure Records

This directory contains timestamped records of all disclosure attempts,
verifiable via OpenTimestamps proofs.

## Structure

```
disclosure/
├── README.md
├── disclosure_commitments.json      # Aggregator (Task 10.5)
└── attempts/
    ├── YYYY-MM-DD_vendor_channel/
    │   ├── content.txt              # Disclosure content (or hash if sensitive)
    │   ├── content.txt.ots          # OpenTimestamps proof
    │   └── metadata.json           # Vendor, channel, git commit hash
    └── ...
```

## Timestamps

Each attempt is timestamped via:
1. `ots stamp content.txt` — OpenTimestamps Bitcoin proof
2. `git commit` + `git push` to public repo — git commit hash as additional anchor

Both anchors are recorded in `disclosure_commitments.json`.

## Verification

```bash
# Verify a single attempt
ots verify attempts/YYYY-MM-DD_vendor_channel/content.txt.ots

# Cross-check git commit timestamp
git log --format="%H %ai" -- attempts/YYYY-MM-DD_vendor_channel/
```

## Timeline

| Event | Task | Target Week |
|---|---|---|
| Initial outreach sent | Task 3.3 | Week 6 |
| Formal disclosure ($D_3$) | Task 6.2 | Week 11 |
| Day-14 reminder | Task 6.4 | Week 13 |
| Day-30 reminder | Task 6.5 | Week 15 |
| Day-60 tracking | Task 9.3 | Week 19 |
| $D_3 + 90$ days (public disclosure eligible) | — | Week 24 |
