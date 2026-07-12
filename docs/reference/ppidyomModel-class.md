<div id="main" class="col-md-9" role="main">

# Initialize a new PPM counter Train on a single sequence (incremental LTM update)

<div class="ref-description section level2">

Initialize a new PPM counter Train on a single sequence (incremental LTM
update)

</div>

<div class="section level2">

## Arguments

-   x:

    Character vector sequence

-   model_type:

    Model type: "stm", "ltm", "both", "ltm+", "both+"

-   ppm_type:

    "interpolation" or "backoff"

-   stm_lambda:

    escape or discount function for STM (default = "C")

-   ltm_lambda:

    escape or discount function for LTM (default = "C")

-   b:

    Bias parameter for relative-entropy weighting (used for + models)

-   idyom_base:

    Logical. If TRUE, use IDyOM-compatible order-(-1) base distribution:
    1/\|alphabet\| when exclusion=FALSE, shrinking denominator when
    exclusion=TRUE. If FALSE (default), always use the shrinking
    denominator (matches Harrison's ppm package). See
    vignette("implementation-discrepancy") for details.

    Note: the constructor flag \`ltm_start_token\` controls whether LTM
    counts include beginning-of-sequence positions (TRUE, default) or
    skip them (FALSE, IDyOM-compatible). See
    vignette("implementation-discrepancy").

</div>

<div class="section level2">

## Value

data.table with columns: index, Event, P, IC, Entropy

</div>

</div>
