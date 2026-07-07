library(testthat)
library(data.table)

skip_if_not_installed("ppm")   # ppm is required for this comparison suite

# All ppidyom calls here use the default idyom_base=FALSE, which matches
# Harrison's ppm package (both use the shrinking-denominator order-(-1) base).
# See vignette("implementation-discrepancy") for why ppm and IDyOM differ
# on exclusion=FALSE configurations.

# ── Helpers ───────────────────────────────────────────────────────────────────

# ppm method strings: ppidyom uses "A"/"B"/"C"/"D"/"X", ppm uses "a"/"b"/"c"/"d"/"ax"
ppm_escape_name <- c(A = "a", B = "b", C = "c", D = "d", X = "ax")

# Run ppidyom STM-interpolated and return IC for the observed sequence.
ppidyom_stm_ic <- function(x, alphabet, N, method,
                            exclusion = FALSE, update_exclusion = FALSE) {
  counts  <- count_tables(x, N = N, alphabet = alphabet, model_type = "stm",
                          stm_update_exclusion = update_exclusion,
                          ltm_update_exclusion = FALSE)
  result  <- ppm_interpolated(x, N = N, alphabet = alphabet,
                               order_counts  = counts$stm,
                               escape_func   = escape_functions[[method]],
                               exclusion     = exclusion)
  result[data.table(index = seq_along(x), Event = x), on = .(index, Event)]$IC
}

# Run Harrison's ppm package (new_ppm_simple) and return IC for the sequence.
# IDyOM equivalent (Common Lisp):
#   (idyom:idyom <db-id> '(cpitch) '(cpitch)
#     :texture :melody :models :stm :k :full :detail 3
#     :stmo '(:escape <method> :order-bound <N>
#             :exclusion <t/nil> :update-exclusion <t/nil>))
ppm_stm_ic <- function(x, alphabet, N, method,
                        exclusion = FALSE, update_exclusion = FALSE) {
  mod <- ppm::new_ppm_simple(
    order_bound           = N,
    alphabet_levels       = alphabet,
    escape                = ppm_escape_name[[method]],
    shortest_deterministic = FALSE,
    exclusion             = exclusion,
    update_exclusion      = update_exclusion
  )
  res <- ppm::model_seq(mod, factor(x, levels = alphabet))
  res$information_content
}

# Compare ppidyom vs ppm and report a diff table if they disagree.
compare_ic <- function(ppidyom_ic, ppm_ic, tolerance = 1e-5, label = "") {
  diff <- abs(ppidyom_ic - ppm_ic)
  if (any(diff > tolerance, na.rm = TRUE)) {
    cat(sprintf("\n[%s] Max IC diff: %.8f at positions: %s\n",
                label, max(diff, na.rm = TRUE),
                paste(which(diff > tolerance), collapse = ", ")))
    cat("ppidyom IC:", round(ppidyom_ic, 6), "\n")
    cat("ppm     IC:", round(ppm_ic,     6), "\n")
  }
  expect_equal(ppidyom_ic, ppm_ic, tolerance = tolerance, label = label)
}

# ── Shared test data ──────────────────────────────────────────────────────────

x1       <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")   # longer, more context
x2       <- c("B", "A", "B", "C", "A")                        # shorter, varied start
alphabet <- c("A", "B", "C")

# ═══════════════════════════════════════════════════════════════════════════════
# 1. ESCAPE METHOD — vary one at a time from baseline
#    Baseline: N=3, exclusion=FALSE, update_exclusion=FALSE
# ═══════════════════════════════════════════════════════════════════════════════

# IDyOM:  :stmo '(:escape :c :order-bound 3 :exclusion nil :update-exclusion nil)
# ppm:    new_ppm_simple(escape="c", exclusion=FALSE, update_exclusion=FALSE)
test_that("method C (baseline) matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "C"),
      ppm_stm_ic   (x, alphabet, N = 3, method = "C"),
      label = "C"
    )
  }
})

# IDyOM:  :stmo '(:escape :a :order-bound 3 :exclusion nil :update-exclusion nil)
test_that("method A matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "A"),
      ppm_stm_ic   (x, alphabet, N = 3, method = "A"),
      label = "A"
    )
  }
})

# IDyOM:  :stmo '(:escape :b :order-bound 3 :exclusion nil :update-exclusion nil)
# NOTE: method B gives zero probability to singletons (Ce=1); probabilities
# may not sum to 1 before normalization.
test_that("method B matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "B"),
      ppm_stm_ic   (x, alphabet, N = 3, method = "B"),
      label = "B"
    )
  }
})

# IDyOM:  :stmo '(:escape :d :order-bound 3 :exclusion nil :update-exclusion nil)
# NOTE: method D subtracts 0.5 from each Ce (absolute discounting).
test_that("method D matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "D"),
      ppm_stm_ic   (x, alphabet, N = 3, method = "D"),
      label = "D"
    )
  }
})

