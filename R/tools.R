alphabetCheck <- function(x, alphabet) {
	if (length(setdiff(k, alphabet))) {
		bad <- setdiff(k, alphabet)
		stop(call. = FALSE, 
				 paste0("Your input sequence includes ", length(bad),
								" unique values that are not present in the alphabet you have indicated.",
								if (length(bad) <= 10) "These values are: " else "These values include: ", 
								paste(bad[1:10], collapse = ', ')))
	}
}
