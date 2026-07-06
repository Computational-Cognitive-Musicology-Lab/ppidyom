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
#' Implements a vectorized PPM backoff.  Starting from the highest order,
#' each order assigns probability to symbols it has seen (Ce > 0); any
#' probability mass not allocated by that order survives to lower orders.
#' Symbols not seen at any order receive the remaining mass divided by the
#' uniform base distribution.
#'
#' ## How compute_local_probs and the backoff cascade relate
#'
#' `compute_local_probs` converts raw counts into per-symbol local weights:
#'
#'   prob_local(s) = max(Ce(s) - subtract, 0) / denom
#'                   where denom and subtract come from escape_func
#'
#' For escape_C: denom = C + t, subtract = 0, so prob_local(s) = Ce(s)/(C+t).
#' Summing over all seen symbols: Σ prob_local = C/(C+t) = 1 - esc.
#'
#' The backoff cascade (p_mass tracks unallocated probability):
#'
#'   p_mass starts at 1
#'   for n = N downto 0:
#'     for each seen symbol s (Ce_n > 0):
#'       P(s) = p_mass(s) · prob_local_n(s)   ← allocate a share
#'       p_mass(s) *= (1 - prob_local_n(s))   ← reduce remaining share
#'   after loop:
#'     unseen symbols: P(s) = p_mass(s) / |alphabet|
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
#'
#' @return data.table with columns: index, Event, P, IC, Entropy
#' @keywords internal
ppm_backoff <- function(x, N, alphabet, order_counts, escape_func=escape_C) {

  T <- length(x)
  alpha_len <- length(alphabet)

  if (is_stm(order_counts)) {
    dt_orders <- order_counts
  } else {
    dt_orders <- ltm_to_timestep_counts(x, N, alphabet, order_counts)
  }

  dt_final <- copy(dt_orders[[N + 1]])[, .(index, Event)]
  dt_final[, P := NA_real_]

  # Uniform base: used only for symbols unseen at all orders
  base_prob <- rep(1 / alpha_len, T * alpha_len)

  # p_mass: unallocated probability for each (timestep × symbol) row; starts at 1
  p_mass <- rep(1, nrow(dt_final))

  # Pre-compute prob_local for every order (avoids recomputing inside the loop)
  local_probs <- lapply(dt_orders, compute_local_probs, escape_func = escape_func)

  # Cascade: allocate probability from highest order downward
  for (n in N:0) {
    dt_n <- local_probs[[n + 1]]

    seen <- dt_orders[[n + 1]]$Ce > 0   # symbol observed in this context

    # P is overwritten each time a symbol is seen, so the final P(s) reflects
    # the contribution from the lowest order where Ce(s) > 0, weighted by the
    # p_mass remaining after higher orders have taken their share.
    dt_final[seen, P := p_mass[seen] * dt_n$prob_local[seen]]
    p_mass[seen]   <- p_mass[seen] * (1 - dt_n$prob_local[seen])
  }

  # Symbols with P still NA were never seen at any order; assign remaining mass
  remaining <- is.na(dt_final$P)
  dt_final[remaining, P := p_mass[remaining] * base_prob[remaining]]

  dt_final[, IC      := -log2(P)]
  dt_final[, Entropy := -sum(P * log2(P)), by = index]

  # TODO: track which order was chosen for each symbol (model_order column)
  dt_final
}

