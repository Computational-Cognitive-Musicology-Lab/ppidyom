<div id="main" class="col-md-9" role="main">

# Generate Lagged N-gram Matrix

<div class="ref-description section level2">

Creates a lagged representation of a sequence for N-gram modeling.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
lag_matrix(x, N = 3)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    Character vector of symbols/events.

-   N:

    Maximum N-gram order.

</div>

<div class="section level2">

## Value

A \`data.table\` with columns LagN..Lag0 and index.

</div>

</div>
