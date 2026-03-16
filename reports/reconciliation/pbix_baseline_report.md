# PBIX Baseline Reconciliation Report

- Generated: 2026-03-16T01:52:50Z
- Baseline: `/home/edwards/Dev/edwards.bookclub/artifacts/current_state.json`

## Summary

- Development readiness: yes
- Cutover readiness: no
- Blockers: Book Requests, Attendance Rows

## Comparisons

| Item | PBIX Baseline | Rails Current | Status | Notes |
|------|---------------|---------------|--------|-------|
| Members | 52 | 52 | match | Full PBIX-derived members export is available locally. |
| Book Requests | 185 | 2 | mismatch | Rails currently reflects imported CSV scope; full SharePoint export has not been loaded yet. |
| Attendance Rows | 149 | 2 | mismatch | Rails currently reflects imported CSV scope; full SharePoint export has not been loaded yet. |
| Member Reserve Points | 5000 | 5000 | match | Checks parity for the general member attendance rule. |
| Leader Reserve Points | 10000 | 10000 | match | Checks parity for leader attendance rules. |
| Fiscal Period Start | 2026-01-01 | 2026-01-01 | match | Derived from the PBIX `SumOfBooks` date boundary and current seeded fiscal period. |

## Assessment

- The current migration baseline is sufficient to continue Rails feature development.
- The imported data is not yet ready for cutover because one or more blocker mismatches remain.
- Current mismatches are expected where the repo uses fixture SharePoint CSVs instead of the full live exports.

