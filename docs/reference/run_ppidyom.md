<div id="main" class="col-md-9" role="main">

# Run PPM over a corpus of sequences

<div class="ref-description section level2">

Lower-level building block behind `ppidyom()`. Takes a plain list of
sequences (rather than viewpoint vectors + grouping columns) and, for
`model_type`s with an LTM component, evaluates each sequence
leave-one-out: the whole corpus is trained first, then for each sequence
in turn it is detrained, predicted on, and retrained before moving to
the next.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
run_ppidyom(
  seq_list,
  N,
  alphabet = NULL,
  model_type = c("stm", "ltm", "both", "ltm+", "both+"),
  ppm_type = c("interpolation", "backoff"),
  stm_lambda = "C",
  ltm_lambda = "C",
  stm_exclusion = TRUE,
  ltm_exclusion = TRUE,
  stm_update_exclusion = TRUE,
  ltm_update_exclusion = FALSE,
  b = 1,
  idyom_base = FALSE,
  ltm_start_token = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   seq_list:

    List of character-vector sequences (the corpus). Each element is one
    sequence, e.g. one piece.

-   N:

    Maximum n-gram order (order bound).

-   alphabet:

    Character vector of all possible symbols. If `NULL` (default),
    inferred as the set of unique symbols across `seq_list`.

-   model_type:

    Which memory component(s) to use:

    -   `"stm"` — short-term memory, one sequence at a time, no
        leave-one-out.

    -   `"ltm"` — long-term memory, pretrained on the corpus, no update
        during test.

    -   `"both"` — STM + LTM blended.

    -   `"ltm+"`/`"both+"` — as `"ltm"`/`"both"`, but LTM updates online
        per event.

-   ppm_type:

    PPM estimation method:

    -   `"interpolation"` — weighted sum across all n-gram orders.

    -   `"backoff"` — falls through orders from longest to shortest
        matching context.

-   stm_lambda:

    Escape/discount method for STM: `"A"`, `"B"`, `"C"` (Witten-Bell,
    default), `"D"` (absolute discounting), or `"X"` (AX, based on
    singleton counts). See the [Escape
    method](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.html#escape-method)
    section of the [Parameter
    Correspondence](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.md)
    vignette for the exact formulas.

-   ltm_lambda:

    Escape/discount method for LTM; same options as `stm_lambda`.

-   stm_exclusion:

    Logical; exclude symbols already assigned a probability at a higher
    order when computing STM escape probabilities (default TRUE).

-   ltm_exclusion:

    Logical; same as `stm_exclusion`, for LTM (default TRUE).

-   stm_update_exclusion:

    Logical; stop updating lower-order STM counts once a higher order
    already matched at this timestep (default TRUE).

-   ltm_update_exclusion:

    Logical; same as `stm_update_exclusion`, but applied while
    accumulating LTM counts (default FALSE).

-   b:

    Bias exponent for entropy-weighted blending, used only when
    `model_type` is `"both"`/`"both+"`; higher values favor whichever of
    STM/LTM is currently more confident (default 1).

-   idyom_base:

    Logical; use IDyOM's order-(-1) base distribution instead of the
    default shrinking-denominator base (default FALSE). See the
    [Implementation
    Discrepancy](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ImplementationDiscrepancy.md)
    vignette.

-   ltm_start_token:

    Logical; count beginning-of-sequence positions when accumulating LTM
    (default TRUE; set FALSE to match IDyOM).

</div>

<div class="section level2">

## Value

A list the same length as `seq_list`; each element is a data.table with
columns `index`, `Event`, `P`, `IC`, `Entropy`, `seq_id` (the position
of that sequence in `seq_list`). Combine with `data.table::rbindlist()`.

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
# run_ppidyom is internal; use ::: since this example isn't run via library()
seq1 <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
seq2 <- c("A", "B", "C", "A", "B", "C", "A", "B", "C")
seq3 <- c("B", "A", "B", "C", "A")

# STM only, no leave-one-out (each sequence starts from scratch):
res_stm <- ppidyom:::run_ppidyom(
  seq_list = list(seq1, seq2, seq3), N = 3, model_type = "stm",
  stm_exclusion = FALSE, stm_update_exclusion = FALSE
)
#> run_ppidyom: 3 sequences, N=3, model=stm, ppm=interpolation, alphabet=3 (inferred)
#>   [1/3] 0.0s elapsed, 0.0s remaining
#>   [2/3] 0.0s elapsed, 0.0s remaining
#>   [3/3] 0.0s elapsed, 0.0s remaining
data.table::rbindlist(res_stm)
#>     index  Event          P         IC   Entropy seq_id
#>     <int> <char>      <num>      <num>     <num>  <int>
#>  1:     1      A 0.33333333 1.58496250 1.5849625      1
#>  2:     2      B 0.16666667 2.58496250 1.2516292      1
#>  3:     3      A 0.40000000 1.32192809 1.5219281      1
#>  4:     4      C 0.09090909 3.45943162 1.2406705      1
#>  5:     5      A 0.38461538 1.37851162 1.5766212      1
#>  6:     6      B 0.36363636 1.45943162 1.5726237      1
#>  7:     7      A 0.78571429 0.34792330 0.9619687      1
#>  8:     8      C 0.79245283 0.33560303 0.9240572      1
#>  9:     9      A 0.89361702 0.16227143 0.5952916      1
#> 10:     1      A 0.33333333 1.58496250 1.5849625      2
#> 11:     2      B 0.16666667 2.58496250 1.2516292      2
#> 12:     3      C 0.20000000 2.32192809 1.5219281      2
#> 13:     4      A 0.33333333 1.58496250 1.5849625      2
#> 14:     5      B 0.55000000 0.86249648 1.4387587      2
#> 15:     6      C 0.73684211 0.44057259 1.0946323      2
#> 16:     7      A 0.87179487 0.19793938 0.6807002      2
#> 17:     8      B 0.91269841 0.13178987 0.5141786      2
#> 18:     9      C 0.94117647 0.08746284 0.3815805      2
#> 19:     1      B 0.33333333 1.58496250 1.5849625      3
#> 20:     2      A 0.16666667 2.58496250 1.2516292      3
#> 21:     3      B 0.40000000 1.32192809 1.5219281      3
#> 22:     4      C 0.09090909 3.45943162 1.2406705      3
#> 23:     5      A 0.30769231 1.70043972 1.5766212      3
#>     index  Event          P         IC   Entropy seq_id
#>     <int> <char>      <num>      <num>     <num>  <int>

# STM + LTM with leave-one-out:
res_both <- ppidyom:::run_ppidyom(
  seq_list = list(seq1, seq2, seq3), N = 3, model_type = "both"
)
#> run_ppidyom: 3 sequences, N=3, model=both, ppm=interpolation, alphabet=3 (inferred)
#>   [1/3] 0.1s elapsed, 0.2s remaining
#>   [2/3] 0.2s elapsed, 0.1s remaining
#>   [3/3] 0.2s elapsed, 0.0s remaining
data.table::rbindlist(res_both)
#>     index  Event         P        IC  Entropy seq_id
#>     <int> <char>     <num>     <num>    <num>  <int>
#>  1:     1      A 0.3687182 1.4394094 1.568027      1
#>  2:     2      B 0.3650109 1.4539884 1.513370      1
#>  3:     3      A 0.3170504 1.6572161 1.542989      1
#>  4:     4      C 0.1346393 2.8928282 1.328617      1
#>  5:     5      A 0.6109051 0.7109798 1.352865      1
#>  6:     6      B 0.5399664 0.8890586 1.455414      1
#>  7:     7      A 0.3526596 1.5036517 1.486372      1
#>  8:     8      C 0.3525649 1.5040393 1.527710      1
#>  9:     9      A 0.6788781 0.5587755 1.226387      1
#> 10:     1      A 0.4127292 1.2767326 1.550421      2
#> 11:     2      B 0.3998953 1.3223056 1.552150      2
#> 12:     3      C 0.2117043 2.2398776 1.438925      2
#> 13:     4      A 0.4781576 1.0644418 1.519818      2
#> 14:     5      B 0.5785190 0.7895637 1.402114      2
#> 15:     6      C 0.3558129 1.4908093 1.510474      2
#> 16:     7      A 0.5818873 0.7811883 1.398205      2
#> 17:     8      B 0.5785190 0.7895637 1.402114      2
#> 18:     9      C 0.3558129 1.4908093 1.510474      2
#> 19:     1      B 0.2023672 2.3049526 1.378387      3
#> 20:     2      A 0.3005012 1.7345574 1.574385      3
#> 21:     3      B 0.3550614 1.4938594 1.476904      3
#> 22:     4      C 0.2166153 2.2067932 1.447246      3
#> 23:     5      A 0.5329516 0.9079235 1.463141      3
#>     index  Event         P        IC  Entropy seq_id
#>     <int> <char>     <num>     <num>    <num>  <int>
```

</div>

</div>

</div>
