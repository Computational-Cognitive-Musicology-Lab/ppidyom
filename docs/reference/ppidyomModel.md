# Initialize a new PPM counter

Initialize a new PPM counter

## Arguments

- N:

  Maximum n-gram order (order bound).

- alphabet:

  Character vector of all possible symbols/events.

- stm_exclusion:

  Logical; when computing STM escape probabilities, exclude symbols
  already assigned a probability at a higher order (default TRUE).

- ltm_exclusion:

  Logical; same as `stm_exclusion`, for LTM (default TRUE).

- stm_update_exclusion:

  Logical; stop updating lower-order STM counts once a higher order
  already matched at this timestep (default TRUE).

- ltm_update_exclusion:

  Logical; same as `stm_update_exclusion`, but applied while
  accumulating LTM counts (default FALSE).

- ltm_start_token:

  Logical; count beginning-of-sequence positions when accumulating LTM
  (default TRUE; set FALSE to match IDyOM).

- x:

  Character vector sequence

- model_type:

  Which memory component(s) to use:

  - `"stm"` — short-term memory, `x` only.

  - `"ltm"` — long-term memory, from prior `train_sequence()` calls.

  - `"both"` — STM + LTM blended.

  - `"ltm+"`/`"both+"` — as `"ltm"`/`"both"`, but LTM is updated online
    after each event of `x`.

- ppm_type:

  PPM estimation method:

  - `"interpolation"` — weighted sum across all n-gram orders.

  - `"backoff"` — falls through orders from longest to shortest matching
    context.

- stm_lambda:

  Escape/discount method for STM:

  - `"A"` — very conservative; escapes rarely.

  - `"B"` — escapes in proportion to novelty.

  - `"C"` — Witten-Bell (default); balances novelty and count stability.

  - `"D"` — absolute discounting (d = 0.5).

  - `"X"` — AX; escapes based on singleton count.

  See the [Escape
  method](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.html#escape-method)
  section of the [Parameter
  Correspondence](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.md)
  vignette for the exact formulas.

- ltm_lambda:

  Escape/discount method for LTM; same options as `stm_lambda`.

- b:

  Bias exponent for entropy-weighted blending, used only when
  `model_type` is `"both"`/`"both+"`; higher values favor whichever of
  STM/LTM is currently more confident (lower entropy).

- idyom_base:

  Logical order-(-1) base distribution:

  - `TRUE` — IDyOM-compatible: 1/\|alphabet\| when exclusion=FALSE,
    shrinking denominator when exclusion=TRUE.

  - `FALSE` (default) — always the shrinking denominator (matches
    Harrison's ppm package).

  See the [Implementation
  Discrepancy](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ImplementationDiscrepancy.md)
  vignette for details. (Matching IDyOM for LTM also requires the
  constructor's `ltm_start_token = FALSE`.)

## Value

data.table with columns: index, Event, P, IC, Entropy

## Examples

``` r
# ppidyomModel is internal; use ::: since this example isn't run via library()
model <- ppidyom:::ppidyomModel$new(N = 3, alphabet = c("A", "B", "C"), stm_exclusion = TRUE)
result <- model$predict_sequence(
  c("A", "B", "A", "C", "A", "B", "A", "C", "A"),
  model_type = "stm", stm_lambda = "C"
)
result[, .(index, Event, P, IC, Entropy)]
#>    index  Event         P        IC  Entropy
#>    <int> <char>     <num>     <num>    <num>
#> 1:     1      A 0.3333333 1.5849625 1.584963
#> 2:     2      B 0.1666667 2.5849625 1.251629
#> 3:     3      A 0.4000000 1.3219281 1.521928
#> 4:     4      C 0.1000000 3.3219281 1.295462
#> 5:     5      A 0.3846154 1.3785116 1.576621
#> 6:     6      B 0.3500000 1.5145732 1.581291
#> 7:     7      A 0.5789474 0.7884959 1.402993
#> 8:     8      C 0.5428571 0.8813555 1.431006
#> 9:     9      A 0.5789474 0.7884959 1.402993
```
