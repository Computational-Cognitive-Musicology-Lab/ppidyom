library(data.table)


ppidyom <- setRefClass(
  "ppidyom",

  fields = list(
    N = "numeric",
    alphabet = "character",
    counts_ltm = "list"
  ),

  methods = list(

    #' Initialize a new PPM counter
    initialize = function(N, alphabet) {
      .self$N <- N
      .self$alphabet <- alphabet
      .self$counts_ltm <- list()
    },

    #' Train on a single sequence (incremental LTM update)
    #' @param x Character vector sequence to train
    train_sequence = function(x) {
      count_tables <- count_tables(
        x = x,
        N = .self$N,
        alphabet = .self$alphabet,
        model_type="ltm",
        prior = .self$counts_ltm
      )
      # Update LTM
      .self$counts_ltm <- count_tables$ltm
      invisible(NULL)
    },


    #' Remove a single sequence from the trained LTM counts
    #' @param x Character vector sequence to de-train
    detrain_sequence = function(x) {
      T <- length(x)
      dt_lag <- lag_matrix(x, .self$N)

      for(n in 0:N) {
        context_cols <- if(n == 0) character(0) else paste0("Lag", n:1)
        # Context identifiers
        if(n==0) dt_lag[, context_id := "ROOT"]
        else dt_lag[, context_id := do.call(paste, c(.SD, sep="_")), .SDcols=context_cols]

        # counts_ltm has one table for each N
        counts_ltm_n <- .self$counts_ltm[[n+1]]
        setkey(counts_ltm_n, context_id, Event)
        for(t in seq_len(T)) {
          ctx <- dt_lag$context_id[t]
          event <- dt_lag$Lag0[t]
          # Locate each (context_id, event) pair in the LTM counts
          idx <- counts_ltm_n[list(ctx, event), which = TRUE]

          if(length(idx) == 0) next  # nothing to remove
          old_ce <- counts_ltm_n$Ce[idx]
          if(old_ce <= 0) next # original LTM did not have this (ctx, event) pair

          # --- Update Ce for the row of (ctx, event) pair ---
          counts_ltm_n$Ce[idx] <- old_ce - 1L

          # --- Update C for all rows where context_id=ctx ---
          counts_ltm_n[context_id == ctx, C := C - 1L]

          # --- Update t and t1 ---
          if(old_ce == 1L) {
            # event disappears
            counts_ltm_n[context_id == ctx, t := t - 1L]
            counts_ltm_n[context_id == ctx, t1 := t1 - 1L]
          } else if(old_ce == 2L) {
            # becomes singleton
            counts_ltm_n[context_id == ctx, t1 := t1 + 1L]
          }
        }

        .self$counts_ltm[[n+1]] <- counts_ltm_n
      }
    },

    #' Predict IC and entropy for a sequence
    #' @param x Character vector sequence
    #' @param model_type Model type: "stm", "ltm", "both", "ltm+", "both+"
    #' @param ppm_type "interpolation" or "backoff"
    #' @param lambda escape or discount function (default = "C")
    #' @param b Bias parameter for relative-entropy weighting (used for + models)
    #' @return data.table with columns: index, Event, P, IC, Entropy
    predict_sequence = function(x, model_type = c("stm", "ltm", "both", "ltm+", "both+"),
                                ppm_type = c("interpolation", "backoff"),
                                lambda = "C",
                                b = 1) {
      model_type <- match.arg(model_type)
      ppm_type <- match.arg(ppm_type)
      T <- length(x)
      alpha_len <- length(.self$alphabet)

      # -------------------------
      # lambda function
      # -------------------------
      escape_func <- escape_functions[[lambda]]
      if(is.null(escape_func)) stop("Unknown escape lambda: ", lambda)
      discount_func <- discount_functions[[lambda]]
      if(is.null(discount_func)) stop("Unknown discount lambda: ", lambda)

      # ------------------------------------------------
      # Build count tables
      # ------------------------------------------------
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
        prior = .self$counts_ltm
      )

      # ------------------------------------------------
      # STM probabilities
      # ------------------------------------------------

      P_stm <- NULL
      if(model_type %in% c("stm","both","both+")) {

        P_stm <- if(ppm_type == "interpolation")
          ppm_interpolated(x, .self$N, .self$alphabet, counts$stm, discount_func=discount_func)
        else
          ppm_backoff(x, .self$N, .self$alphabet, counts$stm, escape_func=escape_func)

      }

      # ------------------------------------------------
      # LTM probabilities
      # ------------------------------------------------

      P_ltm <- NULL
      if(model_type %in% c("ltm","both","ltm+","both+")) {

        P_ltm <- if(ppm_type == "interpolation")
          ppm_interpolated(x, .self$N, .self$alphabet, counts$ltm, discount_func=discount_func)
        else
          ppm_backoff(x, .self$N, .self$alphabet, counts$ltm, escape_func=escape_func)
      }

      # ------------------------------------------------
      # Model selection
      # ------------------------------------------------

      if(model_type == "stm")
        result_all_symbols <- P_stm
      else if(model_type == "ltm" || model_type == "ltm+")
        result_all_symbols <- P_ltm
      else if(model_type %in% c("both","both+"))
        result_all_symbols <- combine_models(.self$alphabet, P_stm, P_ltm, b)

      # ------------------------------------------------
      # Online learning (+ models)
      # ------------------------------------------------

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
