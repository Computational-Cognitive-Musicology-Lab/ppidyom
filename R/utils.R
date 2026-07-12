# Runs leave-one-out PPM over a corpus: trains on all sequences, then for each
# sequence detrains itself, predicts, and retrains.
run_ppidyom <- function(
    seq_list,
    N,
    alphabet = NULL,
    model_type = c("stm", "ltm", "both", "ltm+", "both+"),
    ppm_type = c("interpolation", "backoff"),
    stm_lambda = "C",
    ltm_lambda = "C",
    stm_exclusion = TRUE,
    ltm_exclusion = TRUE,
    stm_update_exclusion = TRUE,
    ltm_update_exclusion = FALSE,
    b = 1,
    idyom_base = FALSE,
    ltm_start_token = TRUE
) {
  model_type <- match.arg(model_type)
  ppm_type   <- match.arg(ppm_type)

  alphabet_inferred <- is.null(alphabet)
  if (alphabet_inferred) {
    alphabet <- unique(unlist(seq_list, use.names = FALSE))
  }
  model <- ppidyom$new(
    N = N, alphabet = alphabet,
    stm_exclusion = stm_exclusion,
    ltm_exclusion = ltm_exclusion,
    stm_update_exclusion = stm_update_exclusion,
    ltm_update_exclusion = ltm_update_exclusion,
    ltm_start_token = ltm_start_token
  )

  has_ltm <- model_type %in% c("ltm","both","ltm+","both+")

  # Train all sequences
  if(has_ltm) {
    for(seq in seq_list) {
      model$train_sequence(seq)
    }
  }

  n_seqs       <- length(seq_list)
  results_list <- vector("list", n_seqs)
  t0           <- proc.time()[["elapsed"]]

  message(sprintf("run_ppidyom: %d sequences, N=%d, model=%s, ppm=%s, alphabet=%d%s",
                  n_seqs, N, model_type, ppm_type,
                  length(alphabet),
                  if (alphabet_inferred) " (inferred)" else " (user-supplied)"))

  for(i in seq_along(seq_list)) {
    x <- seq_list[[i]]
    if(has_ltm) model$detrain_sequence(x)

    pred <- model$predict_sequence(
      x,
      model_type = model_type,
      ppm_type = ppm_type,
      stm_lambda = stm_lambda,
      ltm_lambda = ltm_lambda,
      b = b,
      idyom_base = idyom_base
    )
    pred[, seq_id := i]
    results_list[[i]] <- pred

    if(has_ltm) model$train_sequence(x)

    elapsed <- proc.time()[["elapsed"]] - t0
    eta     <- if (i < n_seqs) elapsed / i * (n_seqs - i) else 0
    message(sprintf("  [%d/%d] %.1fs elapsed, %.1fs remaining",
                    i, n_seqs, elapsed, eta))
  }

  results_list
}

