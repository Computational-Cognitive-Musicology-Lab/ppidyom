library(data.table)

#' Compute PPM Probabilities for all symbols with Interpolation
#'
#' Implements the interpolated variant of PPM (Prediction by Partial Matching).
#' Every order from N down to 0 contributes a share of probability mass, with
#' any leftover mass falling through to a base (uniform) distribution.
#'
#' ## Math
#'
#' At each order n, every symbol receives a contribution:
#'
#'   alpha_n(s) = max(Ce_n(s) - d, 0) / denom_n
#'
#' where d = subtract and denom_n = context_count + esc_numer,
#' with (subtract, esc_numer) returned by escape_func (see escape.R):
#'
#'   Method A : d=0,   eff=1,    ctx=C,       denom=C+1
#'   Method B : d=1,   eff=t,    ctx=C-t,     denom=C
#'   Method C : d=0,   eff=t,    ctx=C,       denom=C+t
#'   Method D : d=0.5, eff=t/2,  ctx=C-0.5t,  denom=C
#'   Method AX: d=0,   eff=t1+1, ctx=C,       denom=C+t1+1
#'
#' Contributions are accumulated across orders using a running "remaining
#' mass" (R) that shrinks by the escape probability at each order:
#'
#'   R starts at 1
#'   each order n:   P(s) += R · contrib_n(s)
#'                   R    *= esc_n
#'   after order 0:  P(s) += R · base(s)
#'
#' Expanded (method C for concreteness):
#'
#'   P(s) =  Ce_N(s)/(C_N+t_N)
#'         + [t_N/(C_N+t_N)] · Ce_{N-1}(s)/(C_{N-1}+t_{N-1})
#'         + [t_N/(C_N+t_N)] · [t_{N-1}/(...)] · Ce_{N-2}(s)/(...)
#'         + ...
#'         + (∏ esc_k) · base(s)
#'
#' @param x Character vector of events
#' @param N Maximum order
#' @param alphabet Character vector of full alphabet
#' @param order_counts List of length N+1 containing count tables for orders
#'   0..N. Each element must be a `data.table` with columns:
#'   `index`, `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.
#'   - For **STM**, `index` corresponds to the timestep.
#'   - For **LTM**, `index` is constantly -1; `ltm_to_timestep_counts` maps
#'     them to per-timestep tables before the loop.
#' @param escape_func Escape function from escape.R (e.g., `escape_C`).
#'   Signature: `function(t, t1)` returning `list(subtract, esc_numer)`.
#'   Method C is the standard choice and matches ppm package defaults.
#' @param exclusion Logical. If TRUE, applies exclusion (Cleary & Witten 1984).
#'   Symbols already seen at a higher order are excluded from C when computing
#'   denom and esc at lower orders.  Effect: denom shrinks → esc increases →
#'   more mass flows to truly unseen symbols.  Excluded symbols can still
#'   receive contrib mass from this order; only the denominator changes.
#'
#' @return data.table with columns: index, Event, P, IC, Entropy
#' @export
ppm_interpolated <- function(
    x, N, alphabet, order_counts,
    escape_func = escape_C,
    exclusion = TRUE
) {
  T <- length(x)
  alpha_len <- length(alphabet)

  if (is_stm(order_counts)) {
    dt_orders <- order_counts
  } else {
    dt_orders <- ltm_to_timestep_counts(x, N, alphabet, order_counts)
  }

  # Base (order -1) distribution: uniform over alphabet, but denominator
  # shrinks by 1 per unique symbol already seen in x[1..t-1].  This matches
  # IDyOM's order-(-1) model. Renormalization at the end makes the exact
  # magnitude irrelevant; the shrinking denominator only matters when some
  # orders contribute zero (all-zero context) so the ratio between seen and
  # unseen symbols is set entirely by the base.
  base_prob <- numeric(T * alpha_len)
  seen_symbols <- character(0)
  for (t in seq_len(T)) {
    if (t > 1) seen_symbols <- unique(c(seen_symbols, x[t - 1]))
    denom_base <- length(alphabet) + 1 - length(seen_symbols)
    idx <- ((t - 1) * alpha_len + 1):(t * alpha_len)
    base_prob[idx] <- 1 / denom_base
  }

  # All vectors are length (T × |alphabet|): one entry per (timestep, symbol) pair.
  n_rows        <- T * alpha_len
  P             <- numeric(n_rows)      # accumulated probability
  remaining     <- rep(1.0, n_rows)    # R: ∏(esc_k) for k > current order
  is_excluded   <- rep(FALSE, n_rows)  # TRUE once Ce > 0 at any higher order

  # ── Main interpolation loop: order N down to 0 ──────────────────────────────
  #
  # Mirrors Harrison's ppm C++ `get_smoothed_distribution`. Each order n
  # contributes using `remaining` to carry the cumulative escape product:
  #
  #   P(s)      += remaining * alpha[s]
  #   remaining *= esc               (= 1 - lambda; shrinks toward 0)
  #
  # Following ppm's internal structure (function names in parens):
  #   Ce_adj[s]     = max(Ce[s] - subtract, 0)           (modify_count)
  #   context_count = Σ Ce_adj[s] per context             (get_context_count)
  #   esc_numer  = method-specific t-like term          (get_esc_numer)
  #   denom         = context_count + esc_numer
  #   lambda        = context_count / denom
  #   alpha[s]      = Ce_adj[s] / denom  (= lambda · Ce_adj / context_count)
  #   esc           = esc_numer / denom  (= 1 - lambda)
  #
  # (subtract, esc_numer) come from escape_func; per-method breakdown:
  #   A : (0,   1)     ctx=C,       denom=C+1
  #   B : (1,   t)     ctx=C-t,     denom=C
  #   C : (0,   t)     ctx=C,       denom=C+t
  #   D : (0.5, t/2)   ctx=C-0.5t,  denom=C      [ctx+eff = C-0.5t+t/2 = C]
  #   AX: (0,   t1+1)  ctx=C,       denom=C+t1+1
  #
  # ── Exclusion (Cleary & Witten 1984) ─────────────────────────────────────────
  # ppm's get_context_count sums Ce_adj over NON-EXCLUDED symbols only → ctx.
  # ppm's num_distinct_symbols (→ esc_numer) counts ALL symbols with
  # Ce > 0, INCLUDING excluded, because it is computed before the exclusion
  # filter; this is why escape_func receives the ORIGINAL dt_n$t / dt_n$t1.
  #
  # Excluded symbols still receive alpha mass when their Ce > subtract, matching
  # ppm's get_alphas behavior — only context_count (the denominator's ctx term)
  # reflects exclusion, not the per-symbol numerator Ce_adj.

  for (n in N:0) {
    dt_n         <- dt_orders[[n + 1]]
    stats        <- escape_func(dt_n$t, dt_n$t1)   # subtract and esc_numer for this order
    subtract     <- stats$subtract
    esc_numer <- stats$esc_numer

    Ce_adj <- pmax(dt_n$Ce - subtract, 0)           # modify_count(Ce)

    if (exclusion) {
      # context_count: sum Ce_adj over non-excluded symbols only (ppm get_context_count).
      # esc_numer uses original dt_n$t (includes excluded — see note above).
      Ce_excl <- ifelse(is_excluded, 0L, dt_n$Ce)
      ctx     <- ave(pmax(Ce_excl - subtract, 0), dt_n$index, FUN = sum)
      has_ctx <- ctx > 0
    } else {
      # context_count = Σ max(Ce-d,0) = C - d*t  (C and t already per-context in table)
      ctx     <- dt_n$C - subtract * dt_n$t
      has_ctx <- ctx > 0
    }

    denom    <- ctx + esc_numer
    esc_prob <- ifelse(has_ctx & denom > 0, esc_numer / denom, 1)
    contrib  <- ifelse(has_ctx & denom > 0, Ce_adj / denom, 0)   # alpha[s]

    P         <- P + remaining * contrib
    remaining <- remaining * esc_prob

    if (exclusion) {
      is_excluded[!is_excluded & dt_n$Ce > 0] <- TRUE
    }
  }
  # ────────────────────────────────────────────────────────────────────────────

  # Leftover remaining mass goes to the base distribution.
  P <- P + remaining * base_prob

  dt_final <- copy(dt_orders[[N + 1]])[, .(index, Event)]
  dt_final[, P := P]

  # Renormalize per timestep: handles floating-point drift and the IDyOM base
  # model (base does not integrate to 1 over the alphabet, so raw sum ≠ 1).
  dt_final[, P := {
    s <- sum(P)
    if (s > 0) P / s else rep(1 / alpha_len, .N)
  }, by = index]

  dt_final[, IC      := -log2(P)]
  dt_final[, Entropy := -sum(P * log2(P)), by = index]
  dt_final
}
