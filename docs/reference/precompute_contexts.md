<div id="main" class="col-md-9" role="main">

# Precompute context identifiers for all orders

<div class="ref-description section level2">

Precompute context identifiers for all orders

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
precompute_contexts(dt_lag, N)
```

</div>

</div>

<div class="section level2">

## Arguments

-   dt_lag:

    Lag matrix from lag_matrix()

-   N:

    Maximum n-gram order

</div>

<div class="section level2">

## Value

List of length N+1, each element is a character vector of context IDs

</div>

</div>
