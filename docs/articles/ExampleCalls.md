# Example Calls: Matching ppm and IDyOM

PPM models a listener who hears a musical sequence event by event and
forms expectations about what comes next. Different configurations of
ppidyom correspond to different assumptions about what kind of memory
that listener has:

- **STM only** — the listener remembers only the current sequence.
  Predictions become sharper as the sequence unfolds and patterns
  repeat.
- **LTM only** — the listener draws entirely on prior musical experience
  encoded in a training corpus. The current sequence does not update
  their expectations.
- **Both** — the listener blends long-term knowledge with growing memory
  of the current piece, weighting each source by how confident it is.

This vignette shows the exact calls needed to replicate Harrison’s
**ppm** package and IDyOM (Common Lisp) using very simple toy examples.
The two differ in several subtle ways that are explained in
[`vignette("implementation-discrepancy")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ImplementationDiscrepancy.md);
the full parameter map is in
[`vignette("parameter-correspondence")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.md).

------------------------------------------------------------------------

## Shared test data

``` r
testSequence <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
alphabet     <- c("A", "B", "C")
N            <- 3L
```

------------------------------------------------------------------------

## Matching Harrison’s ppm package

The **ppm** package models STM only, using interpolated PPM with the
Witten-Bell escape (method C) by default. It uses a *shrinking* base
distribution: the order-(-1) prior denominator grows as more distinct
symbols are observed, concentrating probability on the already-seen
symbols.

ppidyom matches this with `idyom_base = FALSE` (the default).

### STM, escape C, no exclusion (ppm defaults)

The simplest configuration: the model counts how often each n-gram has
occurred before the current position, then assigns probabilities via
interpolation. Early in the sequence, it relies heavily on low-order
statistics; as patterns repeat, higher orders take over.

``` r
# ppm equivalent:
#   ppm::new_ppm_simple(
#     order_bound = 3, alphabet_levels = c("A","B","C"),
#     escape = "c", exclusion = FALSE, update_exclusion = FALSE
#   )
#   ppm::model_seq(mod, factor(x, levels = alphabet))$information_content

ppidyom(testSequence, maxN = N, alphabet = alphabet, 
                model_type = 'stm', ppm_type = 'interpolation', idyom_base = FALSE,
                shortTermArgs = list(lambda = 'C', exclusion = FALSE, update_exclusion = FALSE))
#>    index  Event          P        IC   Entropy
#>    <int> <char>      <num>     <num>     <num>
#> 1:     1      A 0.33333333 1.5849625 1.5849625
#> 2:     2      B 0.16666667 2.5849625 1.2516292
#> 3:     3      A 0.40000000 1.3219281 1.5219281
#> 4:     4      C 0.09090909 3.4594316 1.2406705
#> 5:     5      A 0.38461538 1.3785116 1.5766212
#> 6:     6      B 0.36363636 1.4594316 1.5726237
#> 7:     7      A 0.78571429 0.3479233 0.9619687
#> 8:     8      C 0.79245283 0.3356030 0.9240572
#> 9:     9      A 0.89361702 0.1622714 0.5952916
```

### STM, escape A, with exclusion

Escape A (`1/(C+1)`) is more conservative than Witten-Bell: it assigns a
smaller escape probability, so the model stays closer to the specific
context rather than falling back quickly to lower orders. Combined with
exclusion, lower orders only distribute their escaped mass over symbols
not yet covered by higher-order predictions.

