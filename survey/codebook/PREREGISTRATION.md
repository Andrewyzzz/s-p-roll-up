# Survey Codebook Pre-Registration Record

**File:** `survey/codebook/codebook_v1.md`
**Status:** PRE-REGISTERED — coding may now begin (Task 1.2)

## Integrity

| Field | Value |
|-------|-------|
| SHA-256 | `118c03e5d7afae933d359694aab17a9579c6760b5bd5e80cccef564b2c82c7c9` |
| OTS proof file | `survey/codebook/codebook_v1.md.ots` |
| Stamped (UTC) | `2026-05-28T03:06:39Z` |
| Git commit | PENDING (see below) |

## Verification

```bash
# Verify OTS proof (after Bitcoin confirmation ~1 hour):
ots verify survey/codebook/codebook_v1.md.ots

# Verify file integrity:
shasum -a 256 survey/codebook/codebook_v1.md
# Expected: 118c03e5d7afae933d359694aab17a9579c6760b5bd5e80cccef564b2c82c7c9
```

## Scope

This pre-registration fixes the coding criteria before any candidate review
begins. The codebook may not be altered after this commit. Any future revision
requires a new version file (`codebook_v2.md`) with its own OTS stamp.

## Anti-Gaming Commitment

The coding variables, mandatory filter (TF-1/2/3), auxiliary filter (AX-1–7),
and AX-4 Theorem 1 mitigation check are fixed at this commit. Retroactive
criterion changes are prohibited per Part 5 of `candidate_protocol.md`.
