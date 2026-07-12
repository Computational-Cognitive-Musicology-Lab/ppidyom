<div id="main" class="col-md-9" role="main">

# Compute PPM Probabilities for all symbols with Interpolation

<div class="ref-description section level2">

Implements the interpolated variant of PPM (Prediction by Partial
Matching). Every order from N down to 0 contributes a share of
probability mass, with any leftover mass falling through to a base
(uniform) distribution.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
ppm_interpolated(
  x,
  N,
  alphabet,
  order_counts,
  escape_func = escape_C,
  exclusion = TRUE,
  idyom_base = FALSE
)
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
    maps them to per-timestep tables before the loop.

-   escape_func:

    Escape function from escape.R (e.g., \`escape_C\`). Signature:
    \`function(t, t1)\` returning \`list(subtract, esc_numer)\`. Method
    C is the standard choice and matches ppm package defaults.

-   exclusion:

    Logical. If TRUE, applies exclusion (Cleary & Witten 1984). Symbols
    already seen at a higher order are excluded from C when computing
    denom and esc at lower orders. Effect: denom shrinks → esc increases
    → more mass flows to truly unseen symbols. Excluded symbols can
    still receive contrib mass from this order; only the denominator
    changes.

</div>

<div class="section level2">

## Value

data.table with columns: index, Event, P, IC, Entropy

</div>

<div class="section level2">

## Details

\## Math

At each order n, every symbol receives a contribution:

alpha_n(s) = max(Ce_n(s) - d, 0) / denom_n

where d = subtract and denom_n = context_count + esc_numer, with
(subtract, esc_numer) returned by escape_func (see escape.R):

Method A : d=0, eff=1, ctx=C, denom=C+1 Method B : d=1, eff=t, ctx=C-t,
denom=C Method C : d=0, eff=t, ctx=C, denom=C+t Method D : d=0.5,
eff=t/2, ctx=C-0.5t, denom=C Method AX: d=0, eff=t1+1, ctx=C,
denom=C+t1+1

Contributions are accumulated across orders using a running "remaining
mass" (R) that shrinks by the escape probability at each order:

R starts at 1 each order n: P(s) += R · contrib_n(s) R \*= esc_n after
order 0: P(s) += R · base(s)

Expanded (method C for concreteness):

P(s) = Ce_N(s)/(C_N+t_N) + \[t_N/(C_N+t_N)\] · Ce_N-1(s)/(C_N-1+t_N-1) +
\[t_N/(C_N+t_N)\] · \[t_N-1/(...)\] · Ce_N-2(s)/(...) + ... + (∏ esc_k)
· base(s)

</div>

</div>
