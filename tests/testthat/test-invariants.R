test_that("probabilities for observed events are in (0, 1]", {

  set.seed(42)
  alphabet <- LETTERS[1:5]
  x <- sample(alphabet, 50, replace = TRUE)
  order <- 3

  counts <- count_tables(x, N = order, alphabet = alphabet, model_type = "stm")
  result <- ppm_interpolated(x, N = order, alphabet = alphabet,
                             order_counts = counts$stm, exclusion = TRUE)

  observed <- result[data.table(index = seq_along(x), Event = x),
                     on = .(index, Event)]
  expect_true(all(observed$P > 0))
  expect_true(all(observed$P <= 1))
})

test_that("probability distributions sum to 1 at each timestep", {

  alphabet <- c("I", "IV", "V")
  x <- c("I", "IV", "V", "I", "IV", "V")
  order <- 3

  counts <- count_tables(x, N = order, alphabet = alphabet, model_type = "stm")
  result <- ppm_interpolated(x, N = order, alphabet = alphabet,
                             order_counts = counts$stm, exclusion = TRUE)

  sums <- result[, .(total = sum(P)), by = index]
  expect_true(all(abs(sums$total - 1) < 1e-9))
})
