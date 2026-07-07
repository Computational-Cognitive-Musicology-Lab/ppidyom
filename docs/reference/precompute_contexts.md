# Precompute context identifiers for all orders

Precompute context identifiers for all orders

## Usage

``` r
precompute_contexts(dt_lag, N)
```

## Arguments

- dt_lag:

  Lag matrix from lag_matrix()

- N:

  Maximum n-gram order

## Value

List of length N+1, each element is a character vector of context IDs
