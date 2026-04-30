library(data.table)
#' @import data.table

#' Generate Lagged N-gram Matrix
#'
#' Creates a lagged representation of a sequence for N-gram modeling.
#' @param x Character vector of symbols/events.
#' @param N Maximum N-gram order.
#' @return A `data.table` with columns LagN..Lag0 and index.
#' @export
lag_matrix <- function(x, N = 3) {
  dt <- data.table::as.data.table(lapply(N:0, function(n) data.table::shift(x, n)))
  data.table::setnames(dt, paste0("Lag", N:0))
  dt[, index := seq_len(.N)]
  dt
}

#' Precompute context identifiers for all orders
#'
#' @param dt_lag Lag matrix from lag_matrix()
#' @param N Maximum n-gram order
#' @return List of length N+1, each element is a character vector of context IDs
precompute_contexts <- function(dt_lag, N) {

  context_list <- vector("list", N + 1)

  for (n in 0:N) {
    if (n == 0) {
      context_list[[n+1]] <- rep("ROOT", nrow(dt_lag))
    } else {
      cols <- paste0("Lag", n:1)
      context_list[[n+1]] <- do.call(paste, c(dt_lag[, ..cols], sep = "_"))
    }
  }

  context_list
}

#' Initialize LTM with prior counts
#'
#' @param counts_ltm LTM env list
#' @param prior prior LTM tables
#' @param N maximum order
#' @return modified counts_ltm
apply_prior_ltm <- function(counts_ltm, prior, N) {

  if (length(prior) == 0) return(counts_ltm)

  for (n in 0:N) {

    prior_dt <- prior[[n+1]]
    if (is.null(prior_dt) || nrow(prior_dt) == 0) next

    env <- counts_ltm[[n+1]]

    for (ctx in unique(prior_dt$context_id)) {
      rows <- prior_dt[context_id == ctx]
      env[[ctx]] <- setNames(as.integer(rows$Ce), rows$Event)
    }
  }

  counts_ltm
}

#' Update a Sparse Context Count Environment
#'
#' Increment or decrement the count of a symbol within a given context
#' stored in an environment-based sparse representation.
#'
#' This function is used as the core update primitive for PPM-style models,
#' where each context (`ctx`) stores a named integer vector of symbol counts.
#'
#' The update is *sparse*: only symbols with non-zero counts are stored.
#'
#' @param env An environment mapping context IDs (`ctx`) to named integer vectors.
#'        Each vector represents symbol counts for that context.
#' @param ctx Character. Context identifier key (n-grams).
#' @param sym Character. Symbol/event that follows the context.
#' @param sign Integer. Update direction:
#'        - `+1` increments the count (default behavior during training)
#'        - `-1` decrements the count (used during detrain or reversal)
#'
#' @return Invisibly returns `NULL`. The environment is modified in place.
#'
#' @examples
#' env <- new.env()
#'
#' # add observations
#' update_env(env, "A_B", "C", +1)
#' update_env(env, "A_B", "C", +1)
#'
#' # decrement
#' update_env(env, "A_B", "C", -1)
#'
#' env[["A_B"]]
#'
#' @export
update_env <- function(env, ctx, sym, sign = +1) {
  v <- env[[ctx]]

  if (is.null(v)) {
    if (sign > 0) env[[ctx]] <- setNames(1L, sym)
    return(invisible(NULL))
  }

  if (sym %in% names(v)) {
    v[sym] <- v[sym] + sign
  } else if (sign > 0) {
    v[sym] <- 1L
  }

  env[[ctx]] <- v
}

