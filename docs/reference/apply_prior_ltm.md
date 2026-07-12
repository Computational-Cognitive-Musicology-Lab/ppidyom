<div id="main" class="col-md-9" role="main">

# Seed LTM environments from previously accumulated count tables

<div class="ref-description section level2">

Converts a list of data.tables (the output format of count_tables) back
into sparse environments so that update_env_and_build_stm_tables can
continue accumulating counts on top of them.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
apply_prior_ltm(counts_ltm, prior, N)
```

</div>

</div>

<div class="section level2">

## Arguments

-   counts_ltm:

    List of environments (one per order 0..N)

-   prior:

    List of data.tables from a previous count_tables() call

-   N:

    Maximum n-gram order

</div>

<div class="section level2">

## Value

counts_ltm with prior counts loaded into the environments

</div>

<div class="section level2">

## Details

Only symbols with Ce \> 0 are stored as environment keys. This is
critical: \`update_env_and_build_stm_tables\` uses \`sym whether a
symbol was already "seen" in a context, which controls the
ltm_update_exclusion early-stop logic. Storing Ce = 0 entries as keys
would cause false "already seen" hits and premature stopping.

</div>

</div>
