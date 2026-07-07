# Generate Lagged N-gram Matrix

Creates a lagged representation of a sequence for N-gram modeling.

## Usage

``` r
lag_matrix(x, N = 3)
```

## Arguments

- x:

  Character vector of symbols/events.

- N:

  Maximum N-gram order.

## Value

A \`data.table\` with columns LagN..Lag0 and index.
