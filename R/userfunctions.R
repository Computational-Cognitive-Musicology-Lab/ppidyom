#' Calculate information dynamics using PPIDyOM
#'
#' This function calls ppidyom on arbitrary vectors of data,
#' or humdrumR data.
#' @export
ppidyom <- function(...) {
	UseMethod("ppidyom")

}


#' @exportS3Method
ppidyom.default <- function(...) {

	TRUE
}


#' @exportS3Method
ppidyom.humdrumR <- function(humdrumR, ...) {
	TRUE

}
