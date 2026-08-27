library(data.table)


ppidyomModel <- setRefClass(
  "ppidyomModel",

  fields = list(
    N = "numeric",
    alphabet = "character",
    counts_ltm = "list",
    stm_exclusion = "logical",
    ltm_exclusion = "logical",
    stm_update_exclusion = "logical",
    ltm_update_exclusion = "logical",
    ltm_start_token = "logical"
  ),

  methods = list(

    #' Initialize a new PPM counter
    #' @name ppidyomModel
    #' @rdname ppidyomModel
    #' @param N Maximum n-gram order (order bound).
    #' @param alphabet Character vector of all possible symbols/events.
    #' @param stm_exclusion Logical; when computing STM escape probabilities,
    #'   exclude symbols already assigned a probability at a higher order
    #'   (default TRUE).
    #' @param ltm_exclusion Logical; same as `stm_exclusion`, for LTM (default TRUE).
    #' @param stm_update_exclusion Logical; stop updating lower-order STM counts
    #'   once a higher order already matched at this timestep (default TRUE).
    #' @param ltm_update_exclusion Logical; same as `stm_update_exclusion`, but
    #'   applied while accumulating LTM counts (default FALSE).
    #' @param ltm_start_token Logical; count beginning-of-sequence positions
    #'   when accumulating LTM (default TRUE; set FALSE to match IDyOM).
    #'
    initialize = function(
      N, alphabet,
      stm_exclusion = TRUE, ltm_exclusion = TRUE,
      stm_update_exclusion = TRUE, ltm_update_exclusion = FALSE,
      ltm_start_token = TRUE
    ) {
      .self$N <- N
      .self$alphabet <- alphabet
      .self$counts_ltm <- list()
      .self$stm_exclusion <- stm_exclusion
      .self$ltm_exclusion <- ltm_exclusion
      .self$stm_update_exclusion <- stm_update_exclusion
      .self$ltm_update_exclusion <- ltm_update_exclusion
      .self$ltm_start_token <- ltm_start_token
    },

    # Train on a single sequence (incremental LTM update)
    #' @param x Character vector sequence to train
    train_sequence = function(x) {
      count_tables <- count_tables(
        x = x,
        N = .self$N,
        alphabet = .self$alphabet,
        model_type="ltm",
        prior = .self$counts_ltm,
        stm_update_exclusion = .self$stm_update_exclusion,
        ltm_update_exclusion = .self$ltm_update_exclusion,
        ltm_start_token = .self$ltm_start_token
      )
      # Update LTM
      .self$counts_ltm <- count_tables$ltm
      invisible(NULL)
    },


    # Remove a single sequence from the trained LTM counts
    #
    # Exactly reverses one call to train_sequence(x), event by event.
    #
    # ## Why the loop order matters for ltm_update_exclusion
    #
    # train_sequence increments counts with this per-timestep logic:
    #
    #   seen = FALSE
    #   for n = N downto 0:
    #     if !ltm_update_exclusion OR !seen:
    #       exists = (ctx_n, sym) already in LTM   [Ce > 0 BEFORE update]
    #       Ce_n += 1
    #       if exists: seen = TRUE   ← stop updating lower orders
    #
    # detrain_sequence must undo exactly those increments.  The key is
    # reconstructing which orders were actually updated:
    #
    #   • We know Ce_current (the value NOW, after training).
    #   • The Ce before training was Ce_current - 1.
    #   • "exists before training" = Ce_before > 0 = Ce_current - 1 > 0
    #     = old_ce > 1.
    #
    # So we mirror the training loop, decrementing Ce at each order and
    # stopping (setting seen_ltm=TRUE) whenever old_ce > 1, because that
    # is exactly when training would have stopped updating lower orders.
    #' @param x Character vector sequence to de-train
    detrain_sequence = function(x) {
      N_ord <- .self$N
      T_len <- length(x)
      dt_lag <- lag_matrix(x, N_ord)
      context_list <- precompute_contexts(dt_lag, N_ord)

      # Keyed copies for fast O(1) (context_id, Event) lookup
      counts_local <- lapply(.self$counts_ltm, function(dt) {
        dt_copy <- data.table::copy(dt)
        setkeyv(dt_copy, c("context_id", "Event"))
        dt_copy
      })

      for (ti in seq_len(T_len)) {
        sym      <- x[ti]
        seen_ltm <- FALSE   # mirrors the seen_ltm flag in train_sequence

        for (n in N_ord:0) {
          if (.self$ltm_update_exclusion && seen_ltm) break

          ctx  <- context_list[[n + 1]][ti]
          dt_n <- counts_local[[n + 1]]

          idx <- dt_n[.(ctx, sym), which = TRUE]
          if (length(idx) == 0) next

          old_ce <- dt_n$Ce[idx]
					if (is.na(old_ce)) old_ce <- 0 
          if (old_ce <= 0L) next      # nothing to undo

          # Decrement Ce and the context-level aggregates
          dt_n[idx, Ce := Ce - 1L]
          dt_n[context_id == ctx, C := C - 1L]

          if (old_ce == 1L) {
            # sym disappears entirely from this context
            dt_n[context_id == ctx, `:=`(t = t - 1L, t1 = t1 - 1L)]
          } else if (old_ce == 2L) {
            # sym goes from observed-twice to singleton
            dt_n[context_id == ctx, t1 := t1 + 1L]
          }

          # old_ce > 1  ↔  Ce before training was > 0  ↔  exists=TRUE during
          # training  ↔  training set seen_ltm=TRUE at this order, stopping lower
          if (.self$ltm_update_exclusion && old_ce > 1L) seen_ltm <- TRUE
        }
      }

      .self$counts_ltm <- counts_local
    },

    # Predict IC and entropy for a sequence
    #' @param x Character vector sequence
    #' @param model_type Which memory component(s) to use:
    #'   - `"stm"` — short-term memory, `x` only.
    #'   - `"ltm"` — long-term memory, from prior `train_sequence()` calls.
    #'   - `"both"` — STM + LTM blended.
    #'   - `"ltm+"`/`"both+"` — as `"ltm"`/`"both"`, but LTM is updated online
    #'     after each event of `x`.
    #' @param ppm_type PPM estimation method:
    #'   - `"interpolation"` — weighted sum across all n-gram orders.
    #'   - `"backoff"` — falls through orders from longest to shortest matching context.
    #' @param stm_lambda Escape/discount method for STM:
    #'   - `"A"` — very conservative; escapes rarely.
    #'   - `"B"` — escapes in proportion to novelty.
    #'   - `"C"` — Witten-Bell (default); balances novelty and count stability.
    #'   - `"D"` — absolute discounting (d = 0.5).
    #'   - `"X"` — AX; escapes based on singleton count.
    #'
    #'   See the [Escape method](../articles/ParameterCorrespondence.html#escape-method)
    #'   section of the [Parameter Correspondence](../articles/ParameterCorrespondence.html)
    #'   vignette for the exact formulas.
    #' @param ltm_lambda Escape/discount method for LTM; same options as `stm_lambda`.
    #' @param b Bias exponent for entropy-weighted blending, used only when
    #'   `model_type` is `"both"`/`"both+"`; higher values favor whichever of
    #'   STM/LTM is currently more confident (lower entropy).
    #' @param idyom_base Logical order-(-1) base distribution:
    #'   - `TRUE` — IDyOM-compatible: 1/|alphabet| when exclusion=FALSE,
    #'     shrinking denominator when exclusion=TRUE.
    #'   - `FALSE` (default) — always the shrinking denominator (matches
    #'     Harrison's ppm package).
    #'
    #'   See the [Implementation Discrepancy](../articles/ImplementationDiscrepancy.html)
    #'   vignette for details.
    #'   (Matching IDyOM for LTM also requires the constructor's `ltm_start_token = FALSE`.)
    #' @return data.table with columns: index, Event, P, IC, Entropy
    #' @examples
    #' # ppidyomModel is internal; use ::: since this example isn't run via library()
    #' model <- ppidyom:::ppidyomModel$new(N = 3, alphabet = c("A", "B", "C"), stm_exclusion = TRUE)
    #' result <- model$predict_sequence(
    #'   c("A", "B", "A", "C", "A", "B", "A", "C", "A"),
    #'   model_type = "stm", stm_lambda = "C"
    #' )
    #' result[, .(index, Event, P, IC, Entropy)]
    predict_sequence = function(x, model_type = c("stm", "ltm", "both", "ltm+", "both+"),
                                ppm_type = c("interpolation", "backoff"),
                                stm_lambda = "C",
                                ltm_lambda = "C",
                                b = 1,
                                idyom_base = FALSE) {
      model_type <- match.arg(model_type)
      ppm_type   <- match.arg(ppm_type)
      T          <- length(x)

      stm_lambda_func <- escape_functions[[stm_lambda]]
      if (is.null(stm_lambda_func)) stop("Unknown escape function: ", stm_lambda)
      ltm_lambda_func <- escape_functions[[ltm_lambda]]
      if (is.null(ltm_lambda_func)) stop("Unknown escape function: ", ltm_lambda)

      is_plus   <- model_type %in% c("ltm+", "both+")
      needs_stm <- model_type %in% c("stm", "both", "both+")
      needs_ltm <- model_type %in% c("ltm", "ltm+", "both", "both+")

      # ── STM counts (always batch: observe-before-predict is baked into
      #   update_env_and_build_stm_tables, which snapshots before writing) ───────
      stm_order_counts <- NULL
      if (needs_stm) {
        stm_order_counts <- count_tables(
          x = x, N = .self$N, alphabet = .self$alphabet,
          model_type = "stm",
          stm_update_exclusion = .self$stm_update_exclusion,
          ltm_update_exclusion = .self$ltm_update_exclusion,
          ltm_start_token = .self$ltm_start_token
        )$stm
      }

      # ── LTM counts ────────────────────────────────────────────────────────────
      # ltm/both  : use pre-trained .self$counts_ltm only (no test-data leakage).
      # ltm+/both+: online update — predict x[t] using LTM state before x[t],
      #             then add x[t] to LTM; matches IDyOM's :both+ / :ltm+ semantics.
      ltm_order_counts <- NULL
      if (needs_ltm) {
        if (is_plus) {
          ltm_order_counts <- build_online_ltm_timestep_counts(
            x, .self$N, .self$alphabet, .self$counts_ltm,
            ltm_update_exclusion = .self$ltm_update_exclusion,
            ltm_start_token      = .self$ltm_start_token
          )
        } else {
          ltm_order_counts <- if (length(.self$counts_ltm) > 0)
            .self$counts_ltm
          else {
            # Edge case: untrained model — fall back to x itself as training data
            count_tables(
              x = x, N = .self$N, alphabet = .self$alphabet,
              model_type = "ltm",
              stm_update_exclusion = .self$stm_update_exclusion,
              ltm_update_exclusion = .self$ltm_update_exclusion,
              ltm_start_token      = .self$ltm_start_token
            )$ltm
          }
        }
      }

      # ── Compute probabilities ─────────────────────────────────────────────────
      P_stm <- NULL
      if (needs_stm) {
        P_stm <- if (ppm_type == "interpolation")
          ppm_interpolated(
            x, .self$N, .self$alphabet, stm_order_counts,
            escape_func = stm_lambda_func, exclusion = .self$stm_exclusion,
            idyom_base = idyom_base
          )
        else
          ppm_backoff(x, .self$N, .self$alphabet, stm_order_counts,
                      escape_func = stm_lambda_func,
                      exclusion = .self$stm_exclusion, idyom_base = idyom_base)
      }

      P_ltm <- NULL
      if (needs_ltm) {
        P_ltm <- if (ppm_type == "interpolation")
          ppm_interpolated(
            x, .self$N, .self$alphabet, ltm_order_counts,
            escape_func = ltm_lambda_func, exclusion = .self$ltm_exclusion,
            idyom_base = idyom_base
          )
        else
          ppm_backoff(x, .self$N, .self$alphabet, ltm_order_counts,
                      escape_func = ltm_lambda_func,
                      exclusion = .self$ltm_exclusion, idyom_base = idyom_base)
      }

      result_all_symbols <- if (model_type == "stm")
        P_stm
      else if (model_type %in% c("ltm", "ltm+"))
        P_ltm
      else
        combine_models(.self$alphabet, P_stm, P_ltm, b)

      # ── Online LTM update (+ models only) ─────────────────────────────────────
      # train_sequence(x) adds x's events on top of the current .self$counts_ltm,
      # which still holds the pre-prediction state — so the final LTM = prior + x.
      if (is_plus) {
        .self$train_sequence(x)
      }

      result_all_symbols[
        data.table(index = seq_len(T), Event = x),
        on = .(index, Event)
      ][, .(index, Event, P, IC, Entropy)]
    }
  )

)

