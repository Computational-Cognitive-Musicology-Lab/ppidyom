![](ppidyom_logo.svg)

Welcome to the main website of ppidyom!

## What is ppidyom?

**ppidyom** is an R package for applying *partial predictive matching*
(PPM) algorithms to musical data. PPM algorithms are a sophisticated
form of N-gram model, which predict consequent musical events (notes,
chords, etc.) sequentially based on the immediate context of antecedent
musical events. For example, if I hear the sequence of notes “G B D F,”
a PPM algorithm would come up with a prediction for how probable it is
for the next note to be “E.” These (probabilistic) predictions can then
be used as the basis for information theory metrics, like *information
content* and *entropy*.

**ppidyom** is similar to the widely used
[IDyOM](https://www.marcus-pearce.com/idyom/) (Pearce, 2005) and
[ppm](https://github.com/pmcharrison/ppm) (Harrison, et al. 2020)
softwares. The goal of the **ppidyom** project is to make
partial-predictive-modeling (à la IDyOM) faster, easier, and more
transparent than ever. In particular, **ppidyom** is designed to work
within the [humdrumR](https://humdrumR.ccml.gtcmt.gatech.edu) package
framework, making is super easy to apply ppm-model predictions to any of
the [tens of
thousands](https://github.com/search?q=topic%3Ahumdrum+topic%3Adigital-scores+&type=repositories)
of scores encoded in the [humdrum
syntax](https://github.com/search?q=topic%3Ahumdrum+topic%3Adigital-scores+&type=repositories).

#### What does ppidyom stand for?

**P**artial **P**redictive **I**nformation **Dy**namics of **M**usic.
It’s an homage/mash-up of IDyOM and ppm!

## What is partial predictive matching?

PPM models originated in the field of computational linguistics. PPM
models are a form of N-gram model, where each sequential musical event
(note, chord, etc.) is predicted based on the N-previous events. In a
basic N-gram models, we use one fixed value for N, like $N = 5$ to
create “5-grams.” In a PPM model, N-grams of various lengths are
“blended” to create the final prediction.

PPM model implementations can also incorporate:

- Methods for blending “long-term” knowledge (learned from many pieces)
  and “short-term” knowledge (learned dynamically within a piece).
- Different approaches to dealing with never-seen-before events.
