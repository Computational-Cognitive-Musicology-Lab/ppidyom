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
#' @param exclusion Logical. If TRUE, applies exclusion as per Cleary & Witten (1984).
#'
#'   When a symbol has been observed in a higher-order context, it is excluded
#'   from the context count used to compute the escape probability at lower orders.
#'   This does NOT prevent excluded symbols from receiving probability mass at
#'   lower orders — they still receive the (1-lambda) spillover from above.
#'   Rather, exclusion prevents already-predicted symbols from inflating the
#'   lower-order context count, which would otherwise suppress the escape
#'   probability and starve unseen symbols of probability mass.
#'
#' @return data.table with columns: index, Event, P, IC
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

    # TODO: make this work for escape functions other than C that includes the concept of K

    # Probability contribution for seen symbols at this order
    # PPM: alphas[i] + (1 - lambda) * lower_order_distribution[i];
    # PPIDYOM: higher_order_P + product of all (1-lambda) from orders above * this_P
    # P_2 = alpha_2 + (1-λ_2) * [alpha_1 + (1-λ_1) * [alpha_0 + (1-λ_0) * base]]
    # P = alpha_2 + (1-λ_2) * alpha_1 + (1-λ_2)(1-λ_1) * alpha_0 + (1-λ_2)(1-λ_1)(1-λ_0) * base
    # remaining mass = product of all (1-lambda) from orders above
    P <- P + remaining_mass * (lambda * Ce_over_C)

    # Product of all (1-lambda) from orders
    remaining_mass <- remaining_mass * (1 - lambda)

    # Exclusion only: exclude seen symbols from context count in lower orders probability distribution
    if (exclusion) {
      is_excluded[!is_excluded & (dt_n$Ce > 0)] <- TRUE
    }
  }

  # Leftover mass → base distribution: all symbols receive their remaining base mass
  P <- P + remaining_mass * base_prob

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
#x <- c("A", "B", "B", "B")
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
  update_exclusion = TRUE,
  debug_smooth=TRUE
)
res <- model_seq(mod, seq)
print(res)
print(res$distribution)

