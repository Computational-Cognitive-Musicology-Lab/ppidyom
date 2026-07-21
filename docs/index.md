![](ppidyom_logo.svg)

Welcome to the main website of ppidyom!

## What is ppidyom?

**ppidyom** is an R package for applying *partial predictive matching*
(PPM) algorithms to musical data. PPM algorithms are a sophisticated
form of N-gram model, where musical events (notes, chords, etc.) are
predicted based on the previous music. This (probabilistic) predictions
can then be used as the basis for information theory metrics, like
information content and entropy.

**ppidyom** is similar to the widely used
[IDyOM](https://www.marcus-pearce.com/idyom/) (Pearce, 2005) and
[ppm](https://github.com/pmcharrison/ppm) (Harrison, et al. 2020)
softwares. The goal of the **ppidyom** project is to make
partial-predictive-modeling faster, easier, and more transparent than
these existing systems. In particular, **ppidyom** is designed to work
within the [humdrumR](https://humdrumR.ccml.gtcmt.gatech.edu) package
framework, making a complete system for musicological analysis.

#### What does ppidyom stand for?

**P**artial **P**redictive **I**nformation **Dy**namics of **M**usic.
It’s an homage/mash-up of IDyOM and ppm!

## What is partial predictive matching?

PPM models originated in the field of computational linguistics. PPM
models are a form of N-gram model, where each sequential musical event
(note, chord, etc.) is predicted based on the N-previous events. In a
PPM model, N-grams of various lengths are “blended” to create the final
prediction.

PPM model implementations can also incorporate:

- Long-term and short-term models.