update_env_and_build_stm_tables <- function(
  x, N, alphabet, context_list,
  use_stm, use_ltm, stm_update_exclusion, ltm_update_exclusion,
  counts_stm, counts_ltm
) {
  T <- length(x)
  stm_tables <- if(use_stm) lapply(0:N, function(.) vector("list", T)) else NULL

  for (t in seq_len(T)) {
    # Build STM tables from lower order after optional update exclusion
    if (use_stm) {
      for (n in 0:N) {
        ctx <- context_list[[n+1]][t]
        ctx_counts <- counts_stm[[n+1]][[ctx]]

        # Ce for all symbols in the alphabet (fill missing with 0)
        Ce_full <- setNames(integer(length(alphabet)), alphabet)
        if (!is.null(ctx_counts)) Ce_full[names(ctx_counts)] <- ctx_counts
        stm_tables[[n+1]][[t]] <- data.table(
          index = t,
          context_id = ctx,
          Event = alphabet,
          Ce = as.integer(Ce_full),
          C = sum(Ce_full),
          t = sum(Ce_full > 0L),
          t1 = sum(Ce_full == 1L)
        )
      }
    }

    sym <- x[t]
    seen_stm <- FALSE
    seen_ltm <- FALSE

    # Update env with optional exclusion
    for (n in N:0) {
      ctx <- context_list[[n+1]][t]

      # ---------- STM ----------
      if (use_stm) {
        if (!stm_update_exclusion || !seen_stm) {
          env <- counts_stm[[n+1]]
          v <- env[[ctx]]
          exists <- !is.null(v) && sym %in% names(v)
          update_env(env, ctx, sym, +1)
          if (exists) seen_stm <- TRUE
        }
      }
      # ---------- LTM ----------
      if (use_ltm) {
        if (!ltm_update_exclusion || !seen_ltm) {
          env <- counts_ltm[[n+1]]
          v <- env[[ctx]]
          exists <- !is.null(v) && sym %in% names(v)
          update_env(env, ctx, sym, +1)
          if (exists) seen_ltm <- TRUE
        }
      }
    }
  }

  stm_tables_out <- NULL
  if (use_stm) stm_tables_out <- lapply(stm_tables, rbindlist)
  list(
    counts_stm = counts_stm,
    counts_ltm = counts_ltm,
    stm_tables_out = stm_tables_out
  )
}

#' Compute Count Tables for STM and LTM with Optional Prior
#'
#' Generates count tables for STM (per-timestep) and/or LTM (per-context),
#' optionally incorporating previously accumulated LTM counts.
#'
#' @param x Character vector of symbols/events.
#' @param N Maximum N-gram order.
#' @param alphabet Character vector of all possible symbols.
#' @param model_type Character: one of `"stm"`, `"ltm"`, `"both"`.
#' @param prior Optional: previously accumulated LTM tables (list of length N+1).
#'   Used to initialize/accumulate counts for LTM or `both` type.
#' @param stm_update_exclusion Logical; apply update exclusion in STM (default TRUE).
#'   Prevents lower-order updates when an event is already observed in a higher-order
#'   context at the same timestep.
#' @param ltm_update_exclusion Logical; apply update exclusion in LTM (default FALSE).
#'   If TRUE, applies the same exclusion logic during corpus accumulation; if FALSE,
#'   all orders are updated for every event.
#' @return A list with elements depending on `model_type`:
#'   - `$stm`: list of length N+1, each a data.table of counts per timestep (if `model_type` includes `"stm"`).
#'   - `$ltm`: list of length N+1, each a data.table of counts per context (if `model_type` includes `"ltm"`).
#' @export
count_tables <- function(
  x, N, alphabet,
  model_type = c("stm","ltm","both"),
  prior = list(),
  # TODO: change STM defaults to TRUE after adding update exclusion
  stm_update_exclusion = FALSE, ltm_update_exclusion=FALSE
) {
  model_type <- match.arg(model_type)
  T <- length(x)
  dt_lag <- lag_matrix(x, N)
  context_list <- precompute_contexts(dt_lag, N)

  # Initialize count stores
  use_stm <- (model_type %in% c("stm","both"))
  use_ltm <- (model_type %in% c("ltm","both"))

  counts_stm <- if (use_stm)
    lapply(0:N, function(.) new.env(hash=TRUE, parent=emptyenv())) else NULL
  counts_ltm <- if (use_ltm)
    lapply(0:N, function(.) new.env(hash=TRUE, parent=emptyenv())) else NULL
  # Add prior counts to counts_ltm, if provided
  if (use_ltm && length(prior) > 0) {
    counts_ltm <- apply_prior_ltm(counts_ltm, prior, N)
  }
  ltm_tables <- if(use_ltm) vector("list", N+1) else NULL

  updated <- update_env_and_build_stm_tables(
    x = x,
    N = N,
    alphabet = alphabet,
    context_list = context_list,
    use_stm = use_stm,
    use_ltm = use_ltm,
    stm_update_exclusion = stm_update_exclusion,
    ltm_update_exclusion = ltm_update_exclusion,
    counts_stm = counts_stm,
    counts_ltm = counts_ltm
  )
  counts_stm <- updated$counts_stm
  counts_ltm <- updated$counts_ltm
  stm_tables_out <- updated$stm_tables_out

  # Build LTM tables
  if (use_ltm) {
    for (n in 0:N) {
      env <- counts_ltm[[n+1]]
      ltm_idx <- 1
      ctx_ids_prior <- if(length(prior) > 0 && !is.null(prior[[n+1]])) unique(prior[[n+1]]$context_id) else character(0)
      combined_ctx_ids <- unique(c(names(env), ctx_ids_prior))
      ltm_list <- vector("list", length(combined_ctx_ids))

      for(ctx in combined_ctx_ids) {
        if(is.null(env[[ctx]])) {
          env[[ctx]] <- setNames(integer(length(alphabet)), alphabet)
        }
        Ce_full <- setNames(integer(length(alphabet)), alphabet)
        if(length(env[[ctx]]) > 0) Ce_full[names(env[[ctx]])] <- env[[ctx]]
        ltm_list[[ltm_idx]] <- data.table(
          index = -1L,
          context_id = ctx,
          Event = alphabet,
          Ce = as.integer(Ce_full),
          C = sum(Ce_full),
          t = sum(Ce_full > 0L),
          t1 = sum(Ce_full == 1L)
        )
        ltm_idx <- ltm_idx + 1
      }
      ltm_tables[[n+1]] <- rbindlist(ltm_list)
    }
  }

  list(stm = stm_tables_out, ltm = ltm_tables)
}