``` r
# ppm::(escape="a", exclusion=TRUE, update_exclusion=FALSE)

ppidyom(testSequence, maxN = N, alphabet = alphabet, 
                model_type = 'stm', ppm_type = 'interpolation', idyom_base = FALSE,
                shortTermArgs = list(lambda = 'A', exclusion = TRUE, update_exclusion = FALSE)) 
#>    index  Event          P        IC  Entropy
#>    <int> <char>      <num>     <num>    <num>
#> 1:     1      A 0.33333333 1.5849625 1.584963
#> 2:     2      B 0.16666667 2.5849625 1.251629
#> 3:     3      A 0.42857143 1.2223924 1.448816
#> 4:     4      C 0.06666667 3.9068906 1.230960
#> 5:     5      A 0.42857143 1.2223924 1.556657
#> 6:     6      B 0.37500000 1.4150375 1.561278
#> 7:     7      A 0.61538462 0.7004397 1.334679
#> 8:     8      C 0.55000000 0.8624965 1.376357
#> 9:     9      A 0.62500000 0.6780719 1.329434
```

### Multiple “pieces”

In most research, we work with corpora of multiple musical
sequences—this can include multiple independent pieces, or different
parts within the same piece. You can tell ppidyom() how your input data
is divided into pieces and/or parts. Each sequence is then processed
independently: the STM the model resets between all sequences (each
sequence starts from scratch with no accumulated memory); The LTM is
“trained” across pieces.

Here we’ll build some toy data with two “pieces.” We’ll put the data
into one column of a data.frame, and the piece indicator in another
column:

``` r

testCorpus <- data.frame(Sequence = c('A', 'B', 'C', 'A', 'B', 'C', 'A', 'C', 'B',
                                                                        'B', 'A', 'B', 'C', 'A'),
                                           Piece = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2))

ppidyom(testCorpus$Sequence, maxN = N, alphabet = alphabet,
                model_type = 'stm', ppm_type = 'interpolation', idyom_base = FALSE,
                shortTermArgs = list(lambda = 'C', exclusion = FALSE, update_exclusion = FALSE),
              shortTermGroups = list(testCorpus$Piece))
#>     index  Event          P        IC   Entropy
#>     <int> <char>      <num>     <num>     <num>
#>  1:     1      A 0.33333333 1.5849625 1.5849625
#>  2:     2      B 0.16666667 2.5849625 1.2516292
#>  3:     3      C 0.20000000 2.3219281 1.5219281
#>  4:     4      A 0.33333333 1.5849625 1.5849625
#>  5:     5      B 0.55000000 0.8624965 1.4387587
#>  6:     6      C 0.73684211 0.4405726 1.0946323
#>  7:     7      A 0.87179487 0.1979394 0.6807002
#>  8:     8      C 0.03968254 4.6553518 0.5141786
#>  9:     9      B 0.12820513 2.9634741 1.1385983
#> 10:     1      B 0.33333333 1.5849625 1.5849625
#> 11:     2      A 0.16666667 2.5849625 1.2516292
#> 12:     3      B 0.40000000 1.3219281 1.5219281
#> 13:     4      C 0.09090909 3.4594316 1.2406705
#> 14:     5      A 0.30769231 1.7004397 1.5766212
```

------------------------------------------------------------------------

## Matching IDyOM (Common Lisp)

IDyOM differs from ppm in three ways that matter for LTM and `both`-type
predictions:

| Flag              | Value for IDyOM match | Why                                                                                   |
|-------------------|-----------------------|---------------------------------------------------------------------------------------|
| `ltm_start_token` | `FALSE`               | IDyOM skips beginning-of-sequence positions when building LTM                         |
| `idyom_base`      | `TRUE`                | IDyOM’s order-(-1) prior uses `t_root` from the training model, not the test sequence |
| `b`               | `7`                   | IDyOM weights the more confident model much more sharply (Pearce 2005)                |

For **STM with exclusion on**, all three implementations already agree —
no special flags are needed. The flags become important as soon as LTM
is involved.

### Default IDyOM STM — exclusion ON

With exclusion on, the order-(-1) base distribution depends on how many
distinct symbols the model has seen, and for STM this is the same
whether you compute it from the training data or from the test sequence
— they are the same sequence. So `idyom_base` has no numerical effect
here; all three implementations agree.

