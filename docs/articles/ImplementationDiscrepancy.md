<div id="main" class="col-md-9" role="main">

# Implementation Differences: ppm, IDyOM, and ppidyom

<div class="section level2">

## Overview

PPM is not a single algorithm — it is a family of models defined by a
set of algorithmic choices. Harrison’s **ppm** R package and IDyOM
(Common Lisp) are both interpolated PPM implementations, but they make
different choices at six decision points. ppidyom covers both: its
defaults are documented, and every divergence is exposed as a named
parameter.

| \#  | Topic                    | ppm              | IDyOM                        | ppidyom default            | Flag to match IDyOM       |
|-----|--------------------------|------------------|------------------------------|----------------------------|---------------------------|
| 1   | Base prior, LTM          | — (no LTM)       | Training `t_root`            | Test-sequence `t_root`     | `idyom_base = TRUE`       |
| 2   | Base prior, STM excl=OFF | Shrinking        | Flat uniform                 | Shrinking (= ppm)          | `idyom_base = TRUE`       |
| 3   | LTM start positions      | — (no LTM)       | Skip start tokens            | Include all                | `ltm_start_token = FALSE` |
| 4   | STM+LTM normalisation    | — (no mixture)   | Conditional skip             | Conditional skip (= IDyOM) | (already matching)        |
| 5   | Mixture exponent *b*     | — (no mixture)   | b = 7                        | b = 1                      | `b = 7`                   |
| 6   | AX escape method         | `"ax"` (correct) | `:ax` is dead code; use `:x` | `"X"` (correct)            | Call IDyOM with `:x`      |

------------------------------------------------------------------------

</div>

<div class="section level2">

## 1. Base prior — LTM

<div class="section level3">

### The concept

Every PPM model chains through context orders from the longest available
down to a final fallback — the **order −1 distribution** — that absorbs
any probability mass that escapes every context. At this level the model
has no context at all, so it assigns probability proportionally across
alphabet symbols. But *how many symbols does it think remain?* The
denominator of this prior depends on what the model has seen, and the
answer differs by model type.

With exclusion on, symbols already assigned probability at higher orders
are conceptually covered. The order −1 prior only needs to distribute
over the *remaining* symbols — and how many remain depends on whether
you look at the **training corpus** or the **current test sequence**.

</div>

<div class="section level3">

### The implementations’ choices

IDyOM determines this count from the model’s root: specifically, the
number of distinct symbols observed at order 0 in the **training data**.
For a LTM trained on all three symbols A, B, C, this is a fixed
constant: `t_root = 3`, giving order-minus1-p = 1 / (3 + 1 − 3) =
**1.0**.

ppm has no LTM, so this comparison does not apply.

ppidyom by default uses the test-sequence count (how many symbols have
been observed so far in the current sequence), which gives a more
natural STM-style answer. When working with LTM or both-type models, set
`idyom_base = TRUE` to use the training-data count as IDyOM does.

The relevant logic in `R/interpolation.R`:

<div id="cb1" class="sourceCode">

``` r
# t_root comes from the order-0 count table:
# for STM: counts observed in the test sequence so far
# for LTM: counts from the training corpus (fixed)
t_root_by_t <- dt_orders[[1]][, .(t_root = t[1]), by = index]$t_root

p_base <- if (idyom_base && !exclusion)
  1.0 / length(alphabet)                                     # IDyOM excl=OFF (§2)
else if (idyom_base && exclusion)
  1.0 / (length(alphabet) + 1L - t_root_by_t[t])           # IDyOM excl=ON
else
  1.0 / (length(alphabet) + 1L - length(seen_symbols))     # ppm-compatible
```

</div>

IDyOM source (`ppm-star/ppm-star.lisp`, `order-minus1-probability`):

<div id="cb2" class="sourceCode">

``` lisp
(defmethod order-minus1-probability ((m ppm) update-exclusion)
  (/ 1.0
     (float (- (+ 1.0 (alphabet-size m))
               (if (ppm-exclusion m)
                   (hash-table-count          ; ← t_root: from MODEL (training)
                     (transition-counts m (get-root) update-exclusion))
                   1.0))                      ; ← flat uniform when exclusion=OFF
            0.0)))
```

</div>

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## 2. Base prior — STM, exclusion OFF

<div class="section level3">

### The concept

When exclusion is off, there is no “accounted-for” set: all symbols in
the alphabet are always eligible at order −1. The question becomes
simply: should the uniform prior be `1 / |alphabet|` (flat over all
symbols always) or should the denominator shrink until all symbols have
appeared in the sequence?

This is a design choice. IDyOM uses the flat uniform; ppm uses a
shrinking denominator. The difference is only visible before all
alphabet symbols have appeared — after that, both converge.

</div>

<div class="section level3">

