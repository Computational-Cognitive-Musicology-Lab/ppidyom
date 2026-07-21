# Expand LTM Count Tables to Timestep-Aligned Order Tables

Converts aggregated Long-Term Memory (LTM) count tables into
timestep-aligned tables compatible with PPM probability computation.

## Usage

``` r
ltm_to_timestep_counts(x, N, alphabet, order_counts)
```

## Arguments

- x:

  Character vector of events.

- N:

  Maximum context order.

- alphabet:

  Character vector of the full symbol alphabet.

- order_counts:

  List of LTM count tables for orders `0..N`. Each element must be a
  `data.table` containing: `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.

## Value

A list of length `N + 1`. Each element is a `data.table` with columns:
`index`, `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.

The tables contain one row per `(timestep, event)` pair and can be
directly passed to probability computation routines.

## Details

LTM count tables contain counts aggregated over a training corpus
(typically with `index = -1`). For prediction on a new sequence `x`, we
must derive the counts associated with each timestep's context.

The result matches the structure expected by PPM implementations
(`ppm_backoff`, `ppm_interpolated`, etc.).