``` r
# IDyOM call (Common Lisp):
#   (idyom:idyom <db-id> '(cpitch) '(cpitch) :texture :melody :models :stm
#     :stmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil))


ppidyom(testSequence, maxN = N, alphabet = alphabet, 
                model_type = 'stm', ppm_type = 'interpolation', idyom_base = TRUE,
                shortTermArgs = list(lambda = 'C', exclusion = TRUE, update_exclusion = FALSE))
#>    index  Event         P        IC  Entropy
#>    <int> <char>     <num>     <num>    <num>
#> 1:     1      A 0.3333333 1.5849625 1.584963
#> 2:     2      B 0.1666667 2.5849625 1.251629
#> 3:     3      A 0.4000000 1.3219281 1.521928
#> 4:     4      C 0.1000000 3.3219281 1.295462
#> 5:     5      A 0.3846154 1.3785116 1.576621
#> 6:     6      B 0.3500000 1.5145732 1.581291
#> 7:     7      A 0.5714286 0.8073549 1.409975
#> 8:     8      C 0.5308642 0.9135852 1.442672
#> 9:     9      A 0.5833333 0.7776076 1.396535
```

### IDyOM STM — exclusion OFF

Without exclusion, IDyOM uses a flat uniform `1/|alphabet|` as the base
prior, regardless of how many symbols have appeared so far. Harrison’s
ppm uses a shrinking denominator instead. This difference is most
visible at the beginning of the sequence, before all alphabet symbols
have been observed. **Set `idyom_base = TRUE` to reproduce IDyOM’s
values.**

``` r
# IDyOM call:
#   :stmo '(:escape :c :order-bound 3 :exclusion nil :update-exclusion nil)


result_idyom <- ppidyom(testSequence, maxN = N, alphabet = alphabet, 
                                                model_type = 'stm', ppm_type = 'interpolation', idyom_base = TRUE,
                                                shortTermArgs = list(lambda = 'C', exclusion = FALSE, update_exclusion = FALSE))

result_ppm   <- ppidyom(testSequence, maxN = N, alphabet = alphabet, 
                                                model_type = 'stm', ppm_type = 'interpolation', idyom_base = FALSE,
                                                shortTermArgs = list(lambda = 'C', exclusion = FALSE, update_exclusion = FALSE))
data.frame(event = testSequence,
                     IC_idyom_compat = result_idyom$IC, 
                     IC_ppm_compat   = result_ppm$IC
)
#>   event IC_idyom_compat IC_ppm_compat
#> 1     A       1.5849625     1.5849625
#> 2     B       2.5849625     2.5849625
#> 3     A       1.2630344     1.3219281
#> 4     C       3.9068906     3.4594316
#> 5     A       1.2223924     1.3785116
#> 6     B       1.4150375     1.4594316
#> 7     A       0.2157287     0.3479233
#> 8     C       0.2863042     0.3356030
#> 9     A       0.1018796     0.1622714
```

### IDyOM LTM only

The LTM is trained on a separate corpus before prediction begins. Once
trained, it does not update — the listener’s long-term knowledge stays f
throughout the test sequence. The base prior is determined by the
training data: if all three symbols appear during training, `t_root = 3`
and the order-(-1) probability is `1/(3+1-3) = 1.0`.

`ltm_start_token = FALSE` is required to match IDyOM’s practice of
skipping beginning-of-sequence positions during training.

We’ll use our `testCorpus` again, but this time—by using
`longTermGroups`—we can tell ppidyom() to train its long-term model
based on the `Piece` field.

