library(testthat)
library(data.table)

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
  model <- ppidyomModel$new(N = max_order, alphabet = alphabet)

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


test_that("run_ppidyom matches manual leave-one-out", {
  set.seed(1)
  alphabet <- c("A", "B", "C", "D", "E")
  N        <- 3
  seq_list <- replicate(10, sample(alphabet, 15, replace = TRUE), simplify = FALSE)

  args <- list(seq_list = seq_list, N = N, alphabet = alphabet,
               model_type = "both", ppm_type = "interpolation",
               stm_lambda = "C", ltm_lambda = "C", b = 1)

  res_fast   <- do.call(run_ppidyom,   args)
  res_manual <- do.call(manual_ppidyom, args)

  expect_true(compare_results(res_fast, res_manual, by = c("index", "Event")))
})


test_that("detrain_sequence restores LTM state with ltm_update_exclusion=TRUE", {

  train_seq1 <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
  train_seq2 <- c("A", "B", "C", "A", "B", "C", "A", "B", "C")

  alphabet    <- c("A", "B", "C")
  max_order   <- 3

  model <- ppidyomModel$new(
    N = max_order, alphabet = alphabet,
    ltm_update_exclusion = TRUE
  )

  model$train_sequence(train_seq1)
  counts_before <- lapply(model$counts_ltm, copy)

  model$train_sequence(train_seq2)
  model$detrain_sequence(train_seq2)
  counts_after <- model$counts_ltm

  expect_true(
    compare_results(
      clean_counts(counts_before),
      clean_counts(counts_after),
      by = c("context_id", "Event")
    )
  )
})

