<div id="main" class="col-md-9" role="main">

# Overview: Motivation, Design, and Applications

<div class="section level2">

## Why model musical expectation?

When people listen to music, they form expectations about what comes
next — which note, harmony, or rhythm follows from what they have
already heard. These expectations reflect both the statistical
regularities of musical culture (patterns learned over years of
listening) and the specific context of the piece playing right now.

Information theory gives us a way to measure surprise. When an event is
unexpected, it carries high **information content** (IC); when it was
anticipated, IC is low. Averaged over a sequence, this gives **entropy**
— a measure of how predictable a passage is overall. These quantities
have been linked empirically to:

-   melodic expectancy ratings (Pearce et al., 2010; Pearce, 2018)
-   perceived tension and resolution (Farbood, 2012)
-   neural responses to music (EEG, fMRI)
-   cross-cultural differences in tonal stability

**PPM** (Prediction by Partial Matching) is the statistical model
underlying most of this research. It processes a musical sequence event
by event, maintains counts of how often each pattern has occurred, and
uses those counts to assign probabilities to the next event. The output
is a per-event IC trajectory that can be compared against listener data,
neural recordings, or other models.

------------------------------------------------------------------------

</div>

<div class="section level2">

## How PPM works

A PPM model keeps a running record of every n-gram (subsequence of
length 1, 2, …, N) it has encountered. When it sees a new event, it
finds the longest matching context, reads off the conditional
probability, and — when a context has never been seen — **escapes** to
the next shorter context. This chaining continues down to a uniform
prior that covers any event not seen at all.

Two kinds of memory can be involved:

-   **Short-term memory (STM)**: counts built from the current sequence
    only. Predictions sharpen as patterns repeat within a single piece.
-   **Long-term memory (LTM)**: counts pre-built from a training corpus.
    The model brings prior musical knowledge to each new sequence.
-   **Both / both+**: the model blends LTM knowledge with growing STM
    counts, weighting each source by how confident it currently is
    (lower entropy = higher weight).

The escape fraction at each order is controlled by the **escape method**
(A, B, C, D, or AX). Different methods trade off between relying on the
current context and falling back quickly to shorter histories.

------------------------------------------------------------------------

</div>

<div class="section level2">

## Existing implementations and their gaps

Three PPM-based tools for music IC analysis are in active use:

| Tool                        | Language    | Memory                | First published       |
|-----------------------------|-------------|-----------------------|-----------------------|
| **IDyOM** (Pearce)          | Common Lisp | STM, LTM, both, both+ | Pearce, 2005          |
| **ppm** (Harrison et al.)   | R           | STM only              | Harrison et al., 2020 |
| **IDyOMpy** (Marion et al.) | Python      | STM, LTM, both        | Marion et al., 2025   |

Despite sharing the same conceptual model, these implementations make
different choices at several algorithmic decision points: how the base
prior is computed, whether beginning-of-sequence positions are counted
during LTM training, how the escape method AX is interpreted, and what
the default mixture weight is.

These divergences are subtle — they are not documented comprehensively
anywhere and are not obvious from reading the respective codebases. The
result is that the same musical sequence can produce different IC values
from different tools even when the nominal settings appear identical.
This makes it difficult to:

1.  **Compare results** across studies that used different tools
2.  **Reproduce** a published analysis in a different implementation
3.  **Understand** what each parameter actually implies for the model’s
    behaviour

------------------------------------------------------------------------

</div>

<div class="section level2">

## What ppidyom offers

ppidyom is a new R implementation of PPM covering all four memory
configurations (STM, LTM, both, both+) and exposing every parameter that
governs how the model behaves.

<div class="section level3">

### Transparency and parameter correspondence

Every algorithmic choice that differs between IDyOM and ppm is exposed
as a named parameter.
[`vignette("implementation-discrepancy")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ImplementationDiscrepancy.md)
documents the six divergences, explains the information-theoretic
motivation for each, and shows exactly which ppidyom flag controls which
behaviour.
[`vignette("parameter-correspondence")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.md)
maps each ppidyom parameter to its IDyOM and ppm equivalents.

</div>

<div class="section level3">

### Benchmarking

ppidyom is validated against both IDyOM (Common Lisp) and ppm (R) using
a pre-generated reference fixture. Over 240 tests confirm that ppidyom
produces numerically identical IC values when configured to match either
implementation.

</div>

<div class="section level3">

### Speed

ppidyom builds count tables with `data.table` and processes sequences
with vectorised operations. This makes it substantially faster than the
IDyOM CLI on large corpora.

</div>

<div class="section level3">

### HumdrumR integration (early / basic)

ppidyom now integrates with
[HumdrumR](https://github.com/Computational-Cognitive-Musicology-Lab/humdrumR),
the symbolic music analysis framework for R, via `ppidyom.humdrumR()` —
an S3 method on the new `ppidyom()` generic. It accepts Humdrum-format
scores directly and returns IC results attached to the HumdrumR data
object, enabling PPM-based analysis as part of a broader corpus analysis
pipeline. This is a first-pass implementation; see
[`vignette("example-calls")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ExampleCalls.html#humdrumr-integration-early-basic)
for a usage example.

------------------------------------------------------------------------

</div>

</div>

<div class="section level2">

## Applications

PPM-based IC analysis has been applied to a wide range of questions:

-   **Melodic expectancy** — does high IC predict moments listeners rate
    as surprising? (Pearce et al., 2010)
-   **Tension and resolution** — do IC peaks correlate with felt
    tension? (Farbood, 2012)
-   **Cross-cultural comparison** — do listeners from different musical
    backgrounds assign different IC to the same passage?
-   **Computational stylistics** — does IC profile distinguish composers
    or historical periods?
-   **Neuroimaging** — does BOLD signal or EEG amplitude track per-note
    IC?

ppidyom’s full LTM support and configurable parameters make it suitable
for any of these use cases. The ability to replicate both IDyOM and ppm
behaviour from a single codebase also makes it useful for replication
studies and cross-implementation comparison.

------------------------------------------------------------------------

</div>

<div class="section level2">

## Quick start

<div id="cb1" class="sourceCode">

``` r
library(ppidyom)
library(data.table)

# A short melody represented as symbol labels
melody   <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
alphabet <- c("A", "B", "C")
N        <- 3L   # order bound: consider up to 3-event contexts

# STM model with default IDyOM-compatible settings
model <- ppidyomModel$new(N = N, alphabet = alphabet, stm_exclusion = TRUE)

result <- model$predict_sequence(
  melody,
  model_type = "stm",
  ppm_type   = "interpolation",
  stm_lambda = "C",
  idyom_base = TRUE
)

# Extract IC for the observed events
obs <- data.table(index = seq_along(melody), Event = melody)
result[obs, on = .(index, Event)][, .(index, Event, IC, Entropy)]
```

</div>

For calls that replicate IDyOM or the ppm package exactly, see
[`vignette("example-calls")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ExampleCalls.md).
For a full description of how the implementations differ and how to
configure ppidyom, see
[`vignette("implementation-discrepancy")`](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ImplementationDiscrepancy.md).

</div>

</div>