``` r
# IDyOM call:
#   (idyom:idyom <db-id> '(cpitch) '(cpitch) :texture :melody :models :ltm
#     :ltmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil))

ppidyom(testCorpus$Sequence, maxN = N, alphabet = alphabet, 
                model_type = 'ltm', ppm_type = 'interpolation', idyom_base = TRUE,
                longTermArgs = list(lambda = 'C', exclusion = TRUE, start_token = FALSE),
                longTermGroups = list(testCorpus$Piece)) 
#>     index  Event         P        IC  Entropy
#>     <int> <char>     <num>     <num>    <num>
#>  1:     1      A 0.3571429 1.4854268 1.577406
#>  2:     2      B 0.5500000 0.8624965 1.438759
#>  3:     3      C 0.5283019 0.9205655 1.455683
#>  4:     4      A 0.5500000 0.8624965 1.438759
#>  5:     5      B 0.5500000 0.8624965 1.438759
#>  6:     6      C 0.5283019 0.9205655 1.455683
#>  7:     7      A 0.5500000 0.8624965 1.438759
#>  8:     8      C 0.2000000 2.3219281 1.438759
#>  9:     9      B 0.2500000 2.0000000 1.438759
#> 10:     1      B 0.3333333 1.5849625 1.584963
#> 11:     2      A 0.1666667 2.5849625 1.251629
#> 12:     3      B 0.4444444 1.1699250 1.530493
#> 13:     4      C 0.6666667 0.5849625 1.251629
#> 14:     5      A 0.6666667 0.5849625 1.241946
```

### IDyOM both+ model

`both+` blends the STM and LTM distributions using an entropy-weighted
geometric mean, and simultaneously updates the LTM as the sequence is
processed. The listener starts with long-term experience and also learns
from the piece in real time.

The blend sharpness is controlled by `b = 7`: the model with lower
entropy (more confident predictions) strongly dominates. All three
IDyOM-specific flags are required.

``` r
# IDyOM call:
#   (idyom:idyom <db-id> '(cpitch) '(cpitch) :texture :melody :models :both+
#     :stmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil)
#     :ltmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil))

ppidyom(testCorpus$Sequence, maxN = N, alphabet = alphabet, 
                model_type = 'both+', ppm_type = 'interpolation', idyom_base = TRUE, b = 7,
                shortTermArgs = list(lambda = 'C', exclusion = TRUE, update_exclusion = FALSE),
                longTermArgs = list(lambda = 'C', exclusion = TRUE, update_exclusion = FALSE, start_token = FALSE),
                longTermGroups = list(testCorpus$Piece)) 
#>     index  Event         P        IC  Entropy
#>     <int> <char>     <num>     <num>    <num>
#>  1:     1      A 0.3455200 1.5331590 1.583009
#>  2:     2      B 0.3207316 1.6405615 1.489050
#>  3:     3      C 0.3445727 1.5371195 1.579550
#>  4:     4      A 0.4500539 1.1518303 1.541824
#>  5:     5      B 0.6043820 0.7264674 1.358232
#>  6:     6      C 0.5963342 0.7458071 1.373280
#>  7:     7      A 0.6175950 0.6952671 1.341650
#>  8:     8      C 0.1975305 2.3398527 1.435343
#>  9:     9      B 0.1385047 2.8519929 1.156471
#> 10:     1      B 0.3333333 1.5849625 1.584963
#> 11:     2      A 0.1605485 2.6389189 1.432502
#> 12:     3      B 0.4684657 1.0939848 1.528652
#> 13:     4      C 0.4534789 1.1408927 1.517111
#> 14:     5      A 0.6196401 0.6904975 1.318967
```

------------------------------------------------------------------------

## Quick decision table

| Goal                           | `ltm_start_token` | `idyom_base`      | `b`     | Notes                              |
|--------------------------------|-------------------|-------------------|---------|------------------------------------|
| Match ppm (STM, any exclusion) | `TRUE`            | `FALSE`           | any     | ppm always uses shrinking base     |
| Match IDyOM STM, excl=ON       | `TRUE`            | `TRUE` or `FALSE` | any     | all three implementations agree    |
| Match IDyOM STM, excl=OFF      | `TRUE`            | **`TRUE`**        | any     | base distribution differs from ppm |
| Match IDyOM LTM/ltm+           | **`FALSE`**       | **`TRUE`**        | any     | t_root comes from training data    |
| Match IDyOM both/both+         | **`FALSE`**       | **`TRUE`**        | **`7`** | all three flags required           |