### The implementations’ choices

| exclusion | IDyOM prior                      | ppm prior                          | ppidyom default            |
|-----------|----------------------------------|------------------------------------|----------------------------|
| OFF       | `1 / \|alphabet\|` — flat always | `1 / (\|α\|+1−\|seen\|)` — shrinks | ppm-compatible (shrinking) |
| ON        | `1 / (\|α\|+1−t_root)`           | `1 / (\|α\|+1−\|seen\|)`           | matches IDyOM              |

Set `idyom_base = TRUE` in `predict_sequence()` to use IDyOM’s flat
uniform when `exclusion = FALSE`. When `exclusion = TRUE`, all three
implementations already agree.

<div id="cb3" class="sourceCode">

``` r
x        <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
alphabet <- c("A", "B", "C")
N        <- 3L

model <- ppidyomModel$new(N = N, alphabet = alphabet,
                     stm_exclusion = FALSE, stm_update_exclusion = FALSE)

ic_ppm_compat <- model$predict_sequence(
  x, model_type = "stm", stm_lambda = "C", idyom_base = FALSE
)[data.table(index=seq_along(x),Event=x), on=.(index,Event)]$IC

ic_idyom_compat <- model$predict_sequence(
  x, model_type = "stm", stm_lambda = "C", idyom_base = TRUE
)[data.table(index=seq_along(x),Event=x), on=.(index,Event)]$IC

data.frame(
  t            = seq_along(x),
  event        = x,
  IC_ppm_base  = round(ic_ppm_compat,   4),
  IC_idyom_base= round(ic_idyom_compat, 4),
  diff         = round(ic_ppm_compat - ic_idyom_compat, 4)
)
```

</div>

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## 3. LTM beginning-of-sequence positions (`ltm_start_token`)

<div class="section level3">

### The concept

When training the LTM on a corpus, should the very first note of each
piece contribute to the count tables? At position 1 there is no prior
context — the preceding N−1 events are undefined — so the note can only
be counted as an unconditional observation.

Piece beginnings are a structurally special context: they often start on
the tonic, the first beat, with particular melodic shapes. Whether to
treat this as a generalisable observation (count it) or as too specific
to generalise (skip it) is a design choice.

</div>

<div class="section level3">

### The implementations’ choices

IDyOM silently skips positions where the context window extends before
the start of a sequence. Harrison’s ppm includes them. ppm has no LTM,
so only ppidyom and IDyOM differ here.

The practical effect: with `ltm_start_token = FALSE` (IDyOM-compatible),
the total count at order 0 — and therefore `t_root` and the order −1
prior — will be lower than with `TRUE`.

| ppidyom `ltm_start_token` | Positions counted                                     | Matches                 |
|---------------------------|-------------------------------------------------------|-------------------------|
| `TRUE` (default)          | all positions, including those with undefined context | Harrison’s ppm approach |
| `FALSE`                   | positions with NA lags are skipped                    | **IDyOM**               |

<div id="cb4" class="sourceCode">

``` r
# IDyOM-compatible LTM (used in all IDyOM comparison tests)
model <- ppidyomModel$new(
  N               = 3L,
  alphabet        = c("A","B","C"),
  ltm_start_token = FALSE
)
```

</div>

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## 4. STM+LTM mixture normalisation (`sums-to-one-p`)

<div class="section level3">

### The concept

When blending STM and LTM in `both`/`both+` models, the model computes a
log-linear combination and then renormalises it to sum to 1. In
floating-point arithmetic the blended distribution almost never sums to
*exactly* 1, so renormalising always applies a small correction.

IDyOM avoids this by checking: if the sum already falls between 0.999
and 1.0, treat it as already normalised and skip the division. Without
this shortcut, division by a number like 0.99999… introduces small but
systematic differences in the output.

</div>

<div class="section level3">

### The implementations’ choices

ppm has no mixture support, so this does not apply.

IDyOM source (`ppm-star.lisp`, `normalise-distribution`):

<div id="cb5" class="sourceCode">

``` lisp
(defun sums-to-one-p (distribution)
  (let ((s (apply #'+ (mapcar #'cadr distribution))))
    (and (> s 0.999) (< s 1.0))))

(defun normalise-distribution (distribution)
  (if (sums-to-one-p distribution)
      distribution                    ; already close enough — skip division
      (let ((sum (apply #'+ (mapcar #'cadr distribution))))
        (mapcar (lambda (p) (list (car p) (/ (cadr p) sum)))
                distribution))))
```

</div>

ppidyom’s `combine_models` replicates this exactly:

<div id="cb6" class="sourceCode">

