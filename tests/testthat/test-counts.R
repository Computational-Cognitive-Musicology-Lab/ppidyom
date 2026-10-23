library(data.table)
library(testthat)

# Test sequence and alphabet
seq1 <- c("A","B","A","C")
alphabet <- c("A","B","C")
N <- 2

# Expected STM counts for order 0 (ROOT context)
expected_stm_order0 <- data.table(
  index = 1:4,
  context_id = rep("ROOT", 4),
  Event = rep(alphabet, each = 4),
  Ce = c(0,0,0,  # t=1
         1,0,0,  # t=2
         1,1,0,  # t=3
         2,1,0), # t=4
  C = c(0,0,0,1,1,1,2,2,2,3,3,3),
  t = c(0,0,0,1,1,1,2,2,2,2,2,2),
  t1 = c(0,0,0,1,1,1,2,2,2,1,1,1)
)

test_that("STM exact counts for order 0 match expectations", {
  counts <- count_tables(seq1, N=N, alphabet=alphabet, model_type="stm")
  stm0 <- counts$stm[[1]]  # order 0
  expect_equal(stm0$Ce, expected_stm_order0$Ce)
  expect_equal(stm0$C, expected_stm_order0$C)
  expect_equal(stm0$t, expected_stm_order0$t)
  expect_equal(stm0$t1, expected_stm_order0$t1)
  expect_equal(stm0$context_id, expected_stm_order0$context_id)
})

# Expected LTM counts for order 0 (ROOT context)
expected_ltm_order0 <- data.table(
  index = -1L,
  context_id = "ROOT",
  Event = alphabet,
  Ce = c(2,1,1),  # A occurs 2 times, B 1 time, C 1 time
  C = c(4,4,4),
  t = c(3,3,3),
  t1 = c(2,2,2)
)

test_that("LTM exact counts for order 0 match expectations", {
  counts <- count_tables(seq1, N=N, alphabet=alphabet, model_type="ltm")
  ltm0 <- counts$ltm[[1]][context_id == "ROOT"]
  expect_equal(ltm0$Ce, expected_ltm_order0$Ce)
  expect_equal(ltm0$C, expected_ltm_order0$C)
  expect_equal(ltm0$t, expected_ltm_order0$t)
  expect_equal(ltm0$t1, expected_ltm_order0$t1)
  expect_equal(ltm0$context_id, expected_ltm_order0$context_id)
})

# Test both STM and LTM together
test_that("Both STM and LTM produce correct exact counts", {
  counts <- count_tables(seq1, N=N, alphabet=alphabet, model_type="both")

  # STM order 0
  expect_equal(counts$stm[[1]]$Ce, expected_stm_order0$Ce)

  # LTM order 0
  expect_equal(counts$ltm[[1]][context_id=="ROOT"]$Ce, expected_ltm_order0$Ce)
})


# Expected STM counts for order 2
expected_stm_order2 <- data.table(
  index = rep(1:4, each = 3),
  context_id = c("NA_NA","NA_NA","NA_NA",
                 "NA_C","NA_C","NA_C",
                 "C_A","C_A","C_A",
                 "A_B","A_B","A_B"),
  Event = rep(alphabet, 4),
  Ce = rep(0,12),
  C = rep(0,12),
  t = rep(0,12),
  t1 = rep(0,12)
)


# Expected LTM counts for order 2 (after training seq1 then seq2 with prior)
# seq1 = c("A","B","A","C"), seq2 = c("C","A","B","A")
# Contexts and values are correct; comparison is done after sorting by
# (context_id, Event) to avoid dependence on hash-environment ordering.
expected_ltm_order2 <- data.table(
  index = -1L,
  context_id = c("NA_NA","NA_NA","NA_NA",
                 "NA_C","NA_C","NA_C",
                 "C_A","C_A","C_A",
                 "A_B","A_B","A_B",
                 "NA_A","NA_A","NA_A",
                 "B_A","B_A","B_A"),
  Event = rep(alphabet, 6),
  Ce = c(1,0,1, 1,0,0, 0,1,0, 2,0,0, 0,1,0, 0,0,1),
  C  = c(2,2,2, 1,1,1, 1,1,1, 2,2,2, 1,1,1, 1,1,1),
  t  = c(2,2,2, 1,1,1, 1,1,1, 1,1,1, 1,1,1, 1,1,1),
  t1 = c(2,2,2, 1,1,1, 1,1,1, 0,0,0, 1,1,1, 1,1,1)
)


