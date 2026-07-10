# N-grams 101

Music, like language, consists of streams of sequential events. For
example, a melody consists of a sequence of notes, while a chord
progression consists of sequences of chords. “N-grams” are one approach
to analyzing sequential data like this.

It is probably intuitive that each note in a melody is perceived and
understood in the context of the notes around it—particularly the ones
before it. But, how much context do we consider? And how do we use that
context to “understand” each note?

The basic idea of N-grams is to look at a fixed number ($N$) of notes.
We might pick $N = 5$, which means we’ll look at windows (“grams”) of
five notes at a time. We then create these grams for every *overlapping*
five-note sequence in the melody—the grams becomes like a sliding 5-note
window on the melody.

Consider this familiar tune, the Ode to Joy:

    #> E E F G G F E D C C D E E D D E E F  G G F E D C C D E D C C

This melody consists of 30 notes. If we divide it into five grams, we
get:

    #> E E F G G
    #> E F G G F
    #> F G G F E
    #> G G F E D
    #> G F E D C
    #> F E D C C
    #> E D C C D
    #> D C C D E
    #> C C D E E
    #> C D E E D
    #> D E E D D
    #> E E D D E
    #> E D D E E
    #> D D E E F
    #> D E E F  G
    #> E E F  G G
    #> E F  G G F
    #> F  G G F E
    #>  G G F E D
    #> G F E D C
    #> F E D C C
    #> E D C C D
    #> D C C D E
    #> C C D E D
    #> C D E D C
    #> D E D C C
    #> E D C C NA
    #> D C C NA NA
    #> C C NA NA NA
    #> C NA NA NA NA

Note, as we said above, that the N-grams overlap!

## Predictive context

In the example above, we break the Ode to Joy into overlapping 5-grams.
What are these grams useful for? One particularly common approach is in
predictive modeling.

In the context of music cognition (and psycholinguistic) research,
n-grams are often used to model how a listener will perceive each note
in a melody (or chord in a progression, etc.). Consider a five-gram
`G-F-E-D-C`. Somebody listening to this melody in real time would hear
the first four notes (`G-F-E-D-`) *then* hit the final note (`C`). So we
could think of the first four ($N - 1$) notes of the gram as the context
for the *last* note. But then we look at the next 5-gram, which
represents four notes of context plus one *new* note—and we can keep
doing this. With this perspective, we can try to predict the *last* note
the of the N-gram using the $N - 1$ notes of context—and do this over
and over again for each new note!

This approach to sequential modeling is the core of “N-gram” analysis.
Generally, we compute *conditional probabilities* for consequent events,
*given* $N - 1$ events of context.

## Padding

You probably noticed that for the first four notes of the Ode To Joy, we
can’t construct predictive 5-grams, because there haven’t been five
notes yet. This is a basic issue you have to deal with, and there are
various approaches. The simplest approaches are to (1) just ignore these
early grams or (2) pad them with “NA” (or something like that), but
there are more sophisticated approaches.

## Partial Predictive Matching

A key problem with N-gram modeling is knowing what size of N-gram to
use. You might think “the bigger the better, right”? That *is* sort of
right…but if you use large $N$, every melodic sequence becomes unique,
so there is nothing to learn or *generalize*. The core idea of the
*partial predictive matching* algorithm is to compute N-grams of a range
of sizes, then make your final prediction based on a blend of these
different N-grams.
