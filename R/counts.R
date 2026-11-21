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

	if (N > 0L) { # N = 0: no lags
	
		lags <- paste0('Lag', 1:N)

		lag_matrix[ , c(lags) := lapply(1:N, \(n) data.table::shift(Event, n)), by = .(stmGroups, ltmGroups)]

		if (!includeStart) lag_matrix <- lag_matrix[!is.na(lag_matrix[[paste0('Lag', N)]])]
	}

	# extra lag N+1: update exclusion at top order N needs the order N+1 context
	lag_matrix[ , (paste0('Lag', N + 1L)) := data.table::shift(Event, N + 1L), by = .(stmGroups, ltmGroups)]
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

	counts <- vector('list', par$N + 1L) # one table per order 0..N

	lag_matrix[, EventMutable := Event]
	# EventMutable starts the same as Event, but if update_exclusion = TRUE, on each pass some events are set to "" (excluding them from later pass)

	# IDyOM uses full counts at order N where the context one order up was seen before (update-exclusion)
	use_full_counts <- duplicated(lag_matrix, by = c('stmGroups', paste0('Lag', 1:(par$N + 1L))))
  	full_matrix <- lag_matrix[CJ(index, Sym = Event, unique = TRUE), on = c('index')]
	for (n in (par$N):0) {
    	curmatrix <- full_matrix # every order needs every symbol (they all escape to lower orders)
		lags <- if (n > 0) paste0('Lag', 1:n)

		# update exclusion (IDyOM): count an event only if the symbol is new after the context one order up
		if (update_exclusion) {
			new_after_longer_context <- !duplicated(lag_matrix, by = c('stmGroups', paste0('Lag', 1:(n + 1L)), 'Event'))
			curmatrix[ , EventMutable := fifelse(new_after_longer_context[index], Event, '')]
		}

		setorderv(curmatrix, c('Sym', 'stmGroups', lags, 'index'))

		curmatrix[, Ce := cumgroup(list(Sym == EventMutable), .SD), .SDcols = c('Sym', 'stmGroups', lags)]
		# If the order N+1 context was seen before, top order N uses full counts, not update-excluded (IDyOM's rule)
		if (n == par$N && update_exclusion) {
			curmatrix[ , Ce_full := cumgroup(list(Sym == Event), .SD), .SDcols = c('Sym', 'stmGroups', lags)]
			curmatrix[use_full_counts[index], Ce := Ce_full]
		}
		
		# now get C, t, and (maybe) t1
		curmatrix[ , c('C', 't', 't1') := list(sum(Ce), sum(Ce > 0L), sum(Ce == 1L)), by = c('index')]

		setorderv(curmatrix, c('index', 'Sym'))
		counts[[n + 1L]] <- curmatrix[ , .SD, .SDcols = c('stmGroups','Event', 'Sym', 'index', 'C','t', if (needt1) 't1','Ce', lags)]

	}

	par$model_type <- 'stm'
	par$update_exclusion_counts <- update_exclusion
	setattr(counts, 'modelPar', par)
	counts

}




ltm_counts <- function(lag_matrix, update_exclusion = TRUE, N = modelPar(lag_matrix)$N, start_token = FALSE, ends = FALSE) {
	par      <- modelPar(lag_matrix)
	alphabet <- par$alphabet
	lags     <- if (N > 0L) paste0('Lag', 1:N) # counts of order N contexts (the last N lags)
	crossValidate <- uniqueN(lag_matrix$ltmGroups) > 1L

	ltm <- lag_matrix[, .(Ce = tabulate(match(Event, alphabet), nbins = length(alphabet)),
	                       Sym = alphabet),
	                   by = c(lags, 'ltmGroups')]

	# update exclusion (IDyOM): a symbol counts once per distinct context one order up (each piece start its own), from the other groups
	if (update_exclusion) {
		units <- lag_matrix[ , c(lags, 'Event', 'ltmGroups', paste0('Lag', N + 1L)), with = FALSE]
		# An NA lag one order up means a piece start. .I is the row number, so each start gets its own unique label.
		setnames(units, ncol(units), 'Above')
		units[is.na(Above), Above := paste0('start', .I)]
		# A unit = (context, symbol, one-order-up context, group).
		units <- unique(units)
		units[ , shared := uniqueN(ltmGroups) > 1L, by = c(lags, 'Event', 'Above')]
		# Ce_ue = Total distinct one-order-up contexts per (context, symbol)
		ltm[units[ , .(Ce_ue = uniqueN(Above)), by = c(lags, 'Event')], on = c(lags, Sym = 'Event'), Ce_ue := i.Ce_ue]
		if (crossValidate) {
			# Leave-one-out = (distinct over all pieces) − (those that occur only in the held-out piece).
			ltm[
				units[shared == FALSE, .N, 
				by = c(lags, 'Event', 'ltmGroups')], on = c(lags, Sym = 'Event', 'ltmGroups'), 
				Ce_ue := Ce_ue - i.N
			]
		}
		ltm[is.na(Ce_ue), Ce_ue := 0L]
	}

	# IDyOM appends an end marker to each training piece, so the last context of a piece exists in its model even though no symbol follows it.
	if (ends) {
		last <- lag_matrix[lag_matrix[ , .I[.N], by = .(stmGroups, ltmGroups)]$V1]
		# The context after the last event: Lag1 = last Event, Lag2 = last Lag1, and so on.
		endContexts <- setnames(last[ , c('Event', head(lags, -1L), 'ltmGroups'), with = FALSE], c(lags, 'ltmGroups'))
		ltm[endContexts[ , .N, by = c(lags)], on = lags, nEnds := i.N]
		if (crossValidate) {
			ltm[
				endContexts[ , .N, by = c(lags, 'ltmGroups')], 
				on = c(lags, 'ltmGroups'), 
				nEnds := nEnds - i.N
			]
		}
		ltm[is.na(nEnds), nEnds := 0L]
	}
	
	# When user asks to match IDyOM which has no start-of-piece contexts, contexts with an NA lag (piece starts) get count 0 (either it's full count of update-exclusion count).
	if (!start_token && N > 0L) {
		ltm[!complete.cases(ltm[ , lags, with = FALSE]), intersect(c('Ce', 'Ce_ue'), names(ltm)) := 0L] # complete.cases() is TRUE for rows with no NA.
	}

	setcolorder(ltm, c('ltmGroups', 'Sym', 'Ce', lags))

	par$N <- N
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
	lags <-  if (par$N > 0L) paste0('Lag', 1:par$N)

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


