# §4.4.4 Case Templates

Six pre-written templates for the "Coordinated Disclosure and Vendor Response"
subsection (§4.4.4), one for each possible outcome.

At **Week 23** (Task 9.4), select the matching case file, rename it to
`04-pefo-case-SELECTED.tex`, and `\input` it from `04-pefo.tex`.

## Case Selection Table

| Case | File | Trigger | Prob |
|------|------|---------|------|
| 3d | `case_3d_mainnet_confirm.tex` | Vendor provides technical confirmation of mainnet applicability | 7.5% |
| 3b | `case_3b_acknowledge.tex` | Vendor acknowledges but gives no technical engagement | 15% |
| 3c | `case_3c_disagree.tex` | Vendor disputes applicability or characterization | 12% |
| 2  | `case_2_ghost.tex` | Vendor non-responsive to all outreach attempts | 30% |
| 1  | `case_1_week8_abort.tex` | Week 8 abort — no suitable candidate; §4.4 removed | 23.5% |
| 6  | `case_6_mitigation_found.tex` | Testnet PoC reveals existing Theorem 1 mitigation | 12% |

## Usage

```latex
% In 04-pefo.tex, replace the placeholder with the selected case:
\input{sections/04-pefo-case-templates/case_SELECTED}
```

## Notes

- **Case 1** is the only case where §4.4 is removed entirely — see decision record
  in `case_1_week8_abort.tex`
- **Case 6** requires §4.4.2 to be reframed ("Attack Design and Discovery of
  Mitigation") and §7 design-space map to include the application as a positive example
- **Case 3c** requires §4.5 to include the structural-not-normative claim
  (already in the template)
- All cases include a disclosure timeline table — fill actual dates from
  `disclosure/disclosure_commitments.json`
