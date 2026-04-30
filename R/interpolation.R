library(data.table)

#' Compute PPM Probabilities for all symbols with Interpolation
#'
#' Vectorized interpolated PPM.
#' Each order contributes to the final probability weighted by its discounted probability mass.
#'
#' @param x Character vector of events
#' @param N Maximum order
#' @param alphabet Character vector of full alphabet
#' @param order_counts List of length N+1 containing count tables for orders
#'   0..N. Each element must be a `data.table` with columns:
#'   `index`, `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.
#'
#'   - For **STM**, `index` corresponds to the timestep.
#'   - For **LTM**, `index` is constantly -1 since counts
#'     represent aggregated training statistics.
#' @param discount_func Discount function (e.g., `discount_C`).
#' @param exclusion Logical. If TRUE, symbols seen at a higher-order context
#'  are excluded from lower-order probability contributions.
#' @return data.table with columns: index, Event, P, IC
#' @export
ppm_interpolated <- function(
    x, N, alphabet, order_counts,
    discount_func=discount_C,
    exclusion=FALSE
) {
  T <- length(x)
  alpha_len <- length(alphabet)

  if (is_stm(order_counts)) {
    dt_orders <- order_counts
  } else {
    dt_orders <- ltm_to_timestep_counts(x, N, alphabet, order_counts)
  }

  # Base probabilities: 1 / (∣alphabet∣+1−tseen)
  base_prob <- numeric(T * alpha_len)
  seen_symbols <- character(0)
  for (t in seq_len(T)) {
    if (t > 1) seen_symbols <- unique(c(seen_symbols, x[t - 1]))
    denom <- length(alphabet) + 1 - length(seen_symbols)
    idx <- ((t - 1) * alpha_len + 1):(t * alpha_len)
    base_prob[idx] <- 1 / denom
  }

  n_rows <- T * alpha_len
  P <- numeric(n_rows)
  remaining_mass <- rep(1.0, n_rows)
  # TRUE = this symbol has been handled at a higher order and is excluded
  is_excluded <- rep(FALSE, n_rows)

  for (n in N:0) {
    dt_n <- dt_orders[[n + 1]]

    if (exclusion) {
      # Recompute C excluding already-excluded symbols
      Ce_excl  <- ifelse(is_excluded, 0L, dt_n$Ce)
      C_excl   <- ave(Ce_excl,      dt_n$index, FUN = sum)

      stats     <- discount_func(C_excl, dt_n$t, dt_n$t1)
      lambda    <- ifelse(C_excl > 0, stats$lambda, 0)
      Ce_over_C <- ifelse(C_excl > 0, dt_n$Ce / C_excl, 0)
    } else {
      stats     <- discount_func(dt_n$C, dt_n$t, dt_n$t1)
      lambda    <- ifelse(dt_n$C > 0, stats$lambda, 0)
      Ce_over_C <- ifelse(dt_n$C > 0, dt_n$Ce / dt_n$C, 0)
    }

    # Interpolation formula:
    # Interpolated P = lambda * (Ce / C if C > 0 else 0) + (1 - lambda) * P_lower
    # TODO: check what k does in ppm
    Ce_over_C <- ifelse(dt_n$C > 0, dt_n$Ce / dt_n$C, 0)

    active <- !is_excluded                   # symbols still in play
    seen_here <- active & (dt_n$Ce > 0)        # seen at this order, not yet excluded

    # Probability contribution for seen symbols at this order
    P[seen_here] <- P[seen_here] +
      remaining_mass[seen_here] * lambda[seen_here] * Ce_over_C[seen_here]

    # All active symbols lose their lambda-share of remaining mass
    remaining_mass[active] <- remaining_mass[active] * (1 - lambda[active])

    # Exclusion only: freeze seen symbols out of lower orders
    if (exclusion) {
      is_excluded[seen_here] <- TRUE
      remaining_mass[seen_here] <- 0
    }
  }

  # Leftover mass → base distribution
  # With exclusion: only unseen-at-any-order symbols receive base mass
  # Without exclusion: all symbols receive their remaining base mass
  active_final <- !is_excluded
  P[active_final] <- P[active_final] +
    remaining_mass[active_final] * base_prob[active_final]

  dt_final <- copy(dt_orders[[N + 1]])[, .(index, Event)]
  dt_final[, P := P]

  # normalization
  dt_final[, P := {
    s <- sum(P)
    if (s > 0) P / s else rep(1 / alpha_len, .N)
  }, by = index]

  dt_final[, IC := -log2(P)]
  dt_final[, Entropy := -sum(P * log2(P)), by = index]
  dt_final
}


print("PPIDYOM Result:")
x <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
alphabet <- c("A", "B", "C")
max_order <- 3
counts <- count_tables(
  x = x,
  N = max_order,
  alphabet = alphabet,
  model_type="both",
  stm_update_exclusion = TRUE,
  ltm_update_exclusion = FALSE
)
print(counts$stm)

result <- ppm_interpolated(
  x = x,
  N = max_order,
  alphabet = alphabet,
  order_counts = counts$stm,
  discount_func = discount_C,
  exclusion = TRUE
)
print(result)

res_ppidyom <- result[
  data.table(index = seq_len(length(x)), Event = x),
  on = .(index, Event)
][
  , .(index, Event, P, IC, Entropy)
]

print(res_ppidyom)


library(ppm)
print("PPM Result:")
# same as:
# (idyom:idyom 66041326023457 '(cpitch) '(cpitch) :texture :melody :models :stm :k :full :detail 3 :stmo '(:escape :c :order-bound 3 :exclusion nil) :output-path "experiment_history/13-04-26_02.20.05/experiment_output_data_folder/" :overwrite nil)

seq <- factor(x, levels = alphabet)
mod <- new_ppm_simple(
  order_bound = max_order,
  alphabet_levels = alphabet,
  escape = "c",
  shortest_deterministic = FALSE,
  exclusion = TRUE,
  update_exclusion = TRUE
)
res <- model_seq(mod, seq)
print(res)

