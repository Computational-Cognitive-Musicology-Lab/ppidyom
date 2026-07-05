#!/usr/bin/env python3
"""
Generate the IDyOM ground-truth reference CSV used by tests/testthat/test-idyom-comparison.R.

Run once (inside Docker or with a local SBCL + IDyOM installation):

    cd ppidyom/inst/validation
    python3 generate_idyom_reference.py

Or via Docker (recommended):

    ./run_idyom_docker.sh

Output:
    ../../tests/testthat/fixtures/idyom_reference_ic.csv

Working files (safe to delete after a successful run):
    _idyom_work/inputs/   — one-pitch-per-line .txt files for IDyOM import
    _idyom_work/outputs/  — per-run experiment folders containing compute.lisp + *.dat
"""

import os
import glob
import random
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
FIXTURE_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "../../tests/testthat/fixtures/idyom_reference_ic.csv")
)
WORK_DIR     = os.path.join(SCRIPT_DIR, "_idyom_work")
INPUT_DIR    = os.path.join(WORK_DIR, "inputs")
OUTPUT_DIR   = os.path.join(WORK_DIR, "outputs")

for d in (INPUT_DIR, OUTPUT_DIR, os.path.dirname(FIXTURE_PATH)):
    os.makedirs(d, exist_ok=True)

# ── Toy sequences (3-symbol alphabet, cpitch mapping) ────────────────────────
# These must match the sequences used in test-idyom-comparison.R.
PITCH_MAP  = {"A": 60, "B": 62, "C": 64}
LETTER_MAP = {v: k for k, v in PITCH_MAP.items()}   # 60→"A", 62→"B", 64→"C"

x1            = ["A", "B", "A", "C", "A", "B", "A", "C", "A"]
x2            = ["B", "A", "B", "C", "A"]
LTM_TRAIN_SEQ = ["A", "B", "C", "A", "B", "C", "A", "C", "B"]   # pretraining corpus

TEST_SEQS = {"x1": x1, "x2": x2}


def to_pitches(seq):
    return [PITCH_MAP[s] for s in seq]


def write_idyom_txt(pitches, path):
    """
    Write in IDyOM :txt format.
    text2db reads each LINE as one melody, with pitches space-separated.
    A single file → single melody → all pitches on one line.
    """
    with open(path, "w") as f:
        f.write(" ".join(str(p) for p in pitches) + "\n")


TRAIN_FILE = os.path.join(INPUT_DIR, "train.txt")
write_idyom_txt(to_pitches(LTM_TRAIN_SEQ), TRAIN_FILE)
for label, seq in TEST_SEQS.items():
    write_idyom_txt(to_pitches(seq), os.path.join(INPUT_DIR, f"{label}.txt"))

# ── LISP command template ─────────────────────────────────────────────────────
# %s slots (16 total, in order):
#  1. train file path (quoted)         2. train_id
#  3. test file path (quoted)          4. test_id
#  5. test_id  (idyom dataset arg)
#  6. models keyword (stm/ltm/ltm+/both/both+)
#  7. train_id (pretraining-ids)
#  8. stm escape                       9. stm exclusion (t/nil)
# 10. stm update-exclusion (t/nil)
# 11. ltm escape                      12. ltm exclusion (t/nil)
# 13. ltm update-exclusion (t/nil)
# 14. output path (quoted)
# 15. train_id (delete-dataset)       16. test_id (delete-dataset)
LISP_TEMPLATE = """\
(start-idyom)
(idyom-db:import-data :txt %s "TRAIN_DATASET" %s)
(idyom-db:import-data :txt %s "TEST_DATASET" %s)
(idyom:idyom %s '(cpitch) '(cpitch) :k 1 :models :%s :detail 3 :pretraining-ids '(%s)
:stmo '(:escape :%s :order-bound 3 :exclusion %s :update-exclusion %s)
:ltmo '(:escape :%s :order-bound 3 :exclusion %s :update-exclusion %s)
:output-path %s :overwrite nil :use-resampling-set-cache? nil :use-ltms-cache? nil)
(idyom-db:delete-dataset %s)
(idyom-db:delete-dataset %s)
(quit)
"""

ESCAPE_METHODS  = ("c", "a", "b", "d", "x")
BASELINE_ESCAPE = "c"


def lisp_bool(b):
    return "t" if b else "nil"


