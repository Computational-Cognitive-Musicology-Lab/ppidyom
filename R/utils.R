# Right now, it runs on all sequences provided by training on the remaining as LTM.
run_ppidyom <- function(
    seq_list,
    N,
    alphabet = NULL,
    model_type = c("stm", "ltm", "both", "ltm+", "both+"),
    ppm_type = c("interpolation", "backoff"),
    stm_lambda = "C",
    ltm_lambda = "C",
    exclusion = TRUE,
    stm_update_exclusion = TRUE,
    ltm_update_exclusion = FALSE,
    b = 1
){
  model_type <- match.arg(model_type)
  ppm_type <- match.arg(ppm_type)

  if (is.null(alphabet)) {
    alphabet <- unique(unlist(seq_list, use.names = FALSE))
  }
  model <- ppidyom$new(
    N = N, alphabet = alphabet,
    exclusion = exclusion,
    stm_update_exclusion = stm_update_exclusion,
    ltm_update_exclusion = ltm_update_exclusion
  )

  has_ltm <- model_type %in% c("ltm","both","ltm+","both+")

  # Train all sequences
  if(has_ltm) {
    for(seq in seq_list) {
      model$train_sequence(seq)
    }
  }

  results_list <- vector("list", length(seq_list))

  # For each test sequence, detrain itself, predict, and retrain itself
  for(i in seq_along(seq_list)) {
    x <- seq_list[[i]]
    # Leave-one-out option
    if(has_ltm) {
      model$detrain_sequence(x)
    }
    pred <- model$predict_sequence(
      x,
      model_type = model_type,
      ppm_type = ppm_type,
      stm_lambda = stm_lambda,
      ltm_lambda = ltm_lambda,
      b = b
    )
    pred[, seq_id := i]
    results_list[[i]] <- pred

    if(has_ltm) {
      model$train_sequence(x)
    }
  }

  results_list
}