``` r
# R/ppidyom.R — combine_models
dt[, P_raw := P_stm^w_stm_n * P_ltm^w_ltm_n]
dt[, Z     := sum(P_raw), by = index]
dt[, P     := if (Z[1] > 0.999 && Z[1] < 1.0) P_raw else P_raw / Z,
    by = index]
```

</div>

ppidyom matches IDyOM by default for this; no flag is required.

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## 5. Mixture weight exponent *b*

<div class="section level3">

### The concept

When blending STM and LTM, the model gives more weight to whichever
distribution is more confident — lower entropy means more certain
predictions. The exponent *b* controls how sharply this
confidence-weighting operates.

$$w\_{i} \\propto \\left( \\frac{H\_{i}}{H\_{\\max}} \\right)^{- b},\\quad H\_{\\max} = \\log\_{2}\|alphabet\|$$

With b = 1, the two models contribute roughly in proportion to their
confidence. With b = 7 (IDyOM’s default, Pearce 2005), the lower-entropy
model almost completely dominates — a sharp, near-winner-take-all blend.

</div>

<div class="section level3">

### The implementations’ choices

ppm has no mixture support, so this does not apply.

ppidyom defaults to `b = 1`; pass `b = 7` to match IDyOM’s default
behaviour:

<div id="cb7" class="sourceCode">

``` r
model$predict_sequence(x, model_type = "both", b = 7, ...)
```

</div>

The `test-idyom-comparison.R` suite always passes `b = 7` when testing
`both`/`both+` configurations.

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## 6. Escape method AX — IDyOM bug; call with `:x`

<div class="section level3">

### The concept

Method AX (Moffat 1990) adjusts the escape probability using the count
of *singleton* symbols — symbols seen exactly once in the current
context — rather than the count of all distinct symbols. The intuition
is that a symbol seen only once is weak evidence, so more probability
mass should escape to shorter contexts.

Harrison’s **ppm** and ppidyom implement this directly: escape =
(t₁ + 1) / (C + t₁ + 1) where t₁ = count of singletons.

<div id="cb8" class="sourceCode">

``` r
# R/escape.R — escape_AX
esc_numer <- t1 + 1L
weight    <- C / (C + esc_numer)
escape    <- esc_numer / (C + esc_numer)
```

</div>

</div>

<div class="section level3">

### The IDyOM bug

IDyOM stores AX internally under the keyword `:x`. The
`set-ppm-parameters` case expression and the singleton-counting branch
in `type-count` are both keyed on `:x`:

<div id="cb9" class="sourceCode">

``` lisp
;; ppm-star.lisp — set-ppm-parameters
(case escape
  (:a  (values 0 1))
  (:b  (values -1 1))
  ((or :c :x) (values 0 1))   ; ← AX handled as :x internally
  (:d  (values -1/2 2))
  (otherwise (values 0 1)))   ; ← :ax falls through, accidentally same as :c

;; ppm-star.lisp — type-count (singleton branch)
(:x (let ((count 1))
      (maphash (lambda (k v)
                 (declare (ignore k))
                 (when (= v 1) (incf count 1)))
               (transition-counts m location))
      count))   ; → 1 + t₁, but only reached when escape = :x, not :ax
```

</div>

When IDyOM is called with `:escape :ax` (the documented keyword), the
singleton branch never executes — `:ax` silently produces the same
values as `:c`. **The correct call is `:x`.**

</div>

<div class="section level3">

### How ppidyom handles this

ppidyom uses `"X"` (uppercase) for AX, which maps to ppm’s `"ax"` and to
IDyOM’s `:x` (not `:ax`). The fixture generator calls IDyOM with `"x"`
so the AX singleton branch actually fires. AX is fully covered in both
the IDyOM and ppm comparison suites.

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## Summary

ppidyom’s default behaviour and required flags:

| Configuration                  | ppidyom matches IDyOM?   | Flags required                                          |
|--------------------------------|--------------------------|---------------------------------------------------------|
| STM, any escape, exclusion=ON  | ✓ always                 | `stm_exclusion = TRUE`                                  |
| STM, any escape, exclusion=OFF | ✗ by default             | `idyom_base = TRUE`                                     |
| LTM / ltm+, exclusion=ON       | ✓ with flags             | `ltm_start_token = FALSE`, `idyom_base = TRUE`          |
| LTM / ltm+, exclusion=OFF      | ✗ by default             | `ltm_start_token = FALSE`, `idyom_base = TRUE`          |
| both / both+                   | ✓ with flags             | `ltm_start_token = FALSE`, `idyom_base = TRUE`, `b = 7` |
| AX escape                      | ✓ (call IDyOM with `:x`) | fixture uses `:x`; test maps `"x"` → ppidyom `"X"`      |

For working code examples see
[`vignette("example-calls")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ExampleCalls.md).
For the full parameter map see
[`vignette("parameter-correspondence")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.md).

</div>

</div>
