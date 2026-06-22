# examples/demo.R
#
# Usage examples for ppidyom.
# Run after devtools::load_all() (see README_DEV.md for setup).
#
# Two sections:
#   1. ABC toy sequence — ppidyom vs ppm package (no special files needed)
#   2. HumdrumR / kern corpus — real music data (requires humdrumR + kern files)

library(data.table)
devtools::load_all()   # or: library(ppidyom)

# ─────────────────────────────────────────────────────────────────────────────
# 1. TOY EXAMPLE: compare ppidyom to Harrison's ppm package
# ─────────────────────────────────────────────────────────────────────────────
# Equivalent IDyOM command (Common Lisp):
#   (idyom:idyom <db-id> '(cpitch) '(cpitch)
#     :texture :melody :models :stm :k :full :detail 3
#     :stmo '(:escape :c :order-bound 3 :exclusion nil :update-exclusion nil))

x        <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
alphabet <- c("A", "B", "C")
N        <- 3

# ── ppidyom ──────────────────────────────────────────────────────────────────
counts <- count_tables(
  x        = x,
  N        = N,
  alphabet = alphabet,
  model_type           = "stm",
  stm_update_exclusion = FALSE,
  ltm_update_exclusion = FALSE
)

result <- ppm_interpolated(
  x           = x,
  N           = N,
  alphabet    = alphabet,
  order_counts = counts$stm,
  escape_func  = escape_AX,
  exclusion    = TRUE
)
print(result)

# Predicted IC for the observed sequence
res_ppidyom <- result[
  data.table(index = seq_along(x), Event = x), on = .(index, Event)
][, .(index, Event, P, IC, Entropy)]
print(res_ppidyom)

# ── ppm package (Harrison et al. 2020) ───────────────────────────────────────
# install: devtools::install_github("pmcharrison/ppm")
if (requireNamespace("ppm", quietly = TRUE)) {
  mod <- ppm::new_ppm_simple(
    order_bound            = N,
    alphabet_levels        = alphabet,
    escape                 = "ax",
    shortest_deterministic = FALSE,
    exclusion              = TRUE,
    update_exclusion       = FALSE
  )
  res_ppm <- ppm::model_seq(mod, factor(x, levels = alphabet))
  print(res_ppm)
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. MULTI-SEQUENCE EXAMPLE: run_ppidyom with leave-one-out
# ─────────────────────────────────────────────────────────────────────────────

seq1 <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
seq2 <- c("A", "B", "C", "A", "B", "C", "A", "B", "C")
seq3 <- c("B", "A", "B", "C", "A")

alphabet  <- c("A", "B", "C")
N         <- 3

# STM only (no LTM, no leave-one-out):
res_stm <- run_ppidyom(
  seq_list             = list(seq1, seq2, seq3),
  N                    = N,
  alphabet             = alphabet,
  model_type           = "stm",
  ppm_type             = "interpolation",
  stm_lambda           = "C",
  ltm_lambda           = "C",
  stm_exclusion        = FALSE,
  ltm_exclusion        = FALSE,
  stm_update_exclusion = FALSE,
  ltm_update_exclusion = FALSE,
  b                    = 1
)
print(rbindlist(res_stm))

# Both STM + LTM with leave-one-out:
res_both <- run_ppidyom(
  seq_list             = list(seq1, seq2, seq3),
  N                    = N,
  alphabet             = alphabet,
  model_type           = "both",
  ppm_type             = "interpolation",
  stm_lambda           = "C",
  ltm_lambda           = "C",
  stm_exclusion        = TRUE,
  ltm_exclusion        = TRUE,
  stm_update_exclusion = TRUE,
  ltm_update_exclusion = FALSE,
  b                    = 1
)
print(rbindlist(res_both))

# Compare STM only vs IDyOM :stm with ppm if installed:
if (requireNamespace("ppm", quietly = TRUE)) {
  # seq3 alone, same parameters
  mod3 <- ppm::new_ppm_simple(
    order_bound            = N,
    alphabet_levels        = alphabet,
    escape                 = "c",
    shortest_deterministic = FALSE,
    exclusion              = FALSE,
    update_exclusion       = FALSE
  )
  res3_ppm <- ppm::model_seq(mod3, factor(seq3, levels = alphabet))
  print(res3_ppm)
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. HUMDRUMR EXAMPLE: real music corpus (requires humdrumR + kern files)
# ─────────────────────────────────────────────────────────────────────────────
# Requires:
#   install.packages("humdrumR")
#   kern files under tests/data/kern/*.krn

if (requireNamespace("humdrumR", quietly = TRUE) &&
    length(list.files("tests/data/kern", pattern = "\\.krn$")) > 0) {

  library(humdrumR)

  kern_files <- readHumdrum("tests/data/kern/*.krn")
  kern_files |> select(Token) |> pitch()

  seq_df <- kern_files |>
    midi() |>
    group_by(Piece) |>
    summarise(seq = list(as.character(Midi)))
  seq_list <- seq_df$seq
  attributes(seq_list) <- NULL

  # LTM leave-one-out
  run_ppidyom(
    seq_list,
    N          = 5,
    model_type = "ltm",
    ppm_type   = "interpolation",
    stm_lambda = "C",
    ltm_lambda = "C",
    b          = 1
  )

  # Combined STM + LTM
  run_ppidyom(
    seq_list,
    N          = 5,
    model_type = "both",
    ppm_type   = "interpolation",
    stm_lambda = "C",
    ltm_lambda = "C",
    b          = 1
  )
}
