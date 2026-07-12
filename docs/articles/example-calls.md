<div id="main" class="col-md-9" role="main">

# Example Calls: Matching ppm and IDyOM

PPM models a listener who hears a musical sequence event by event and
forms expectations about what comes next. Different configurations of
ppidyom correspond to different assumptions about what kind of memory
that listener has:

-   **STM only** — the listener remembers only the current sequence.
    Predictions become sharper as the sequence unfolds and patterns
    repeat.
-   **LTM only** — the listener draws entirely on prior musical
    experience encoded in a training corpus. The current sequence does
    not update their expectations.
-   **Both** — the listener blends long-term knowledge with growing
    memory of the current piece, weighting each source by how confident
    it is.

This vignette shows the exact calls needed to replicate Harrison’s
**ppm** package and IDyOM (Common Lisp). The two differ in several
subtle ways that are explained in
`vignette("implementation-discrepancy")`; the full parameter map is in
`vignette("parameter-correspondence")`.

------------------------------------------------------------------------

<div class="section level2">

## Shared test data

<div id="cb1" class="sourceCode">

``` r
x        <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
alphabet <- c("A", "B", "C")
N        <- 3L
```

</div>

------------------------------------------------------------------------

</div>

<div class="section level2">

## Matching Harrison’s ppm package

The **ppm** package models STM only, using interpolated PPM with the
Witten-Bell escape (method C) by default. It uses a *shrinking* base
distribution: the order-(-1) prior denominator grows as more distinct
symbols are observed, concentrating probability on the already-seen
symbols.

ppidyom matches this with `idyom_base = FALSE` (the default).

<div class="section level3">

### STM, escape C, no exclusion (ppm defaults)

The simplest configuration: the model counts how often each n-gram has
occurred before the current position, then assigns probabilities via
interpolation. Early in the sequence, it relies heavily on low-order
statistics; as patterns repeat, higher orders take over.

<div id="cb2" class="sourceCode">

``` r
# ppm equivalent:
#   ppm::new_ppm_simple(
#     order_bound = 3, alphabet_levels = c("A","B","C"),
#     escape = "c", exclusion = FALSE, update_exclusion = FALSE
#   )
#   ppm::model_seq(mod, factor(x, levels = alphabet))$information_content

model <- ppidyom$new(
  N                    = N,
  alphabet             = alphabet,
  stm_exclusion        = FALSE,
  stm_update_exclusion = FALSE
)
result <- model$predict_sequence(
  x,
  model_type = "stm",
  ppm_type   = "interpolation",
  stm_lambda = "C",    # uppercase = ppidyom; lowercase = ppm/IDyOM
  idyom_base = FALSE   # FALSE = ppm-compatible shrinking base (default)
)
result[data.table(index = seq_along(x), Event = x), on = .(index, Event)]$IC
```

</div>

</div>

<div class="section level3">

### STM, escape A, with exclusion

Escape A (`1/(C+1)`) is more conservative than Witten-Bell: it assigns a
smaller escape probability, so the model stays closer to the specific
context rather than falling back quickly to lower orders. Combined with
exclusion, lower orders only distribute their escaped mass over symbols
not yet covered by higher-order predictions.

<div id="cb3" class="sourceCode">

``` r
# ppm::(escape="a", exclusion=TRUE, update_exclusion=FALSE)

model <- ppidyom$new(
  N                    = N,
  alphabet             = alphabet,
  stm_exclusion        = TRUE,
  stm_update_exclusion = FALSE
)
result <- model$predict_sequence(
  x,
  model_type = "stm",
  ppm_type   = "interpolation",
  stm_lambda = "A",
  idyom_base = FALSE
)
result[data.table(index = seq_along(x), Event = x), on = .(index, Event)]$IC
```

</div>

</div>

<div class="section level3">

### Multiple sequences via `run_ppidyom`

For a corpus of sequences, `run_ppidyom` handles the loop automatically.
Each sequence is processed independently; for STM the model resets
between sequences (each sequence starts from scratch with no accumulated
memory).

<div id="cb4" class="sourceCode">

