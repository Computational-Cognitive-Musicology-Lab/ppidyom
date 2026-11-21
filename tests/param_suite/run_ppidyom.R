# ─────────────────────────────────────────────────────────────────────────────
# run_ppidyom.R — run ppidyom() for one parameter set.
#
#   run_ppidyom(param_set, data, config)
#     param_set: named list, parameter -> value (from make_param_sets() in compare.R)
#     data:      list(name, symbols, piece = piece number per event)
#     config:    load_config()
#   -> list(IC, H, seconds, error, call)
# ─────────────────────────────────────────────────────────────────────────────

# The arguments for ppidyom(), as a list for do.call()
ppidyom_args <- function(param_set, data, config) {
  args        <- list(data$symbols)
  model_lists <- list(dynamic = list(), schematic = list())
  for (param in names(param_set)) {
    info <- config$parameters[[param]]
    if (is.null(info$ppidyom)) next
    value <- param_set[[param]]
    if (identical(info$type, "grouping")) value <- if (value == "piece") data$piece else NULL   # none = leave unset
    target <- strsplit(info$ppidyom, "$", fixed = TRUE)[[1]]        # "maxN" or c("dynamic", "escape")
    if (length(target) == 1) args[target] <- list(value)
    else if (!is.null(value)) model_lists[[target[1]]][[target[2]]] <- value
  }
  args$dynamic   <- if (isTRUE(param_set$dynamic))   model_lists$dynamic   else FALSE
  args$schematic <- if (isTRUE(param_set$schematic)) model_lists$schematic else FALSE
  args
}

run_ppidyom <- function(param_set, data, config) {
  args <- ppidyom_args(param_set, data, config)
  format_arg <- function(value) if (is.list(value)) paste0("list(", paste(names(value), vapply(value, format_arg, ""), sep = " = ", collapse = ", "), ")")
                                else if (length(value) > 5) "<groups>" else deparse(value)
  call <- paste0("ppidyom(x, ", paste(names(args)[-1], vapply(args[-1], format_arg, ""), sep = " = ", collapse = ", "), ")")
  start_time <- proc.time()[["elapsed"]]
  result <- tryCatch({ utils::capture.output(output <- suppressWarnings(do.call(ppidyom::ppidyom, args))); output },
                     error = function(e) e)
  seconds <- proc.time()[["elapsed"]] - start_time
  if (inherits(result, "error")) return(list(error = conditionMessage(result), seconds = seconds, call = call))
  list(IC = result$IC, H = result$H, seconds = seconds, call = call)
}
