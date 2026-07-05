library(testthat)
library(data.table)

# ══════════════════════════════════════════════════════════════════════════════
# IDyOM reference comparison
#
# Compares ppidyom IC/entropy against ground-truth IDyOM (Common Lisp) output.
# For STM configs, also validates the three-way ppidyom ↔ ppm ↔ IDyOM match.
#
# PREREQUISITES — run once before this test suite:
#   bash inst/validation/run_idyom_docker.sh
# (or: python3 inst/validation/generate_idyom_reference.py with local IDyOM)
#
# The fixture CSV is read-only; adding new parameter combinations means
# re-running the Python script — no R changes needed.
# ══════════════════════════════════════════════════════════════════════════════

FIXTURE  <- test_path("fixtures", "idyom_reference_ic.csv")
SKIP_MSG <- paste(
  "IDyOM reference fixture not found.",
  "Run: bash inst/validation/run_idyom_docker.sh",
  "(see README_DEV.md §4 for details)"
)
TOLERANCE <- 1e-4   # IDyOM (double-float Lisp) vs R float-precision gap

# ── Test sequences — must match generate_idyom_reference.py ──────────────────
x1            <- c("A","B","A","C","A","B","A","C","A")
x2            <- c("B","A","B","C","A")
ltm_train_seq <- c("A","B","C","A","B","C","A","C","B")
alphabet      <- c("A","B","C")
test_seqs     <- list(x1 = x1, x2 = x2)
N             <- 3L

# IDyOM escape code  →  ppidyom escape name  (used in predict_sequence())
# Note: IDyOM's AX is invoked as :x (not :ax); the fixture uses "x" accordingly.
idyom2pp  <- c(a = "A", b = "B", c = "C", d = "D", x = "X")

# ppm package uses "ax" for AX; IDyOM fixture uses "x".  Map here.
idyom2ppm <- c(a = "a", b = "b", c = "c", d = "d", x = "ax")

# ── Helpers ───────────────────────────────────────────────────────────────────

make_model <- function(cfg) {
  ppidyom$new(
    N                    = N,
    alphabet             = alphabet,
    stm_exclusion        = as.logical(cfg$stm_exclusion),
    ltm_exclusion        = as.logical(cfg$ltm_exclusion),
    stm_update_exclusion = as.logical(cfg$stm_update_exclusion),
    ltm_update_exclusion = as.logical(cfg$ltm_update_exclusion),
    # IDyOM does not include beginning-of-sequence positions in LTM counts.
    # Set ltm_start_token=FALSE to match that behaviour.
    # See vignette("implementation-discrepancy") for details.
    ltm_start_token      = FALSE
  )
}

# Run ppidyom and return a data.table of (IC, Entropy) for observed events only.
# idyom_base=TRUE matches IDyOM's order-(-1) distribution (see vignette
# "implementation-discrepancy" for details on the base-distribution difference).
ppidyom_predict <- function(x, cfg) {
  model <- make_model(cfg)
  if (cfg$model != "stm") model$train_sequence(ltm_train_seq)
  res <- model$predict_sequence(
    x,
    model_type = cfg$model,
    ppm_type   = "interpolation",
    stm_lambda = idyom2pp[[cfg$stm_escape]],
    ltm_lambda = idyom2pp[[cfg$ltm_escape]],
    b          = 7,
    idyom_base = TRUE
  )
  # Filter to observed events (result has one row per symbol per timestep)
  observed <- data.table(index = seq_along(x), Event = x)
  res[observed, on = .(index, Event)]
}

# Run ppm package STM and return IC vector (STM comparison only).
ppm_stm_ic <- function(x, cfg) {
  mod <- ppm::new_ppm_simple(
    order_bound            = N,
    alphabet_levels        = alphabet,
    escape                 = idyom2ppm[[cfg$stm_escape]],
    shortest_deterministic = FALSE,
    exclusion              = as.logical(cfg$stm_exclusion),
    update_exclusion       = as.logical(cfg$stm_update_exclusion)
  )
  ppm::model_seq(mod, factor(x, levels = alphabet))$information_content
}

# ── Guard: report clearly if the fixture is missing ──────────────────────────
test_that("IDyOM reference fixture exists", {
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
    se  <- cfg$stm_escape;  le  <- cfg$ltm_escape
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
        "model=%s seq=%s se_esc=%s se=%s su=%s le_esc=%s le=%s lu=%s",
        m, sl, se, as.integer(sex), as.integer(seu),
        le, as.integer(lex), as.integer(leu)
      )

      # ── ppidyom vs IDyOM ─────────────────────────────────────────────────
      test_that(paste("ppidyom vs IDyOM:", label), {
        pp <- ppidyom_predict(x, cfg)
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

      # ── ppidyom vs ppm (STM only — ppm package has no LTM) ───────────────
      # Only compare against ppm when stm_exclusion=TRUE: that is the only
      # setting where all three implementations agree on the base distribution.
      # When exclusion=FALSE, ppidyom(idyom_base=TRUE) uses 1/|alphabet| for
      # the order-(-1) prior (matching IDyOM), while ppm always uses the
      # shrinking denominator.  See vignette("implementation-discrepancy").
      if (m == "stm" && as.logical(sex)) {
        test_that(paste("ppidyom vs ppm (STM):", label), {
          skip_if_not(
            requireNamespace("ppm", quietly = TRUE),
            "ppm package not installed (devtools::install_github('pmcharrison/ppm'))"
          )
          pp     <- ppidyom_predict(x, cfg)
          ic_ppm <- ppm_stm_ic(x, cfg)
          expect_equal(
            pp$IC, ic_ppm,
            tolerance = TOLERANCE,
            label = paste("IC vs ppm", label)
          )
        })
      }
    }
  }
}
