# ─────────────────────────────────────────────────────────────────────────────
# run_idyom.R — run IDyOM (Common Lisp, in Docker) for a list of parameter sets.
#
#   run_idyom(param_sets, data, config)  -> one list(IC, H, seconds, error, call) per parameter set
#
# Pieces are written to IDyOM one per line (symbols as integer cpitch values).
# All parameter sets without cached output go into ONE Lisp script, so Docker and
# IDyOM start once. Outputs are cached in <workdir>/<dataset>/<hash>/; delete
# that folder to re-run.
# ─────────────────────────────────────────────────────────────────────────────

idyom_available <- function(config) {
  found <- tryCatch(length(system2("docker", c("images", "-q", config$settings$idyom$image), stdout = TRUE, stderr = FALSE)) > 0,
                    error = function(e) FALSE, warning = function(w) FALSE)
  isTRUE(found)
}

to_lisp <- function(value) if (is.logical(value)) (if (isTRUE(value)) "t" else "nil") else as.character(value)

# Value of the parameter whose `idyom:` mapping is the given role (bias, log_base, resampling).
role_value <- function(param_set, config, role) {
  params <- Filter(function(param) identical(config$parameters[[param]]$idyom, role), names(param_set))
  if (length(params)) param_set[[params[1]]]
}

# The Lisp for one parameter set: set the bias, then (idyom:idyom ...).
idyom_lisp <- function(param_set, config, n_pieces, output_dir) {
  stm_options <- ltm_options <- character(0)
  for (param in names(param_set)) {
    mapping <- config$parameters[[param]]$idyom
    if (!is.list(mapping)) next
    value <- to_lisp(mapping$map[[as.character(param_set[[param]])]] %||% param_set[[param]])
    if (!is.null(mapping$stm) || !is.null(mapping$both)) stm_options <- c(stm_options, paste(mapping$stm %||% mapping$both, value))
    if (!is.null(mapping$ltm) || !is.null(mapping$both)) ltm_options <- c(ltm_options, paste(mapping$ltm %||% mapping$both, value))
  }
  models <- if (isTRUE(param_set$dynamic) && isTRUE(param_set$schematic)) "both" else if (isTRUE(param_set$dynamic)) "stm" else "ltm"
  leave_one_out <- identical(role_value(param_set, config, "resampling"), "piece")
  sprintf(paste0("(mvs:set-ltm-stm-bias %s)\n",
                 "(idyom:idyom 1 '(cpitch) '(cpitch) :models :%s :k %d%s :detail 3\n",
                 "  :stmo '(%s) :ltmo '(%s)\n",
                 "  :output-path \"%s/\" :overwrite t :use-resampling-set-cache? nil :use-ltms-cache? nil)"),
          format(role_value(param_set, config, "bias")), models, if (leave_one_out) n_pieces else 1L,
          if (!leave_one_out && models != "stm") " :pretraining-ids '(1)" else "",      # no CV: train on the same data
          paste(stm_options, collapse = " "), paste(ltm_options, collapse = " "), output_dir)
}

run_idyom <- function(param_sets, data, config) {
  settings <- config$settings$idyom
  # part of the cache key, so rebuilding the image (e.g. a new IDyOM) re-runs everything
  image_id <- suppressWarnings(system2("docker", c("image", "inspect", "--format", "{{.Id}}", settings$image), stdout = TRUE, stderr = FALSE))
  if (!length(image_id)) stop("can't read Docker image '", settings$image, "': is Docker running and the image built?")
  root     <- config$root                                    # mounted in Docker as /work
  work_dir <- file.path(settings$workdir, data$name)          # relative to root
  dir.create(file.path(root, work_dir), recursive = TRUE, showWarnings = FALSE)

  alphabet <- unique(data$symbols)
  cpitch   <- match(data$symbols, alphabet) + settings$pitch_offset
  pieces   <- vapply(split(cpitch, data$piece), paste, "", collapse = " ")
  writeLines(pieces, file.path(root, work_dir, "pieces.txt"))

  # one output folder per distinct (Lisp call, data)
  jobs <- lapply(param_sets, function(param_set) {
    cache_key  <- substr(rlang::hash(list(idyom_lisp(param_set, config, length(pieces), ""), pieces, image_id)), 1, 16)
    output_dir <- file.path(work_dir, cache_key)
    list(output_dir = output_dir, lisp = idyom_lisp(param_set, config, length(pieces), file.path("/work", output_dir)))
  })

  # run every job without a cached .dat in one Docker session
  jobs_to_run <- Filter(function(job) !length(Sys.glob(file.path(root, job$output_dir, "*.dat"))), jobs)
  if (length(jobs_to_run)) {
    timed_lisp <- vapply(jobs_to_run, function(job) {
      dir.create(file.path(root, job$output_dir), showWarnings = FALSE)
      sprintf(paste0('(let ((t0 (get-internal-real-time)))\n',
                     '  (handler-case (progn %s)\n',
                     '    (error (e) (with-open-file (f "/work/%s/error.txt" :direction :output :if-exists :supersede) (format f "~a" e))))\n',
                     '  (with-open-file (f "/work/%s/seconds.txt" :direction :output :if-exists :supersede)\n',
                     '    (format f "~f" (/ (- (get-internal-real-time) t0) internal-time-units-per-second))))'),
              job$lisp, job$output_dir, job$output_dir)
    }, "")
    writeLines(c("(start-idyom)", sprintf('(idyom-db:import-data :txt "/work/%s/pieces.txt" "param suite" 1)', work_dir), timed_lisp, "(quit)"),
               file.path(root, work_dir, "compute.lisp"))
    docker_log <- suppressWarnings(system2("docker", c("run", "--rm", "-v", paste0(shQuote(root), ":/work"), "-w", "/work", settings$image,
                                                       "sbcl", "--dynamic-space-size", settings$dynamic_space_mb, "--noinform", "--non-interactive",
                                                       "--load", file.path("/work", work_dir, "compute.lisp")), stdout = TRUE, stderr = TRUE))
    writeLines(docker_log, file.path(root, work_dir, "docker.log"))
  }

  # read results back; IDyOM reports bits, convert to the parameter set's log base
  Map(jobs, param_sets, f = function(job, param_set) {
    output_dir  <- file.path(root, job$output_dir)
    read_output <- function(file) if (file.exists(file.path(output_dir, file))) readLines(file.path(output_dir, file), warn = FALSE)
    seconds  <- as.numeric(read_output("seconds.txt") %||% NA)
    dat_file <- Sys.glob(file.path(output_dir, "*.dat"))
    if (!length(dat_file))
      return(list(error = paste(read_output("error.txt") %||% "no IDyOM output (see docker.log)", collapse = " "), seconds = seconds, call = job$lisp))
    idyom_output <- utils::read.table(dat_file[1], header = TRUE, check.names = FALSE)
    idyom_output <- idyom_output[order(idyom_output$melody.id, idyom_output$note.id), ]
    if (!identical(as.numeric(idyom_output$cpitch), as.numeric(cpitch)))
      return(list(error = "IDyOM output does not line up with the input", seconds = seconds, call = job$lisp))
    bits_to_log_base <- log(2) / log(as.numeric(role_value(param_set, config, "log_base") %||% 2))
    list(IC = idyom_output[["cpitch.ic"]] * bits_to_log_base, H = idyom_output[["cpitch.entropy"]] * bits_to_log_base,
         seconds = seconds, call = job$lisp)
  })
}
