
# ── Escape function interface ─────────────────────────────────────────────────
# Each escape_* function takes (t, t1) and returns:
#   $subtract           : discount d subtracted from each Ce before summing
#   $esc_numer : numerator of esc = esc_numer / (context_count + esc_numer); equals t/d in thesis notation
#
# The calling code (interpolation.R / backoff.R) then computes:
#   Ce_adj        = max(Ce - subtract, 0)          ← modified count per symbol
#   context_count = Σ Ce_adj per context            ← = C - subtract*t
#   denom         = context_count + esc_numer
#   lambda        = context_count / denom
#   alpha[s]      = Ce_adj[s] / denom              ← = lambda * Ce_adj / context_count
#   esc           = esc_numer / denom              ← = 1 - lambda
#
# This mirrors Harrison's ppm C++ structure:
#   modify_count()                 → Ce_adj
#   get_context_count()            → context_count
#   get_effective_distinct_symbols() → esc_numer  [Harrison's name for this quantity]
#   lambda = ctx / (ctx + esc_numer) → lambda
#   get_alphas(lambda, Ce, ctx)    → alpha[s]
#
# ── Mapping to Pearce thesis notation (Bunton 1996, ch. 6 via Pearce 2005) ───
# Thesis: lambda = (C + k*t) / ((C + k*t) + t/d)
# Our parameters: subtract = -k,  esc_numer = t/d
#
# Method | k    | d | subtract | esc_numer    | context_count | lambda
# A      | 0    | t | 0        | t/t = 1      | C             | C/(C+1)
# B      | -1   | 1 | 1        | t            | C-t           | (C-t)/C
# C      | 0    | 1 | 0        | t            | C             | C/(C+t)
# D      | -1/2 | 2 | 0.5      | t/2          | C-0.5t        | (C-0.5t)/C
# AX     | 0    | 1 | 0        | t1+1 *       | C             | C/(C+t1+1)
#
# * AX: thesis gives eff = t1/d = t1, but Harrison's ppm uses t1+1 (Moffat 1990
#   original, which adds 1 to prevent division by zero when t1=0). Our code
#   follows ppm, confirmed by ppm-comparison tests.
# ─────────────────────────────────────────────────────────────────────────────

escape_A <- function(t, t1) {
  list(subtract = 0, esc_numer = 1)
}

escape_B <- function(t, t1) {
  list(subtract = 1, esc_numer = t)
}

escape_C <- function(t, t1) {
  list(subtract = 0, esc_numer = t)
}

escape_D <- function(t, t1) {
  # PPM-D absolute discounting (Ney et al. 1994): d = 0.5.
  # esc_numer = t/2, so lambda = (C-0.5t)/((C-0.5t)+t/2) = (C-0.5t)/C.
  list(subtract = 0.5, esc_numer = t / 2)
}

escape_AX <- function(t, t1) {
  # AX uses singletons+1 as esc_numer, not total distinct types.
  list(subtract = 0, esc_numer = t1 + 1)
}

escape_functions <- list(
  A = escape_A,
  B = escape_B,
  C = escape_C,
  D = escape_D,
  X = escape_AX
)
