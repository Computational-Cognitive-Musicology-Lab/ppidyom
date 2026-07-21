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

A `data.table` with columns LagN..Lag0 and index.

## Examples

``` r
lag_matrix(c("A", "B", "A", "C", "A"), N = 2)
#>      Lag2   Lag1   Lag0 index
#>    <char> <char> <char> <int>
#> 1:   <NA>   <NA>      A     1
#> 2:   <NA>      A      B     2
#> 3:      A      B      A     3
#> 4:      B      A      C     4
#> 5:      A      C      A     5
```
