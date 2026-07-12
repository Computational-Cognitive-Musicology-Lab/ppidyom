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

### Test coverage summary

| Test file | What it covers | 
|---|---|
| `test-escape.R` | Escape functions A/B/C/D/AX: correct `subtract`, `esc_numer`, full escape probability |
| `test-counts.R` | STM and LTM count tables (`Ce`, `C`, `t`, `t1`) at order 0 and order 2; LTM prior accumulation across sequences | 
| `test-invariants.R` | `P ∈ (0,1]` for observed events; per-timestep distribution sums to 1 | 
| `test-ppidyom.R` | `detrain_sequence` exactly reverses training (with and without `ltm_update_exclusion`); `run_ppidyom` matches manual leave-one-out | 
| `test-ppm-comparison.R` | ppidyom STM ↔ Harrison's **ppm** for all 5 escape methods, both exclusion flags, both update-exclusion flags, N ∈ {1,3,5}; full `run_ppidyom` grid | 
| `test-idyom-comparison.R` | ppidyom ↔ IDyOM (Common Lisp) for all model/escape/exclusion combinations × 2 sequences (AX via `:x`); ppidyom ↔ ppm for STM excl=ON | 
| `test-scalability.R` | timing benchmarks for large sequences (disabled by default) |

---

### `test-ppm-comparison.R` — detailed coverage

Compares ppidyom STM against Harrison's **ppm** package.  All tests use
`ppm_type = "interpolation"` and `idyom_base = FALSE` (ppm-compatible
shrinking-denominator base).

#### What IS covered

| Section | Escape | Exclusion | Update-excl | N | Sequences |
|---|---|---|---|---|---|
| §1 escape sweep | A, B, C, D, AX | FALSE | FALSE | 3 | x1, x2 |
| §2 exclusion | C | **TRUE** | FALSE | 3 | x1, x2 |
| §3 update-exclusion | C | FALSE | **TRUE** | 3 | x1, x2 |
| §3 both flags | C | **TRUE** | **TRUE** | 3 | x1, x2 |
| §4 order bound | C | FALSE | FALSE | **1** | x1 only |
| §4 order bound | C | FALSE | FALSE | **5** | x1 only |
| §5 `run_ppidyom` grid | A, B, C, D, X | FALSE, TRUE | FALSE, TRUE | 3 | x1, x2 |

Full `run_ppidyom` grid (§5) covers 5 × 2 × 2 = 20 parameter combinations × 2 sequences = 40 checks.

#### What is NOT covered

| Gap | Notes |
|---|---|
| LTM / ltm+ / both / both+ model types | ppm package has no LTM; STM only |
| `idyom_base = TRUE` | always uses ppm-compatible shrinking base |
| Backoff mode (`ppm_type = "backoff"`) | ppm package uses interpolation only |
---

### `test-idyom-comparison.R` — detailed coverage

Compares ppidyom against ground-truth IDyOM (Common Lisp) output from
a pre-generated fixture CSV.  All tests use `N = 3`, `idyom_base = TRUE`,
`ltm_start_token = FALSE`, `b = 7`.  STM with `stm_exclusion = TRUE` also
gets a three-way ppidyom ↔ ppm ↔ IDyOM comparison.

#### What IS covered
* OFAT: one-factor-at-a-time

| Model | Parameter combinations | Sequences |
|---|---|---|
| `stm` | escape ∈ {a,b,c,d,x} × stm_exclusion ∈ {0,1} × stm_update_exclusion ∈ {0,1} | x1, x2 |
| `ltm` | OFAT: escape × ltm_exclusion × ltm_update_exclusion (all combos) | x1, x2 |
| `ltm+` | spot-check: exclusion, update_exclusion | x1, x2 |
| `both` | OFAT on stm/ltm escape, exclusion, update_exclusion | x1, x2 |
| `both+` | spot-check: exclusion | x1, x2 |
| backoff (`mixtures=nil`) | stm/ltm/ltm+/both/both+ baselines; stm+exclusion variant | x1, x2 |
| `b = 1` | both (baseline + excl=T) + both+ baseline | x1, x2 |

