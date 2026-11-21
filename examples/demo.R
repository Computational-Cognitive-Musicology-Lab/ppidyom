# examples/demo.R — ppidyom() on a toy sequence and on CoCoPops chords.
# Run from the repo root.

devtools::load_all()   # or: library(ppidyom)

# ── 1. One sequence ─────────────────────────────────────────────────────────
x <- strsplit("ABCABCACBABAB", "")[[1]]
ppidyom(x, maxN = 3)                       # dynamic (STM) + schematic (LTM), escape C

# ── 2. Several pieces ──────────────────────────────────────────────────────
# groupby: the dynamic model restarts at each piece
# crossValidate: the schematic model predicts each piece from the other pieces
piece <- rep(1:2, c(9, 4))
ppidyom(x, maxN = 3, dynamic = list(groupby = piece), schematic = list(crossValidate = piece))
ppidyom(x, maxN = 3, dynamic = list(escape = "A"), schematic = list(escape = "D"), b = 2)

# ── 3. CoCoPops chords, read with humdrumR ─────────────────────────────────
library(humdrumR)
chords <- readHumdrum("tests/data/CoCoPops_varms", ".*.hum")[1:10] |>
  filter(Spine == 1 & !Token %~% "r") |>          # **harm spine, no rests
  mutate(Chord = Token %~m% "[^0-9.][^;]*")        # drop duration and fermata

chord <- chords |> pull(Chord)
song  <- chords |> pull(Piece)
ppidyom(chord, maxN = 3, dynamic = list(groupby = song), schematic = list(crossValidate = song))

