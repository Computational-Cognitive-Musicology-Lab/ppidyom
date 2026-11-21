# Does ppidyom() match IDyOM? Every parameter set from tests/param_suite/config.yaml
# is run through both, and each one is an expectation, so a failure names its parameter set.
#
#   devtools::test(filter = "idyom-match")            # each parameter on its own
#   Sys.setenv(PPIDYOM_PAIRWISE = "true")             # also run the pairwise sets (slower)
#   devtools::test(filter = "idyom-match")            # + every pair of parameters
#
# Needs the IDyOM Docker image (docker build -t ppidyom-idyom-validation inst/validation).
# Datasets: settings$test_datasets in config.yaml. Results: tests/param_suite/results/<mode>/.
# Each run prints a Markdown table per dataset: matching sets, events matching, and ppidyom vs IDyOM seconds.

skip_on_cran()
skip_if_not_installed("humdrumR")
source(test_path("..", "param_suite", "compare.R"), local = TRUE, chdir = TRUE)
config <- load_config(test_path("..", "param_suite", "config.yaml"))
skip_if_not(idyom_available(config), "IDyOM Docker image not available")

test_that("each parameter on its own matches IDyOM", {
  results <- compare_suite("single", test_datasets(config, "single"), config = config, verbose = FALSE)
  report_summary(results, "single")
  expect_match_idyom(results)
})

test_that("each pair of parameters matches IDyOM", {
  skip_if_not(identical(Sys.getenv("PPIDYOM_PAIRWISE"), "true"), "set PPIDYOM_PAIRWISE=true to run")
  results <- compare_suite("pairwise", test_datasets(config, "pairwise"), config = config, verbose = FALSE)
  report_summary(results, "pairwise")
  expect_match_idyom(results)
})
