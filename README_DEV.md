# PPIDyOM — Developer Guide

This document covers the developer workflow: first-time setup, building, and running tests.
For the package overview and algorithm description, see [README.md](README.md).

---

## Prerequisites

- **R ≥ 4.5** (see `DESCRIPTION`)
- **RStudio** (recommended) or any R IDE with project support
- **devtools** — the standard R package development toolkit

---

## 1. First-Time Setup

### 1.1 Install devtools

```r
install.packages("devtools")
```

### 1.2 Install package dependencies

`ppidyom` depends on `data.table` (CRAN) and `ppm` (GitHub):

```r
install.packages("data.table")
devtools::install_github("pmcharrison/ppm")
```

### 1.3 Install testthat (for running tests)

```r
install.packages("testthat")
```

### 1.4 Open the project

Open `ppidyom.Rproj` in RStudio — this sets the working directory and activates the project environment automatically.

---

## 2. Build

### Active development (recommended)

`load_all()` sources every file in `R/` into the current session without a full install. Use this during development — it's fast and reflects your edits immediately:

```r
devtools::load_all()
```

### Regenerate documentation

After editing roxygen2 comments (`#'` blocks) in any `R/` file, regenerate `NAMESPACE` and the `man/` pages:

```r
devtools::document()
```

### Install the package

Performs a full build and install into your R library. Use this when you want the package available outside this project, or to test it as an end user would:

```r
devtools::install()
```

### Run R CMD CHECK

Runs the full CRAN-style check suite (build, tests, documentation completeness):

```r
devtools::check()
```

---

## 3. Running Tests

Tests live in `tests/testthat/`. The test suite uses the **testthat** framework.

### Run all tests

```r
devtools::test()
```

This is the standard command. It loads the package first (equivalent to `load_all()`), then runs every `test-*.R` file under `tests/testthat/`.

### Run a specific test file

```r
devtools::test(filter = "counts")    # runs test-counts.R
devtools::test(filter = "escape")    # runs test-escape.R
devtools::test(filter = "invariants") # runs test-invariants.R
devtools::test(filter = "ppidyom")   # runs test-ppidyom.R
```

Or use `testthat::test_file()` directly after `load_all()`:

```r
devtools::load_all()
testthat::test_file("tests/testthat/test-counts.R")
```

### Run scalability / timing tests

Scalability tests are disabled by default (they are slow). Enable them with an environment variable before running:

```r
Sys.setenv(RUN_SCALABILITY_TESTS = "true")
devtools::test(filter = "scalability")
```

---

## Typical Development Loop

```
# Once per session
devtools::load_all()

# Edit R/*.R files ...

# Reload and run relevant tests
devtools::load_all()
devtools::test(filter = "counts")

# Before committing
devtools::document()   # if you changed roxygen comments
devtools::check()      # full check (optional but recommended)
```

---

## Understanding the Codebase

### File-by-file overview

| File | Role |
|------|------|
| `R/escape.R` | Pure math: escape and discount function definitions (methods A, B, C, D, AX). No side effects, no dependencies. |
| `R/counts.R` | Count accumulation: builds the sparse count tables (Ce, C, t, t1) for all n-gram orders, for both STM and LTM. Also handles the lag matrix, context key generation, prior seeding, and update-exclusion logic. |
| `R/interpolation.R` | Probability computation (interpolated PPM): consumes count tables, applies the weighted sum across orders, handles the exclusion mechanism. |
| `R/backoff.R` | Probability computation (backoff PPM): consumes count tables, cascades through orders assigning probability mass to seen symbols. |
| `R/ppidyom.R` | The main `ppidyom` R5 Reference Class: wraps LTM state and calls `count_tables`, `ppm_interpolated`/`ppm_backoff`, and `detrain_sequence`. Also contains `combine_models` for STM+LTM blending. |
| `R/utils.R` | Top-level user function `run_ppidyom`: runs leave-one-out or train-all evaluation over a corpus using the `ppidyom` class. |

### Dependency graph

```
escape.R  ──────────────────────────────────────────┐
                                                    ▼
counts.R  ──► interpolation.R ──────────────► ppidyom.R ──► utils.R
          └─► backoff.R ───────────────────────────►┘
```

### Key data structures

**Count table** (output of `count_tables`, input to `ppm_interpolated` / `ppm_backoff`):

A list of N+1 `data.table`s (one per order 0..N). Each row is one `(timestep, symbol)` pair:

| Column | Type | Meaning |
|--------|------|---------|
| `index` | int | Timestep (1..T for STM; -1 for LTM, a constant sentinel) |
| `context_id` | chr | N-gram context string, e.g. `"A_B"` for order 2, `"ROOT"` for order 0 |
| `Event` | chr | Symbol/event label |
| `Ce` | int | Count of times this symbol followed this context |
| `C` | int | Total count of all symbols after this context (= sum of Ce over the alphabet) |
| `t` | int | Number of distinct symbols seen after this context |
| `t1` | int | Number of symbols seen exactly once (singletons) |

**LTM environments** (internal representation during accumulation in `counts.R`):

During training, counts are stored as `new.env(hash=TRUE)` objects — one environment per order. Each key is a `context_id` string; each value is a named integer vector `c(A=3, B=1, ...)` mapping symbols to Ce counts. These are converted to data.tables at the end of `count_tables`. Only symbols with Ce > 0 are stored as keys.

---