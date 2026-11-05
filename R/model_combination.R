# combining stm and ltm models


combine_P <- function(P1, P2, b = 1, base = 2) {
	if (is.null(P2)) return(P1)
	if (is.null(P1)) return(P2)

	par1 <- modelPar(P1)
	par2 <- modelPar(P2)
	if (uniqueN(P1$index) != uniqueN(P2$index))   stop("combine_P(): index counts don't match.")


	#maxHpossible <- log(max(length(par1$alphabet), length(par2$alphabet)), 2)
	maxHpossible <- log(length(par1$alphabet) * length(par2$alphabet), 2)

	H_1 <- (get_H(P1) / maxHpossible)^(-b)
	H_2 <- (get_H(P2) / maxHpossible)^(-b)

	H_sum <- H_1 + H_2
	H_1 <- H_1 / H_sum
	H_2 <- H_2 / H_sum

	same_alphabet <- setequal(par1$alphabet, par2$alphabet)

	if (same_alphabet) {
		P <- P1[P2, on = .(index, Sym), nomatch = 0]
	} else {
		P <- P1[P2, on = 'index', allow.cartesian = TRUE]
		P[, Sym   := paste(Sym,   i.Sym)]
		P[, Event := paste(Event, i.Event)]
	}

	P[, P := fcase(i.P == 0, P,
	               P    == 0, i.P,
	               default = P^H_1[index] * i.P^H_2[index])]
	P[, c('i.P', 'i.Event', if (!same_alphabet) 'i.Sym') := NULL]

	P[ , rawSums := sum(P), by = index]
	P[ , dontNormalize := rawSums > 0.999 & rawSums < 1.0]
	P[dontNormalize == FALSE, P := P / rawSums]

	result <- P[, .(P, Event, Sym, index)]
	par <- par1
	if (!same_alphabet) par$alphabet <- do.call('paste', expand.grid(par1$alphabet, par2$alphabet))
	setattr(result, 'modelPar', par)
	result

}


if (FALSE) {


pitch <- rep(c('c','d','e'), 10)
rhythm <- rep(c('4','8','8'), 10)


both <- ppidyom(pitch, rhythm, schematic=F, maxN=3)$P
rr <- ppidyom(rhythm, schematic=FALSE, maxN = 3)$P
pp <- ppidyom(pitch, schematic=FALSE,maxN=3)$P


plot(both, ylim =c(0,1),type='l')

points(rr, col = 'red', type = 'l')
points(pp, col = 'blue', type = 'l')
}
