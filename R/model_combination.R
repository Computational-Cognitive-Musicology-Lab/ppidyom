# combining stm and ltm models
combine_models <- function(alphabet, p_stm, p_ltm, b=1) {
  dt <- merge(
    p_stm[, .(index, Event, P_stm=P, H_stm=Entropy)],
    p_ltm[, .(index, Event, P_ltm=P, H_ltm=Entropy)],
    by=c("index","Event")
  )

  logA <- log2(length(alphabet))

  # Relative entropy weights: w_i = (H_i / H_max)^{-b}
  # Dividing by logA (= H_max for a uniform alphabet) makes w scale-invariant.
  # The logA^b factor cancels in normalisation, so only the H ratio matters.
  dt[, Hrel_stm := H_stm / logA]
  dt[, Hrel_ltm := H_ltm / logA]

  dt[, w_stm := Hrel_stm^(-b)]
  dt[, w_ltm := Hrel_ltm^(-b)]

  # Normalise weights to [0,1] so they can be used as geometric-mean exponents
  dt[, w_norm := w_stm + w_ltm]
  dt[, w_stm_n := w_stm / w_norm]
  dt[, w_ltm_n := w_ltm / w_norm]

  # IDyOM log-linear (geometric-mean) combination.
  # Geometric mean: P_raw(s) = P_stm(s)^w_stm_n * P_ltm(s)^w_ltm_n
  #
  # IDyOM normalises conditionally (ppm-star.lisp: normalise-distribution /
  # sums-to-one-p): if 0.999 < sum(P_raw) < 1.0 it treats the distribution as
  # already summing to one and skips the division.  We replicate that exactly.
  dt[, P_raw := P_stm^w_stm_n * P_ltm^w_ltm_n]
  dt[, Z     := sum(P_raw), by = index]
  dt[, P     := if (Z[1] > 0.999 && Z[1] < 1.0) P_raw else P_raw / Z,
      by = index]

  dt[, IC      := -log2(P)]
  dt[, Entropy := -sum(P * log2(P)), by = index]

  dt[, .(index, Event, P, IC, Entropy)]
}

