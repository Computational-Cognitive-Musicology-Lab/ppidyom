library(data.table)


ppidyom <- setRefClass(
  "ppidyom",

  fields = list(
    N = "numeric",
    alphabet = "character",
    counts_ltm = "list",
    stm_exclusion = "logical",
    ltm_exclusion = "logical",
    stm_update_exclusion = "logical",
    ltm_update_exclusion = "logical"
  ),

  methods = list(

    #' Initialize a new PPM counter
    initialize = function(
      N, alphabet,
      stm_exclusion = TRUE, ltm_exclusion = TRUE,
      stm_update_exclusion = TRUE, ltm_update_exclusion = FALSE
    ) {
      .self$N <- N
      .self$alphabet <- alphabet
      .self$counts_ltm <- list()
      .self$stm_exclusion <- stm_exclusion
      .self$ltm_exclusion <- ltm_exclusion
      .self$stm_update_exclusion <- stm_update_exclusion
      .self$ltm_update_exclusion <- ltm_update_exclusion
    },

    #' Train on a single sequence (incremental LTM update)
    #' @param x Character vector sequence to train
    train_sequence = function(x) {
      count_tables <- count_tables(
        x = x,
        N = .self$N,
        alphabet = .self$alphabet,
        model_type="ltm",
        prior = .self$counts_ltm,
        stm_update_exclusion = .self$stm_update_exclusion,
        ltm_update_exclusion = .self$ltm_update_exclusion
      )
      # Update LTM
      .self$counts_ltm <- count_tables$ltm
      invisible(NULL)
    },


    #' Remove a single sequence from the trained LTM counts
    #'
    #' Exactly reverses one call to train_sequence(x), event by event.
    #'
    #' ## Why the loop order matters for ltm_update_exclusion
    #'
    #' train_sequence increments counts with this per-timestep logic:
    #'
    #'   seen = FALSE
    #'   for n = N downto 0:
    #'     if !ltm_update_exclusion OR !seen:
    #'       exists = (ctx_n, sym) already in LTM   [Ce > 0 BEFORE update]
    #'       Ce_n += 1
    #'       if exists: seen = TRUE   ← stop updating lower orders
    #'
    #' detrain_sequence must undo exactly those increments.  The key is
    #' reconstructing which orders were actually updated:
    #'
    #'   • We know Ce_current (the value NOW, after training).
    #'   • The Ce before training was Ce_current - 1.
    #'   • "exists before training" = Ce_before > 0 = Ce_current - 1 > 0
    #'     = old_ce > 1.
    #'
    #' So we mirror the training loop, decrementing Ce at each order and
    #' stopping (setting seen_ltm=TRUE) whenever old_ce > 1, because that
    #' is exactly when training would have stopped updating lower orders.
    #'
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

    #' Predict IC and entropy for a sequence
    #' @param x Character vector sequence
    #' @param model_type Model type: "stm", "ltm", "both", "ltm+", "both+"
    #' @param ppm_type "interpolation" or "backoff"
    #' @param stm_lambda escape or discount function for STM (default = "C")
    #' @param ltm_lambda escape or discount function for LTM (default = "C")
    #' @param b Bias parameter for relative-entropy weighting (used for + models)
    #' @return data.table with columns: index, Event, P, IC, Entropy
    predict_sequence = function(x, model_type = c("stm", "ltm", "both", "ltm+", "both+"),
                                ppm_type = c("interpolation", "backoff"),
                                stm_lambda = "C",
                                ltm_lambda = "C",
                                b = 1) {
      model_type <- match.arg(model_type)
      ppm_type <- match.arg(ppm_type)
      T <- length(x)
      alpha_len <- length(.self$alphabet)

      # Both backoff and interpolation use the escape_functions lookup.
      # escape_* functions return denom/esc/subtract, which is the correct
      # interface for both algorithms (ppm_interpolated was fixed to match).
      stm_lambda_func <- escape_functions[[stm_lambda]]
      if (is.null(stm_lambda_func)) stop("Unknown escape function: ", stm_lambda)
      ltm_lambda_func <- escape_functions[[ltm_lambda]]
      if (is.null(ltm_lambda_func)) stop("Unknown escape function: ", ltm_lambda)


      # Build count tables
      # Determine which counts to compute
      if (model_type == "stm") {
        count_type <- "stm"
      } else if (grepl("ltm", model_type) && !grepl("both", model_type)) {
        count_type <- "ltm"
      } else if (grepl("both", model_type)) {
        count_type <- "both"
      } else {
        stop("Invalid model_type")
      }

      counts <- count_tables(
        x = x,
        N = .self$N,
        alphabet = .self$alphabet,
        model_type = count_type,
        prior = .self$counts_ltm,
        stm_update_exclusion = .self$stm_update_exclusion,
        ltm_update_exclusion = .self$ltm_update_exclusion
      )

      # STM probabilities
      P_stm <- NULL
      if (model_type %in% c("stm","both","both+")) {
        P_stm <- if (ppm_type == "interpolation")
          ppm_interpolated(
            x, .self$N, .self$alphabet, counts$stm,
            escape_func = stm_lambda_func, exclusion = .self$stm_exclusion
          )
        else
          ppm_backoff(x, .self$N, .self$alphabet, counts$stm, escape_func = stm_lambda_func)
      }

      # LTM probabilities
      P_ltm <- NULL
      if (model_type %in% c("ltm","both","ltm+","both+")) {
        P_ltm <- if (ppm_type == "interpolation")
          ppm_interpolated(
            x, .self$N, .self$alphabet, counts$ltm,
            escape_func = ltm_lambda_func, exclusion = .self$ltm_exclusion
          )
        else
          ppm_backoff(x, .self$N, .self$alphabet, counts$ltm, escape_func = ltm_lambda_func)
      }

      # Model selection
      if(model_type == "stm")
        result_all_symbols <- P_stm
      else if(model_type == "ltm" || model_type == "ltm+")
        result_all_symbols <- P_ltm
      else if(model_type %in% c("both","both+"))
        result_all_symbols <- combine_models(.self$alphabet, P_stm, P_ltm, b)

      # Online learning (+ models)
      if(model_type %in% c("ltm+","both+")) {
        .self$counts_ltm <- counts$ltm
      }

      result <- result_all_symbols[
        data.table(index = seq_len(length(x)), Event = x),
        on = .(index, Event)
      ][
        , .(index, Event, P, IC, Entropy)
      ]
      result
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

  # TODO: relative = if Hmax([τb]) > 0, below; else, 1
  dt[, Hrel_stm := H_stm / logA]
  dt[, Hrel_ltm := H_ltm / logA]

  dt[, w_stm := Hrel_stm^(-b)]
  dt[, w_ltm := Hrel_ltm^(-b)]

  dt[, norm := w_stm + w_ltm]

  dt[, P := (w_stm * P_stm + w_ltm * P_ltm) / norm]

  dt[, IC := -log2(P)]

  dt[, Entropy := -sum(P * log2(P)), by = index]

  dt[, .(index, Event, P, IC, Entropy)]
}

