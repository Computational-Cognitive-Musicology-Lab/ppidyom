<div id="main" class="col-md-9" role="main">

# Convert online-update environments to LTM data.table format

<div class="ref-description section level2">

After running build_online_ltm_timestep_counts, the updated environments
are not directly accessible. This helper rebuilds them and converts to
the data.table list format used by counts_ltm (index = -1L rows).

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
envs_to_ltm_tables(envs, N, alphabet)
```

</div>

</div>

<div class="section level2">

## Arguments

-   envs:

    List of N+1 environments (one per order 0..N)

-   N:

    Maximum n-gram order

-   alphabet:

    Character vector of all symbols

</div>

<div class="section level2">

## Value

List of N+1 data.tables, each with columns index=-1L, context_id, Event,
Ce, C, t, t1.

</div>

</div>
