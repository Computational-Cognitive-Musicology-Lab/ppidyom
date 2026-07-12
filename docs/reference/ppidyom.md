<div id="main" class="col-md-9" role="main">

# Calculate information dynamics using PPIDyOM

<div class="ref-description section level2">

This function calls ppidyom on arbitrary vectors of data, or humdrumR
data.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
ppidyom(...)
```

</div>

</div>

<div class="section level2">

## Arguments

-   ...:

    ***One or more input vectors, all the same length.***

-   maxN:

    ***Maximum N-gram length to compute.*** Defaults to 5.

-   alphabet:

    ***The set of possible input values. By default, cartesian product
    of input vectors.***

-   model_type:

    ***Which memory component(s) to use:***

    -   ***`"stm"` — short-term memory, within each `shortTermGroups`
        group only.***

    -   ***`"ltm"` — long-term memory, trained across
        `longTermGroups`.***

    -   ***`"both"` — STM + LTM blended.***

    -   ***`"ltm+"`/`"both+"` — as `"ltm"`/`"both"`, but LTM updates
        online group by group.***

-   ppm_type:

    ***PPM estimation method:***

    -   ***`"interpolation"` — weighted sum across all n-gram orders.***

    -   ***`"backoff"` — falls through orders from longest to shortest
        matching context.***

-   shortTermArgs:

    ***List of STM settings:***

    -   ***`lambda` — escape method, one of
        `"A"`/`"B"`/`"C"`/`"D"`/`"X"` (default `"C"`); see the [Escape
        method](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.html#escape-method)
        section of the [Parameter
        Correspondence](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ParameterCorrespondence.md)
        vignette.***

    -   ***`exclusion` — logical; exclude symbols already assigned a
        probability at a higher order (default TRUE).***

    -   ***`update_exclusion` — logical; stop updating lower-order
        counts once a higher order already matched at this timestep
        (default TRUE).***

-   longTermArgs:

    ***List of LTM settings: same as `shortTermArgs`, plus `start_token`
    (whether to count beginning-of-sequence positions).***

-   longTermGroups:

    ***Groups for long term training (usually pieces).***

-   shortTermGroups:

    ***Groups for short term (local) application (usually parts within a
    piece).***

-   b:

    ***Bias exponent for entropy-weighted blending, used only when
    `model_type` is `"both"`/`"both+"`; higher values favor whichever of
    STM/LTM is currently more confident.***

-   idyom_base:

    ***Logical; use IDyOM's order-(-1) base distribution instead of the
    default shrinking-denominator base. See the [Implementation
    Discrepancy](https://ppidyom.ccml.gtcmt.gatech.edu/articles/ImplementationDiscrepancy.md)
    vignette.***

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
if (FALSE) { # \dontrun{
x <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
ppidyom(x, maxN = 3, model_type = "stm")
} # }
```

</div>

</div>

</div>
