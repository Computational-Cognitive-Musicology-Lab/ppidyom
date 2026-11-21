# PPIDyOM — Developer Guide

Setup, building, and testing. For the package overview see [README.md](README.md).

---

## 1. Setup (once)

- **R ≥ 4.5** (see `DESCRIPTION`) and **devtools**: `install.packages("devtools")`
- Package and test dependencies, from the repo root:

  ```r
  devtools::install_dev_deps()   # Imports + Suggests (testthat, humdrumR, yaml, withr, ...)
  ```

- **Docker**, for the IDyOM tests: https://docs.docker.com/get-docker/. Build the
  IDyOM image once (a few minutes; the IDyOM version is pinned in the Dockerfile):

  ```sh
  docker build -t ppidyom-idyom-validation inst/validation
  ```

Open `ppidyom.Rproj` in RStudio, or start R in the repo root.

---

## 2. Build

```r
devtools::load_all()    # load the package from R/ (use while developing)
devtools::document()    # after editing roxygen (#') comments: regenerates NAMESPACE and man/
devtools::install()     # full install
devtools::check()       # R CMD check
```

---

## 3. Tests

Run from the repo root:

```r
devtools::test()                            # everything
devtools::test(filter = "escape")           # one file: tests/testthat/test-escape.R
```

| Test file | What it checks | Runs when |
|---|---|---|
| `test-escape.R` | Escape methods A/B/C/D/X: discount and escape numerator | always (no Docker) |
| `test-idyom-match.R` | `ppidyom()` vs IDyOM: each parameter on its own, on the datasets in `settings$test_datasets` | IDyOM Docker image present |
| ″ (pairwise) | every pair of parameters, toy corpus | `Sys.setenv(PPIDYOM_PAIRWISE = "true")` |
| `test-idyom-random-fuzz.R` | random parameter sets (every parameter at a random value), a new draw each run | `Sys.setenv(PPIDYOM_RANDOM_N = "20")` |

The IDyOM tests are skipped (not failed) without Docker, and on CRAN.

### The IDyOM comparison suite

Both IDyOM tests use `tests/param_suite/`: one config file lists every parameter,
its values, and how it maps to `ppidyom()` and to IDyOM. See
[tests/param_suite/README.md](tests/param_suite/README.md) for how to run it from R,
add parameters or datasets, and where to find:

- the list of parameter sets tested, with verdicts: `tests/param_suite/results/<mode>/summary.csv`
- the exact `ppidyom()` call and IDyOM Lisp for each: `tests/param_suite/results/<mode>/calls.txt`
- per-event IC/H, ppidyom next to IDyOM: `tests/param_suite/results/<mode>/events.csv`

Test data: `tests/data/CoCoPops_varms/` (100 songs from the CoCoPops corpus, `**harm` chords in spine 1).

---

## 4. Typical loop

```r
devtools::load_all()
# edit R/*.R ...
devtools::load_all()
devtools::test(filter = "idyom-match")
devtools::document()    # if roxygen comments changed
```

---

## 5. Code overview

| File | Contents |
|---|---|
| `R/ppidyom.R` | `ppidyom()` (S3 generic), `ppidyom.default()` (vectors), `ppidyom.humdrumR()` (humdrumR corpus); argument handling (`modelArgs`, `prepGroups`) |
| `R/counts.R` | `lag_matrix()` (each event with its preceding events), `stm_counts()`, `ltm_counts()`, `ltm_crossValidate()`, `ltm2dynamic_counts()` |
| `R/escape.R` | escape methods (`escape_A` … `escape_AX`), `stm_escape()`, `ltm_escape()` |
| `R/interpolation.R` | `stm_interpolation()`, `ltm_interpolation()` (blend all orders) |
| `R/model_combination.R` | `combine_P()`: entropy-weighted blend of the dynamic (STM) and schematic (LTM) models |
| `R/backoff.R` | backoff PPM |
| `R/tools.R` | `alphabetCheck()` |

How `ppidyom.default()` computes IC and H:

```
lag_matrix ─► stm_counts ─► stm_interpolation ─────────────────────────────────────────────┐  dynamic (STM)
           └► ltm_counts ─► ltm_crossValidate ─► ltm_interpolation ─► ltm2dynamic_counts ──┴► combine_P ─► IC, H
                                                                                    schematic (LTM)
```
