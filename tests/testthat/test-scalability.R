# Scalability tests — disabled by default (slow).
# To run: Sys.setenv(RUN_SCALABILITY_TESTS = "true"); devtools::test(filter = "scalability")

test_that("run_ppidyom scales linearly; naive LOO scales quadratically", {
  skip_if_not(Sys.getenv("RUN_SCALABILITY_TESTS") == "true")

  set.seed(42)
  alphabet <- c("A", "B", "C", "D", "E")
  N        <- 3
  seq_len  <- 30   # fixed per-sequence length

  # Vary corpus size (number of sequences)
  n_seqs <- c(5, 10, 20, 40, 80)

  times_fast   <- numeric(length(n_seqs))
  times_manual <- numeric(length(n_seqs))

  cat("\n--- Scalability: run_ppidyom (train/detrain LOO) vs naive LOO ---\n")

  for (i in seq_along(n_seqs)) {
    seq_list <- replicate(n_seqs[i], sample(alphabet, seq_len, replace = TRUE),
                          simplify = FALSE)

    args <- list(seq_list = seq_list, N = N, alphabet = alphabet,
                 model_type = "both", ppm_type = "interpolation",
                 stm_lambda = "C", ltm_lambda = "C", b = 1)

    times_fast[i]   <- system.time(do.call(run_ppidyom,    args))["elapsed"]
    times_manual[i] <- system.time(do.call(manual_ppidyom, args))["elapsed"]

    cat(sprintf("n = %2d | fast: %6.3f s | naive: %6.3f s | speedup: %.1fx\n",
                n_seqs[i], times_fast[i], times_manual[i],
                times_manual[i] / times_fast[i]))
  }

  # ── Plot: time vs corpus size ─────────────────────────────────────────────
  plot(n_seqs, times_manual, type = "b", pch = 17, col = "tomato", lty = 1,
       xlab = "Number of sequences",
       ylab = "Elapsed time (seconds)",
       main = "LOO scaling: run_ppidyom vs naive",
       ylim = c(0, max(times_manual) * 1.1))
  lines(n_seqs, times_fast, type = "b", pch = 16, col = "steelblue", lty = 1)
  legend("topleft",
         legend = c("naive LOO  (O(n²))", "run_ppidyom  (O(n))"),
         col    = c("tomato", "steelblue"),
         pch    = c(17, 16), lty = 1, bty = "n")

  # ── Verify approximate scaling exponents via log-log slope ───────────────
  if (length(n_seqs) >= 3) {
    slope_fast   <- coef(lm(log(times_fast)   ~ log(n_seqs)))[2]
    slope_manual <- coef(lm(log(times_manual) ~ log(n_seqs)))[2]
    cat(sprintf("\nLog-log slopes  —  fast: %.2f (expect ≈1)  |  naive: %.2f (expect ≈2)\n",
                slope_fast, slope_manual))
    expect_lt(slope_fast,   1.5)   # run_ppidyom should be sub-quadratic
    expect_gt(slope_manual, 1.5)   # naive should be clearly super-linear
  }
})
