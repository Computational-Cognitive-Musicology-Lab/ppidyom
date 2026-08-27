# Convert online-update environments to LTM data.table format

After running build_online_ltm_timestep_counts, the updated environments
are not directly accessible. This helper rebuilds them and converts to
the data.table list format used by counts_ltm (index = -1L rows).

## Usage

``` r
envs_to_ltm_tables(envs, N, alphabet)
```

## Arguments

- envs:

  List of N+1 environments (one per order 0..N)

- N:

  Maximum n-gram order

- alphabet:

  Character vector of all symbols

## Value

List of N+1 data.tables, each with columns index=-1L, context_id, Event,
Ce, C, t, t1.
