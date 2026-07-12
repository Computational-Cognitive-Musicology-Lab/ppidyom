<div id="main" class="col-md-9" role="main">

# Compute PPM Probabilities for all symbols with Backoff

<div class="ref-description section level2">

Implements a vectorized PPM backoff. Starting from the highest order,
each order assigns probability to symbols it has seen (Ce \> 0); any
probability mass not allocated by that order survives to lower orders.
Symbols not seen at any order receive the remaining mass divided by the
uniform base distribution.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
ppm_backoff(x, N, alphabet, order_counts, escape_func = escape_C)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    Character vector of events

-   N:

    Maximum order

-   alphabet:

    Character vector of full alphabet

-   order_counts:

    List of length N+1 containing count tables for orders 0..N. Each
    element must be a \`data.table\` with columns: \`index\`,
    \`context_id\`, \`Event\`, \`Ce\`, \`C\`, \`t\`, \`t1\`. - For
    \*\*STM\*\*, \`index\` corresponds to the timestep. - For
    \*\*LTM\*\*, \`index\` is constantly -1; \`ltm_to_timestep_counts\`
    maps them to per-timestep tables first.

-   escape_func:

    Escape function (e.g., \`escape_C\`). Signature: \`function(t, t1)\`
    returning \`list(subtract, esc_numer)\`; see escape.R.

</div>

<div class="section level2">

## Value

data.table with columns: index, Event, P, IC, Entropy

</div>

<div class="section level2">

## Details

\## How compute_local_probs and the backoff cascade relate

\`compute_local_probs\` converts raw counts into per-symbol local
weights:

prob_local(s) = max(Ce(s) - subtract, 0) / denom where denom and
subtract come from escape_func

For escape_C: denom = C + t, subtract = 0, so prob_local(s) =
Ce(s)/(C+t). Summing over all seen symbols: Σ prob_local = C/(C+t) = 1 -
esc.

The backoff cascade (p_mass tracks unallocated probability):

p_mass starts at 1 for n = N downto 0: for each seen symbol s (Ce_n \>
0): P(s) = p_mass(s) · prob_local_n(s) ← allocate a share p_mass(s) \*=
(1 - prob_local_n(s)) ← reduce remaining share after loop: unseen
symbols: P(s) = p_mass(s) / \|alphabet\|

</div>

</div>
