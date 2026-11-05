get_H <- function(P, base = 2) {
	P[P > 0, list(H = -sum(log(P, base = base) * P)), by = index]$H
}

get_p <- function(P) {
	P[Event == Sym, P]
}


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
ppidyom.default <- function(..., maxN = 10, alphabet = lapply(list(...), unique),
														dynamic = TRUE, schematic = TRUE, 
														dynamicGroups = list(), schematicGroups = list(),
														dynamicArgs = list(), schematicArgs = list(),
														ppm_type = c("interpolation", "backoff"),
														b = 1, base = 2) {


	inputs <- data.table(...)
	ninputs <- ncol(inputs)
	len <- nrow(inputs)
	# check inputs are all the same length

	# need alphabet checks

	dynamicArgs <- modifyList(list(escape = 'C', exclusion = TRUE, update_exclusion = TRUE), dynamicArgs)
	schematicArgs <- modifyList(list(escape = 'C', exclusion = TRUE, update_exclusion = FALSE, start_token = TRUE, crossValidate = TRUE), schematicArgs)

	if (length(dynamicGroups) == len) dynamicGroups <- list(dynamicGroups)
	if (length(schematicGroups) == len) schematicGroups <- list(schematicGroups)
	dynamicGroups <- c(dynamicGroups, schematicGroups)
	dynamicGroups   <- if (length(dynamicGroups))   frankv(dynamicGroups, ties.method = 'dense') else rep(1L, len)
	schematicGroups <- if (length(schematicGroups)) frankv(schematicGroups, ties.method = 'dense') else rep(1L, len)


	Map(inputs, alphabet, colnames(inputs),
			f = \(input, alph, i) {
						lags <- lag_matrix(input, N = maxN, stmGroups = dynamicGroups, ltmGroups = schematicGroups, alphabet = alph)
						
						input <- paste0(' for input ', i)

						dynP <- if (dynamic) {
							cat("Computing dynamic probabilities", input, '...', sep = '')
							lags |> stm_counts() |> stm_interpolation(escape = dynamicArgs$escape)
						}
						schP <- if (schematic) {
							cat("Computing schematic probabilities", input, '...', sep = '')
							lags |> ltm_counts() |> ltm_crossValidate() |> ltm_interpolation(escape = schematicArgs$escap) |> ltm2dynamic_counts(lags)
						}

						if (dynamic && schematic) cat("Blending dynamic and schematic models", input, '...', sep = '')
						combine_P(dynP, schP)
						
				 }) -> Ps

	P <- if (ninputs > 1L) {
		cat("Weighing the", ninputs, 'inputs together...')
		Reduce(Ps, f = combine_P)
	} else {
		Ps[[1]] 
	}


	cat("done!\n")

	inputs[, c('IC', 'H') := list(round(-log(get_p(P), base = base), 3), round(get_H(P, base = base), 3))]

	inputs[]

}

#' @exportS3Method
ppidyom.humdrumR <- function(humdrumR, ..., maxN = 10, schematicArgs = list(), dynamicArgs = list()) {

	quos <- rlang::enquos(...)

	ns <- names(quos)
	if (is.null(ns)) ns <- character(length(quos))

	if (any(ns == '')) names(quos)[ns == ''] <- sapply(quos[ns == ''], rlang::quo_squash)
	if (length(quos) == 0L) quos <- setNames(list(rlang::quo(.)), selectedFields(humdrumR)[1])

	rlang::eval_tidy(rlang::expr(within(humdrumR,  ppidyom.default(!!!quos, maxN = maxN, schematicGroups = list(Piece), dynamicGroups = list(Spine, Path),
																																 schematicArgs = schematicArgs, dynamicArgs = dynamicArgs)[ , list(IC, H)], dataTypes = 'D')))

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
