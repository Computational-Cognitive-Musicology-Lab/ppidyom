library(testthat)
library(data.table)

# ══════════════════════════════════════════════════════════════════════════════
# IDyOM random-combination fuzz test — disabled by default (slow, needs Docker).
#
# This test draws N random combinations across every axis at once and checks
# each against a LIVE IDyOM run (same Docker image as inst/validation/), rather
# than a pre-generated fixture.
# It explores combinations the fixture potentially misses.
#
# To run:
#   Sys.setenv(RUN_IDYOM_FUZZ_TESTS = "true")
#   devtools::test(filter = "idyom-random-fuzz")
#
# Tunable via env vars (all optional):
#   IDYOM_FUZZ_N           - number of random trials (default 50)
#   IDYOM_FUZZ_SEED        - RNG seed (random by default -- a fresh slice of the
#                            parameter space every run; printed at test time, so set
#                            it explicitly to reproduce a specific failure)
#   IDYOM_FUZZ_ORDER_BOUND - "3" (default), "nil" or "random" (per trial).
#                            "nil" runs IDyOM with :order-bound nil against the optimized
#                            pipeline with N = NULL (shortest deterministic), which covers
#                            interpolated STM and LTM.
#
# With order bound 3, ppidyomModel is checked on every trial, and the optimized pipeline
# (lag_matrix() -> stm_counts()/ltm_counts() -> ppidyom_interpolation()) is also checked
# on interpolated STM and LTM trials, against the same IDyOM run.
# ══════════════════════════════════════════════════════════════════════════════

DOCKER_IMG <- "ppidyom-idyom-validation"
TOLERANCE  <- 1e-4

skip_reason <- NULL
if (Sys.getenv("RUN_IDYOM_FUZZ_TESTS") != "true") {
  skip_reason <- paste(
    "Opt-in test, skipped by default (slow, needs Docker).",
    'Run: Sys.setenv(RUN_IDYOM_FUZZ_TESTS = "true")'
  )
} else if (Sys.which("docker") == "") {
  skip_reason <- "Docker not found on PATH."
} else if (!nzchar(paste(system2("docker", c("images", "-q", DOCKER_IMG),
                                  stdout = TRUE, stderr = FALSE), collapse = ""))) {
  # `docker images -q`, as in run_idyom_docker.sh: `docker image inspect` intermittently
  # reports existing images as missing under Docker Desktop, which would skip every trial.
  skip_reason <- paste(
    "Docker image", DOCKER_IMG, "not built.",
    "Run: bash inst/validation/run_idyom_docker.sh"
  )
}

test_that("IDyOM random-fuzz prerequisites", {
  skip_if_not(is.null(skip_reason), skip_reason)
  expect_true(TRUE)
})