#' Expand LTM Count Tables to Timestep-Aligned Order Tables
#'
#' Converts aggregated Long-Term Memory (LTM) count tables into
#' timestep-aligned tables compatible with PPM probability computation.
#'
#' LTM count tables contain counts aggregated over a training corpus
#' (typically with `index = -1`). For prediction on a new sequence `x`,
#' we must derive the counts associated with each timestep's context.
#'
#' The result matches the structure expected by PPM implementations
#' (`ppm_backoff`, `ppm_interpolated`, etc.).
#'
#' @param x Character vector of events.
#' @param N Maximum context order.
#' @param alphabet Character vector of the full symbol alphabet.
#' @param order_counts List of LTM count tables for orders `0..N`.
#'   Each element must be a `data.table` containing:
#'   `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.
#'
#' @return A list of length `N + 1`.
#' Each element is a `data.table` with columns:
#' `index`, `context_id`, `Event`, `Ce`, `C`, `t`, `t1`.
#'
#' The tables contain one row per `(timestep, event)` pair and can be
#' directly passed to probability computation routines.
#'
#' @export
ltm_to_timestep_counts <- function(x, N, alphabet, order_counts) {

  dt_orders <- vector("list", N + 1)

  lag_dt <- lag_matrix(x, N)

  for (n in 0:N) {

    context_cols <- if (n == 0) character(0) else paste0("Lag", n:1)

    # Compute context identifiers
    if (n == 0) {
      lag_dt[, context_id := "ROOT"]
    } else {
      lag_dt[, context_id := do.call(paste, c(.SD, sep = "_")), .SDcols = context_cols]
    }

    # Expand contexts to include all alphabet symbols
    context_dt <- lag_dt[
      , .(Event = alphabet),
      by = .(index, context_id)
    ]

    ltm_dt <- order_counts[[n + 1]]

    # Join LTM counts
    # TODO: possible to optimize here?
    dt_n <- merge(
      context_dt,
      ltm_dt[, .(context_id, Event, Ce, C, t, t1)],
      by = c("context_id", "Event"),
      all.x = TRUE
    )

    # Fill unseen contexts with zero counts
    dt_n[is.na(C), `:=`(
      Ce = 0L,
      C = 0L,
      t = 0L,
      t1 = 0L
    )]

    dt_orders[[n + 1]] <- dt_n[, .(index, context_id, Event, Ce, C, t, t1)]
  }

  dt_orders
}

is_stm <- function(order_counts) {
  # Take the first order table as reference
  dt <- order_counts[[1]]
  # STM if any index > 0
  any(dt$index > 0)
}