combine_models <- function(alphabet, p_stm, p_ltm, b=1) {
  dt <- merge(
    p_stm[, .(index, Event, P_stm=P, H_stm=Entropy)],
    p_ltm[, .(index, Event, P_ltm=P, H_ltm=Entropy)],
    by=c("index","Event")
  )

  logA <- log2(length(alphabet))

  # Relative entropy weights: w_i = (H_i / H_max)^{-b}
  # Dividing by logA (= H_max for a uniform alphabet) makes w scale-invariant.
  # The logA^b factor cancels in normalisation, so only the H ratio matters.
  dt[, Hrel_stm := H_stm / logA]
  dt[, Hrel_ltm := H_ltm / logA]

  dt[, w_stm := Hrel_stm^(-b)]
  dt[, w_ltm := Hrel_ltm^(-b)]

  # Normalise weights to [0,1] so they can be used as geometric-mean exponents
  dt[, w_norm := w_stm + w_ltm]
  dt[, w_stm_n := w_stm / w_norm]
  dt[, w_ltm_n := w_ltm / w_norm]

  # IDyOM log-linear (geometric-mean) combination.
  # Geometric mean: P_raw(s) = P_stm(s)^w_stm_n * P_ltm(s)^w_ltm_n
  #
  # IDyOM normalises conditionally (ppm-star.lisp: normalise-distribution /
  # sums-to-one-p): if 0.999 < sum(P_raw) < 1.0 it treats the distribution as
  # already summing to one and skips the division.  We replicate that exactly.
  dt[, P_raw := P_stm^w_stm_n * P_ltm^w_ltm_n]
  dt[, Z     := sum(P_raw), by = index]
  dt[, P     := if (Z[1] > 0.999 && Z[1] < 1.0) P_raw else P_raw / Z,
      by = index]

  dt[, IC      := -log2(P)]
  dt[, Entropy := -sum(P * log2(P)), by = index]

  dt[, .(index, Event, P, IC, Entropy)]
}