def generate_dataset_ids():
    """Two unique numeric IDs per run to avoid SQLite collisions across runs."""
    unique = random.randint(100000000000, 999999999999)
    return int(f"66{unique}"), int(f"77{unique}")


def baseline(model, stm_escape="c", ltm_escape="c"):
    return dict(
        model=model, stm_escape=stm_escape, ltm_escape=ltm_escape,
        stm_exclusion=False, stm_update_exclusion=False,
        ltm_exclusion=False, ltm_update_exclusion=False,
    )


# ── OFAT parameter grid ───────────────────────────────────────────────────────

def generate_stm_grid():
    """Baseline + 4 escape variants + excl + upd + excl&upd = 8 combos."""
    b = baseline("stm", stm_escape=BASELINE_ESCAPE)
    grid = [b]
    for esc in ESCAPE_METHODS:
        if esc != BASELINE_ESCAPE:
            grid.append({**b, "stm_escape": esc})
    grid.append({**b, "stm_exclusion": True})
    grid.append({**b, "stm_update_exclusion": True})
    grid.append({**b, "stm_exclusion": True, "stm_update_exclusion": True})
    return grid  # 8 combos


def generate_ltm_grid(model="ltm"):
    """Same OFAT pattern on the LTM side = 8 combos."""
    b = baseline(model, ltm_escape=BASELINE_ESCAPE)
    grid = [b]
    for esc in ESCAPE_METHODS:
        if esc != BASELINE_ESCAPE:
            grid.append({**b, "ltm_escape": esc})
    grid.append({**b, "ltm_exclusion": True})
    grid.append({**b, "ltm_update_exclusion": True})
    grid.append({**b, "ltm_exclusion": True, "ltm_update_exclusion": True})
    return grid  # 8 combos


def generate_ltm_plus_grid():
    """Spot-check online-update mechanism = 3 combos.
    Escape-method correctness already covered by the ltm section."""
    b = baseline("ltm+", ltm_escape=BASELINE_ESCAPE)
    return [b, {**b, "ltm_exclusion": True}, {**b, "ltm_update_exclusion": True}]


def generate_both_grid():
    """OFAT on the interpolation-combination logic, tied escape = 10 combos."""
    b = baseline("both", stm_escape=BASELINE_ESCAPE, ltm_escape=BASELINE_ESCAPE)
    grid = [b]
    for esc in ESCAPE_METHODS:
        if esc != BASELINE_ESCAPE:
            grid.append({**b, "stm_escape": esc, "ltm_escape": esc})
    grid.append({**b, "stm_exclusion": True})
    grid.append({**b, "ltm_exclusion": True})
    grid.append({**b, "stm_update_exclusion": True})
    grid.append({**b, "ltm_update_exclusion": True})
    grid.append({**b, "stm_exclusion": True, "ltm_exclusion": True})
    return grid  # 10 combos


def generate_both_plus_grid():
    """Spot-check online-updating in both+ = 3 combos."""
    b = baseline("both+", stm_escape=BASELINE_ESCAPE, ltm_escape=BASELINE_ESCAPE)
    return [b, {**b, "ltm_exclusion": True}, {**b, "stm_exclusion": True}]


def generate_grid():
    return (
        generate_stm_grid()         # 8
        + generate_ltm_grid()       # 8
        + generate_ltm_plus_grid()  # 3
        + generate_both_grid()      # 10
        + generate_both_plus_grid() # 3
    )  # 32 total


def params_to_tag(p):
    model_tag = p["model"].replace("+", "plus")
    return (
        f"m-{model_tag}"
        f"_se_esc-{p['stm_escape']}"
        f"_se-{int(p['stm_exclusion'])}"
        f"_su-{int(p['stm_update_exclusion'])}"
        f"_le_esc-{p['ltm_escape']}"
        f"_le-{int(p['ltm_exclusion'])}"
        f"_lu-{int(p['ltm_update_exclusion'])}"
    )


# ── IDyOM runner ──────────────────────────────────────────────────────────────

