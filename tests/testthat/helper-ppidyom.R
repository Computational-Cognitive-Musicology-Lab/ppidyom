library(data.table)

clean_counts <- function(x) {
  lapply(x, function(dt) dt[C > 0])
}

compare_results <- function(a, b, by = c("index", "Event"), tolerance = 1.5e-8) {
  if (length(a) != length(b)) return(FALSE)
  for (i in seq_along(a)) {
    dt1 <- copy(a[[i]])
    dt2 <- copy(b[[i]])
    if (!all(by %in% names(dt1)) || !all(by %in% names(dt2)))
      stop("Missing columns: ", paste(by, collapse = ", "))
    setorderv(dt1, by)
    setorderv(dt2, by)
    common <- intersect(names(dt1), names(dt2))
    if (!isTRUE(all.equal(dt1[, ..common], dt2[, ..common],
                          tolerance = tolerance, check.attributes = FALSE))) {
      return(FALSE)
    }
  }
  TRUE
}

# Naive leave-one-out: retrain from scratch for each held-out sequence.
# O(n^2) in corpus size — used as a correctness reference and scaling baseline.
manual_ppidyom <- function(seq_list, N, alphabet, model_type, ppm_type,
                            stm_lambda, ltm_lambda, b) {
  results <- vector("list", length(seq_list))
  for (i in seq_along(seq_list)) {
    model <- ppidyom$new(N = N, alphabet = alphabet)
    for (j in seq_along(seq_list)) {
      if (j != i) model$train_sequence(seq_list[[j]])
    }
    pred <- model$predict_sequence(
      seq_list[[i]],
      model_type = model_type, ppm_type = ppm_type,
      stm_lambda = stm_lambda, ltm_lambda = ltm_lambda, b = b
    )
    pred[, seq_id := i]
    results[[i]] <- pred
  }
  results
}
