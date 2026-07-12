<div id="main" class="col-md-9" role="main">

# Build Per-Timestep LTM Count Tables with Online Update

<div class="ref-description section level2">

For ltm+/both+ models: records the LTM state BEFORE observing x\[t\] at
each timestep, then updates the LTM with x\[t\]. This matches IDyOM's
online-update semantics, where prediction at position t uses only the
training corpus plus x\[1:t-1\], not x\[t:T\].

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
build_online_ltm_timestep_counts(
  x,
  N,
  alphabet,
  init_ltm,
  ltm_update_exclusion = FALSE,
  ltm_start_token = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    Character vector of events (the prediction sequence).

-   N:

    Maximum n-gram order.

-   alphabet:

    Character vector of all symbols.

-   init_ltm:

    List of data.tables (format of counts_ltm): the pre-trained LTM
    state before any events from x are observed.

-   ltm_update_exclusion:

    Logical. Apply update exclusion during online update.

-   ltm_start_token:

    Logical. If FALSE, skip NA-lag contexts (IDyOM-compatible).

</div>

<div class="section level2">

## Value

List of length N+1, each a data.table with columns index, context_id,
Event, Ce, C, t, t1 — same format as STM tables, with index in 1..T.

</div>

</div>
