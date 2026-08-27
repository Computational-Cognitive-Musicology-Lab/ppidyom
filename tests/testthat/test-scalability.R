# Scalability tests — disabled by default (slow).
# To run: Sys.setenv(RUN_SCALABILITY_TESTS = "true"); devtools::test(filter = "scalability")

# ── Synthetic corpus generator ─────────────────────────────────────────────────
# Random walk over alphabet so adjacent symbols tend to be close —
# produces stepwise melodic movement rather than uniform noise.
make_music_seqs <- function(n_seqs, seq_len_range, alphabet, seed = 42) {
  set.seed(seed)
  lapply(seq_len(n_seqs), function(i) {
    len <- sample(seq_len_range[1]:seq_len_range[2], 1)
    idx <- integer(len)
    idx[1] <- sample(seq_along(alphabet), 1)
    for (j in seq_len(len - 1)) {
      step      <- sample(-3L:3L, 1L)
      idx[j + 1] <- max(1L, min(length(alphabet), idx[j] + step))
    }
    alphabet[idx]
  })
}

# ── STM: corpus-size scaling (ppidyom vs ppm timing; accuracy spot-check) ─────
test_that("run_ppidyom(stm) timing and accuracy vs ppm: corpus size", {
  skip_if_not(Sys.getenv("RUN_SCALABILITY_TESTS") == "true")

  alphabet    <- LETTERS
  N           <- 3
  seq_len_rng <- c(20L, 50L)
  n_seqs_vals <- c(5, 10, 20, 40, 80)

  times_ppidyom <- numeric(length(n_seqs_vals))
  times_ppm     <- numeric(length(n_seqs_vals))

  has_ppm <- requireNamespace("ppm", quietly = TRUE)

  cat(sprintf("\n--- STM scaling: corpus size  [N=%d, alphabet=%d] ---\n",
              N, length(alphabet)))

  for (i in seq_along(n_seqs_vals)) {
    n_i      <- n_seqs_vals[i]
    seq_list <- make_music_seqs(n_i, seq_len_rng, alphabet, seed = i)

    times_ppidyom[i] <- system.time(
      run_ppidyom(seq_list, N = N, alphabet = alphabet,
                  model_type = "stm", ppm_type = "interpolation", stm_lambda = "C")
    )["elapsed"]

    if (has_ppm) {
      times_ppm[i] <- system.time({
        for (s in seq_list) {
          mod <- ppm::new_ppm_simple(order_bound = N, alphabet_levels = alphabet,
                                     escape = "c", exclusion = TRUE,
                                     update_exclusion = TRUE,
                                     shortest_deterministic = FALSE)
          ppm::model_seq(mod, factor(s, levels = alphabet))
        }
      })["elapsed"]
      cat(sprintf("n_seqs = %2d | ppidyom(stm): %6.3f s | ppm(stm): %6.3f s | ratio: %.1fx\n",
                  n_i, times_ppidyom[i], times_ppm[i],
                  times_ppidyom[i] / times_ppm[i]))
    } else {
      cat(sprintf("n_seqs = %2d | ppidyom(stm): %6.3f s\n", n_i, times_ppidyom[i]))
    }
  }

  # ── Accuracy spot-check: ppidyom(stm) vs ppm on a small fixed corpus ──────
  # run_ppidyom defaults (stm_exclusion=TRUE, stm_update_exclusion=TRUE,
  # idyom_base=FALSE) match ppm defaults (exclusion=TRUE, update_exclusion=TRUE).
  if (has_ppm) {
    chk_seqs <- make_music_seqs(5, seq_len_rng, alphabet, seed = 999)
    pp_out   <- data.table::rbindlist(
      run_ppidyom(chk_seqs, N = N, alphabet = alphabet,
                  model_type = "stm", ppm_type = "interpolation", stm_lambda = "C")
    )
    set.seed(1)
    for (si in seq_along(chk_seqs)) {
      s      <- chk_seqs[[si]]
      mod    <- ppm::new_ppm_simple(order_bound = N, alphabet_levels = alphabet,
                                    escape = "c", exclusion = TRUE,
                                    update_exclusion = TRUE,
                                    shortest_deterministic = FALSE)
      ppm_ic <- ppm::model_seq(mod, factor(s, levels = alphabet))$information_content
      pp_ic  <- pp_out[seq_id == si][order(index)]$IC
      pos    <- sample(seq_along(ppm_ic), min(5L, length(ppm_ic)))
      expect_equal(pp_ic[pos], ppm_ic[pos], tolerance = 1e-4,
                   label = sprintf("STM IC seq %d pos %s", si, paste(pos, collapse = ",")))
    }
    cat("Accuracy: ppidyom(stm) matches ppm at sampled positions\n")
  }

  expect_true(all(times_ppidyom > 0))
})

