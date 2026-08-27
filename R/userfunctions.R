#' Calculate information dynamics using PPIDyOM
#'
#' This function calls ppidyom on arbitrary vectors of data, or humdrumR data.
#'
#' @param ... ***One or more input vectors, all the same length.***
#' @param maxN ***Maximum N-gram length to compute.***
#'        Defaults to 5.
#' @param alphabet ***The set of possible input values. By default, cartesian product of input vectors.***
#' @param model_type ***Which memory component(s) to use:***
#' - ***`"stm"` — short-term memory, within each `shortTermGroups` group only.***
#' - ***`"ltm"` — long-term memory, trained across `longTermGroups`.***
#' - ***`"both"` — STM + LTM blended.***
#' - ***`"ltm+"`/`"both+"` — as `"ltm"`/`"both"`, but LTM updates online
#'   group by group.***
#' @param ppm_type ***PPM estimation method:***
#' - ***`"interpolation"` — weighted sum across all n-gram orders.***
#' - ***`"backoff"` — falls through orders from longest to shortest matching context.***
#' @param shortTermArgs ***List of STM settings:***
#' - ***`lambda` — escape method, one of `"A"`/`"B"`/`"C"`/`"D"`/`"X"`
#'   (default `"C"`); see the
#'   [Escape method](../articles/ParameterCorrespondence.html#escape-method)
#'   section of the [Parameter Correspondence](../articles/ParameterCorrespondence.html)
#'   vignette.***
#' - ***`exclusion` — logical; exclude symbols already assigned a
#'   probability at a higher order (default TRUE).***
#' - ***`update_exclusion` — logical; stop updating lower-order counts
#'   once a higher order already matched at this timestep (default TRUE).***
#' @param longTermArgs ***List of LTM settings: same as `shortTermArgs`, plus
#'        `start_token` (whether to count beginning-of-sequence positions).***
#' @param longTermGroups ***Groups for long term training (usually pieces).***
#' @param shortTermGroups ***Groups for short term (local) application (usually parts within a piece).***
#' @param b ***Bias exponent for entropy-weighted blending, used only when
#'        `model_type` is `"both"`/`"both+"`; higher values favor whichever of
#'        STM/LTM is currently more confident.***
#' @param idyom_base ***Logical; use IDyOM's order-(-1) base distribution instead
#'        of the default shrinking-denominator base. See the
#'        [Implementation Discrepancy](../articles/ImplementationDiscrepancy.html) vignette.***
#' @examples
#' \dontrun{
#' x <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
#' ppidyom(x, maxN = 3, model_type = "stm")
#' }

#' @export
ppidyom <- function(...) {
	UseMethod("ppidyom")

}


#' @exportS3Method
ppidyom.default <- function(..., maxN = 5, alphabet = do.call('paste', expand.grid(lapply(list(...), unique))),
														model_type = c("stm", "ltm", "both", "ltm+", "both+"), ppm_type = c("interpolation", "backoff"),
														shortTermArgs = list(), longTermArgs = list(), 
														longTermGroups = list(), shortTermGroups = list(),
														b = 1, idyom_base = FALSE) {

  model_type <- match.arg(model_type)
  ppm_type   <- match.arg(ppm_type)

	input <- do.call('paste', list(...)) # lazy approach until we implement viewpoint weighting

	shortTermArgs <- modifyList(list(lambda = 'C', exclusion = TRUE, update_exclusion = TRUE), shortTermArgs)
	longTermArgs <- modifyList(list(lambda = 'C', exclusion = TRUE, update_exclusion = FALSE, start_token = TRUE), longTermArgs)

	longTermGroups <- if (length(longTermGroups)) do.call('paste', longTermGroups) else 1
	shortTermGroups <- if (length(shortTermGroups)) do.call('paste', shortTermGroups) else 1


	data <- data.table(Tokens = input, longTerm = longTermGroups, shortTerm = shortTermGroups)


  model <- ppidyomModel$new(
    N = maxN, alphabet = alphabet,
    stm_exclusion = shortTermArgs$exclusion,
    ltm_exclusion =  longTermArgs$exclusion,
    stm_update_exclusion = shortTermArgs$update_exclusion,
    ltm_update_exclusion =  longTermArgs$update_exclusion,
    ltm_start_token = longTermArgs$start_token
  )


  has_ltm <- model_type %in% c("ltm","both","ltm+","both+") && length(unique(longTermGroups)) > 1L



	# train
	for (group in unique(paste(data$longTerm, data$shortTerm))) {
		print(group)
		model$train_sequence(data[paste(longTerm, shortTerm) == group, Tokens])
	}

	lt_groups <- unique(longTermGroups)
	n_lt      <- length(lt_groups)
	t0        <- proc.time()[["elapsed"]]

	message(sprintf("ppidyom: %d long-term group(s), N=%d, model=%s, ppm=%s, alphabet=%d",
	                n_lt, maxN, model_type, ppm_type, length(alphabet)))

	output <- list()
	for (i in seq_along(lt_groups)) {
		lg <- lt_groups[i]
    print(lg)

		for (sg in data[longTerm == lg, unique(shortTerm)]) {
			model$detrain_sequence(data[longTerm == lg & shortTerm == sg, Tokens])
		}

		result <- list()

		
		for (sg in data[longTerm == lg, unique(shortTerm)]) {
			print(sg)
			result <- c(result, list(model$predict_sequence(data[longTerm == lg & shortTerm == sg, Tokens])))
		}

		for (sg in data[longTerm == lg, unique(shortTerm)]) {
			model$train_sequence(data[longTerm == lg & shortTerm == sg, Tokens])
		}

		output <- c(output, list(do.call('rbind', result)))

		elapsed <- proc.time()[["elapsed"]] - t0
		eta     <- if (i < n_lt) elapsed / i * (n_lt - i) else 0
		message(sprintf("  [%d/%d] %.1fs elapsed, %.1fs remaining", i, n_lt, elapsed, eta))
	}
	do.call('rbind', output) |> pull(IC)


}

