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
lag_matrix <- function(x, N = 3, stmGroups = integer(length(x)), ltmGroups = integer(length(x)), alphabet = sort(unique(x)), includeStart = TRUE) {

	alphabetCheck(x, alphabet)

	lag_matrix <- data.table(Event = x, stmGroups = stmGroups, ltmGroups = ltmGroups)
	
	lags <- paste0('Lag', 1:N)

	lag_matrix[ , c(lags) := lapply(1:N, \(n) data.table::shift(Event, n)), by = .(stmGroups, ltmGroups)]

	if (!includeStart) lag_matrix <- lag_matrix[!is.na(lag_matrix[[paste0('Lag', N)]])]

	lag_matrix[, index := 1:nrow(lag_matrix)]
	

	setattr(lag_matrix, 'modelPar', list(alphabet = alphabet, N = N)) 

  lag_matrix[]

}

lag_matrix_Xvalidate <- function(lag_matrix) {

	cols <- setdiff(colnames(lag_matrix), 'ltmGroups')
	lag_matrix[ , lag_matrix[ltmGroups != .BY$ltmGroups, cols, with = FALSE], by = ltmGroups]
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



cumgroup <- function(xs, groups, fun = cumsum) {
	# this function assumes the xs is already sorted by groups
	groupid <- rleidv(groups)
	change <- which(diff(groupid) != 0L)

	offset <- integer(length(groupid))

	Ces <- lapply(xs, 
									 \(x) {
											counts <- fun(x)
									    offset[change + 1L] <- counts[change]
											Ce <- (counts - cummax(offset)) 
											# it doesn't work to just subtract 1, I don't remember why. You have to do this instead:
											Ce <- c(0L, head(Ce, -1L))
											Ce[change + 1L] <- 0L # this makes the zero-padded index shift within each group
											Ce


									 })
	Ces


	# Ce

}

t1 <- function(countN, lags) {
	setorderv(countN, c('Event', lags, 'index'))

	groupid <- countN[, rleidv(.SD), .SDcols = c('Event', lags)]
	change <- which(diff(groupid) != 0L)
	offset <- integer(nrow(countN))

	seq <- seq_along(offset)
	offset[change + 1L] <- seq[change]

	#countN[ , rank := { rank <- c(0L, head(seq - cummax(offset), -1L))
	#			              rank[change + 1L] <- 0
	#										rank}]
	countN[ , rank := { (seq - cummax(offset)) }]

	setorderv(countN, 'index')
	countN[ , t1 := c(0L, head(cumsum((rank == 1L) - (rank == 2L)), -1L)), by = lags]
	countN[ , rank := NULL]

}




stm_counts <- function(lag_matrix, update_exclusion = TRUE, needt1 = FALSE) {

	par        <- modelPar(lag_matrix)

	counts <- vector('list', length(par$N) + 1L)

	lag_matrix[, EventMutable := Event]
	# EventMutable starts the same as Event, but if update_exclusion = TRUE, on each pass some events are set to "" (excluding them from later pass)

  full_matrix <- lag_matrix[CJ(index, Sym = Event, unique = TRUE), on = c('index')] 
	for (n in (par$N):0) {


    if (n == par$N || n == 0L) {
			curmatrix <- full_matrix
		} else { 
			curmatrix <- lag_matrix
			curmatrix[ , Sym := Event]
		}
		lags <- if (n > 0) paste0('Lag', 1:n)

		setorderv(curmatrix, c('Sym', 'stmGroups', lags, 'index'))

		curmatrix[, Ce := cumgroup(list(Sym == EventMutable), .SD), .SDcols = c('Sym', 'stmGroups', lags)]
		
		# now get C, t, and (maybe) t1
		if (n == par$N || n == 0L) {
			curmatrix[ , c('C', 't', 't1') := list(sum(Ce), sum(Ce > 0L), sum(Ce == 1L)), by = c('index')]

		} else {
				setorderv(curmatrix, c('stmGroups', lags, 'index'))
				curmatrix[ , c('C','t') := cumgroup(list(EventMutable != '', !duplicated(cbind(EventMutable, .SD)) & EventMutable != ''), .SD), .SDcols = c('stmGroups', lags)]
			if (needt1) t1(curmatrix, lags)
		}

		if (n > 0L && update_exclusion) curmatrix[Ce > 0L, EventMutable := '']

		setorderv(curmatrix, c('index', 'Sym'))
		counts[[n + 1L]] <- curmatrix[ , .SD, .SDcols = c('stmGroups','Event', 'Sym', 'index', 'C','t', if (needt1) 't1','Ce', lags)]

	}

	par$model_type <- 'stm'
	par$update_exclusion_counts <- update_exclusion
	setattr(counts, 'modelPar', par)
	counts

}





ltm_counts <- function(lag_matrix, update_exclusion = TRUE) {

	par      <- modelPar(lag_matrix)
	alphabet <- par$alphabet
	lags     <- paste0('Lag', 1:par$N)

	ltm <- lag_matrix[, .(Ce = tabulate(match(Event, alphabet), nbins = length(alphabet)),
	                       Sym = alphabet),
	                   by = c(lags, 'ltmGroups')]
	setcolorder(ltm, c('ltmGroups', 'Sym', 'Ce', lags))

	par$update_exclusion_counts <- update_exclusion
	par$model_type <- 'ltm'
	setattr(ltm, 'modelPar', par)
	ltm

}


ltm_totals <- function(counts) {
	par <- modelPar(counts)
	
	lags <-  if (par$N > 0L) paste0('Lag', 1:par$N)

	counts[ , c('C', 't', 't1') := list(C = sum(Ce), t = sum(Ce > 0), t1 = sum(Ce == 1L)), by = c('ltmGroups', lags)]
	counts[]

	counts

}


ltm_crossValidate <- function(counts) {
	if (length(unique(counts$ltmGroups)) == 1L) return(counts)

	par  <- modelPar(counts)
	lags <- paste0('Lag', 1:par$N)

	setorderv(counts, c('Sym', lags, 'ltmGroups'))
	counts[ , contextID := rleidv(.SD), .SDcols = c('Sym', lags)] # precomputing the grouping ID once helps speed. Using rleidv workds because of the previous sort
	#counts[ , contextID := .GRP, by = c('Sym', lags)]

	cat('cross validating across', length(unique(counts$ltmGroups)), 'schematic groups...')

	total <- counts[, .(Ce_total = sum(Ce)), by = contextID]
	total <- total[Ce_total > 0]


	counts[total, Ce := Ce_total - Ce, on = 'contextID']
	counts[, contextID := NULL]
	setorderv(counts, c('ltmGroups', lags, 'Sym'))

	par$crossValidated <- TRUE
	setattr(counts, 'modelPar', par)
	counts[]

}




ltm2dynamic_counts <- function(ltmP, lag_matrix) {
	par       <- modelPar(ltmP)
	lags      <- if (par$N > 0L) paste0('Lag', 1:par$N)


	result <- ltmP[
		lag_matrix[, c('index', 'Event', 'ltmGroups', lags), with = FALSE],
		on = c('ltmGroups', lags),
		allow.cartesian = TRUE
	]

	par$alphabet <- union(modelPar(lag_matrix)$alphabet, par$alphabet)
	result <- result[P > 0 | Sym == Event, .(index, Event, Sym, P)]
	setattr(result, 'modelPar', par)
	result
}