# ── STM: order-N scaling (ppidyom vs ppm; accuracy vs ppm) ───────────────────
test_that("run_ppidyom(stm) and ppm scale with order N", {
  skip_if_not(Sys.getenv("RUN_SCALABILITY_TESTS") == "true")

  alphabet    <- LETTERS
  n_seqs      <- 20
  seq_len_rng <- c(20L, 50L)
  N_vals      <- c(3, 5, 7, 10, 15)

  seq_list <- make_music_seqs(n_seqs, seq_len_rng, alphabet, seed = 99)

  times_ppidyom <- numeric(length(N_vals))
  times_ppm     <- numeric(length(N_vals))

  has_ppm <- requireNamespace("ppm", quietly = TRUE)

  cat(sprintf("\n--- STM scaling: order N  [n_seqs=%d, seq_len=%d-%d, alphabet=%d] ---\n",
              n_seqs, seq_len_rng[1], seq_len_rng[2], length(alphabet)))

  for (i in seq_along(N_vals)) {
    N_i <- N_vals[i]

    times_ppidyom[i] <- system.time(
      run_ppidyom(seq_list, N = N_i, alphabet = alphabet,
                  model_type = "stm", ppm_type = "interpolation", stm_lambda = "C")
    )["elapsed"]

    if (has_ppm) {
      times_ppm[i] <- system.time({
        for (s in seq_list) {
          mod <- ppm::new_ppm_simple(order_bound = N_i, alphabet_levels = alphabet,
                                     escape = "c", exclusion = TRUE,
                                     update_exclusion = TRUE,
                                     shortest_deterministic = FALSE)
          ppm::model_seq(mod, factor(s, levels = alphabet))
        }
      })["elapsed"]
      cat(sprintf("N = %2d | ppidyom(stm): %6.3f s | ppm(stm): %6.3f s | ratio: %.1fx\n",
                  N_i, times_ppidyom[i], times_ppm[i],
                  times_ppidyom[i] / times_ppm[i]))
    } else {
      cat(sprintf("N = %2d | ppidyom(stm): %6.3f s\n", N_i, times_ppidyom[i]))
    }
  }

  # ── Accuracy spot-check at two representative order values ────────────────
  if (has_ppm) {
    chk_seqs <- make_music_seqs(5, seq_len_rng, alphabet, seed = 888)
    set.seed(2)
    for (N_chk in c(3L, 7L)) {
      pp_out <- data.table::rbindlist(
        run_ppidyom(chk_seqs, N = N_chk, alphabet = alphabet,
                    model_type = "stm", ppm_type = "interpolation", stm_lambda = "C")
      )
      for (si in seq_along(chk_seqs)) {
        s      <- chk_seqs[[si]]
        mod    <- ppm::new_ppm_simple(order_bound = N_chk, alphabet_levels = alphabet,
                                      escape = "c", exclusion = TRUE,
                                      update_exclusion = TRUE,
                                      shortest_deterministic = FALSE)
        ppm_ic <- ppm::model_seq(mod, factor(s, levels = alphabet))$information_content
        pp_ic  <- pp_out[seq_id == si][order(index)]$IC
        pos    <- sample(seq_along(ppm_ic), min(5L, length(ppm_ic)))
        expect_equal(pp_ic[pos], ppm_ic[pos], tolerance = 1e-4,
                     label = sprintf("STM IC N=%d seq %d pos %s",
                                     N_chk, si, paste(pos, collapse = ",")))
      }
    }
    cat("Accuracy: ppidyom(stm) matches ppm at sampled positions (N=3 and N=7)\n")
  }

  if (length(N_vals) >= 3) {
    slope_pp <- coef(lm(log(times_ppidyom) ~ log(N_vals)))[2]
    cat(sprintf("\nLog-log slope for N —  ppidyom(stm): %.2f (expect ≤2)\n", slope_pp))
    expect_lt(slope_pp, 2.5)
  }
})

