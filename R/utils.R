# setwd("/Users/ling/Desktop/ppidyom")

# Right now, it runs on all sequences provided by training on the remaining as LTM.
run_ppidyom <- function(
    seq_list,
    N,
    alphabet = NULL,
    model_type = c("stm", "ltm", "both", "ltm+", "both+"),
    ppm_type = c("interpolation", "backoff"),
    lambda = "C",
    b = 1
){
  model_type <- match.arg(model_type)
  ppm_type <- match.arg(ppm_type)

  if (is.null(alphabet)) {
    alphabet <- unique(unlist(seq_list, use.names = FALSE))
  }
  model <- ppidyom$new(N = N, alphabet = alphabet)

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
      lambda = lambda,
      b = b
    )
    pred[, seq_id := i]
    results_list[[i]] <- pred

    if(has_ltm) {
      model$train_sequence(x)
    }
  }

  results_list
  # rbindlist(results_list)
}

# ---------------------------
# Example sequence
# ---------------------------
library(humdrumR)

kern_files <- readHumdrum("tests/data/kern/*.krn")
kern_files |> select(Token) |> pitch()

seq_df <- kern_files |>
  midi() |>
  group_by(Piece) |>
  summarise(seq = list(as.character(Midi)))
seq_list <- seq_df$seq
attributes(seq_list) <- NULL

run_ppidyom(
  seq_list,
  max_order,
  # alphabet,
  model_type = "both",
  ppm_type = "interpolation",
  lambda = "C",
  b = 1
)

run_ppidyom(
  seq_list,
  max_order,
  # alphabet,
  model_type = "ltm",
  ppm_type = "interpolation",
  lambda = "C",
  b = 1
)


seq1 <- c("A", "B", "A", "C", "A", "B", "A", "C", "A")
seq2 <- c("A", "B", "C", "A", "B", "C", "A", "B", "C")
seq3  <- c("B", "A", "B", "C", "A")

alphabet <- c("A", "B", "C")
max_order <- 3

run_ppidyom(
  list(seq1, seq2, seq3),
  max_order,
  alphabet,
  model_type = "both",
  ppm_type = "interpolation",
  lambda = "C",
  b = 1
)