``` r
corpus <- list(
  c("A","B","A","C","A","B","A","C","A"),
  c("B","A","B","C","A")
)

results <- run_ppidyom(
  corpus,
  N                    = N,
  alphabet             = alphabet,
  model_type           = "stm",
  ppm_type             = "interpolation",
  stm_lambda           = "C",
  stm_exclusion        = FALSE,
  stm_update_exclusion = FALSE,
  idyom_base           = FALSE   # ppm-compatible
)
# results[[i]] has one row per (timestep, symbol); filter to observed events
lapply(seq_along(corpus), function(i) {
  obs <- data.table(index = seq_along(corpus[[i]]), Event = corpus[[i]])
  results[[i]][obs, on = .(index, Event)]$IC
})
```

</div>

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

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

<div class="section level3">

### Default IDyOM STM — exclusion ON

With exclusion on, the order-(-1) base distribution depends on how many
distinct symbols the model has seen, and for STM this is the same
whether you compute it from the training data or from the test sequence
— they are the same sequence. So `idyom_base` has no numerical effect
here; all three implementations agree.

<div id="cb5" class="sourceCode">

``` r
# IDyOM call (Common Lisp):
#   (idyom:idyom <db-id> '(cpitch) '(cpitch) :texture :melody :models :stm
#     :stmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil))

model <- ppidyom$new(
  N                    = N,
  alphabet             = alphabet,
  stm_exclusion        = TRUE,
  stm_update_exclusion = FALSE
)
result <- model$predict_sequence(
  x,
  model_type = "stm",
  ppm_type   = "interpolation",
  stm_lambda = "C",
  idyom_base = TRUE   # no numerical effect with exclusion=TRUE and STM, but explicit for clarity
)
result[data.table(index = seq_along(x), Event = x), on = .(index, Event)]$IC
```

</div>

</div>

<div class="section level3">

### IDyOM STM — exclusion OFF

Without exclusion, IDyOM uses a flat uniform `1/|alphabet|` as the base
prior, regardless of how many symbols have appeared so far. Harrison’s
ppm uses a shrinking denominator instead. This difference is most
visible at the beginning of the sequence, before all alphabet symbols
have been observed. **Set `idyom_base = TRUE` to reproduce IDyOM’s
values.**

<div id="cb6" class="sourceCode">

``` r
# IDyOM call:
#   :stmo '(:escape :c :order-bound 3 :exclusion nil :update-exclusion nil)

model <- ppidyom$new(
  N                    = N,
  alphabet             = alphabet,
  stm_exclusion        = FALSE,
  stm_update_exclusion = FALSE
)

result_idyom <- model$predict_sequence(
  x, model_type = "stm", stm_lambda = "C", idyom_base = TRUE
)
result_ppm <- model$predict_sequence(
  x, model_type = "stm", stm_lambda = "C", idyom_base = FALSE
)

obs <- data.table(index = seq_along(x), Event = x)
data.frame(
  event           = x,
  IC_idyom_compat = result_idyom[obs, on = .(index, Event)]$IC,
  IC_ppm_compat   = result_ppm  [obs, on = .(index, Event)]$IC
)
```

</div>

</div>

<div class="section level3">

### IDyOM LTM only

The LTM is trained on a separate corpus before prediction begins. Once
trained, it does not update — the listener’s long-term knowledge stays
fixed throughout the test sequence. The base prior is determined by the
training data: if all three symbols appear during training, `t_root = 3`
and the order-(-1) probability is `1/(3+1-3) = 1.0`.

`ltm_start_token = FALSE` is required to match IDyOM’s practice of
skipping beginning-of-sequence positions during training.

<div id="cb7" class="sourceCode">