# Test accumulation with prior
test_that("LTM prior counts accumulate correctly", {
  # seq1 <- c("A","B","A","C")
  prior_counts <- count_tables(seq1, N=N, alphabet=alphabet, model_type="ltm")
  seq2 <- c("C","A","B","A")
  counts_with_prior <- count_tables(seq2, N=N, alphabet=alphabet, model_type="both", prior=prior_counts$ltm)

  expect_equal(counts_with_prior$stm[[3]]$Ce, expected_stm_order2$Ce)
  expect_equal(counts_with_prior$stm[[3]]$C, expected_stm_order2$C)
  expect_equal(counts_with_prior$stm[[3]]$t, expected_stm_order2$t)
  expect_equal(counts_with_prior$stm[[3]]$t1, expected_stm_order2$t1)

  # Sort both by (context_id, Event) — hash-env ordering is not deterministic
  actual_ltm2 <- data.table::copy(counts_with_prior$ltm[[3]])
  setorderv(actual_ltm2, c("context_id", "Event"))
  expected_ltm2 <- data.table::copy(expected_ltm_order2)
  setorderv(expected_ltm2, c("context_id", "Event"))

  expect_equal(actual_ltm2$Ce, expected_ltm2$Ce)
  expect_equal(actual_ltm2$C,  expected_ltm2$C)
  expect_equal(actual_ltm2$t,  expected_ltm2$t)
  expect_equal(actual_ltm2$t1, expected_ltm2$t1)
})



# ── Optimized pipeline: same expected counts from stm_counts() / ltm_counts() ──
# count_tables() defaults: no update exclusion, ltm_start_token = TRUE.
# stm_counts() tables are sorted by (index, Sym), matching the expected row order.
# ltm_counts() tables are sparse (only pairs that occurred), so they are compared
# on the non-zero counts.

test_that("optimized STM exact counts for order 0 match expectations", {
  stm0 <- stm_counts(lag_matrix(seq1, N = N, alphabet = alphabet), update_exclusion = FALSE)[[1]]
  expect_equal(stm0$Ce, expected_stm_order0$Ce)
  expect_equal(stm0$C,  expected_stm_order0$C)
  expect_equal(stm0$t,  expected_stm_order0$t)
  expect_equal(stm0$t1, expected_stm_order0$t1)
})

test_that("optimized LTM exact counts for order 0 match expectations", {
  ltm0 <- ltm_counts(lag_matrix(seq1, N = N, alphabet = alphabet), update_exclusion = FALSE)[[1]]
  setorder(ltm0, Sym)
  expect_equal(ltm0$Sym, expected_ltm_order0$Event)
  expect_equal(ltm0$Ce,  expected_ltm_order0$Ce)
  expect_equal(ltm0$C,   expected_ltm_order0$C)
  expect_equal(ltm0$t,   expected_ltm_order0$t)
  expect_equal(ltm0$t1,  expected_ltm_order0$t1)
})

test_that("optimized LTM counts accumulate across training pieces", {
  seq2 <- c("C","A","B","A")

  # STM order 2 for seq2 alone: every context is new, so all counts are 0.
  stm2 <- stm_counts(lag_matrix(seq2, N = N, alphabet = alphabet), update_exclusion = FALSE)[[3]]
  expect_equal(stm2$Ce, expected_stm_order2$Ce)
  expect_equal(stm2$C,  expected_stm_order2$C)

  # LTM trained on seq1 then seq2, one piece each, summed across pieces.
  train <- lag_matrix(c(seq1, seq2), N = N, alphabet = alphabet, Piece = rep(1:2, each = 4))
  ltm2  <- ltm_collapseGroups(ltm_counts(train, update_exclusion = FALSE))[[3]]
  ltm2[ , context_id := paste(ifelse(is.na(Lag2), "NA", Lag2), ifelse(is.na(Lag1), "NA", Lag1), sep = "_")]
  setorderv(ltm2, c("context_id", "Sym"))

  expected <- data.table::copy(expected_ltm_order2)[Ce > 0]
  setorderv(expected, c("context_id", "Event"))
  expect_equal(ltm2$context_id, expected$context_id)
  expect_equal(ltm2$Sym,        expected$Event)
  expect_equal(ltm2$Ce,         expected$Ce)
})
