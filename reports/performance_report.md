# Performance Report

_Week 5 deliverable — benchmark un-indexed multi-join era queries, apply
`sql/schema/002_indexes.sql`, and re-benchmark._

## Methodology

Run each Layer 2–4 query with `EXPLAIN (ANALYZE, BUFFERS)` before and after
indexing. Record wall-clock time and whether the plan changes from a
sequential scan to an index scan/lookup.

## Results

| Query | Pre-index time | Pre-index plan | Post-index time | Post-index plan |
|---|---|---|---|---|
| Layer 2: team ranking | | | | |
| Layer 3: win correlation | | | | |
| Layer 4: roster composition | | | | |

## Discussion

The plan change (seq scan → index scan) is the evidence that matters here,
not just the wall-clock improvement, since the dataset is small enough that
raw timing differences can be noisy.
