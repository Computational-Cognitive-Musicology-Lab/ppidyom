# Does ppidyom match IDyOM?

Runs `ppidyom()` and IDyOM with the same parameters and compares the
information content (IC) and entropy (H) of every event.

## Files

| File | What it does |
|---|---|
| `config.yaml` | **Edit this.** The parameters, the values to try, how each one is passed to `ppidyom()` and to IDyOM, the datasets, and the settings. |
| `run_ppidyom.R` | `run_ppidyom(param_set, data, config)`: runs `ppidyom()` with one parameter set. |
| `run_idyom.R` | `run_idyom(param_sets, data, config)`: runs IDyOM (in Docker) with many parameter sets at once. |
| `compare.R` | Loads the config and data, builds the parameter sets, runs both, and compares them (`compare_suite()`). Also has the two helpers the tests use. |
| `../testthat/test-idyom-match.R` | testthat: each parameter on its own (+ every pair). |
| `../testthat/test-idyom-random-fuzz.R` | testthat: random parameter sets. |

A **parameter set** is one combination of values, e.g.
`list(maxN = 1, dynamic.escape = "A", ...)`. Each run takes one dataset and many
parameter sets; each `run_*` returns IC, H, seconds and the exact call for each.

## Where to find things

| What | Where |
|---|---|
| Parameters, values, datasets | `config.yaml` |
| Every parameter set in the last run, with its verdict | `results/<mode>/summary.csv` (one row per dataset × parameter set) |
| The exact `ppidyom()` call and IDyOM Lisp for each parameter set | `results/<mode>/calls.txt` |
| IC and H of every event, ppidyom next to IDyOM | `results/<mode>/events.csv` (filter by `param_set`) |
| IDyOM's raw output and Docker log | `_idyom_work/<dataset>/<hash>/*.dat`, `_idyom_work/<dataset>/docker.log` |
| The parameter sets of a mode, without running anything | `make_param_sets(load_config(), "single")` |

`<mode>` is `single`, `pairwise` or `random`. Every `compare_suite()` call,
including the testthat runs, overwrites `results/<mode>/`. `results/` and
`_idyom_work/` are not in git.

## Setup (once)

1. R packages, from the repo root: `devtools::install_dev_deps()`
   (installs humdrumR from GitHub, see `Remotes:` in `DESCRIPTION`).
2. Install [Docker](https://docs.docker.com/get-docker/), start it, and build
   the IDyOM image (a few minutes; the IDyOM version is pinned in
   `inst/validation/Dockerfile`):

   ```sh
   docker build -t ppidyom-idyom-validation inst/validation
   ```

Without Docker or the image, the tests are skipped, not failed.
IDyOM outputs are cached in `_idyom_work/<dataset>/<hash>/`, so only new
parameter sets start Docker. The hash includes the image ID, so a rebuilt image
re-runs everything. Delete `_idyom_work/` to clear the cache.

## Running

With testthat, from the repo root:

```r
devtools::test(filter = "idyom-match")      # each parameter on its own

Sys.setenv(PPIDYOM_PAIRWISE = "true")       # also run the pairwise sets (slower)
devtools::test(filter = "idyom-match")      # + every pair of parameters

Sys.setenv(PPIDYOM_RANDOM_N = "20")         # 20 random parameter sets, a new draw each run
devtools::test(filter = "idyom-random")     # the seed is in the test name; PPIDYOM_RANDOM_SEED repeats a draw
```

The datasets each mode uses are `settings$test_datasets` in `config.yaml`.
Each parameter set is one expectation, so each failure names it:

```
[toy] maxN=1: MISMATCH (max IC error 1.12)
[harm_small] dynamic.escape=X: ppidyom: <the error message>
```

From R, to look at the numbers:

```r
devtools::load_all()
source("tests/param_suite/compare.R", chdir = TRUE)

results <- compare_suite("single", datasets = c("toy", "harm_small"))
results[verdict != "MATCH", .(dataset, param_set, verdict, ic_max_error, message)]
compare_suite("single", "toy", params_to_vary = c("maxN", "dynamic.escape"))   # vary only these
compare_suite("single", "toy", only_values = list(maxN = 1:3))                 # try only these values
compare_suite("pairwise", "toy")
compare_suite("random", "toy", n_random = 50)                                  # every parameter at a random value

# one parameter set by hand
config <- load_config(); data <- load_data("toy", config)
param_set <- make_param_sets(config)[[1]]              # the baseline
ppidyom_result <- run_ppidyom(param_set, data, config)
idyom_result   <- run_idyom(list(param_set), data, config)[[1]]
data.table(symbol = data$symbols, ppidyom = ppidyom_result$IC, idyom = round(idyom_result$IC, 3))
ppidyom_result$call; cat(idyom_result$call)           # the exact ppidyom() call and IDyOM Lisp
```

Verdicts: `MATCH` (IC and H within `tolerance`, 1e-3 because ppidyom rounds
to 3 decimals) · `IC MATCH, H DIFFERS` · `MISMATCH` · `ERROR` (`message` says
which side failed).

## Changing the tests

- **Add a value:** append it to the parameter's `values:` in `config.yaml`.
- **Add a parameter:** add an entry to `config.yaml` with `default`, `values`,
  `ppidyom:` (`argName` or `dynamic$argName` / `schematic$argName`) and
  `idyom:` (`{stm: ":key"}`, `{ltm: ":key"}` or `{both: ":key"}`, optional
  `map:`). Nothing else changes.
- **Add a dataset:** add it under `datasets:`, either as `sequences:` (one
  string per piece, one character per event) or as a humdrum corpus:
  `corpus:` (folder of humdrum files), `spine_index:`, `n_pieces:`, and optionally
  `symbol_regex:` (part of each token to keep) and `file_pattern:` (default `.*.hum`). To test on it, add its name to `settings$test_datasets`.
- **A new kind of IDyOM option** (not a key in `:stmo`/`:ltmo`): handle it in
  `idyom_lisp()` in `run_idyom.R`.

## What IDyOM can't express

Only values IDyOM has an equivalent for are listed in `config.yaml`:
`dynamic.groupby` is always `piece` (IDyOM resets its STM after every piece),
`schematic.start_token` is always `FALSE`, and there is no extended alphabet or
second input.

