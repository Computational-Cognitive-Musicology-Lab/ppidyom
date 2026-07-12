<div id="main" class="col-md-9" role="main">

# Compute Local Probabilities for a Single Order; Used by Backoff PPM

<div class="ref-description section level2">

Compute Local Probabilities for a Single Order; Used by Backoff PPM

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
compute_local_probs(dt, escape_func, normalize = FALSE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   dt:

    Data.table for a single order. Columns: index, context_id, Event,
    Ce, C, t, t1.

-   escape_func:

    Escape function from escape.R. Signature: `function(t, t1)`
    returning `list(subtract, esc_numer)`.

</div>

<div class="section level2">

## Value

Data.table with columns: index, Event, prob_local, esc

</div>

</div>