All LTM models are pretrained on two training sequences (the "multi" corpus).
Total: 41 IDyOM configurations × 2 sequences = 82 comparison tests.
IDyOM's AX escape is invoked as `:x` (not `:ax` — see §6 of `vignette("implementation-discrepancy")`).

**Note:** The IDyOM `b` parameter is set via `(mvs:set-ltm-stm-bias N)` in the fixture generator.

#### What is NOT covered

| Gap | Notes |
|---|---|
| N ≠ 3 | fixture only uses order-bound=3 |
| `idyom_base = FALSE` | always uses IDyOM-compatible base; ppm-compatible base not cross-checked for LTM |
| STM excl=OFF vs ppm | three-way check only when `stm_exclusion = TRUE` and `mixtures = TRUE` (only setting where all three agree) |

---

## 4. IDyOM Comparison Tests (Ground-Truth Validation)

The test file `tests/testthat/test-idyom-comparison.R` validates ppidyom against
real IDyOM (Common Lisp) output. This is a three-way check for STM:

```
ppidyom  ↔  ppm package  ↔  IDyOM (Lisp)
```

and a two-way check for LTM / ltm+ / both / both+:

```
ppidyom  ↔  IDyOM (Lisp)
```

The comparison requires a pre-generated reference CSV. You only need to regenerate
it when you change the toy sequences or add new parameter combinations.

### 4.1 Prerequisites

- **Docker** — install from https://docs.docker.com/get-docker/

No local Lisp or IDyOM installation is needed; Docker handles everything.

### 4.2 Generate the IDyOM reference fixture (run once)

From the repo root:

```bash
bash inst/validation/run_idyom_docker.sh
```

This will:
1. Build a Docker image with SBCL + IDyOM + Python 3 (takes ~5 min the first time; cached afterwards).
2. Run `inst/validation/generate_idyom_reference.py` inside the container.
3. Write `tests/testthat/fixtures/idyom_reference_ic.csv`.

The script supports **checkpointing** — if interrupted, re-running it skips already-completed parameter combinations.

### 4.3 Run the comparison tests

After the fixture CSV exists, run normally:

```r
devtools::test(filter = "idyom")
```

Tests are skipped automatically (with an informative message) if the fixture is absent,
so `devtools::test()` remains safe to run without Docker.

### 4.4 Parameter grid
* OFAT: one-factor-at-a-time

All LTM models are pretrained on two training sequences.
The fixture covers **41 IDyOM configurations × 2 sequences = 82 total runs**:

| Model | Combos | What's varied |
|-------|--------|---------------|
| `stm`  | 8 | baseline + 4 escape methods + exclusion + update_exclusion + both |
| `ltm`  | 8 | OFAT: escape × exclusion × update_exclusion |
| `ltm+` | 3 | spot-check of online updating |
| `both` | 10 | OFAT on STM+LTM interpolation + key interactions |
| `both+`| 3 | spot-check of online updating in both+ |
| backoff | 6 | `mixtures=False` for stm/ltm/ltm+/both/both+ + stm excl=T |
| b=1 | 3 | both (2 combos) + both+ with mixture exponent b=1 |

To add more combinations, edit `generate_grid()` in
`inst/validation/generate_idyom_reference.py` and re-run the Docker script.
The R test file reads all configs directly from the fixture CSV and requires
no changes when new rows are added.

### 4.5 What the Dockerfile installs

`inst/validation/Dockerfile` installs:
- `sbcl` — Steel Bank Common Lisp (the Lisp compiler IDyOM runs on)
- `quicklisp` — Common Lisp package manager (downloads IDyOM automatically)
- `idyom` — Pearce's IDyOM system from GitHub
- `python3` + `pandas` — to run the generator script and parse `.dat` outputs

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