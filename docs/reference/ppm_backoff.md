# Compute PPM Probabilities for all symbols with Backoff

Implements the PPM non-mixture (backoff) model that matches IDyOM's
`:mixtures nil` behaviour. Each symbol is finalized at the deepest order
whose context has observed it (highest order wins); symbols not seen at
any order receive the accumulated escape mass scaled by the base prior.
The final per-timestep distribution is renormalized to sum to 1.

## Usage

``` r
ppm_backoff(
  x,
  N,
  alphabet,
  order_counts,
  escape_func = escape_C,
  exclusion = FALSE,
  idyom_base = FALSE
)
```

## Arguments

- x:

  Character vector of events

- N:

  Maximum order

- alphabet:

  Character vector of full alphabet

- order_counts:

  List of length N+1 containing count tables for orders 0..N. Each
  element must be a `data.table` with columns: `index`, `context_id`,
  `Event`, `Ce`, `C`, `t`, `t1`.

  - For **STM**, `index` corresponds to the timestep.

  - For **LTM**, `index` is constantly -1; `ltm_to_timestep_counts` maps
    them to per-timestep tables first.

- escape_func:

  Escape function (e.g., `escape_C`). Signature: `function(t, t1)`
  returning `list(subtract, esc_numer)`; see escape.R.

- exclusion:

  Logical. If TRUE, symbols seen at higher orders are excluded from the
  context count at lower orders (Cleary & Witten 1984).

- idyom_base:

  Logical. Selects the order-(-1) base distribution. TRUE =
  IDyOM-compatible (1/\|alphabet\| or shrinking with exclusion); FALSE =
  Harrison's ppm-compatible shrinking denominator.

## Value

data.table with columns: index, Event, P, IC, Entropy

## Details

### Cascade algorithm

esc_mass[t](https://rdrr.io/r/base/t.html) tracks remaining probability
mass for timestep t (starts at 1). At each order, only symbols not yet
finalized AND not excluded are eligible.

for n = N downto 0: for each eligible symbol s (Ce_n(s) \> 0, unfixed,
not excluded): P(s) = esc_mass[t](https://rdrr.io/r/base/t.html) \*
prob_local_n(s) \<- finalize at highest order
esc_mass[t](https://rdrr.io/r/base/t.html) \*=
esc_n[t](https://rdrr.io/r/base/t.html) \<- remaining mass flows down if
exclusion: mark all Ce\>0 symbols as excluded for each symbol s still
unset: P(s) = esc_mass[t](https://rdrr.io/r/base/t.html) \* base(s) \<-
base prior normalize P[t](https://rdrr.io/r/base/t.html) so that sum = 1

### Exclusion (Cleary & Witten 1984)

Same as `ppm_interpolated`: once a symbol has Ce \> 0 at any order it is
marked excluded and removed from the context count (ctx) at lower
orders. The escape numerator (esc_numer) uses the ORIGINAL t (including
excluded), matching Harrison's ppm and IDyOM behaviour (see
`ppm_interpolated` docs).

### Base distribution

Mirrors `ppm_interpolated`: idyom_base + !exclusion -\> 1 / \|alphabet\|
idyom_base + exclusion -\> 1 / (\|alphabet\| + 1 - t_root) !idyom_base
-\> 1 / (\|alphabet\| + 1 - \|seen_at_t\|)
