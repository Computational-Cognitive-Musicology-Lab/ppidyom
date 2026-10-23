#!/usr/bin/env python3
"""
Generate the IDyOM reference CSV for shortest-deterministic selection
(IDyOM :order-bound nil), used by tests/testthat/test-idyom-shortest-deterministic.R.

Reuses the toy sequences, helpers and runner of generate_idyom_reference.py,
with the order bound set to nil instead of 3 and its own test sequences
(x3 repeats a phrase, so long contexts are seen and the selection matters).

Run via Docker (recommended):

    bash inst/validation/run_idyom_docker.sh generate_idyom_sd_reference.py

Output:
    ../../tests/testthat/fixtures/idyom_reference_sd.csv
"""

import os
import pandas as pd

import generate_idyom_reference as ref

FIXTURE_PATH = os.path.normpath(
    os.path.join(ref.SCRIPT_DIR, "../../tests/testthat/fixtures/idyom_reference_sd.csv")
)

# ── Test sequences — must match test-idyom-shortest-deterministic.R ──────────
x3 = ["A", "B", "C", "A", "B", "C", "A", "B", "A", "C", "A", "B", "C", "A", "B", "C"]
SD_TEST_SEQS = {"x1": ref.x1, "x2": ref.x2, "x3": x3}
ref.write_idyom_txt([ref.to_pitches(x3)], os.path.join(ref.INPUT_DIR, "x3.txt"))

# Same runner and parser as the main fixture, pointed at the order-bound-nil
# template, these sequences, and a separate output folder (keeps checkpoints apart).
ref.LISP_TEMPLATE = ref.LISP_TEMPLATE.replace(":order-bound 3", ":order-bound nil")
ref.TEST_SEQS     = SD_TEST_SEQS
ref.OUTPUT_DIR    = os.path.join(ref.WORK_DIR, "outputs_sd")
os.makedirs(ref.OUTPUT_DIR, exist_ok=True)


def generate_grid():
    """Interpolated STM and LTM, OFAT over escape, exclusion, update exclusion = 16 combos."""
    return ref.generate_stm_grid() + ref.generate_ltm_grid()


def main():
    grid   = generate_grid()
    n_runs = len(grid) * len(SD_TEST_SEQS)
    print(f"Grid: {len(grid)} configs × {len(SD_TEST_SEQS)} sequences = {n_runs} runs (order-bound nil)\n")

    all_rows = []
    failed   = []

    for seq_label in SD_TEST_SEQS:
        for params in grid:
            out_dir, tag, rc = ref.run_one(seq_label, params)
            if rc != 0:
                print(f"  ✗ FAILED (exit {rc}): {seq_label} [{tag}]")
                failed.append((seq_label, tag))
                continue
            try:
                rows = ref.parse_dat(out_dir, seq_label, params, tag)
            except Exception as e:
                print(f"  ✗ Parse error for {seq_label} [{tag}]: {e}")
                failed.append((seq_label, tag))
                continue
            for row in rows:
                row["order_bound"] = "nil"
            all_rows.extend(rows)

    pd.DataFrame(all_rows).to_csv(FIXTURE_PATH, index=False)
    print(f"\n✓ Wrote {len(all_rows)} rows → {FIXTURE_PATH}")
    if failed:
        print(f"✗ Failed runs ({len(failed)}): {failed}")
    else:
        print("All runs succeeded.")


if __name__ == "__main__":
    main()
