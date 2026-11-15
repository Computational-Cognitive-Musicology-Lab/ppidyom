# ─────────────────────────────────────────────────────────────────────────────
# compare.R — run ppidyom and IDyOM on the same parameter sets and compare.
# ─────────────────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({ library(data.table); library(yaml); library(humdrumR) })

# chdir = TRUE makes this folder the working directory while the file is sourced.
SUITE_DIR <- normalizePath(".")
if (!file.exists(file.path(SUITE_DIR, "config.yaml")))
  stop('source this file with chdir = TRUE: source("tests/param_suite/compare.R", chdir = TRUE)')
source(file.path(SUITE_DIR, "run_ppidyom.R"), local = environment())
source(file.path(SUITE_DIR, "run_idyom.R"),   local = environment())


load_config <- function(file = file.path(SUITE_DIR, "config.yaml")) {
  config <- yaml::read_yaml(file)
  config$root <- normalizePath(file.path(dirname(file), "..", ".."))       # repo root
  config
}

# list(name, symbols = one per event, piece = piece number per event)
load_data <- function(dataset_name, config) {
  dataset <- config$datasets[[dataset_name]]
  if (is.null(dataset)) stop("no dataset '", dataset_name, "' in config.yaml")
  pieces <- if (!is.null(dataset$sequences)) strsplit(unlist(dataset$sequences), "")
            else read_humdrum_data(dataset, config$root)
  list(name = dataset_name, symbols = unlist(pieces), piece = rep(seq_along(pieces), lengths(pieces)))
}

# One spine of the first n_pieces of a humdrum corpus, rests dropped; one character vector per piece
read_humdrum_data <- function(dataset, root) {
  symbol_regex <- dataset$symbol_regex %||% ".*"                   # part of each token to keep
  file_pattern <- dataset$file_pattern %||% ".*.hum"
  corpus <- withr::with_dir(root, readHumdrum(dataset$corpus, file_pattern))   # humdrumR needs the path relative to the repo root
  corpus[1:dataset$n_pieces] |>
    filter(Spine == dataset$spine_index & !Token %~% "^[0-9.]*r") |>        # rests: optional duration, then r
    mutate(Symbol = Token %~m% symbol_regex) |>
    with(unname(split(Symbol, Piece)))
}

# ── parameter sets ───────────────────────────────────────────────────────────
# A parameter set is a named list, parameter -> value, e.g. list(maxN = 1, dynamic.escape = "A", ...).
# "single":   change one parameter at a time, others at default
# "pairwise": change two parameters at a time, to test combination of parameters
# "random":   every parameter at a random value; n_random sets
# Skips duplicates (dynamic=FALSE with any dynamic.escape) and sets with both models off.
make_param_sets <- function(config, mode = c("single", "pairwise", "random"), params_to_vary = NULL, n_random = 20) {
  mode       <- match.arg(mode)
  param_info <- config$parameters
  baseline   <- lapply(param_info, `[[`, "default")
  params_to_vary <- Filter(function(param) length(param_info[[param]]$values) > 1, params_to_vary %||% names(param_info))

  # every combination of values of the given parameters, the rest at baseline
  vary <- function(params) {
    value_combos <- expand.grid(lapply(param_info[params], function(info) seq_along(info$values)))
    lapply(seq_len(nrow(value_combos)), function(combo) {
      param_set <- baseline
      for (i in seq_along(params)) param_set[params[i]] <- list(param_info[[params[i]]]$values[[value_combos[combo, i]]])
      param_set
    })
  }
  random_set <- function() {
    param_set <- baseline
    for (param in params_to_vary) param_set[param] <- list(sample(param_info[[param]]$values, 1)[[1]])
    param_set
  }
  param_sets <- switch(mode,
    single   = c(list(baseline), unlist(lapply(params_to_vary, vary), recursive = FALSE)),
    pairwise = c(list(baseline), unlist(lapply(combn(params_to_vary, 2, simplify = FALSE), vary), recursive = FALSE)),
    random   = replicate(n_random, random_set(), simplify = FALSE))

  param_sets <- lapply(param_sets, function(param_set) {
    for (model in c("dynamic", "schematic")) if (!isTRUE(param_set[[model]]))
      for (sub_param in grep(paste0("^", model, "\\."), names(param_set), value = TRUE))
        param_set[sub_param] <- list(baseline[[sub_param]])
    param_set
  })
  param_sets <- Filter(function(param_set) isTRUE(param_set$dynamic) || isTRUE(param_set$schematic), param_sets)
  param_sets[!duplicated(vapply(param_sets, param_set_label, "", config = config))]
}

# "baseline", or the parameters that differ from it: "maxN=1; dynamic.escape=A"
param_set_label <- function(param_set, config) {
  baseline <- lapply(config$parameters, `[[`, "default")
  changed  <- Filter(function(param) !identical(param_set[[param]], baseline[[param]]), names(param_set))
  if (!length(changed)) "baseline"
  else paste(changed, vapply(param_set[changed], format, ""), sep = "=", collapse = "; ")
}

