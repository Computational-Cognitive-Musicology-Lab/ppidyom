library(data.table)

#' Generate Lagged N-gram Matrix
#'
#' Creates a lagged representation of a sequence for N-gram modeling,
#' grouped within blocks indicated in `...` vectors.
#'
#' @param x Character vector of symbols/events.
#' @param N Maximum N-gram order.
#' @param ... Zero or more grouping vectors.
#' @param includeStart Logical switch to include or exclude incomplete contexts at the start.
#'
#' @return A `data.table` with columns LagN..Event and index.
#' @examples
#' lag_matrix(c("A", "B", "A", "C", "A"), N = 2)
#' @export
lag_matrix <- function(x, N = 3, ltmGroups = integer(length(x)), alphabet = sort(unique(x)), includeStart = TRUE) {

	alphabetCheck(x, alphabet)

	lag_matrix <- data.table(Event = x, ltmGroups = ltmGroups)
	
	lags <- paste0('Lag', 1:N)

	lag_matrix[ , c(lags) := lapply(1:N, \(n) data.table::shift(Event, n)), by = ltmGroups]

	if (!includeStart) lag_matrix <- lag_matrix[!is.na(lag_matrix[[paste0('Lag', N)]])]

	lag_matrix[, index := 1:nrow(lag_matrix)]
	

	setattr(lag_matrix, 'modelPar', list(alphabet = alphabet, ltmGroups = ltmGroups, N = N)) 

  lag_matrix[]

}


modelPar <- function(obj) attr(obj, 'modelPar')


shortestDeterm <- function(x, maxN = length(x), alphabet = sort(unique(x))) { 

		lag_matrix <- data.table(Event = x, inde = seq_along(x))
	

		deterministic <- rep(length(unique(x)) == 1L, length(x))
	  Ce_cols <- paste0('Ce.', alphabet)
	  lag_matrix[, c(Ce_cols) := 0L]

		counts <- list()
		N <- 1
		while (any(!deterministic) & N <= maxN) {
				lags <- paste0('Lag', 1:N) 
			  curlag <- paste0('Lag', N)

				lag_matrix[ , (curlag) := data.table::shift(x, N)]
				cur <- data.table::copy(lag_matrix)

		    cur[ , c(Ce_cols) := lapply(alphabet, \(sym) c(0L, head(cumsum(sym == Event), -1L))), by = lags]

		    cur[ , c('C', 't', 't1') := list(rowSums(.SD), rowSums(.SD > 0L), rowSums(.SD == 1L)), .SDcols = Ce_cols]

				deterministic <- cur[, t == 1L]

				counts[[N]] <- cur
				N <- N + 1

				lag_matrix[deterministic == TRUE, Event := "" ]

		}

		counts



}



## model counts ----



cumgroup <- function(x, groups) {

	groupid <- rleidv(groups)
	change <- which(diff(groupid) != 0L)

	counts <- cumsum(x)
	offset <- integer(length(counts))

	offset[change + 1L] <- counts[change]

	Ce <- counts - cummax(offset)

	Ce <- c(0L, head(Ce, -1L))
	Ce[change + 1L] <- 0L # this makes the zero-padded index shift within each group

	Ce 

}




stm_counts <- function(lag_matrix, update_exclusion = TRUE) {

	par        <- modelPar(lag_matrix)

	counts <- vector('list', length(par$N) + 1L)

	lag_matrix[, EventMutable := Event]
	# EventMutable starts the same as Event, but if update_exclusion = TRUE, on each pass some events are set to "" (excluding them from later pass)

	expanded <- lag_matrix[CJ(index, Sym = Event, unique = TRUE), on = 'index']

	for (n in (par$N):0) {


		lags <- if (n > 0) paste0('Lag', 1:n)

		setorderv(expanded, c('Sym', lags, par$groupingFactors, 'index'))

		expanded[, Ce := cumgroup(Sym == EventMutable, .SD), .SDcols = c('Sym', lags, par$groupingFactors)]

		if (n > 0L && update_exclusion) expanded[Ce > 0L, EventMutable := '']

		expanded[ , c('C', 't', 't1') := list(sum(Ce), sum(Ce > 0L), sum(Ce == 1L)), by = index]

			

		counts[[n + 1L]] <- expanded[ , .SD, .SDcols = c('Event', 'Sym', 'index', par$groupingFactors, 'C','t','t1','Ce', lags)]

	}

	structure(counts, class = 'stm_counts', update_exclusion = update_exclusion, modelPar = par)

}





ltm_counts <- function(lag_matrix,  update_exclusion = TRUE) {

	par <- modelPar(lag_matrix)

	counts <- vector('list', length(par$N) + 1L)

	alphabet <- par$alphabet
	tmp <- integer(length(alphabet))

	for (n in (par$N):0) {
		lags <- if (n > 0) paste0('Lag', 1:n)
	
		ltm <- lag_matrix[ , list(Ce = .N), by = c('Event', lags, 'ltmGroups')]


		if (n > 0L && update_exclusion) lag_matrix <- lag_matrix[ , .SD[1], by = c('Event', 'ltmGroups', lags)]


		ltm[ , c('C', 't', 't1') := list(sum(Ce), sum(Ce > 0L), sum(Ce == 1L)), by = c(lags, 'ltmGroups')]

		setnames(ltm, 'Event', 'Sym')
		setcolorder(ltm, c('ltmGroups', 'Sym', 'C', 't', 't1', 'Ce', lags))

		counts[[n + 1L]] <- ltm[]
	
	}
	structure(counts, class = 'ltm_counts', update_exclusion = update_exclusion, modelPar = par)

}



ltm_collapseGroups <- function(counts) {
	par <- modelPar(counts)

	if (length(par$groupingFactors) == 0L) return(counts)

  for (n in 0:(par$N)) {
			lags <- if (n > 0) paste0('Lag', 1:n)

			counts[[n + 1]] <- counts[[n + 1]][ , list(Ce = sum(Ce)), by = c('Event', lags)]
	}
	par$groupingFactors <- NULL
	setattr(counts, 'modelPar', par)
	counts
		
}


ltm2dynamic_counts <- function(counts, lag_matrix) {
	#counts <- ltm_cast(counts)
	par <- modelPar(counts)

	new_counts <- list()

	for (n in 0:(par$N)) {

		if (n > 0) {
			lags <- paste0('Lag', 1:n)
			new <- counts[[n + 1L]][lag_matrix[ , c('Event', 'index', lags), with = FALSE],  on = (lags), allow.cartesian = TRUE] 

		} else {
			lags <- NULL
			new <- counts[[n + 1L]][rep(1L:nrow(counts[[n + 1L]]), nrow(lag_matrix))]
			new[ , index := rep(lag_matrix$index, each = nrow(counts[[n + 1L]]))]
			new[ , Event := rep(lag_matrix$Event, each = nrow(counts[[n + 1L]]))]

		}
  
		setcolorder(new, unique(c('Event', 'Sym', 'index', colnames(counts[[n + 1L]]))))

	
		# get complete distribution for each index

		new <- new[CJ(index = unique(index), Sym = unique(Sym)), on = c('index', 'Sym')]
		setnafill(new, fill = 0L, cols = setdiff(colnames(new), c('Event', 'index', 'Sym', lags)))

		new_counts[[n + 1L]] <- new
	}
	
	par$alphabet <- union(modelPar(lag_matrix)$alphabet, par$alphabet)
	setattr(new_counts, 'modelPar', par)
	new_counts

	
}


