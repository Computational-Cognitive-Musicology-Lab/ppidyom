# Random parameter sets: every parameter at a random value, a new draw each run,
# to find edge cases that single and pairwise (test-idyom-match.R) don't reach.
#
#   Sys.setenv(PPIDYOM_RANDOM_N = "20")         # number of sets; unset = skipped
#   Sys.setenv(PPIDYOM_RANDOM_SEED = "123")     # optional: repeat an earlier draw
#   devtools::test(filter = "idyom-random")
#
# The seed is in the test name (PPIDYOM_RANDOM_SEED). Results: tests/param_suite/results/random/.

skip_on_cran()
skip_if(Sys.getenv("PPIDYOM_RANDOM_N") == "", "set PPIDYOM_RANDOM_N to run")
skip_if_not_installed("humdrumR")
source(test_path("..", "param_suite", "compare.R"), local = TRUE, chdir = TRUE)
config <- load_config(test_path("..", "param_suite", "config.yaml"))
skip_if_not(idyom_available(config), "IDyOM Docker image not available")

seed <- as.integer(Sys.getenv("PPIDYOM_RANDOM_SEED", sample.int(1e6, 1)))

test_that(sprintf("seed %d: random parameter sets match IDyOM", seed), {
  withr::local_seed(seed)
  expect_match_idyom(compare_suite("random", test_datasets(config, "random"), n_random = as.integer(Sys.getenv("PPIDYOM_RANDOM_N")),
                                   config = config, verbose = FALSE))
})