def run_one(seq_label, params):
    tag      = params_to_tag(params)
    out_dir  = os.path.join(OUTPUT_DIR, f"{seq_label}_{tag}")
    os.makedirs(out_dir, exist_ok=True)

    # Checkpoint: skip runs that already produced a .dat file.
    if glob.glob(os.path.join(out_dir, "*.dat")):
        print(f"  ⏭  Already done: {seq_label} [{tag}]")
        return out_dir, tag, 0

    train_id, test_id = generate_dataset_ids()
    test_file = os.path.join(INPUT_DIR, f"{seq_label}.txt")

    lisp = LISP_TEMPLATE % (
        f'"{TRAIN_FILE}"',  train_id,
        f'"{test_file}"',   test_id,
        test_id,
        params["model"],
        train_id,
        params["stm_escape"],
        lisp_bool(params["stm_exclusion"]),
        lisp_bool(params["stm_update_exclusion"]),
        params["ltm_escape"],
        lisp_bool(params["ltm_exclusion"]),
        lisp_bool(params["ltm_update_exclusion"]),
        f'"{out_dir}"',
        train_id, test_id,
    )

    lisp_file = os.path.join(out_dir, "compute.lisp")
    with open(lisp_file, "w") as f:
        f.write(lisp)

    print(f"  ▶  Running: {seq_label} [{tag}]")
    rc = os.system(f"sbcl --dynamic-space-size 8192 --noinform --load {lisp_file}")
    return out_dir, tag, rc


# ── Output parser ─────────────────────────────────────────────────────────────

def parse_dat(out_dir, seq_label, params, tag):
    """Return a list of row dicts from one IDyOM .dat output file."""
    dat_files = glob.glob(os.path.join(out_dir, "*.dat"))
    assert dat_files, f"No .dat output found in {out_dir}"

    df = pd.read_csv(dat_files[0], sep=r"\s+", engine="python")

    # IDyOM detail=3 uses cpitch.ic / cpitch.entropy for the modelled viewpoint;
    # fall back to the overall ic/entropy columns for older IDyOM versions.
    ic_col  = "cpitch.ic"      if "cpitch.ic"      in df.columns else "ic"
    ent_col = "cpitch.entropy" if "cpitch.entropy"  in df.columns else "entropy"

    # Sort by note.id so row order matches the input sequence.
    if "note.id" in df.columns:
        df = df.sort_values("note.id").reset_index(drop=True)

    seq              = TEST_SEQS[seq_label]
    expected_pitches = to_pitches(seq)
    actual_pitches   = [int(v) for v in df["cpitch"]]
    assert actual_pitches == expected_pitches, (
        f"[{seq_label} {tag}] cpitch mismatch:\n"
        f"  IDyOM: {actual_pitches}\n"
        f"  expected: {expected_pitches}"
    )

    rows = []
    for i in range(len(df)):
        rows.append({
            "tag":                  tag,
            "model":                params["model"],
            "seq_label":            seq_label,
            "index":                i + 1,
            "Event":                seq[i],
            "cpitch":               int(df["cpitch"].iloc[i]),
            "IC_idyom":             float(df[ic_col].iloc[i]),
            "H_idyom":              float(df[ent_col].iloc[i]),
            "stm_escape":           params["stm_escape"],
            "ltm_escape":           params["ltm_escape"],
            "stm_exclusion":        params["stm_exclusion"],
            "stm_update_exclusion": params["stm_update_exclusion"],
            "ltm_exclusion":        params["ltm_exclusion"],
            "ltm_update_exclusion": params["ltm_update_exclusion"],
        })
    return rows


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    grid = generate_grid()
    n_runs = len(grid) * len(TEST_SEQS)
    print(f"Grid: {len(grid)} configs × {len(TEST_SEQS)} sequences = {n_runs} runs\n")

    all_rows = []
    failed   = []

    for seq_label in TEST_SEQS:
        for params in grid:
            out_dir, tag, rc = run_one(seq_label, params)
            if rc != 0:
                print(f"  ✗ FAILED (exit {rc}): {seq_label} [{tag}]")
                failed.append((seq_label, tag))
                continue
            try:
                all_rows.extend(parse_dat(out_dir, seq_label, params, tag))
            except Exception as e:
                print(f"  ✗ Parse error for {seq_label} [{tag}]: {e}")
                failed.append((seq_label, tag))

    pd.DataFrame(all_rows).to_csv(FIXTURE_PATH, index=False)
    print(f"\n✓ Wrote {len(all_rows)} rows → {FIXTURE_PATH}")
    if failed:
        print(f"✗ Failed runs ({len(failed)}): {failed}")
    else:
        print("All runs succeeded.")


if __name__ == "__main__":
    main()