``` r
# IDyOM call:
#   (idyom:idyom <db-id> '(cpitch) '(cpitch) :texture :melody :models :ltm
#     :ltmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil))

train_seq <- c("A","B","C","A","B","C","A","C","B")

model <- ppidyom$new(
  N               = N,
  alphabet        = alphabet,
  ltm_exclusion   = TRUE,
  ltm_start_token = FALSE    # IDyOM-compatible: skip beginning-of-sequence positions
)
model$train_sequence(train_seq)

result <- model$predict_sequence(
  x,
  model_type = "ltm",
  ppm_type   = "interpolation",
  ltm_lambda = "C",
  idyom_base = TRUE           # use t_root from training data, not test sequence
)
result[data.table(index = seq_along(x), Event = x), on = .(index, Event)][
  , .(index, Event, IC, Entropy)
]
```

</div>

</div>

<div class="section level3">

### IDyOM both+ model

`both+` blends the STM and LTM distributions using an entropy-weighted
geometric mean, and simultaneously updates the LTM as the sequence is
processed. The listener starts with long-term experience and also learns
from the piece in real time.

The blend sharpness is controlled by `b = 7`: the model with lower
entropy (more confident predictions) strongly dominates. All three
IDyOM-specific flags are required.

<div id="cb8" class="sourceCode">

``` r
# IDyOM call:
#   (idyom:idyom <db-id> '(cpitch) '(cpitch) :texture :melody :models :both+
#     :stmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil)
#     :ltmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil))

model <- ppidyom$new(
  N                    = N,
  alphabet             = alphabet,
  stm_exclusion        = TRUE,
  ltm_exclusion        = TRUE,
  stm_update_exclusion = FALSE,
  ltm_update_exclusion = FALSE,
  ltm_start_token      = FALSE   # IDyOM-compatible
)
model$train_sequence(train_seq)

result <- model$predict_sequence(
  x,
  model_type = "both+",
  ppm_type   = "interpolation",
  stm_lambda = "C",
  ltm_lambda = "C",
  b          = 7,         # IDyOM default: sharp entropy-weighting (Pearce 2005)
  idyom_base = TRUE
)
result[data.table(index = seq_along(x), Event = x), on = .(index, Event)][
  , .(index, Event, IC, Entropy)
]
```

</div>

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## Quick decision table

| Goal                           | `ltm_start_token` | `idyom_base`      | `b`     | Notes                              |
|--------------------------------|-------------------|-------------------|---------|------------------------------------|
| Match ppm (STM, any exclusion) | `TRUE`            | `FALSE`           | any     | ppm always uses shrinking base     |
| Match IDyOM STM, excl=ON       | `TRUE`            | `TRUE` or `FALSE` | any     | all three implementations agree    |
| Match IDyOM STM, excl=OFF      | `TRUE`            | **`TRUE`**        | any     | base distribution differs from ppm |
| Match IDyOM LTM/ltm+           | **`FALSE`**       | **`TRUE`**        | any     | t_root comes from training data    |
| Match IDyOM both/both+         | **`FALSE`**       | **`TRUE`**        | **`7`** | all three flags required           |

------------------------------------------------------------------------

</div>

<div class="section level2">

## HumdrumR integration (planned)

ppidyom is designed to integrate with
[HumdrumR](https://github.com/Computational-Cognitive-Musicology-Lab/humdrumR),
the symbolic music analysis framework for R. The planned workflow will
allow you to pass a Humdrum score directly into ppidyom without any
manual format conversion:

<div id="cb9" class="sourceCode">

``` r
# Planned API — not yet implemented
# library(humdrumR)
#
# h <- readHumdrum("my_score.krn")
#
# # ppidyom will accept HumdrumR objects directly:
# ic_results <- h |>
#   select_viewpoint("cpitch") |>
#   run_ppidyom(
#     N               = 3L,
#     model_type      = "both+",
#     stm_lambda      = "C",
#     ltm_lambda      = "C",
#     b               = 7,
#     ltm_start_token = FALSE,
#     idyom_base      = TRUE
#   )
```

</div>

The current `run_ppidyom` function operates on plain R lists of
character vectors (one per sequence). The HumdrumR wrapper will handle
the extraction of the chosen viewpoint (e.g. chromatic pitch, scale
degree, interval) and convert the results back into a
HumdrumR-compatible data object, enabling IC analysis as part of a
broader corpus analysis pipeline.

</div>

</div>