if (is.null(skip_reason)) {

  # ── Shared toy corpus (same as test-idyom-comparison.R) ─────────────────────
  alphabet   <- c("A", "B", "C")
  pitch_map  <- c(A = 60, B = 62, C = 64)
  train_seqs <- list(c("A","B","C","A","B","C","A","C","B"),
                      c("B","C","A","B","A","C","A","B","C"))
  test_seqs  <- list(x1 = c("A","B","A","C","A","B","A","C","A"),
                      x2 = c("B","A","B","C","A"),
                      # x3 repeats a phrase, so long contexts are seen (matters for :order-bound nil)
                      x3 = c("A","B","C","A","B","C","A","B","A","C","A","B","C","A","B","C"))
  N          <- 3L
  idyom2pp   <- c(a = "A", b = "B", c = "C", d = "D", x = "X")

  # ── ppidyom side ─────────────────────────────────────────────────────────────
  ppidyom_predict <- function(x, cfg) {
    model <- ppidyomModel$new(
      N = N, alphabet = alphabet,
      stm_exclusion = cfg$stm_exclusion, ltm_exclusion = cfg$ltm_exclusion,
      stm_update_exclusion = cfg$stm_update_exclusion,
      ltm_update_exclusion = cfg$ltm_update_exclusion,
      ltm_start_token = FALSE
    )
    if (cfg$model != "stm") for (ts in train_seqs) model$train_sequence(ts)
    res <- model$predict_sequence(
      x, model_type = cfg$model,
      ppm_type = if (cfg$mixtures) "interpolation" else "backoff",
      stm_lambda = cfg$stm_escape, ltm_lambda = cfg$ltm_escape,
      b = cfg$b, idyom_base = TRUE
    )
    observed <- data.table(index = seq_along(x), Event = x)
    res[observed, on = .(index, Event)][, .(index, Event, P, IC, Entropy)]
  }

  # ── ppidyom side, optimized pipeline (interpolated STM / LTM) ───────────────
  # lag_matrix() -> stm_counts() / ltm_counts() -> shortest_deterministic() -> ppidyom_interpolation().
  # N = NULL is :order-bound nil (shortest deterministic); a number is a fixed order bound.
  pp2escape <- list(A = escape_A, B = escape_B, C = escape_C, D = escape_D, X = escape_AX)

  ppidyom_predict_optimized <- function(x, cfg, N) {
    if (cfg$model == "stm") {
      counts <- stm_counts(lag_matrix(x, N = N, alphabet = alphabet), update_exclusion = cfg$stm_update_exclusion)
    } else {
      # No train/test entry point for N = NULL yet: the bound must cover test contexts
      # that occur in training, so compute it from both and mark the training lag matrix.
      N_ltm <- if (is.null(N)) effective_order_bound(c(unlist(train_seqs), x)) else N
      train <- lag_matrix(unlist(train_seqs), N = N_ltm, alphabet = alphabet,
                          Piece = rep(seq_along(train_seqs), lengths(train_seqs)))
      if (is.null(N)) {
        par <- modelPar(train)
        par$shortestDeterministic <- TRUE
        setattr(train, "modelPar", par)
      }
      counts <- ltm_counts(train, update_exclusion = cfg$ltm_update_exclusion, ltm_start_token = FALSE)
      counts <- ltm2dynamic_counts(counts, lag_matrix(x, N = N_ltm, alphabet = alphabet))
    }
    side <- if (cfg$model == "stm") "stm" else "ltm"
    P <- ppidyom_interpolation(
      shortest_deterministic(counts),   # no-op for a fixed N
      escape_func = pp2escape[[cfg[[paste0(side, "_escape")]]]],
      exclusion   = cfg[[paste0(side, "_exclusion")]],
      idyom_base  = TRUE
    )
    data.table(index = seq_along(x), Event = x, IC = -log2(get_p(P)), Entropy = get_H(P))
  }

  # ── Live IDyOM side (writes a temp .lisp, runs it in the validation image) ──
  lisp_bool <- function(v) if (isTRUE(v)) "t" else "nil"

  run_idyom_live <- function(x, cfg, work_dir) {
    inputs  <- file.path(work_dir, "inputs")
    outputs <- file.path(work_dir, "outputs")
    dir.create(inputs, recursive = TRUE, showWarnings = FALSE)
    dir.create(outputs, recursive = TRUE, showWarnings = FALSE)

    write_txt <- function(seqs, path) {
      lines <- vapply(seqs, function(s) paste(pitch_map[s], collapse = " "), character(1))
      writeLines(lines, path)
    }
    write_txt(train_seqs, file.path(inputs, "train.txt"))
    write_txt(list(x), file.path(inputs, "test.txt"))

    lisp <- sprintf(
      '(start-idyom)
(idyom-db:import-data :txt "/work/inputs/train.txt" "TRAIN_DATASET" 1001)
(idyom-db:import-data :txt "/work/inputs/test.txt" "TEST_DATASET" 2002)
(mvs:set-ltm-stm-bias %s)
(idyom:idyom 2002 \'(cpitch) \'(cpitch) :k 1 :models :%s :detail 3 :pretraining-ids \'(1001)
:stmo \'(:escape :%s :order-bound %s :exclusion %s :update-exclusion %s :mixtures %s)
:ltmo \'(:escape :%s :order-bound %s :exclusion %s :update-exclusion %s :mixtures %s)
:output-path "/work/outputs" :overwrite nil :use-resampling-set-cache? nil :use-ltms-cache? nil)
(idyom-db:delete-dataset 1001)
(idyom-db:delete-dataset 2002)
(quit)',
      cfg$b, cfg$model,
      tolower(cfg$stm_escape), cfg$order_bound, lisp_bool(cfg$stm_exclusion), lisp_bool(cfg$stm_update_exclusion),
      lisp_bool(cfg$mixtures),
      tolower(cfg$ltm_escape), cfg$order_bound, lisp_bool(cfg$ltm_exclusion), lisp_bool(cfg$ltm_update_exclusion),
      lisp_bool(cfg$mixtures)
    )
    lisp_path <- file.path(work_dir, "compute.lisp")
    writeLines(lisp, lisp_path)

    rc <- system2("docker", c(
      "run", "--rm", "-v", paste0(work_dir, ":/work"), "-w", "/work", DOCKER_IMG,
      "sbcl", "--dynamic-space-size", "8192", "--noinform", "--load", "/work/compute.lisp"
    ), stdout = FALSE, stderr = FALSE)

    dat_files <- list.files(outputs, pattern = "\\.dat$", full.names = TRUE)
    if (rc != 0 || length(dat_files) == 0) stop("IDyOM run failed (rc=", rc, ")")

    df <- fread(dat_files[1])
    setorder(df, note.id)
    ic_col   <- if ("cpitch.ic" %in% names(df)) "cpitch.ic" else "ic"
    ent_col  <- if ("cpitch.entropy" %in% names(df)) "cpitch.entropy" else "entropy"
    prob_col <- if ("cpitch.probability" %in% names(df)) "cpitch.probability" else "probability"
    data.table(
      index = seq_len(nrow(df)), Event = x,
      P_idyom = df[[prob_col]], IC_idyom = df[[ic_col]], H_idyom = df[[ent_col]]
    )
  }

  # ── Draw N random combinations ───────────────────────────────────────────────
  # Seed is random by default (a fresh slice of the parameter space every run)
  # unless IDYOM_FUZZ_SEED pins it -- e.g. to reproduce a specific failure.
  n_trials <- as.integer(Sys.getenv("IDYOM_FUZZ_N", "50"))
  seed_env <- Sys.getenv("IDYOM_FUZZ_SEED", "")
  seed     <- if (nzchar(seed_env)) as.integer(seed_env) else sample.int(.Machine$integer.max, 1)
  cat(sprintf(
    "[idyom-random-fuzz] seed = %d (rerun with Sys.setenv(IDYOM_FUZZ_SEED = \"%d\") to reproduce)\n",
    seed, seed
  ))
  set.seed(seed)

  models   <- c("stm", "ltm", "ltm+", "both", "both+")
  sd_models <- c("stm", "ltm")   # what the optimized pipeline covers (interpolated)
  escapes  <- names(idyom2pp)
  bs       <- c(1, 3, 7, 10)
  order_bound_env <- Sys.getenv("IDYOM_FUZZ_ORDER_BOUND", "3")
  stopifnot(order_bound_env %in% c("3", "nil", "random"))

  configs <- lapply(seq_len(n_trials), function(i) {
    order_bound <- if (order_bound_env == "random") sample(c("3", "nil"), 1) else order_bound_env
    cfg <- list(
      order_bound = order_bound,
      model = sample(if (order_bound == "nil") sd_models else models, 1),
      stm_escape = idyom2pp[[sample(escapes, 1)]], ltm_escape = idyom2pp[[sample(escapes, 1)]],
      stm_exclusion = sample(c(TRUE, FALSE), 1), ltm_exclusion = sample(c(TRUE, FALSE), 1),
      stm_update_exclusion = sample(c(TRUE, FALSE), 1), ltm_update_exclusion = sample(c(TRUE, FALSE), 1),
      mixtures = sample(c(TRUE, FALSE), 1), b = sample(bs, 1),
      seq_label = sample(names(test_seqs), 1)
    )
    if (order_bound == "nil") cfg$mixtures <- TRUE   # interpolation only
    cfg
  })

  for (i in seq_along(configs)) {
    cfg <- configs[[i]]
    label <- sprintf(
      "#%02d ob=%s model=%s se=%s le=%s sex=%s lex=%s seu=%s leu=%s mix=%s b=%s seq=%s",
      i, cfg$order_bound, cfg$model, cfg$stm_escape, cfg$ltm_escape,
      as.integer(cfg$stm_exclusion), as.integer(cfg$ltm_exclusion),
      as.integer(cfg$stm_update_exclusion), as.integer(cfg$ltm_update_exclusion),
      as.integer(cfg$mixtures), cfg$b, cfg$seq_label
    )

    test_that(paste("random fuzz:", label), {
      x    <- test_seqs[[cfg$seq_label]]
      pp   <- if (cfg$order_bound == "nil") ppidyom_predict_optimized(x, cfg, NULL) else ppidyom_predict(x, cfg)
      work <- tempfile("idyom_fuzz_")
      dir.create(work)
      on.exit(unlink(work, recursive = TRUE), add = TRUE)
      idy  <- run_idyom_live(x, cfg, work)
      merged <- pp[idy, on = .(index, Event)]

      expect_equal(merged$IC, merged$IC_idyom, tolerance = TOLERANCE, label = paste("IC", label))
      expect_equal(merged$Entropy, merged$H_idyom, tolerance = TOLERANCE, label = paste("Entropy", label))

      # Fixed order bound: also check the optimized pipeline where it applies (same IDyOM run).
      if (cfg$order_bound == "3" && cfg$model %in% sd_models && cfg$mixtures) {
        opt <- ppidyom_predict_optimized(x, cfg, N)[idy, on = .(index, Event)]
        expect_equal(opt$IC, opt$IC_idyom, tolerance = TOLERANCE, label = paste("optimized IC", label))
        expect_equal(opt$Entropy, opt$H_idyom, tolerance = TOLERANCE, label = paste("optimized Entropy", label))
      }
    })
  }
}