#' @exportS3Method
ppidyom.humdrumR <- function(humdrumR, ...) {

	quos <- rlang::enquos(...)

	ns <- names(quos)
	if (is.null(ns)) ns <- character(length(quos))

	if (!any(ns == '')) quos <- c(rlang::quo(.), quos)

	rlang::eval_tidy(rlang::expr(within(humdrumR, ICppidyom <- ppidyom.default(!!!quos), dataTypes = 'D')))

}

#' Run PPM over a corpus of sequences
#'
#' Lower-level building block behind [ppidyom()]. Takes a plain list of
#' sequences (rather than viewpoint vectors + grouping columns) and, for
#' `model_type`s with an LTM component, evaluates each sequence leave-one-out:
#' the whole corpus is trained first, then for each sequence in turn it is
#' detrained, predicted on, and retrained before moving to the next.
#'
#' @param seq_list List of character-vector sequences (the corpus). Each
#'   element is one sequence, e.g. one piece.
#' @param N Maximum n-gram order (order bound).
#' @param alphabet Character vector of all possible symbols. If `NULL`
#'   (default), inferred as the set of unique symbols across `seq_list`.
#' @param model_type Which memory component(s) to use:
#'   - `"stm"` — short-term memory, one sequence at a time, no leave-one-out.
#'   - `"ltm"` — long-term memory, pretrained on the corpus, no update during test.
#'   - `"both"` — STM + LTM blended.
#'   - `"ltm+"`/`"both+"` — as `"ltm"`/`"both"`, but LTM updates online per event.
#' @param ppm_type PPM estimation method:
#'   - `"interpolation"` — weighted sum across all n-gram orders.
#'   - `"backoff"` — falls through orders from longest to shortest matching context.
#' @param stm_lambda Escape/discount method for STM: `"A"`, `"B"`, `"C"`
#'   (Witten-Bell, default), `"D"` (absolute discounting), or `"X"` (AX, based
#'   on singleton counts). See the
#'   [Escape method](../articles/ParameterCorrespondence.html#escape-method)
#'   section of the [Parameter Correspondence](../articles/ParameterCorrespondence.html)
#'   vignette for the exact formulas.
#' @param ltm_lambda Escape/discount method for LTM; same options as `stm_lambda`.
#' @param stm_exclusion Logical; exclude symbols already assigned a probability
#'   at a higher order when computing STM escape probabilities (default TRUE).
#' @param ltm_exclusion Logical; same as `stm_exclusion`, for LTM (default TRUE).
#' @param stm_update_exclusion Logical; stop updating lower-order STM counts
#'   once a higher order already matched at this timestep (default TRUE).
#' @param ltm_update_exclusion Logical; same as `stm_update_exclusion`, but
#'   applied while accumulating LTM counts (default FALSE).
#' @param b Bias exponent for entropy-weighted blending, used only when
#'   `model_type` is `"both"`/`"both+"`; higher values favor whichever of
#'   STM/LTM is currently more confident (default 1).
#' @param idyom_base Logical; use IDyOM's order-(-1) base distribution instead
#'   of the default shrinking-denominator base (default FALSE). See the
#'   [Implementation Discrepancy](../articles/ImplementationDiscrepancy.html) vignette.
#' @param ltm_start_token Logical; count beginning-of-sequence positions when
#'   accumulating LTM (default TRUE; set FALSE to match IDyOM).
#' @return A list the same length as `seq_list`; each element is a data.table
#'   with columns `index`, `Event`, `P`, `IC`, `Entropy`, `seq_id` (the position
#'   of that sequence in `seq_list`). Combine with `data.table::rbindlist()`.
#' @examples
#' # run_ppidyom is internal; use ::: since this example isn't run via library()
#' seq1 <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
#' seq2 <- c("A", "B", "C", "A", "B", "C", "A", "B", "C")
#' seq3 <- c("B", "A", "B", "C", "A")
#'
#' # STM only, no leave-one-out (each sequence starts from scratch):
#' res_stm <- ppidyom:::run_ppidyom(
#'   seq_list = list(seq1, seq2, seq3), N = 3, model_type = "stm",
#'   stm_exclusion = FALSE, stm_update_exclusion = FALSE
#' )
#' data.table::rbindlist(res_stm)
#'
#' # STM + LTM with leave-one-out:
#' res_both <- ppidyom:::run_ppidyom(
#'   seq_list = list(seq1, seq2, seq3), N = 3, model_type = "both"
#' )
#' data.table::rbindlist(res_both)
# Runs leave-one-out PPM over a corpus: trains on all sequences, then for each
# sequence detrains itself, predicts, and retrains.
run_ppidyom <- function(
    seq_list,
    N,
    alphabet = NULL,
    model_type = c("stm", "ltm", "both", "ltm+", "both+"),
    ppm_type = c("interpolation", "backoff"),
    stm_lambda = "C",
    ltm_lambda = "C",
    stm_exclusion = TRUE,
    ltm_exclusion = TRUE,
    stm_update_exclusion = TRUE,
    ltm_update_exclusion = FALSE,
    b = 1,
    idyom_base = FALSE,
    ltm_start_token = TRUE
) {
  model_type <- match.arg(model_type)
  ppm_type   <- match.arg(ppm_type)

  alphabet_inferred <- is.null(alphabet)
  if (alphabet_inferred) {
    alphabet <- unique(unlist(seq_list, use.names = FALSE))
  }
  model <- ppidyomModel$new(
    N = N, alphabet = alphabet,
    stm_exclusion = stm_exclusion,
    ltm_exclusion = ltm_exclusion,
    stm_update_exclusion = stm_update_exclusion,
    ltm_update_exclusion = ltm_update_exclusion,
    ltm_start_token = ltm_start_token
  )

  has_ltm <- model_type %in% c("ltm","both","ltm+","both+")

  # Train all sequences
  if(has_ltm) {
    for(seq in seq_list) {
      model$train_sequence(seq)
    }
  }

  n_seqs       <- length(seq_list)
  results_list <- vector("list", n_seqs)
  t0           <- proc.time()[["elapsed"]]

  message(sprintf("run_ppidyom: %d sequences, N=%d, model=%s, ppm=%s, alphabet=%d%s",
                  n_seqs, N, model_type, ppm_type,
                  length(alphabet),
                  if (alphabet_inferred) " (inferred)" else " (user-supplied)"))

  # For each test sequence, detrain itself, predict, and retrain itself
  for(i in seq_along(seq_list)) {
    x <- seq_list[[i]]
    # Leave-one-out option
    if(has_ltm) {
      model$detrain_sequence(x)
    }
    pred <- model$predict_sequence(
      x,
      model_type = model_type,
      ppm_type = ppm_type,
      stm_lambda = stm_lambda,
      ltm_lambda = ltm_lambda,
      b = b,
      idyom_base = idyom_base
    )
    pred[, seq_id := i]
    results_list[[i]] <- pred

    if(has_ltm) {
      model$train_sequence(x)
    }

    elapsed <- proc.time()[["elapsed"]] - t0
    eta     <- if (i < n_seqs) elapsed / i * (n_seqs - i) else 0
    message(sprintf("  [%d/%d] %.1fs elapsed, %.1fs remaining",
                    i, n_seqs, elapsed, eta))
  }

  results_list
}