# ── comparison ───────────────────────────────────────────────────────────────
compare_runs <- function(ppidyom_result, idyom_result, tolerance = 1e-3) {
  comparison <- list(verdict = NA_character_, ic_max_error = NA_real_, h_max_error = NA_real_,
                     pct_events_match = NA_real_, message = NA_character_)
  if (!is.null(ppidyom_result$error) || !is.null(idyom_result$error)) {
    comparison$verdict <- "ERROR"
    comparison$message <- paste(c(if (!is.null(ppidyom_result$error)) paste("ppidyom:", ppidyom_result$error),
                                  if (!is.null(idyom_result$error))   paste("IDyOM:", idyom_result$error)), collapse = " | ")
    return(comparison)
  }
  if (length(ppidyom_result$IC) != length(idyom_result$IC)) {
    comparison$verdict <- "MISMATCH"
    comparison$message <- sprintf("ppidyom gave %d events, IDyOM %d", length(ppidyom_result$IC), length(idyom_result$IC))
    return(comparison)
  }
  ic_error <- abs(ppidyom_result$IC - idyom_result$IC)
  h_error  <- abs(ppidyom_result$H  - idyom_result$H)
  within_tolerance <- function(error) is.finite(error) & error <= tolerance       # NA / Inf counts as wrong
  max_finite <- function(error) if (any(is.finite(error))) max(error[is.finite(error)]) else NA_real_
  comparison$ic_max_error     <- max_finite(ic_error)
  comparison$h_max_error      <- max_finite(h_error)
  n_not_finite <- sum(!is.finite(ic_error) | !is.finite(h_error))
  if (n_not_finite) comparison$message <- sprintf("%d of %d events have NA/Inf IC or H", n_not_finite, length(ic_error))
  comparison$pct_events_match <- round(100 * mean(within_tolerance(ic_error)), 1)
  comparison$verdict <- if (all(within_tolerance(ic_error)) && all(within_tolerance(h_error))) "MATCH"
                        else if (all(within_tolerance(ic_error))) "IC MATCH, H DIFFERS"
                        else "MISMATCH"
  comparison
}

# Run both on every parameter set of every dataset. One row per (dataset, parameter set).
# Also writes summary.csv, events.csv and calls.txt to <results_dir>/<mode>/ (see README).
compare_suite <- function(mode = "single", datasets = "toy", params_to_vary = NULL, only_values = NULL,
                          n_random = 20, config = load_config(), verbose = TRUE) {
  for (param in names(only_values)) {                          # only_values = list(maxN = 0:3): try only these
    info   <- config$parameters[[param]]
    values <- as.list(only_values[[param]])
    info$default <- values[[match(info$default, unlist(values), nomatch = 1)]]   # keep the default if still listed
    info$values  <- values
    config$parameters[[param]] <- info
  }
  param_sets <- make_param_sets(config, mode, params_to_vary, n_random)
  runs <- unlist(lapply(datasets, function(dataset_name) {
    data <- load_data(dataset_name, config)
    if (verbose) cat(sprintf("%s: %d events, %d parameter sets\n", dataset_name, length(data$symbols), length(param_sets)))
    idyom_results <- run_idyom(param_sets, data, config)
    lapply(seq_along(param_sets), function(i) {
      ppidyom_result <- run_ppidyom(param_sets[[i]], data, config)
      label <- param_set_label(param_sets[[i]], config)
      summary <- data.table(dataset   = dataset_name,
                            param_set = label,
                            as.data.table(compare_runs(ppidyom_result, idyom_results[[i]], config$settings$tolerance)),
                            ppidyom_seconds = round(ppidyom_result$seconds, 3),
                            idyom_seconds   = round(idyom_results[[i]]$seconds, 3),
                            ppidyom_call    = ppidyom_result$call,
                            idyom_call      = idyom_results[[i]]$call)
      if (verbose) cat(sprintf("  %-50s %s\n", label, summary$verdict))
      list(summary = summary, events = event_table(dataset_name, label, data, ppidyom_result, idyom_results[[i]]))
    })
  }), recursive = FALSE)
  results <- rbindlist(lapply(runs, `[[`, "summary"))
  save_results(results, rbindlist(lapply(runs, `[[`, "events")), file.path(config$root, config$settings$results_dir, mode))
  results
}

# One row per event: both models' IC and H side by side
event_table <- function(dataset_name, label, data, ppidyom_result, idyom_result) {
  if (!is.null(ppidyom_result$error) || !is.null(idyom_result$error) || length(ppidyom_result$IC) != length(data$symbols)) return(NULL)
  data.table(dataset = dataset_name, param_set = label, piece = data$piece,
             position = ave(data$piece, data$piece, FUN = seq_along), symbol = data$symbols,
             ppidyom_IC = ppidyom_result$IC, idyom_IC = round(idyom_result$IC, 3),
             ppidyom_H  = ppidyom_result$H,  idyom_H  = round(idyom_result$H, 3),
             IC_error   = round(abs(ppidyom_result$IC - idyom_result$IC), 3))
}

save_results <- function(results, events, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  calls <- sprintf("── [%s] %s: %s\nppidyom: %s\nIDyOM:\n%s\n", results$dataset, results$param_set, results$verdict,
                   results$ppidyom_call, results$idyom_call)
  writeLines(calls, file.path(output_dir, "calls.txt"))
  fwrite(copy(results)[, idyom_call := gsub("\\s*\n\\s*", " ", idyom_call)], file.path(output_dir, "summary.csv"))
  fwrite(events, file.path(output_dir, "events.csv"))
}

# Datasets a test mode runs on (settings$test_datasets); a corpus not on disk is left out
test_datasets <- function(config, mode) {
  Filter(function(dataset_name) {
    corpus <- config$datasets[[dataset_name]]$corpus
    is.null(corpus) || dir.exists(file.path(config$root, corpus))
  }, config$settings$test_datasets[[mode]])
}

# One expectation per parameter set, so each failure names its parameter set
expect_match_idyom <- function(results) {
  testthat::expect_gt(nrow(results), 0)
  messages <- sprintf("[%s] %s: %s", results$dataset, results$param_set,
                      ifelse(results$verdict == "ERROR", results$message,
                             sprintf("%s (max IC error %.3g)", results$verdict, results$ic_max_error)))
  for (i in seq_len(nrow(results))) testthat::expect(results$verdict[i] == "MATCH", messages[i], trace_env = parent.frame())
}
