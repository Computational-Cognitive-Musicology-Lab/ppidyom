#' Calculate information dynamics using PPIDyOM
#'
#' This function calls ppidyom on arbitrary vectors of data, or humdrumR data.
#'
#' @param ... ***One or more input vectors, all the same length.***
#' @param maxN ***Maximum N-gram length to compute.***
#'        Defaults to 10.
#' @param alphabet ***The set of possible input values. By default, cartesian product of input vectors.***
#' @param shortTermArgs ***List of arguments for short-term ppm algorithm. See details.***
#' @param longTermArgs ***List of arguments for long-term ppm algorithm. See details.***
#' @param longTermGroups ***Groups for long term training (usually pieces).***
#' @param shortTermGroups ***Groups for short term (local) application (usually parts within a piece).***

#' @export
ppidyom <- function(...) {
	UseMethod("ppidyom")

}


#' @exportS3Method
ppidyom.default <- function(..., maxN = 10, alphabet = do.call('paste', expand.grid(lapply(list(...), unique))), 
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

	output <- list()
	for (lg in unique(longTermGroups)) {
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

  if (is.null(alphabet)) {
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

  results_list <- vector("list", length(seq_list))

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
  }

  results_list
}

