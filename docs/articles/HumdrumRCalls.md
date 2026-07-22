# Using ppidyom with humdrumR

Though it can be used on any R data vectors, `ppidyom` is fully
incorporated into [humdrumR](https://humdrumr.ccml.gtcmt.gatech.edu/),
making it very easy to apply to existing musical datasets using various
operational definitions (“viewpoints”).

``` r
library(humdrumR)
library(ppidyom)
```

## First examples

Let’s start with trusty Bach chorales, the first ten of which are
packaged with humdrumR. To load them, we just need this:

``` r

chorales <- readHumdrum(humdrumRroot, "HumdrumData/BachChorales/.*krn")
#> Finding and reading files...
#>  REpath-pattern '/home/nat/R/x86_64-pc-linux-gnu-library/4.5/humdrumR/HumdrumData/BachChorales/.*krn' matches 10 text files in 1 directory.
#> Ten files read from disk.
#> Validating ten files...all valid.
#> Parsing ten files...Assembling corpus...Done!

chorales
#> ######################## vvv chor001.krn vvv #########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:           **kern         **kern         **kern         **kern
#>             9:           *ICvox         *ICvox         *ICvox         *ICvox
#>            10:           *Ibass        *Itenor         *Ialto        *Isoprn
#>            11:          *I"Bass       *I"Tenor        *I"Alto     *I"Soprano
#>            12:        *>[A,A,B]      *>[A,A,B]      *>[A,A,B]      *>[A,A,B]
#>            13:     *>norep[A,B]   *>norep[A,B]   *>norep[A,B]   *>norep[A,B]
#>            14:              *>A            *>A            *>A            *>A
#>            15:          *clefF4       *clefGv2        *clefG2        *clefG2
#>            16:           *k[f#]         *k[f#]         *k[f#]         *k[f#]
#>            17:              *G:            *G:            *G:            *G:
#>            18:            *M3/4          *M3/4          *M3/4          *M3/4
#>            19:           *MM100         *MM100         *MM100         *MM100
#>            20:              4GG             4B             4d             4g
#>            21:               =1             =1             =1             =1
#>            22:               4G             4B             4d             2g
#>            23:               4E            8cL             4e              .
#>            24:                .            8BJ              .              .
#>            25:              4F#             4A             4d            4dd
#>            26:               =2             =2             =2             =2
#>            27:               4G             4G             2d            4.b
#>            28:               4D            4F#              .              .
#>            29:                .              .              .             8a
#>            30:               4E             4G             4B             4g
#>            31:               =3             =3             =3             =3
#>            32:               4C            8cL            8eL            4.g
#>            33:                .            8BJ             8d              .
#>            34:             8BBL             4c             8e              .
#>            35:             8AAJ              .           8f#J             8a
#>            36:              4GG             4d             4g             4b
#>            37:               =4             =4             =4             =4
#>            38:              2D;            2d;           2f#;            2a;
#>            39:              4GG             4d             4g             4b
#>            40:               =5             =5             =5             =5
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ######################## ^^^ chor001.krn ^^^ #########################
#> 
#>      (eight more pieces...)
#> 
#> ######################## vvv chor010.krn vvv #########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:             2AA;            2c;            2e;            2a;
#>            62:               2A             2e             2a            2cc
#>            63:               =9             =9             =9             =9
#>            64:               4E             4e             4g             4b
#>            65:              8DL             4e             4g            4cc
#>            66:              8CJ              .              .              .
#>            67:              4BB             4d            8gL            4dd
#>            68:                .              .            8fJ              .
#>            69:               4C             4c             4e             4g
#>            70:              =10            =10            =10            =10
#>            71:               4D            8F#             4d             4b
#>            72:                .             4G              .              .
#>            73:               4D              .             4c             4a
#>            74:                .            8F#              .              .
#>            75:             2GG;            2G;            2B;            2g;
#>            76:              =11            =11            =11            =11
#>            77:               2C             2G             2e             2g
#>            78:              4AA             4A             4e            4cc
#>            79:               4E            4G#            8eL             4b
#>            80:                .              .            8dJ              .
#>            81:              =12            =12            =12            =12
#>            82:               4F             4A             4c             4a
#>            83:               4C             4G             4c             4e
#>            84:             4BB-             4G            [2d             4g
#>            85:              4AA             4A              .             4f
#>            86:              =13            =13            =13            =13
#>            87:             4GG#             4B            4d]            1e;
#>            88:              4AA             4A             4c              .
#>            89:             2EE;          2G#X;            2B;              .
#>            90:               ==             ==             ==             ==
#>            91:               *-             *-             *-             *-
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebastian B***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf und H&a***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach, 371 ***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc., c.1***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ######################## ^^^ chor010.krn ^^^ #########################
#>               (***four global comments truncated due to screen size***)
#> 
#>  humdrumR corpus of ten pieces.
#> 
#>    Data fields: 
#>          *Token :: character
```

If you have any other humdrum data on your machine, you can just pass
[`readHumdrum()`](https://rdrr.io/pkg/humdrumR/man/readHumdrum.html) the
path and pattern to match your files.

Before applying ppidyom, consider what dimension of the music you want
to model, and your *operational definition* for that dimension. This
choral data is encoded as `**kern`, which means it has relative rhythm
data and absolute pitch encoded for each note, as well as notation
details like stem direction. Here we’ll consider just focus on modeling
pitch, ignoring rhythm. But “pitch” can be viewed different ways:
absolute vs relative, tonal vs atonal, etc.

Let’s start with simple (no octave information) scale degree, which we
can extract using `solfa(simple = TRUE)`. We can then pass that straight
to
[`ppidyom()`](https://ppidyom.ccml.gtcmt.gatech.edu/reference/ppidyom.md):

``` r

chorales |> solfa(simple = TRUE) |> ppidyom()
#> ######################## vvv chor001.krn vvv #########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:           **kern         **kern         **kern         **kern
#>             9:           *ICvox         *ICvox         *ICvox         *ICvox
#>            10:           *Ibass        *Itenor         *Ialto        *Isoprn
#>            11:          *I"Bass       *I"Tenor        *I"Alto     *I"Soprano
#>            12:        *>[A,A,B]      *>[A,A,B]      *>[A,A,B]      *>[A,A,B]
#>            13:     *>norep[A,B]   *>norep[A,B]   *>norep[A,B]   *>norep[A,B]
#>            14:              *>A            *>A            *>A            *>A
#>            15:          *clefF4       *clefGv2        *clefG2        *clefG2
#>            16:           *k[f#]         *k[f#]         *k[f#]         *k[f#]
#>            17:              *G:            *G:            *G:            *G:
#>            18:            *M3/4          *M3/4          *M3/4          *M3/4
#>            19:           *MM100         *MM100         *MM100         *MM100
#>            20:            2.416           3.05          2.591          2.416
#>            21:               =1             =1             =1             =1
#>            22:            1.332          1.207          1.155          1.332
#>            23:            4.184          3.422          3.954              .
#>            24:                .          1.991              .              .
#>            25:            3.667          2.096          1.325          3.683
#>            26:               =2             =2             =2             =2
#>            27:            1.026          3.367          1.716          4.335
#>            28:            4.081          3.654              .              .
#>            29:                .              .              .          3.159
#>            30:            2.945          1.489          4.956          1.986
#>            31:               =3             =3             =3             =3
#>            32:            3.813          3.648          2.312          1.739
#>            33:                .          1.451          0.675              .
#>            34:            3.698          2.432          2.731              .
#>            35:            2.311              .          3.578           3.42
#>            36:            2.091          2.917           2.29          2.085
#>            37:               =4             =4             =4             =4
#>            38:            2.587          3.015          3.172          1.176
#>            39:            2.636          1.274          1.116          1.924
#>            40:               =5             =5             =5             =5
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ######################## ^^^ chor001.krn ^^^ #########################
#> 
#>      (eight more pieces...)
#> 
#> ######################## vvv chor010.krn vvv #########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:            2.591          3.466          3.306          1.349
#>            62:             3.15          4.339          3.027           4.58
#>            63:               =9             =9             =9             =9
#>            64:            2.544          1.993          3.746          1.726
#>            65:            2.994          1.803          4.164          3.067
#>            66:            2.421              .              .              .
#>            67:            0.856          2.702          2.873          1.673
#>            68:                .              .          3.726              .
#>            69:            2.696          2.276          1.204          5.665
#>            70:              =10            =10            =10            =10
#>            71:            2.022          5.662          1.639          3.614
#>            72:                .          4.499              .              .
#>            73:            4.611              .           1.72           2.52
#>            74:                .          2.333              .              .
#>            75:            4.734          2.931          1.455          3.036
#>            76:              =11            =11            =11            =11
#>            77:            4.278          3.974          1.575          3.909
#>            78:            3.974          3.279          2.684          3.467
#>            79:            2.298          3.054          2.406          1.238
#>            80:                .              .          3.009              .
#>            81:              =12            =12            =12            =12
#>            82:            4.412          0.966           2.38          1.032
#>            83:            2.227          4.875          3.953          3.653
#>            84:            8.969          3.012          4.028          4.619
#>            85:            1.009          1.642              .          3.277
#>            86:              =13            =13            =13            =13
#>            87:            4.701          2.689          2.486          0.554
#>            88:            1.447          2.651          2.392              .
#>            89:            2.285          1.647          1.446              .
#>            90:               ==             ==             ==             ==
#>            91:               *-             *-             *-             *-
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebastian B***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf und H&a***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach, 371 ***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc., c.1***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ######################## ^^^ chor010.krn ^^^ #########################
#>               (***four global comments truncated due to screen size***)
#> 
#>  humdrumR corpus of ten pieces.
#> 
#>    Data fields: 
#>          *ICppidyom :: numeric
#>           Solfa     :: character (**solfa tokens)
#>           Token     :: character
```

And that’s all it takes! We see a unique information theory prediction
for each and every note in the score.

------------------------------------------------------------------------

The ppidyom() function has *many* arguments, but here we’re just using
the default settings. What exactly did ppidyom do here, by default?:

- *Leave-one-out cross validation*:
  - For each chorale, the model is trained on the *other nine* chorales
    to create the “long-term” model.
- All four voices (bass, tenor, alto, soprano) within each chorale are
  used, each treated like a separate sequence.
- The maximum N-gram length of five is used.

### Different operational definitions

Perhaps you decide that, *given your research questions*, it makes more
sense to incorporate absolute pitch information. Just get rid of
`simple = TRUE` (or set `simple = FALSE`).

``` r

chorales |> solfa(simple = FALSE) |> ppidyom()
#> ######################## vvv chor001.krn vvv #########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:           **kern         **kern         **kern         **kern
#>             9:           *ICvox         *ICvox         *ICvox         *ICvox
#>            10:           *Ibass        *Itenor         *Ialto        *Isoprn
#>            11:          *I"Bass       *I"Tenor        *I"Alto     *I"Soprano
#>            12:        *>[A,A,B]      *>[A,A,B]      *>[A,A,B]      *>[A,A,B]
#>            13:     *>norep[A,B]   *>norep[A,B]   *>norep[A,B]   *>norep[A,B]
#>            14:              *>A            *>A            *>A            *>A
#>            15:          *clefF4       *clefGv2        *clefG2        *clefG2
#>            16:           *k[f#]         *k[f#]         *k[f#]         *k[f#]
#>            17:              *G:            *G:            *G:            *G:
#>            18:            *M3/4          *M3/4          *M3/4          *M3/4
#>            19:           *MM100         *MM100         *MM100         *MM100
#>            20:              5.7            5.7            5.7            5.7
#>            21:               =1             =1             =1             =1
#>            22:              6.7          0.973          0.973          0.973
#>            23:            6.687            6.7            6.7              .
#>            24:                .          1.305              .              .
#>            25:            6.672          6.687          1.305            6.7
#>            26:               =2             =2             =2             =2
#>            27:             2.93           7.08          1.959          7.006
#>            28:            7.723          6.972              .              .
#>            29:                .              .              .          6.891
#>            30:             3.37          3.491          7.849          2.151
#>            31:               =3             =3             =3             =3
#>            32:            7.812          4.525          2.937          1.417
#>            33:                .           0.85          0.739              .
#>            34:            6.841          2.906          3.515              .
#>            35:            6.796              .          7.977          4.852
#>            36:             4.03          7.931          7.106          4.153
#>            37:               =4             =4             =4             =4
#>            38:            4.983          3.883          3.603          0.881
#>            39:            4.172           0.93          0.959          2.414
#>            40:               =5             =5             =5             =5
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ######################## ^^^ chor001.krn ^^^ #########################
#> 
#>      (eight more pieces...)
#> 
#> ######################## vvv chor010.krn vvv #########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:            6.065          2.198          3.622           1.12
#>            62:            4.702          4.757          4.405          5.128
#>            63:               =9             =9             =9             =9
#>            64:            4.505          2.392          2.696          0.945
#>            65:            3.102          2.564          5.651          3.452
#>            66:            2.807              .              .              .
#>            67:            0.721           3.16          2.425          1.977
#>            68:                .              .          6.614              .
#>            69:            2.608           1.94          0.904          5.348
#>            70:              =10            =10            =10            =10
#>            71:            2.789          8.667          1.141          3.124
#>            72:                .          7.318              .              .
#>            73:            5.385              .          0.916            2.9
#>            74:                .          4.831              .              .
#>            75:            8.289          1.013          1.021          2.102
#>            76:              =11            =11            =11            =11
#>            77:            3.566          5.788          0.904          5.195
#>            78:            5.489          4.931           3.27          2.652
#>            79:            2.233          2.535          2.982          0.516
#>            80:                .              .          3.654              .
#>            81:              =12            =12            =12            =12
#>            82:            4.216          0.972          2.119          0.815
#>            83:            0.861          6.385          5.943          5.528
#>            84:            9.132            2.4          5.943          3.985
#>            85:            3.714          0.937              .          3.673
#>            86:              =13            =13            =13            =13
#>            87:            8.191          3.589          5.024          0.942
#>            88:            3.439          3.299          2.606              .
#>            89:              8.1          0.968          1.789              .
#>            90:               ==             ==             ==             ==
#>            91:               *-             *-             *-             *-
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebastian B***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf und H&a***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach, 371 ***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc., c.1***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ######################## ^^^ chor010.krn ^^^ #########################
#>               (***four global comments truncated due to screen size***)
#> 
#>  humdrumR corpus of ten pieces.
#> 
#>    Data fields: 
#>          *ICppidyom :: numeric
#>           Solfa     :: character (**solfa tokens)
#>           Token     :: character
```

Or maybe you want to instead consider an atonal absolute perspective on
pitch (semitones). That’s easy, just switch to the
[`semits()`](https://rdrr.io/pkg/humdrumR/man/semits.html) function:

``` r

chorales |> semits() |> ppidyom()
#> ######################## vvv chor001.krn vvv #########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:           **kern         **kern         **kern         **kern
#>             9:           *ICvox         *ICvox         *ICvox         *ICvox
#>            10:           *Ibass        *Itenor         *Ialto        *Isoprn
#>            11:          *I"Bass       *I"Tenor        *I"Alto     *I"Soprano
#>            12:        *>[A,A,B]      *>[A,A,B]      *>[A,A,B]      *>[A,A,B]
#>            13:     *>norep[A,B]   *>norep[A,B]   *>norep[A,B]   *>norep[A,B]
#>            14:              *>A            *>A            *>A            *>A
#>            15:          *clefF4       *clefGv2        *clefG2        *clefG2
#>            16:           *k[f#]         *k[f#]         *k[f#]         *k[f#]
#>            17:              *G:            *G:            *G:            *G:
#>            18:            *M3/4          *M3/4          *M3/4          *M3/4
#>            19:           *MM100         *MM100         *MM100         *MM100
#>            20:            5.358          5.358          5.358          5.358
#>            21:               =1             =1             =1             =1
#>            22:            6.358          0.965          0.965          0.965
#>            23:             6.34          6.358          6.358              .
#>            24:                .          1.301              .              .
#>            25:            6.322           6.34          1.301          6.358
#>            26:               =2             =2             =2             =2
#>            27:            2.911          6.728          1.948          6.658
#>            28:            7.362          6.615              .              .
#>            29:                .              .              .          6.539
#>            30:            3.346          3.466            7.5          2.146
#>            31:               =3             =3             =3             =3
#>            32:            7.445          4.492          2.921          1.418
#>            33:                .          0.854          0.739              .
#>            34:            6.476          2.901          3.496              .
#>            35:            6.426              .          7.622          4.824
#>            36:            3.991          7.562          6.748          4.127
#>            37:               =4             =4             =4             =4
#>            38:             4.93          3.851          3.576          0.882
#>            39:            4.149          0.936          0.962          2.411
#>            40:               =5             =5             =5             =5
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ######################## ^^^ chor001.krn ^^^ #########################
#> 
#>      (eight more pieces...)
#> 
#> ######################## vvv chor010.krn vvv #########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:            5.986          2.203          3.618          1.125
#>            62:            4.669          4.738          4.384           5.11
#>            63:               =9             =9             =9             =9
#>            64:            4.489          2.394          2.702           0.95
#>            65:            3.103          2.565          5.604          3.449
#>            66:            2.809              .              .              .
#>            67:            0.728          3.158          2.434          1.981
#>            68:                .              .          6.522              .
#>            69:            2.612          1.943           0.92          5.298
#>            70:              =10            =10            =10            =10
#>            71:            2.791           8.27           1.15           3.12
#>            72:                .          6.927              .              .
#>            73:            5.358              .          0.926          2.898
#>            74:                .           4.77              .              .
#>            75:            7.877          1.025          1.034          2.104
#>            76:              =11            =11            =11            =11
#>            77:            3.559          5.712           0.92          5.168
#>            78:            5.445          4.895           3.27          2.651
#>            79:            2.243           2.54          2.985          0.519
#>            80:                .              .          3.651              .
#>            81:              =12            =12            =12            =12
#>            82:            4.205          0.984          2.129          0.818
#>            83:            0.871           6.34          5.857          5.501
#>            84:            8.703          2.406          5.857          3.972
#>            85:            3.707          0.943              .          3.663
#>            86:              =13            =13            =13            =13
#>            87:             7.76          3.586          4.984          0.946
#>            88:            3.443          3.298          2.613              .
#>            89:            7.659          0.974          1.796              .
#>            90:               ==             ==             ==             ==
#>            91:               *-             *-             *-             *-
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebastian B***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf und H&a***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach, 371 ***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc., c.1***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ######################## ^^^ chor010.krn ^^^ #########################
#>               (***four global comments truncated due to screen size***)
#> 
#>  humdrumR corpus of ten pieces.
#> 
#>    Data fields: 
#>          *ICppidyom :: numeric
#>           Semits    :: integer (**semits tokens)
#>           Token     :: character
```

I wonder how different the ppm information content estimates will be
when we use these different approaches. Let’s compare:

``` r

chorales |> solfa(simple = TRUE)  |> ppidyom() |> pull() -> tonal
chorales |> semits() |> ppidyom() |> pull() -> atonal

draw(tonal, atonal,
         xlab = 'Tonal Information Content Estimates',
     ylab = 'Atonal Information Content Estimates')
```

![](HumdrumRCalls_files/figure-html/unnamed-chunk-6-1.png)

## Other examples

How about a different type of pitch data: harmonies? Let’s pull up
`humdrumR`’s prepackaged subset of the *Rolling Stone 200* dataset:

``` r

rs <- readHumdrum(humdrumRroot, '/HumdrumData/RollingStoneCorpus/.*hum')
#> Finding and reading files...
#>  REpath-pattern '/home/nat/R/x86_64-pc-linux-gnu-library/4.5/humdrumR/HumdrumData/RollingStoneCorpus/.*hum' matches 13 text files in 1 directory.
#> Thirteen files read from disk.
#> Validating thirteen files...all valid.
#> Parsing thirteen files...Assembling corpus...Done!

rs 
#> #################### vvv ACDC_BackInBlack.hum vvv ####################
#>              1:  !!!Rolling Stone List Rank: 187
#>              2:  !!!OTL: Back in Black
#>              3:  !!!COC: AC/DC
#>              4:  !!!RRD: 1980/
#>              5:  !!!In original RS 5x20 subset: True
#>              6:     **harm  **harte   **harm  **harte    **kern  **silbe    ***
#>              7:    !T.d.C.  !T.d.C.    !D.T.    !D.T.   !T.d.C.        !    ***
#>              8:          !        !        !        !    !OCT=5        !    ***
#>              9:         =1       =1       =1       =1        =1       =1    ***
#>             10:       *tb1     *tb1     *tb1     *tb1      *tb1        *    ***
#>             11:      *M4/4    *M4/4    *M4/4    *M4/4     *M4/4        *    ***
#>             12:        *E:      *E:      *E:      *E:    *e:dor        *    ***
#>             13:          *        *        *        *  *k[f#c#]        *    ***
#>             14:          r        .        r        .         .        .    ***
#>             15:         =2       =2       =2       =2        =2       =2    ***
#>             16:          .        .        .        .         .        .    ***
#>             17:         =3       =3       =3       =3        =3       =3    ***
#>             18:    *>Intro  *>Intro  *>Intro  *>Intro   *>Intro  *>Intro    ***
#>             19:       *tb2     *tb2     *tb2     *tb2      *tb2        *    ***
#>             20:          I    E:maj        I    E:maj         .        .    ***
#>             21:       -VII    D:maj     -VII    D:maj         .        .    ***
#>             22:         =4       =4       =4       =4        =4       =4    ***
#>             23:       *tb1     *tb1     *tb1     *tb1      *tb1        *    ***
#>             24:        IVb  A:maj/3      IVb  A:maj/3         .        .    ***
#>             25:         =5       =5       =5       =5        =5       =5    ***
#>             26:       *tb2     *tb2     *tb2     *tb2      *tb2        *    ***
#>             27:          I    E:maj        I    E:maj         .        .    ***
#>             28:       -VII    D:maj     -VII    D:maj         .        .    ***
#>             29:         =6       =6       =6       =6        =6       =6    ***
#>             30:       *tb1     *tb1     *tb1     *tb1      *tb1        *    ***
#>             31:        IVb  A:maj/3      IVb  A:maj/3         .        .    ***
#>             32:         =7       =7       =7       =7        =7       =7    ***
#>             33:       *tb2     *tb2     *tb2     *tb2      *tb2        *    ***
#>             34:          I    E:maj        I    E:maj         .        .    ***
#>             35:       -VII    D:maj     -VII    D:maj         .        .    ***
#>             36:         =8       =8       =8       =8        =8       =8    ***
#>             37:       *tb1     *tb1     *tb1     *tb1      *tb1        *    ***
#>             38:        IVb  A:maj/3      IVb  A:maj/3         .        .    ***
#>             39:         =9       =9       =9       =9        =9       =9    ***
#>             40:       *tb2     *tb2     *tb2     *tb2      *tb2        *    ***
#> 41-1073:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> #################### ^^^ ACDC_BackInBlack.hum ^^^ ####################
#> 
#>      (eleven more pieces...)
#> 
#> ################### vvv TheBeatles_HeyJude.hum vvv ###################
#>  1-1581:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>           1582:          .        .        .        .         g       na    ***
#>           1583:          .        .        .        .         .        .    ***
#>           1584:          .        .        .        .         f       na    ***
#>           1585:          .        .        .        .         .        .    ***
#>           1586:          .        .        .        .         .        .    ***
#>           1587:          .        .        .        .         .        .    ***
#>           1588:          .        .        .        .         .        .    ***
#>           1589:          .        .        .        .         .        .    ***
#>           1590:          .        .        .        .         .        .    ***
#>           1591:          .        .        .        .         .        .    ***
#>           1592:          .        .        .        .         .        .    ***
#>           1593:          .        .        .        .         .        .    ***
#>           1594:          .        .        .        .         .        .    ***
#>           1595:          .        .        .        .         .        .    ***
#>           1596:       =131     =131     =131     =131      =131     =131    ***
#>           1597:         IV   B-:maj       IV   B-:maj         g       na    ***
#>           1598:          .        .        .        .         f       na    ***
#>           1599:          .        .        .        .         g       na    ***
#>           1600:          .        .        .        .         .        .    ***
#>           1601:          .        .        .        .         f       na    ***
#>           1602:          .        .        .        .         .        .    ***
#>           1603:          .        .        .        .         .        .    ***
#>           1604:          .        .        .        .         .        .    ***
#>           1605:          .        .        .        .         .        .    ***
#>           1606:          .        .        .        .         .        .    ***
#>           1607:          .        .        .        .         .        .    ***
#>           1608:          .        .        .        .         .        .    ***
#>           1609:          .        .        .        .        e-      hey    ***
#>           1610:          .        .        .        .         d        _    ***
#>           1611:          .        .        .        .         .        .    ***
#>           1612:          .        .        .        .         c     jude    ***
#>           1613:       =132     =132     =132     =132      =132     =132    ***
#>           1614:       *tb1     *tb1     *tb1     *tb1      *tb1        *    ***
#>           1615:          I    F:maj        I    F:maj         .        .    ***
#>           1616:         *-       *-       *-       *-        *-       *-    ***
#>           1617:  !!!ONB: Translated from original encodings in the Rolling S***
#>           1618:  !!!ONB: Original transcribers noted in comments in each spi***
#>           1619:  !!!YOE: David Temperley, Trevor de Clercq
#>           1620:  !!!EED: Nathaniel Condit-Schultz
#>           1621:  !!!ENC: Nathaniel Condit-Schultz, automated
#> ################### ^^^ TheBeatles_HeyJude.hum ^^^ ###################
#>               (***two spines/paths not displayed due to screen size***)
#> 
#>  humdrumR corpus of thirteen pieces.
#> 
#>    Data fields: 
#>          *Token :: character
```

We can extract the roman numerals from the `**harm` spine, and then
apply ppidyom:

``` r

rs[[, '**harm']] |> ppidyom()
#> ########### vvv ACDC_BackInBlack.hum vvv ###########
#>              1:  !!!Rolling Stone List Rank: 187
#>              2:  !!!OTL: Back in Black
#>              3:  !!!COC: AC/DC
#>              4:  !!!RRD: 1980/
#>              5:  !!!In original RS 5x20 subset: True
#>              6:                **harm              **harm
#>              7:               !T.d.C.               !D.T.
#>              8:                     !                   !
#>              9:                    =1                  =1
#>             10:                  *tb1                *tb1
#>             11:                 *M4/4               *M4/4
#>             12:                   *E:                 *E:
#>             13:                     *                   *
#>             14:                 5.833               5.833
#>             15:                    =2                  =2
#>             16:                     .                   .
#>             17:                    =3                  =3
#>             18:               *>Intro             *>Intro
#>             19:                  *tb2                *tb2
#>             20:                 6.833               6.833
#>             21:                  6.82                6.82
#>             22:                    =4                  =4
#>             23:                  *tb1                *tb1
#>             24:                 6.807               6.807
#>             25:                    =5                  =5
#>             26:                  *tb2                *tb2
#>             27:                 2.936               2.936
#>             28:                 0.924               0.924
#>             29:                    =6                  =6
#>             30:                  *tb1                *tb1
#>             31:                 0.924               0.924
#>             32:                    =7                  =7
#>             33:                  *tb2                *tb2
#>             34:                 0.838               0.838
#>             35:                 0.924               0.924
#>             36:                    =8                  =8
#>             37:                  *tb1                *tb1
#>             38:                 0.924               0.924
#>             39:                    =9                  =9
#>             40:                  *tb2                *tb2
#> 41-1073:::::::::::::::::::::::::::::::::::::::::::::
#> ########### ^^^ ACDC_BackInBlack.hum ^^^ ###########
#> 
#>      (eleven more pieces...)
#> 
#> ########## vvv TheBeatles_HeyJude.hum vvv ##########
#>  1-1581:::::::::::::::::::::::::::::::::::::::::::::
#>           1582:                     .                   .
#>           1583:                     .                   .
#>           1584:                     .                   .
#>           1585:                     .                   .
#>           1586:                     .                   .
#>           1587:                     .                   .
#>           1588:                     .                   .
#>           1589:                     .                   .
#>           1590:                     .                   .
#>           1591:                     .                   .
#>           1592:                     .                   .
#>           1593:                     .                   .
#>           1594:                     .                   .
#>           1595:                     .                   .
#>           1596:                  =131                =131
#>           1597:                 0.093               0.094
#>           1598:                     .                   .
#>           1599:                     .                   .
#>           1600:                     .                   .
#>           1601:                     .                   .
#>           1602:                     .                   .
#>           1603:                     .                   .
#>           1604:                     .                   .
#>           1605:                     .                   .
#>           1606:                     .                   .
#>           1607:                     .                   .
#>           1608:                     .                   .
#>           1609:                     .                   .
#>           1610:                     .                   .
#>           1611:                     .                   .
#>           1612:                     .                   .
#>           1613:                  =132                =132
#>           1614:                  *tb1                *tb1
#>           1615:                  0.09               0.094
#>           1616:                    *-                  *-
#>           1617:  !!!ONB: Translated from original encodings in the Rolling Stone C***
#>           1618:  !!!ONB: Original transcribers noted in comments in each spine: !D***
#>           1619:  !!!YOE: David Temperley, Trevor de Clercq
#>           1620:  !!!EED: Nathaniel Condit-Schultz
#>           1621:  !!!ENC: Nathaniel Condit-Schultz, automated
#> ########## ^^^ TheBeatles_HeyJude.hum ^^^ ##########
#>                                               (***two
#>      global comments truncated due to screen size***)
#> 
#>  humdrumR corpus of thirteen pieces.
#> 
#>    Data fields: 
#>          *ICppidyom :: numeric
#>           Token     :: character
```

Now we get a information-content estimate for each every chord symbol.
Notice that this corpus includes separate annotations from two different
analyses (Temperley and de Clercq), and ppidyom() is using both as the
training data. We might want to just use on or the other.
