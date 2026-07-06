# Compute Local Probabilities for a Single Order; Used by Backoff PPM

Compute Local Probabilities for a Single Order; Used by Backoff PPM

## Usage

``` r
compute_local_probs(dt, escape_func, normalize = FALSE)
```

## Arguments

- dt:

  Data.table for a single order. Columns: index, context_id, Event, Ce,
  C, t, t1.

- escape_func:

  Escape function from escape.R. Signature: \`function(t, t1)\`
  returning \`list(subtract, esc_numer)\`.

## Value

Data.table with columns: index, Event, prob_local, esc