# ── both-model: corpus-size scaling (timing only) ─────────────────────────────
test_that("run_ppidyom(both) timing: corpus size", {
  skip_if_not(Sys.getenv("RUN_SCALABILITY_TESTS") == "true")

  alphabet    <- LETTERS
  N           <- 3
  seq_len_rng <- c(20L, 50L)
  n_seqs_vals <- c(5, 10, 20, 40, 80)

  times <- numeric(length(n_seqs_vals))

  cat(sprintf("\n--- both-model scaling: corpus size  [N=%d, alphabet=%d] ---\n",
              N, length(alphabet)))

  for (i in seq_along(n_seqs_vals)) {
    n_i      <- n_seqs_vals[i]
    seq_list <- make_music_seqs(n_i, seq_len_rng, alphabet, seed = i + 100)
    times[i] <- system.time(
      run_ppidyom(seq_list, N = N, alphabet = alphabet,
                  model_type = "both", ppm_type = "interpolation",
                  stm_lambda = "C", ltm_lambda = "C", b = 1)
    )["elapsed"]
    cat(sprintf("n_seqs = %2d | ppidyom(both): %6.3f s\n", n_i, times[i]))
  }

  expect_true(all(times > 0))

  if (length(n_seqs_vals) >= 3) {
    slope <- coef(lm(log(times) ~ log(n_seqs_vals)))[2]
    cat(sprintf("\nLog-log slope —  ppidyom(both): %.2f\n", slope))
  }
})

# ── both-model: order-N scaling (timing only) ─────────────────────────────────
test_that("run_ppidyom(both) timing: order N", {
  skip_if_not(Sys.getenv("RUN_SCALABILITY_TESTS") == "true")

  alphabet    <- LETTERS
  n_seqs      <- 50
  seq_len_rng <- c(20L, 50L)
  N_vals      <- c(3, 5, 7, 10, 15)

  seq_list <- make_music_seqs(n_seqs, seq_len_rng, alphabet, seed = 77)

  times <- numeric(length(N_vals))

  cat(sprintf("\n--- both-model scaling: order N  [n_seqs=%d, seq_len=%d-%d, alphabet=%d] ---\n",
              n_seqs, seq_len_rng[1], seq_len_rng[2], length(alphabet)))

  for (i in seq_along(N_vals)) {
    N_i      <- N_vals[i]
    times[i] <- system.time(
      run_ppidyom(seq_list, N = N_i, alphabet = alphabet,
                  model_type = "both", ppm_type = "interpolation",
                  stm_lambda = "C", ltm_lambda = "C", b = 1)
    )["elapsed"]
    cat(sprintf("N = %2d | ppidyom(both): %6.3f s\n", N_i, times[i]))
  }

  expect_true(all(times > 0))

  if (length(N_vals) >= 3) {
    slope <- coef(lm(log(times) ~ log(N_vals)))[2]
    cat(sprintf("\nLog-log slope for N —  ppidyom(both): %.2f\n", slope))
  }
})
