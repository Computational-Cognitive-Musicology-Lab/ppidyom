library(testthat)
library(data.table)

# Helper: compare count tables
compare_results <- function(a, b, by = c("index", "Event"),
                            tolerance = NULL, verbose = FALSE) {

  if(length(a) != length(b)) return(FALSE)

  for(i in seq_along(a)) {
    dt1 <- copy(a[[i]])
    dt2 <- copy(b[[i]])

    # Ensure required columns exist
    if(!all(by %in% names(dt1)) || !all(by %in% names(dt2))) {
      stop("Missing columns in comparison: ", paste(by, collapse = ", "))
    }

    # Order consistently
    setorderv(dt1, by)
    setorderv(dt2, by)

    # Align columns
    common_cols <- intersect(names(dt1), names(dt2))
    dt1 <- dt1[, ..common_cols]
    dt2 <- dt2[, ..common_cols]

    # Comparison
    equal <- if(is.null(tolerance)) {
      identical(dt1, dt2)
    } else {
      isTRUE(all.equal(dt1, dt2, tolerance = tolerance))
    }

    if(!equal) {
      if(verbose) {
        cat("Mismatch at element:", i, "\n")
        print(fsetdiff(dt1, dt2))
        print(fsetdiff(dt2, dt1))
      }
      return(FALSE)
    }
  }

  TRUE
}

# remove zero-count contexts
clean_counts <- function(x) {
  lapply(x, function(dt) dt[C > 0])
}

test_that("detrain_sequence restores LTM state after training", {

  # ---------------------------
  # Data
  # ---------------------------
  train_seq1 <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
  train_seq2 <- c("A", "B", "C", "A", "B", "C", "A", "B", "C")

  alphabet <- c("A", "B", "C")
  max_order <- 3

  # ---------------------------
  # Model
  # ---------------------------
  model <- ppidyom$new(N = max_order, alphabet = alphabet)

  # Train first sequence
  model$train_sequence(train_seq1)
  counts_before <- lapply(model$counts_ltm, copy)

  # Train second sequence
  model$train_sequence(train_seq2)

  # Detrain second sequence
  model$detrain_sequence(train_seq2)
  counts_after <- model$counts_ltm

  # ---------------------------
  # Assertions
  # ---------------------------
  expect_true(
    compare_results(
      clean_counts(counts_before),
      clean_counts(counts_after),
      by = c("context_id", "Event")
    )
  )
})


# ---------------------------
# Helper: manual leave-one-out
# ---------------------------
manual_ppidyom <- function(seq_list, N, alphabet, model_type, ppm_type, lambda, b) {

  results <- vector("list", length(seq_list))

  for(i in seq_along(seq_list)) {

    # Train on all except i
    model <- ppidyom$new(N = N, alphabet = alphabet)

    for(j in seq_along(seq_list)) {
      if(j != i) {
        model$train_sequence(seq_list[[j]])
      }
    }

    # Predict on held-out sequence
    pred <- model$predict_sequence(
      seq_list[[i]],
      model_type = model_type,
      ppm_type = ppm_type,
      lambda = lambda,
      b = b
    )

    pred[, seq_id := i]
    results[[i]] <- pred
  }

  results
}

# ---------------------------
# Test
# ---------------------------
test_that("run_ppidyom matches manual leave-one-out and reports timing", {
  set.seed(1)

  gen_seq <- function(n) sample(c("A","B","C","D","E"), n, replace=TRUE)

  seq_list <- gen_seq(50)

  alphabet <- c("A", "B", "C", "D", "E")
  N <- 3

  args <- list(
    seq_list = seq_list,
    N = N,
    alphabet = alphabet,
    model_type = "both",
    ppm_type = "interpolation",
    lambda = "C",
    b = 1
  )

  # ---------------------------
  # Time run_ppidyom
  # ---------------------------
  print("running ppidyom")
  t1 <- system.time({
    res_fast <- do.call(run_ppidyom, args)
  })

  # ---------------------------
  # Time manual loop
  # ---------------------------
  print("running manual loop")
  t2 <- system.time({
    res_manual <- do.call(manual_ppidyom, args)
  })

  # ---------------------------
  # Check equality
  # ---------------------------
  expect_true(
    compare_results(res_fast, res_manual, by = c("index", "Event"))
  )

  # ---------------------------
  # Report timing
  # ---------------------------
  speedup <- t1["elapsed"] / t2["elapsed"]

  cat("\nTiming comparison:\n")
  cat(sprintf("run_ppidyom: %.4f sec\n", t1["elapsed"]))
  cat(sprintf("manual loop: %.4f sec\n", t2["elapsed"]))
  cat(sprintf("speedup: %.2fx\n", speedup))
})