# IDyOM:  :stmo '(:escape :ax :order-bound 3 :exclusion nil :update-exclusion nil)
# NOTE: AX (method A+, Moffat 1990) uses singleton count t1 in the escape
# formula.  The escape function is esc=(t1+1)/(C+t+1).  The sum of seen
# probabilities plus escape may be <1 when t>t1; renormalization compensates.
# This test may fail if ppm-AX uses a different variant of the formula.
test_that("method AX matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "X"),
      ppm_stm_ic   (x, alphabet, N = 3, method = "X"),
      label = "AX"
    )
  }
})

# ═══════════════════════════════════════════════════════════════════════════════
# 2. EXCLUSION — vary stm_exclusion (method C, update_exclusion=FALSE)
# ═══════════════════════════════════════════════════════════════════════════════

# IDyOM:  :stmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion nil)
test_that("exclusion=TRUE matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "C", exclusion = TRUE),
      ppm_stm_ic   (x, alphabet, N = 3, method = "C", exclusion = TRUE),
      label = "C + exclusion"
    )
  }
})

# ═══════════════════════════════════════════════════════════════════════════════
# 3. UPDATE EXCLUSION — vary stm_update_exclusion (method C, exclusion=FALSE)
# ═══════════════════════════════════════════════════════════════════════════════

# IDyOM:  :stmo '(:escape :c :order-bound 3 :exclusion nil :update-exclusion t)
test_that("update_exclusion=TRUE matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "C", update_exclusion = TRUE),
      ppm_stm_ic   (x, alphabet, N = 3, method = "C", update_exclusion = TRUE),
      label = "C + update_exclusion"
    )
  }
})

# IDyOM:  :stmo '(:escape :c :order-bound 3 :exclusion t :update-exclusion t)
test_that("exclusion=TRUE + update_exclusion=TRUE matches ppm", {
  for (x in list(x1, x2)) {
    compare_ic(
      ppidyom_stm_ic(x, alphabet, N = 3, method = "C",
                     exclusion = TRUE, update_exclusion = TRUE),
      ppm_stm_ic   (x, alphabet, N = 3, method = "C",
                     exclusion = TRUE, update_exclusion = TRUE),
      label = "C + excl + upd_excl"
    )
  }
})

# ═══════════════════════════════════════════════════════════════════════════════
# 4. ORDER BOUND — vary N (method C, no exclusion, no update_exclusion)
# ═══════════════════════════════════════════════════════════════════════════════

# IDyOM:  :stmo '(:escape :c :order-bound 1 :exclusion nil)
test_that("order bound N=1 matches ppm", {
  compare_ic(
    ppidyom_stm_ic(x1, alphabet, N = 1, method = "C"),
    ppm_stm_ic   (x1, alphabet, N = 1, method = "C"),
    label = "N=1"
  )
})

# IDyOM:  :stmo '(:escape :c :order-bound 5 :exclusion nil)
test_that("order bound N=5 matches ppm", {
  compare_ic(
    ppidyom_stm_ic(x1, alphabet, N = 5, method = "C"),
    ppm_stm_ic   (x1, alphabet, N = 5, method = "C"),
    label = "N=5"
  )
})

# ═══════════════════════════════════════════════════════════════════════════════
# 5. RUN_PPIDYOM vs PPM — full grid: escape × exclusion × update_exclusion
#    Covers  STM + interpolation only.
#    The PPM package only has equivalent STM comparison and no backoff method.
# ═══════════════════════════════════════════════════════════════════════════════

# Run run_ppidyom with model_type="stm" (single sequence) and extract IC.
ppidyom_run_stm_ic <- function(x, alphabet, N, method, exclusion, update_exclusion) {
  res <- run_ppidyom(
    list(x), N = N, alphabet = alphabet,
    model_type = "stm", ppm_type = "interpolation",
    stm_lambda = method, ltm_lambda = "C",
    stm_exclusion = exclusion, ltm_exclusion = FALSE,
    stm_update_exclusion = update_exclusion, ltm_update_exclusion = FALSE,
    b = 1
  )
  print(res)
  res[[1]][data.table(index = seq_along(x), Event = x), on = .(index, Event)]$IC
}

test_that("run_ppidyom (STM) matches ppm: all escape × exclusion × update_exclusion", {
  methods   <- names(escape_functions)   # A B C D X
  excl_grid <- c(FALSE, TRUE)
  upd_grid  <- c(FALSE, TRUE)

  for (m in methods) {
    for (excl in excl_grid) {
      for (upd in upd_grid) {
        label <- sprintf("STM m=%s excl=%s upd=%s", m, excl, upd)
        for (x in list(x1, x2)) {
          compare_ic(
            ppidyom_run_stm_ic(x, alphabet, N = 3, m, excl, upd),
            ppm_stm_ic        (x, alphabet, N = 3, method = m,
                               exclusion = excl, update_exclusion = upd),
            label = label
          )
        }
      }
    }
  }
})

