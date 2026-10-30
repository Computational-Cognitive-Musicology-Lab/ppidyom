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


	for (n in (par$N):0) {


    if (n == par$N) {
			curmatrix <- lag_matrix[CJ(index, Sym = Event, unique = TRUE), on = c('index')] 
		} else { 
			curmatrix <- lag_matrix
			curmatrix[ , Sym := Event]
		}
		lags <- if (n > 0) paste0('Lag', 1:n)

		setorderv(curmatrix, c('Sym', 'stmGroups', lags, 'index'))

		curmatrix[, Ce := cumgroup(list(Sym == EventMutable), .SD), .SDcols = c('Sym', 'stmGroups', lags)]
		
		# now get C, t, and (maybe) t1
		if (n == par$N) {
			curmatrix[ , c('C', 't', 't1') := list(sum(Ce), sum(Ce > 0L), sum(Ce == 1L)), by = c('stmGroups', 'index')]

		} else {
				setorderv(curmatrix, c('stmGroups', lags, 'index'))
			if (n == 0L && length(unique(curmatrix$stmGroups)) == 1L) {
				curmatrix[ , c('C', 't') := list(cumsum(EventMutable != '') - 1L, 
																				 c(0L, head(cumsum(!duplicated(EventMutable)), -1L)))]
			} else { 
				curmatrix[ , c('C','t') := cumgroup(list(EventMutable != '', !duplicated(cbind(EventMutable, .SD)) & EventMutable != ''), .SD), .SDcols = c('stmGroups', lags)]
			}
			if (needt1) t1(curmatrix, lags)
		}

		if (n > 0L && update_exclusion) curmatrix[Ce > 0L, EventMutable := '']

		setorderv(curmatrix, c('index', 'Sym'))
		counts[[n + 1L]] <- curmatrix[ , .SD, .SDcols = c('stmGroups','Event', 'Sym', 'index', 'C','t', if (needt1) 't1','Ce', lags)]

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
	
		if (n == par$N) {
			ltm <- lag_matrix[ , list(Ce = tabulate(match(Event, alphabet), nbins = length(alphabet)), Event = alphabet), by = c(lags, 'ltmGroups')]
		} else {
			ltm <- lag_matrix[ , list(Ce = .N), by = c('Event', lags, 'ltmGroups')]
		}

		if (n > 0L && update_exclusion) lag_matrix <- lag_matrix[ , .SD[1], by = c('Event', 'ltmGroups', lags)]

		setnames(ltm, 'Event', 'Sym')
		setcolorder(ltm, c('ltmGroups', 'Sym', 'Ce', lags))

		counts[[n + 1L]] <- ltm[]
	
	}
	structure(counts, class = 'ltm_counts', update_exclusion = update_exclusion, modelPar = par)


}




ltm_collapseGroups <- function(counts) {
	par <- modelPar(counts)

	ngroups <- max(counts[[1]]$ltmGroups)
	if (ngroups == 1L) return(counts)

  for (n in 0:(par$N)) {
			lags <- if (n > 0) paste0('Lag', 1:n)

			countsN <- counts[[n + 1]][ , list(Ce = sum(Ce), ltmGroups = 1L), by = c('Sym', lags)]
			nr <- nrow(countsN)
			countsN <- countsN[rep(1:nr, ngroups)]
			countsN[ , ltmGroups := rep(1:ngroups, each = nr)]

			counts[[n + 1L]] <- countsN
	}
	ltm_totals(counts)
		
}

ltm_totals <- function(counts) {
	par <- modelPar(counts)
	

  for (n in 0:(par$N)) {
			lags <- if (n > 0) paste0('Lag', 1:n)

			countsN <- counts[[n + 1L]]
			countsN[ , c('C', 't', 't1') := list(C = sum(Ce), t = sum(Ce > 0), t1 = sum(Ce == 1L)), by = c('ltmGroups', lags)]

			
			
	}
	counts

}

ltm_crossValidate <- function(counts) {
	par <- modelPar(counts)
	alphaN <- length(par$alphabet)

	ngroups <- max(par$ltmGroups)
	if (ngroups == 1L) return(counts)


  for (n in 0:(par$N)) {
			lags <- if (n > 0L) paste0('Lag', 1:n)


			countsN <- counts[[n + 1L]]
			new <- lapply(1:ngroups, \(G) countsN[, list(ltmGroups = G, Ce = sum(Ce * (ltmGroups != G))), by = c('Sym', lags)])
			#new <- lapply(1:ngroups, \(G) countsN[ltmGroups != G, list(ltmGroups = G, Ce = sum(Ce)), by = c('Sym', lags)])
			new <- rbindlist(new)
			setorder(new, ltmGroups)

			counts[[n + 1L]] <- new
	}

	counts

}

ltm_crossValidatex <- function(counts) {
	par <- modelPar(counts)
	alphaN <- length(par$alphabet)

	if (length(unique(counts[[1]]$ltmGroups)) == 1L) return(counts)

	full <- ltm_collapseGroups(counts)

  for (n in 0:(par$N)) {
			lags <- if (n > 0L) paste0('Lag', 1:n)


			new <- counts[[n + 1L]][full[[n + 1L]], on = c('ltmGroups', 'Sym', lags), c(list(ltmGroups = ltmGroups), .SD, list(Ce = i.Ce - Ce, C = i.C - C, 
																																																						t = getOther_t(t, ltmGroups), 
																																																						t1 = getOther_t1(t1, ltmGroups))), .SDcols = c('Sym', lags)]
			browser()
			setorder(new, ltmGroups)

			counts[[n + 1L]] <- new
	}

	counts

}

getOther_t <- function(t, ltmGroups) prestmax(t[!duplicated(ltmGroups)])[ltmGroups]
getOther_t1 <- function(t, ltmGroups) prestmin(t[!duplicated(ltmGroups)])[ltmGroups]

prestmin <- function(x) {

	m <- sort(x, partial = 1:2) # minimum and second minimum are 1 and 2
	ifelse(x == m[1], m[2], m[1])
}
prestmax <- function(x) {

	n <- length(x)
	m <- sort(x, partial = c(n - 1L, n))[c(n, n - 1L)] # largest and second largest
	ifelse(x == m[1], m[2], m[1])
}


ltm2index <- function(ltm_p, lag_matrix) {
	par <- modelPar(lag_matrix)

	lags <- paste0('Lag', 1:(par$N))


	ltm_p[lag_matrix, on = c(Sym = "Event", "ltmGroups", lags)]
	
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


