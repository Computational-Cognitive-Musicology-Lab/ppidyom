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

    Character: one of \`"stm"\`, \`"ltm"\`, \`"both"\`.

-   prior:

    Optional: previously accumulated LTM tables (list of length N+1).
    Used to initialize/accumulate counts for LTM or \`both\` type.

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

A list with elements depending on \`model_type\`: - \`$stm\`: list of
length N+1, each a data.table of counts per timestep (if \`model_type\`
includes \`"stm"\`). - \`$ltm\`: list of length N+1, each a data.table
of counts per context (if \`model_type\` includes \`"ltm"\`).

</div>

</div>
