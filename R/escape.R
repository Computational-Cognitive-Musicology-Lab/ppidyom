
# ── Shared parameters ─────────────────────────────────────────────────────────
# C   : total observations after this context (sum of all Ce)
# t   : number of distinct event types seen after this context
# t1  : number of event types seen exactly once (singletons)
# ─────────────────────────────────────────────────────────────────────────────
#
# ── Two families of functions ─────────────────────────────────────────────────
#
#  escape_*   used by ppm_backoff.  Each function returns:
#    $denom    denominator when computing P(seen event | context)
#    $esc      probability of escaping to a lower order
#    $subtract subtracted from Ce before dividing (method B/D)
#
#  discount_* used by ppm_interpolated.  Each function returns:
#    $lambda   weight given to this order's MLE estimate;
#              (1 - lambda) = probability mass that flows to lower orders
#    $k        count subtraction per type (currently unused in main loop)
#
#  For method C (the most common choice): esc = t/(C+t) = 1 - lambda.
#  The two families are mathematically equivalent for method C; the naming
#  reflects their role in each algorithm (explicit escape vs. smooth weight).
# ─────────────────────────────────────────────────────────────────────────────

# ── escape_* functions ────────────────────────────────────────────────────────

escape_A <- function(C, t, t1) {
  list(
    denom = C + 1,
    esc = 1 / (C + 1),
    subtract = 0
  )
}

escape_B <- function(C, t, t1) {
  list(
    denom = C,
    esc = t / C,
    subtract = 1
  )
}

escape_C <- function(C, t, t1) {
  list(
    denom = C + t,
    esc = t / (C + t),
    subtract = 0
  )
}

escape_D <- function(C, t, t1) {
  list(
    denom = C + 0.5 * t,
    esc = t / (C + 0.5 * t),
    subtract = 0.5
  )
}

escape_AX <- function(C, t, t1) {
  list(
    denom = C + t + 1,
    esc = (t1 + 1) / (C + t + 1),
    subtract = 0
  )
}


# ── discount_* functions ──────────────────────────────────────────────────────
# TODO: k (count subtraction per type) is not yet applied in ppm_interpolated.

discount_A <- function(C, t, t1) {
  list(
    lambda = C / (C + 1),
    k = 0
  )
}

discount_B <- function(C, t, t1) {
  list(
    lambda = C / (C + t),
    k = -1
  )
}

discount_C <- function(C, t, t1) {
  list(
    lambda = C / (C + t),
    k = 0
  )
}

discount_D <- function(C, t, t1) {
  list(
    lambda = C / (C + t/2),
    k = -1/2
  )
}

discount_AX <- function(C, t, t1) {
  list(
    lambda = C / (C + t1 + 1),
    k = 0
  )
}

# Define all available escape/discount functions
escape_functions <- list(
  A       = escape_A,
  B       = escape_B,
  C       = escape_C,
  D       = escape_D,
  X       = escape_AX
)

discount_functions <- list(
  A       = discount_A,
  B       = discount_B,
  C       = discount_C,
  D       = discount_D,
  X       = discount_AX
)

