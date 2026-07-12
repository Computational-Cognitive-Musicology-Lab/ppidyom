<div id="main" class="col-md-9" role="main">

# Compute Count Tables for STM and LTM with Optional Prior

<div class="ref-description section level2">

Generates count tables for STM (per-timestep) and/or LTM (per-context),
optionally incorporating previously accumulated LTM counts.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
count_tables(
  x,
  N,
  alphabet,
  model_type = c("stm", "ltm", "both"),
  prior = list(),
  stm_update_exclusion = FALSE,
  ltm_update_exclusion = FALSE,
  ltm_start_token = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    Character vector of symbols/events.

-   N:

    Maximum N-gram order.

-   alphabet:

    Character vector of all possible symbols.

-   model_type:

    Character:

    -   `"stm"` — counts per timestep within `x`.

    -   `"ltm"` — counts per context, accumulated across calls via
        `prior`.

    -   `"both"` — compute both.

-   prior:

    Optional: previously accumulated LTM tables (list of length N+1).
    Used to initialize/accumulate counts for LTM or `both` type.

-   stm_update_exclusion:

    Logical; apply update exclusion in STM (default TRUE). Prevents
    lower-order updates when an event is already observed in a
    higher-order context at the same timestep.

-   ltm_update_exclusion:

    Logical; apply update exclusion in LTM (default FALSE). If TRUE,
    applies the same exclusion logic during corpus accumulation; if
    FALSE, all orders are updated for every event.

</div>

<div class="section level2">

## Value

A list with elements depending on `model_type`:

-   `$stm`: list of length N+1, each a data.table of counts per timestep
    (if `model_type` includes `"stm"`).

-   `$ltm`: list of length N+1, each a data.table of counts per context
    (if `model_type` includes `"ltm"`).

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
x <- c("A", "B", "A", "C", "A")
counts <- count_tables(x, N = 1, alphabet = c("A", "B", "C"), model_type = "both")
# STM: order-1 counts (context = previous symbol) at every timestep
counts$stm[[2]]
#>     index context_id  Event    Ce     C     t    t1
#>     <int>     <char> <char> <int> <int> <int> <int>
#>  1:     1         NA      A     0     0     0     0
#>  2:     1         NA      B     0     0     0     0
#>  3:     1         NA      C     0     0     0     0
#>  4:     2          A      A     0     0     0     0
#>  5:     2          A      B     0     0     0     0
#>  6:     2          A      C     0     0     0     0
#>  7:     3          B      A     0     0     0     0
#>  8:     3          B      B     0     0     0     0
#>  9:     3          B      C     0     0     0     0
#> 10:     4          A      A     0     1     1     1
#> 11:     4          A      B     1     1     1     1
#> 12:     4          A      C     0     1     1     1
#> 13:     5          C      A     0     0     0     0
#> 14:     5          C      B     0     0     0     0
#> 15:     5          C      C     0     0     0     0
# LTM: order-1 counts per context, accumulated across all of x
counts$ltm[[2]]
#>     index context_id  Event    Ce     C     t    t1
#>     <int>     <char> <char> <int> <int> <int> <int>
#>  1:    -1          A      A     0     2     2     2
#>  2:    -1          A      B     1     2     2     2
#>  3:    -1          A      C     1     2     2     2
#>  4:    -1          B      A     1     1     1     1
#>  5:    -1          B      B     0     1     1     1
#>  6:    -1          B      C     0     1     1     1
#>  7:    -1         NA      A     1     1     1     1
#>  8:    -1         NA      B     0     1     1     1
#>  9:    -1         NA      C     0     1     1     1
#> 10:    -1          C      A     1     1     1     1
#> 11:    -1          C      B     0     1     1     1
#> 12:    -1          C      C     0     1     1     1
```

</div>

</div>

</div>
