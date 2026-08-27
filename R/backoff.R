library(data.table)


#' Compute Local Probabilities for a Single Order; Used by Backoff PPM
#'
#' @param dt Data.table for a single order. Columns: index, context_id, Event, Ce, C, t, t1.
#' @param escape_func Escape function from escape.R.
#'   Signature: `function(t, t1)` returning `list(subtract, esc_numer)`.
#'
#' @return Data.table with columns: index, Event, prob_local, esc
#' @keywords internal
compute_local_probs <- function(dt, escape_func, normalize = FALSE) {

  escape_stats <- escape_func(dt$t, dt$t1)
  subtract     <- escape_stats$subtract
  esc_numer <- escape_stats$esc_numer

  Ce_adj <- pmax(dt$Ce - subtract, 0)                 # modify_count(Ce)
  ctx    <- dt$C - subtract * dt$t                    # context_count = Σ max(Ce-d,0)
  denom  <- ctx + esc_numer

  has_ctx    <- ctx > 0
  prob_local <- ifelse(has_ctx & denom > 0, Ce_adj / denom, 0)
  esc        <- ifelse(has_ctx & denom > 0, esc_numer / denom, NA_real_)

  data.table(
    index      = dt$index,
    Event      = dt$Event,
    prob_local = prob_local,
    esc        = esc
  )
}


