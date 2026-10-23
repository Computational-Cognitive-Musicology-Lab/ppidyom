library(testthat)
library(data.table)

# ══════════════════════════════════════════════════════════════════════════════
# IDyOM reference comparison: shortest-deterministic selection
#
# Compares lag_matrix(N = NULL) → stm_counts() / ltm_counts() →
# shortest_deterministic() → ppidyom_interpolation() against IDyOM with
# :order-bound nil (interpolated STM and LTM). Bounded runs are covered by
# test-idyom-comparison.R.
#
# PREREQUISITES — run once before this test suite:
#   bash inst/validation/run_idyom_docker.sh generate_idyom_sd_reference.py
#
# The fixture CSV is read-only; adding new parameter combinations means
# re-running the Python script — no R changes needed.
# ══════════════════════════════════════════════════════════════════════════════

FIXTURE  <- test_path("fixtures", "idyom_reference_sd.csv")
SKIP_MSG <- paste(
  "IDyOM shortest-deterministic fixture not found.",
  "Run: bash inst/validation/run_idyom_docker.sh generate_idyom_sd_reference.py"
)
TOLERANCE <- 1e-4   # IDyOM (double-float Lisp) vs R float-precision gap

# ── Test sequences — must match generate_idyom_sd_reference.py ───────────────
x1             <- c("A","B","A","C","A","B","A","C","A")
x2             <- c("B","A","B","C","A")
x3             <- c("A","B","C","A","B","C","A","B","A","C","A","B","C","A","B","C")
ltm_train_seq  <- c("A","B","C","A","B","C","A","C","B")
ltm_train_seq2 <- c("B","C","A","B","A","C","A","B","C")
alphabet       <- c("A","B","C")
test_seqs      <- list(x1 = x1, x2 = x2, x3 = x3)

# All LTM models are pretrained on both training sequences (one piece each).
train_seqs <- list(ltm_train_seq, ltm_train_seq2)

# IDyOM escape code → ppidyom escape function.
# Note: IDyOM's AX is invoked as :x (not :ax); the fixture uses "x" accordingly.
idyom2escape <- list(a = escape_A, b = escape_B, c = escape_C, d = escape_D, x = escape_AX)

# ── Helpers ───────────────────────────────────────────────────────────────────

# Count tables for one model, with shortest-deterministic selection applied.
sd_counts <- function(x, cfg) {
  if (cfg$model == "stm") {
    lm     <- lag_matrix(x, N = NULL, alphabet = alphabet)
    counts <- stm_counts(lm, update_exclusion = as.logical(cfg$stm_update_exclusion))
  } else {
    # There is no train/test entry point for N = NULL yet. The bound must cover
    # test contexts that occur in training, so compute it from both and mark the
    # training lag matrix as a shortest-deterministic run.
    N_ltm <- effective_order_bound(c(unlist(train_seqs), x))
    train <- lag_matrix(unlist(train_seqs), N = N_ltm, alphabet = alphabet,
                        Piece = rep(seq_along(train_seqs), lengths(train_seqs)))
    par <- modelPar(train)
    par$shortestDeterministic <- TRUE
    setattr(train, "modelPar", par)

    # IDyOM does not include beginning-of-sequence positions in LTM counts.
    # Set ltm_start_token = FALSE to match that behaviour.
    counts <- ltm_counts(train,
                         update_exclusion = as.logical(cfg$ltm_update_exclusion),
                         ltm_start_token  = FALSE)
    counts <- ltm2dynamic_counts(counts, lag_matrix(x, N = N_ltm, alphabet = alphabet))
  }
  shortest_deterministic(counts)
}

# Run the pipeline and return a data.table of (IC, Entropy), one row per event.
# idyom_base = TRUE matches IDyOM's order-(-1) distribution.
sd_predict <- function(x, cfg) {
  side <- if (cfg$model == "stm") "stm" else "ltm"
  P <- ppidyom_interpolation(
    sd_counts(x, cfg),
    escape_func = idyom2escape[[cfg[[paste0(side, "_escape")]]]],
    exclusion   = as.logical(cfg[[paste0(side, "_exclusion")]]),
    idyom_base  = TRUE
  )
  data.table(IC = -log2(get_p(P)), Entropy = get_H(P))
}

# ── Guard: report clearly if the fixture is missing ──────────────────────────
test_that("IDyOM shortest-deterministic fixture exists", {
  skip_if_not(file.exists(FIXTURE), SKIP_MSG)
  expect_true(TRUE)
})

# ── Main comparison block — only entered if the fixture is present ────────────
if (file.exists(FIXTURE)) {

  ref <- fread(FIXTURE)

  param_cols <- c("model", "stm_escape", "ltm_escape",
                  "stm_exclusion", "stm_update_exclusion",
                  "ltm_exclusion", "ltm_update_exclusion")
  configs <- unique(ref[, ..param_cols])

  for (i in seq_len(nrow(configs))) {
    cfg <- as.list(configs[i])

    # Unpack to plain variables so data.table j-expressions don't confuse them
    # with column names when filtering ref below.
    m   <- cfg$model
    se  <- cfg$stm_escape;    le  <- cfg$ltm_escape
    sex <- cfg$stm_exclusion; seu <- cfg$stm_update_exclusion
    lex <- cfg$ltm_exclusion; leu <- cfg$ltm_update_exclusion

    for (sl in names(test_seqs)) {
      x <- test_seqs[[sl]]

      ref_rows <- ref[
        model == m & seq_label == sl &
        stm_escape == se & ltm_escape == le &
        stm_exclusion == sex & stm_update_exclusion == seu &
        ltm_exclusion == lex & ltm_update_exclusion == leu
      ][order(index)]

      label <- sprintf(
        "model=%s seq=%s se_esc=%s se=%s su=%s le_esc=%s le=%s lu=%s order-bound=nil",
        m, sl, se, as.integer(sex), as.integer(seu),
        le, as.integer(lex), as.integer(leu)
      )

      test_that(paste("shortest deterministic vs IDyOM:", label), {
        pp <- sd_predict(x, cfg)
        expect_equal(
          pp$IC,      ref_rows$IC_idyom,
          tolerance = TOLERANCE,
          label = paste("IC",      label)
        )
        expect_equal(
          pp$Entropy, ref_rows$H_idyom,
          tolerance = TOLERANCE,
          label = paste("Entropy", label)
        )
      })
    }
  }
}
