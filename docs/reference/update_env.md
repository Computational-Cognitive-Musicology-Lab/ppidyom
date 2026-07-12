<div id="main" class="col-md-9" role="main">

# Update a Sparse Context Count Environment

<div class="ref-description section level2">

Increment or decrement the count of a symbol within a given context
stored in an environment-based sparse representation.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
update_env(env, ctx, sym, sign = +1)
```

</div>

</div>

<div class="section level2">

## Arguments

-   env:

    An environment mapping context IDs (`ctx`) to named integer vectors.
    Each vector represents symbol counts for that context.

-   ctx:

    Character. Context identifier key (n-grams).

-   sym:

    Character. Symbol/event that follows the context.

-   sign:

    Integer. Update direction: - `+1` increments the count (default
    behavior during training) - `-1` decrements the count (used during
    detrain or reversal)

</div>

<div class="section level2">

## Value

Invisibly returns `NULL`. The environment is modified in place.

</div>

<div class="section level2">

## Details

This function is used as the core update primitive for PPM-style models,
where each context (`ctx`) stores a named integer vector of symbol
counts.

The update is *sparse*: only symbols with non-zero counts are stored.

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
env <- new.env()

# add observations
update_env(env, "A_B", "C", +1)
#> Error in update_env(env, "A_B", "C", +1): could not find function "update_env"
update_env(env, "A_B", "C", +1)
#> Error in update_env(env, "A_B", "C", +1): could not find function "update_env"

# decrement
update_env(env, "A_B", "C", -1)
#> Error in update_env(env, "A_B", "C", -1): could not find function "update_env"

env[["A_B"]]
#> NULL
```

</div>

</div>

</div>