#' Compute PPM Probabilities for all symbols with Backoff
#'
#' Implements the PPM non-mixture (backoff) model that matches IDyOM's
#' `:mixtures nil` behaviour.  Each symbol is finalized at the deepest order
#' whose context has observed it (highest order wins); symbols not seen at any
#' order receive the accumulated escape mass scaled by the base prior.  The
#' final per-timestep distribution is renormalized to sum to 1.
#'
#' ## Cascade algorithm
#'
#' esc_mass[t] tracks remaining probability mass for timestep t (starts at 1).
#' At each order, only symbols not yet finalized AND not excluded are eligible.
#'
#'   for n = N downto 0:
#'     for each eligible symbol s (Ce_n(s) > 0, unfixed, not excluded):
#'       P(s) = esc_mass[t] * prob_local_n(s)    <- finalize at highest order
#'     esc_mass[t] *= esc_n[t]                   <- remaining mass flows down
#'     if exclusion: mark all Ce>0 symbols as excluded
#'   for each symbol s still unset:
#'     P(s) = esc_mass[t] * base(s)              <- base prior
#'   normalize P[t] so that sum = 1
#'
#' ## Exclusion (Cleary & Witten 1984)
#'
#' Same as `ppm_interpolated`: once a symbol has Ce > 0 at any order it is
#' marked excluded and removed from the context count (ctx) at lower orders.
#' The escape numerator (esc_numer) uses the ORIGINAL t (including excluded),
#' matching Harrison's ppm and IDyOM behaviour (see `ppm_interpolated` docs).
#'
#' ## Base distribution
#'
#' Mirrors `ppm_interpolated`:
#'   idyom_base + !exclusion  ->  1 / |alphabet|
#'   idyom_base +  exclusion  ->  1 / (|alphabet| + 1 - t_root)
#'   !idyom_base              ->  1 / (|alphabet| + 1 - |seen_at_t|)
#'
#' @param x Character vector of events
#' @param N Maximum order
#' @param alphabet Character vector of full alphabet
#' @param order_counts List of length N+1 containing count tables for orders
#'   0..N. Each element must be a `data.table` with columns:
#'   `index`, `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.
#'   - For **STM**, `index` corresponds to the timestep.
#'   - For **LTM**, `index` is constantly -1; `ltm_to_timestep_counts` maps
#'     them to per-timestep tables first.
#' @param escape_func Escape function (e.g., `escape_C`).
#'   Signature: `function(t, t1)` returning `list(subtract, esc_numer)`; see escape.R.
#' @param exclusion Logical. If TRUE, symbols seen at higher orders are excluded
#'   from the context count at lower orders (Cleary & Witten 1984).
#' @param idyom_base Logical. Selects the order-(-1) base distribution.
#'   TRUE = IDyOM-compatible (1/|alphabet| or shrinking with exclusion);
#'   FALSE = Harrison's ppm-compatible shrinking denominator.
#'
#' @return data.table with columns: index, Event, P, IC, Entropy
#' @keywords internal
ppm_backoff <- function(x, N, alphabet, order_counts, escape_func = escape_C,
                         exclusion = FALSE, idyom_base = FALSE) {

  T <- length(x)
  alpha_len <- length(alphabet)

  if (is_stm(order_counts)) {
    dt_orders <- order_counts
  } else {
    dt_orders <- ltm_to_timestep_counts(x, N, alphabet, order_counts)
  }

  # Base (order -1) distribution — same logic as ppm_interpolated.
  t_root_by_t <- dt_orders[[1]][, .(t_root = t[1]), by = index]$t_root
  base_prob   <- numeric(T * alpha_len)
  seen_syms   <- character(0)
  for (ti in seq_len(T)) {
    if (ti > 1) seen_syms <- unique(c(seen_syms, x[ti - 1]))
    p_base <- if (idyom_base && !exclusion)
      1.0 / alpha_len
    else if (idyom_base && exclusion)
      1.0 / (alpha_len + 1L - t_root_by_t[ti])
    else
      1.0 / (alpha_len + 1L - length(seen_syms))
    idx <- ((ti - 1L) * alpha_len + 1L):(ti * alpha_len)
    base_prob[idx] <- p_base
  }

  n_rows <- T * alpha_len
  dt_final <- copy(dt_orders[[N + 1]])[, .(index, Event)]
  dt_final[, P := NA_real_]

  # esc_mass[t]: accumulated escape mass per timestep (product of esc_n for all
  # orders where the context had data).  Starts at 1.
  esc_mass    <- rep(1.0, T)
  is_excluded <- rep(FALSE, n_rows)   # TRUE once Ce > 0 at any higher order

  for (n in N:0) {
    dt_n      <- dt_orders[[n + 1]]
    stats     <- escape_func(dt_n$t, dt_n$t1)
    subtract  <- stats$subtract
    esc_numer <- stats$esc_numer          # original t-based; NOT modified by exclusion

    Ce_adj <- pmax(dt_n$Ce - subtract, 0)

    if (exclusion) {
      # ctx: sum Ce_adj for non-excluded symbols only (ppm get_context_count).
      # esc_numer uses ORIGINAL t (including excluded) — see ppm_interpolated docs.
      Ce_excl <- ifelse(is_excluded, 0L, dt_n$Ce)
      ctx     <- ave(pmax(Ce_excl - subtract, 0), dt_n$index, FUN = sum)
    } else {
      ctx     <- dt_n$C - subtract * dt_n$t
    }

    has_ctx    <- ctx > 0
    denom      <- ctx + esc_numer
    prob_local <- ifelse(has_ctx & denom > 0, Ce_adj / denom, 0)
    esc_vec    <- ifelse(has_ctx & denom > 0, esc_numer / denom, NA_real_)

    # Eligible: seen, not yet finalized, not already excluded. The exclusion
    # lockout applies regardless of the `exclusion` param (matches IDyOM);
    # `exclusion` only gates the context-count exclusion above.
    seen     <- dt_n$Ce > 0
    unfixed  <- is.na(dt_final$P)
    has_prob <- prob_local > 0
    eligible <- seen & has_prob & unfixed & !is_excluded

    if (any(eligible)) {
      t_idx <- dt_n$index[eligible]
      dt_final[eligible, P := esc_mass[t_idx] * prob_local[eligible]]
    }

    # Update esc_mass for each timestep that had context data at this order.
    non_na <- which(!is.na(esc_vec))
    if (length(non_na) > 0L) {
      esc_dt   <- data.table(index = dt_n$index[non_na], esc_val = esc_vec[non_na])
      esc_by_t <- esc_dt[, .(esc_val = esc_val[1L]), by = index]
      esc_mass[esc_by_t$index] <- esc_mass[esc_by_t$index] * esc_by_t$esc_val
    }

    # Expand exclusion set: symbols seen at this order become excluded in
    # lower orders, regardless of `exclusion` (see note above).
    is_excluded[!is_excluded & seen] <- TRUE
  }

  # Symbols never finalized: base prior scaled by accumulated esc_mass.
  remaining <- is.na(dt_final$P)
  if (any(remaining)) {
    t_idx <- dt_final$index[remaining]
    dt_final[remaining, P := esc_mass[t_idx] * base_prob[remaining]]
  }

  # Renormalize per timestep (required: without exclusion the raw cascade sums
  # to < 1; with exclusion rounding/base-prior interactions still require it).
  dt_final[, P := P / sum(P), by = index]

  dt_final[, IC      := -log2(P)]
  dt_final[, Entropy := -sum(P * log2(P)), by = index]

  dt_final
}
