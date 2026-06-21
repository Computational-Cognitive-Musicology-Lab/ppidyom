library(data.table)

#' Compute PPM Probabilities for all symbols with Interpolation
#'
#' Implements the interpolated variant of PPM (Prediction by Partial Matching).
#' Every order from N down to 0 contributes a weighted share of probability mass,
#' with any leftover mass falling through to a base (uniform) distribution.
#'
#' ## Math
#'
#' The standard recursive definition (one step from order n to n-1):
#'
#'   P_n(s) = λ_n · α_n(s)  +  (1-λ_n) · P_{n-1}(s)
#'
#' where  α_n(s) = Ce_n(s) / C_n  (local MLE at order n),
#'        λ_n    = discount_func(C_n, t_n, t1_n)$lambda,
#'     (1-λ_n)   = probability mass that "escapes" to lower orders.
#'
#' Expanding the recursion fully from N down to the base distribution:
#'
#'   P(s) =  λ_N · α_N(s)
#'         + (1-λ_N) · λ_{N-1} · α_{N-1}(s)
#'         + (1-λ_N)(1-λ_{N-1}) · λ_{N-2} · α_{N-2}(s)
#'         + ...
#'         + (1-λ_N)···(1-λ_0) · base(s)
#'
#' Letting R_n = ∏_{k > n} (1-λ_k)  ("remaining mass" = unallocated probability
#' after processing all orders above n), the loop computes this iteratively:
#'
#'   R starts at 1 (before the highest order)
#'   each iteration:  P        += R · λ_n · α_n(s)
#'                    R        *= (1-λ_n)
#'   after the loop:  P        += R · base(s)
#'
#' @param x Character vector of events
#' @param N Maximum order
#' @param alphabet Character vector of full alphabet
#' @param order_counts List of length N+1 containing count tables for orders
#'   0..N. Each element must be a `data.table` with columns:
#'   `index`, `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.
#'   - For **STM**, `index` corresponds to the timestep.
#'   - For **LTM**, `index` is constantly -1 since counts represent
#'     aggregated training statistics; `ltm_to_timestep_counts` maps
#'     them to per-timestep tables before the loop.
#' @param discount_func Discount function (e.g., `discount_C`).
#'   Returns a list with `$lambda` (weight for the current order).
#'   See escape.R for available functions and their formulas.
#' @param exclusion Logical. If TRUE, applies exclusion (Cleary & Witten 1984).
#'   When a symbol already has Ce > 0 at some higher order, it is excluded
#'   from C when computing λ at lower orders.  Effect: the denominator C_excl
#'   shrinks → (1-λ) increases → more mass escapes to lower orders, giving
#'   truly unseen symbols a larger share.  Excluded symbols still receive
#'   probability mass from lower orders via the (1-λ) spillover; only the
#'   denominator used to compute λ changes.
#'
#' @return data.table with columns: index, Event, P, IC, Entropy
#' @export
ppm_interpolated <- function(
    x, N, alphabet, order_counts,
    discount_func=discount_C,
    exclusion=TRUE
) {
  T <- length(x)
  alpha_len <- length(alphabet)

  if (is_stm(order_counts)) {
    dt_orders <- order_counts
  } else {
    dt_orders <- ltm_to_timestep_counts(x, N, alphabet, order_counts)
  }

  # Base probabilities: 1 / (∣alphabet∣+1−tseen)
  # Base (order -1) distribution: uniform over the alphabet, but the denominator
  # shrinks by 1 for each unique symbol already seen in x[1..t-1].  This
  # concentrates slightly more mass as the sequence progresses, matching IDyOM's
  # order-(-1) model.  (Gets renormalized at the end anyway.)
  base_prob <- numeric(T * alpha_len)
  seen_symbols <- character(0)
  for (t in seq_len(T)) {
    if (t > 1) seen_symbols <- unique(c(seen_symbols, x[t - 1]))
    denom <- length(alphabet) + 1 - length(seen_symbols)
    idx <- ((t - 1) * alpha_len + 1):(t * alpha_len)
    base_prob[idx] <- 1 / denom
  }

  # All vectors are length (T × |alphabet|): one entry per (timestep, symbol) pair.
  n_rows <- T * alpha_len
  P              <- numeric(n_rows)        # accumulated probability
  remaining_mass <- rep(1.0, n_rows)       # R_n: ∏(1-λ_k) for k > current order
  is_excluded    <- rep(FALSE, n_rows)     # TRUE once Ce > 0 at any higher order

  # ── Main interpolation loop: order N down to 0 ──────────────────────────────
  for (n in N:0) {
    dt_n <- dt_orders[[n + 1]]

    if (exclusion) {
      # Exclusion: recompute the context total using only symbols not yet seen
      # at a higher order.  This shrinks C_excl relative to C, which makes
      # (1-λ) larger → more mass escapes to lower orders for truly unseen symbols.
      # Note: Ce_over_C still uses the ORIGINAL Ce (not Ce_excl), so excluded
      # symbols can still receive mass from this order via the λ · (Ce/C_excl)
      # term; only the denominator used to derive λ changes.
      Ce_excl   <- ifelse(is_excluded, 0L, dt_n$Ce) # zero out excluded symbols
      C_excl    <- ave(Ce_excl, dt_n$index, FUN = sum) # per-timestep totals
      stats     <- discount_func(C_excl, dt_n$t, dt_n$t1)
      lambda    <- ifelse(C_excl > 0, stats$lambda, 0)
      Ce_over_C <- ifelse(C_excl > 0, dt_n$Ce / C_excl, 0)
    } else {
      stats     <- discount_func(dt_n$C, dt_n$t, dt_n$t1)
      lambda    <- ifelse(dt_n$C > 0, stats$lambda, 0)
      Ce_over_C <- ifelse(dt_n$C > 0, dt_n$Ce / dt_n$C, 0)
    }

    # TODO: make this work for escape functions other than C that use a subtract (k ≠ 0)

    # Add this order's contribution: remaining_mass is R_n = ∏_{k>n}(1-λ_k),
    # so the term below is exactly the n-th summand in the expanded formula.
    P <- P + remaining_mass * (lambda * Ce_over_C)

    # Update remaining mass: R_{n-1} = R_n · (1-λ_n)
    remaining_mass <- remaining_mass * (1 - lambda)

    # Mark every symbol with Ce > 0 at this order as "seen" for lower orders.
    if (exclusion) {
      is_excluded[!is_excluded & (dt_n$Ce > 0)] <- TRUE
    }
  }
  # ────────────────────────────────────────────────────────────────────────────

  # Remaining mass (= ∏_{all n}(1-λ_n)) goes to the base distribution.
  P <- P + remaining_mass * base_prob

  dt_final <- copy(dt_orders[[N + 1]])[, .(index, Event)]
  dt_final[, P := P]

  # Renormalize per timestep (floating-point drift; also handles the exclusion
  # case where Ce_excl / C_excl numerators don't sum exactly to λ).
  dt_final[, P := {
    s <- sum(P)
    if (s > 0) P / s else rep(1 / alpha_len, .N)
  }, by = index]

  dt_final[, IC := -log2(P)]
  dt_final[, Entropy := -sum(P * log2(P)), by = index]
  dt_final
}



