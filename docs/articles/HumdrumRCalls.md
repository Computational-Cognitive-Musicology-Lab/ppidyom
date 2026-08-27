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
```

If you have any other humdrum data on your machine, you can just pass
[`readHumdrum()`](https://humdrumR.ccml.gtcmt.gatech.edu/reference/readHumdrum.html)
the path and pattern to match your files.

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
#> ppidyom: 10 long-term group(s), N=5, model=stm, ppm=interpolation, alphabet=15
#> i is 1 in lt_groups
#>   [1/10] 0.3s elapsed, 2.8s remaining
#> i is 2 in lt_groups
#>   [2/10] 0.5s elapsed, 2.2s remaining
#> i is 3 in lt_groups
#>   [3/10] 0.8s elapsed, 1.8s remaining
#> i is 4 in lt_groups
#>   [4/10] 1.0s elapsed, 1.5s remaining
#> i is 5 in lt_groups
#>   [5/10] 1.3s elapsed, 1.3s remaining
#> i is 6 in lt_groups
#>   [6/10] 1.7s elapsed, 1.1s remaining
#> i is 7 in lt_groups
#>   [7/10] 2.0s elapsed, 0.8s remaining
#> i is 8 in lt_groups
#>   [8/10] 2.3s elapsed, 0.6s remaining
#> i is 9 in lt_groups
#>   [9/10] 2.6s elapsed, 0.3s remaining
#> i is 10 in lt_groups
#>   [10/10] 2.8s elapsed, 0.0s remaining
#> ####################### vvv chor001.krn vvv ########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:               **kern             **kern             **kern    ***
#>             9:               *ICvox             *ICvox             *ICvox    ***
#>            10:               *Ibass            *Itenor             *Ialto    ***
#>            11:              *I"Bass           *I"Tenor            *I"Alto    ***
#>            12:            *>[A,A,B]          *>[A,A,B]          *>[A,A,B]    ***
#>            13:         *>norep[A,B]       *>norep[A,B]       *>norep[A,B]    ***
#>            14:                  *>A                *>A                *>A    ***
#>            15:              *clefF4           *clefGv2            *clefG2    ***
#>            16:               *k[f#]             *k[f#]             *k[f#]    ***
#>            17:                  *G:                *G:                *G:    ***
#>            18:                *M3/4              *M3/4              *M3/4    ***
#>            19:               *MM100             *MM100             *MM100    ***
#>            20:     3.90689059560852   3.90689059560852   3.90689059560852    ***
#>            21:                   =1                 =1                 =1    ***
#>            22:    0.906890595608519  0.906890595608519  0.906890595608519    ***
#>            23:     4.90689059560852   4.90689059560852   4.90689059560852    ***
#>            24:                    .   1.26303440583379                  .    ***
#>            25:     5.16992500144231   4.85798099512757   1.26303440583379    ***
#>            26:                   =2                 =2                 =2    ***
#>            27:     1.74193184705956    5.1963972128035   1.85798099512757    ***
#>            28:     5.75488750216347   5.04439411935845                  .    ***
#>            29:                    .                  .                  .    ***
#>            30:     3.04439411935845   3.24792751344359                  6    ***
#>            31:                   =3                 =3                 =3    ***
#>            32:     6.04439411935845    4.2045711442492   2.78135971352466    ***
#>            33:                    .  0.891688188964848   0.74416109557041    ***
#>            34:     5.02680005934372    2.8588638274086   3.33985000288462    ***
#>            35:     4.90689059560852                  .   6.06608919045777    ***
#>            36:     2.51986747249927   5.88264304936184   5.16992500144231    ***
#>            37:                   =4                 =4                 =4    ***
#>            38:     2.62846413935774   3.56985560833095   3.34872815423108    ***
#>            39:     3.01667874114663  0.991779493195032  0.995456074855052    ***
#>            40:                   =5                 =5                 =5    ***
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ####################### ^^^ chor001.krn ^^^ ########################
#> 
#>      (eight more pieces...)
#> 
#> ####################### vvv chor010.krn vvv ########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:     3.59332597365578   2.25238716163429   3.45298812851182    ***
#>            62:      4.9126498648972   4.51832530769087   4.06608919045777    ***
#>            63:                   =9                 =9                 =9    ***
#>            64:     2.52910926598764   2.42530583473267   2.72368473754498    ***
#>            65:      3.4391116342577   2.57619229109342   5.12029423371771    ***
#>            66:     2.61945087710645                  .                  .    ***
#>            67:    0.663221514641656   3.13750352374994   2.46039566480808    ***
#>            68:                    .                  .   5.75321674917896    ***
#>            69:     2.45278206404265   1.98351187721143   1.01375315506733    ***
#>            70:                  =10                =10                =10    ***
#>            71:     2.86705033107673   6.28540221886225   1.24065951297955    ***
#>            72:                    .   4.17492568250068                  .    ***
#>            73:     4.76428620016572                  .   0.99007212507039    ***
#>            74:                    .   4.94251450533924                  .    ***
#>            75:     4.99435343685886   1.11547721741994  0.908319309778648    ***
#>            76:                  =11                =11                =11    ***
#>            77:     3.61812936465636   5.07542101497908  0.987288948250446    ***
#>            78:     4.59289668226337   4.39827898101748    3.1768444153821    ***
#>            79:     2.16214765085059   2.57631495210764   2.93326601103282    ***
#>            80:                    .                  .   3.59578547001569    ***
#>            81:                  =12                =12                =12    ***
#>            82:       3.811030580201   1.09080009705465   2.12629806904205    ***
#>            83:    0.867436787378637   5.45724405939953   5.26434060333442    ***
#>            84:     7.28540221886225   2.65037790917012   5.07948478382681    ***
#>            85:     2.96347412397489    1.1110142845159                  .    ***
#>            86:                  =13                =13                =13    ***
#>            87:     6.22881869049588   3.52199854305685   4.53713397563054    ***
#>            88:     2.84890741150211   3.26473469482363   2.53915881110803    ***
#>            89:     2.15912979844282   1.06058798759344   1.91537706149635    ***
#>            90:                   ==                 ==                 ==    ***
#>            91:                   *-                 *-                 *-    ***
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebas***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf u***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ####################### ^^^ chor010.krn ^^^ ########################
#>               (***one spine/path not displayed due to screen size***)
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
#> ppidyom: 10 long-term group(s), N=5, model=stm, ppm=interpolation, alphabet=52
#> i is 1 in lt_groups
#>   [1/10] 0.3s elapsed, 2.7s remaining
#> i is 2 in lt_groups
#>   [2/10] 0.6s elapsed, 2.3s remaining
#> i is 3 in lt_groups
#>   [3/10] 1.0s elapsed, 2.3s remaining
#> i is 4 in lt_groups
#>   [4/10] 1.2s elapsed, 1.8s remaining
#> i is 5 in lt_groups
#>   [5/10] 1.6s elapsed, 1.6s remaining
#> i is 6 in lt_groups
#>   [6/10] 1.7s elapsed, 1.2s remaining
#> i is 7 in lt_groups
#>   [7/10] 2.1s elapsed, 0.9s remaining
#> i is 8 in lt_groups
#>   [8/10] 2.7s elapsed, 0.7s remaining
#> i is 9 in lt_groups
#>   [9/10] 3.0s elapsed, 0.3s remaining
#> i is 10 in lt_groups
#>   [10/10] 3.2s elapsed, 0.0s remaining
#> ####################### vvv chor001.krn vvv ########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:               **kern             **kern             **kern    ***
#>             9:               *ICvox             *ICvox             *ICvox    ***
#>            10:               *Ibass            *Itenor             *Ialto    ***
#>            11:              *I"Bass           *I"Tenor            *I"Alto    ***
#>            12:            *>[A,A,B]          *>[A,A,B]          *>[A,A,B]    ***
#>            13:         *>norep[A,B]       *>norep[A,B]       *>norep[A,B]    ***
#>            14:                  *>A                *>A                *>A    ***
#>            15:              *clefF4           *clefGv2            *clefG2    ***
#>            16:               *k[f#]             *k[f#]             *k[f#]    ***
#>            17:                  *G:                *G:                *G:    ***
#>            18:                *M3/4              *M3/4              *M3/4    ***
#>            19:               *MM100             *MM100             *MM100    ***
#>            20:     5.70043971814109   5.70043971814109   5.70043971814109    ***
#>            21:                   =1                 =1                 =1    ***
#>            22:     6.70043971814109  0.972519263577893  0.972519263577893    ***
#>            23:     6.68650052718322   6.70043971814109   6.70043971814109    ***
#>            24:                    .   1.30518483105279                  .    ***
#>            25:      6.6724253419715   6.68650052718322   1.30518483105279    ***
#>            26:                   =2                 =2                 =2    ***
#>            27:     2.93029102818859   7.08037341646402   1.95858007262002    ***
#>            28:     7.72280753116955   6.97154355395077                  .    ***
#>            29:                    .                  .                  .    ***
#>            30:     3.37011162839733   3.49124806589896   7.84862294042934    ***
#>            31:                   =3                 =3                 =3    ***
#>            32:     7.81249822533356   4.52474497788705   2.93741546262198    ***
#>            33:                    .  0.849653408875252  0.738875184174838    ***
#>            34:     6.84130225398094    2.9056300494026   3.51525352890975    ***
#>            35:     6.79627142292859                  .   7.97727992349992    ***
#>            36:     4.03030276016353   7.93073733756289   7.10590850857116    ***
#>            37:                   =4                 =4                 =4    ***
#>            38:     4.98288597913615   3.88310434274415   3.60299642355142    ***
#>            39:     4.17155978353326  0.930237794500954  0.958931750160245    ***
#>            40:                   =5                 =5                 =5    ***
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ####################### ^^^ chor001.krn ^^^ ########################
#> 
#>      (eight more pieces...)
#> 
#> ####################### vvv chor010.krn vvv ########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:     6.06454450541675   2.19844763727575   3.62241376350288    ***
#>            62:      4.7015952608868   4.75675458543285   4.40529677366614    ***
#>            63:                   =9                 =9                 =9    ***
#>            64:     4.50482989866636   2.39175420003458   2.69578049135276    ***
#>            65:     3.10229857584614   2.56437197808257   5.65052271936428    ***
#>            66:     2.80689786675808                  .                  .    ***
#>            67:    0.721367729361593   3.15970593751872   2.42455130227802    ***
#>            68:                    .                  .   6.61415421343594    ***
#>            69:     2.60845810936517   1.93971795114813  0.904434638002543    ***
#>            70:                  =10                =10                =10    ***
#>            71:     2.78888011144306   8.66666784069036   1.14073280145213    ***
#>            72:                    .   7.31791503238074                  .    ***
#>            73:     5.38513304179707                  .  0.916316964521882    ***
#>            74:                    .   4.83145663596348                  .    ***
#>            75:     8.28940414941975    1.0131709337784   1.02050203544335    ***
#>            76:                  =11                =11                =11    ***
#>            77:     3.56552602125675   5.78777938372084  0.904434638002543    ***
#>            78:     5.48948885249348   4.93073733756289   3.26975435797274    ***
#>            79:     2.23311135648397   2.53481639273714   2.98245081509376    ***
#>            80:                    .                  .   3.65435071357779    ***
#>            81:                  =12                =12                =12    ***
#>            82:     4.21557946842579  0.972421318825301   2.11856111416454    ***
#>            83:     0.86142026027654   6.38505348834615   5.94273579455524    ***
#>            84:     9.13209072793344   2.40022262086411   5.94273579455524    ***
#>            85:     3.71434729150419  0.937213416247146                  .    ***
#>            86:                  =13                =13                =13    ***
#>            87:     8.19133343902229   3.58879045184572    5.0244689955939    ***
#>            88:     3.43881588487865   3.29871562335776    2.6059267341424    ***
#>            89:      8.0996512694839  0.967634474334657    1.7886953066786    ***
#>            90:                   ==                 ==                 ==    ***
#>            91:                   *-                 *-                 *-    ***
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebas***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf u***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ####################### ^^^ chor010.krn ^^^ ########################
#>               (***one spine/path not displayed due to screen size***)
#> 
#>  humdrumR corpus of ten pieces.
#> 
#>    Data fields: 
#>          *ICppidyom :: numeric
#>           Solfa     :: character (**solfa tokens)
#>           Token     :: character
```

Or maybe you just want to atonal absolute pitch (semitones). That’s
easy, just switch to the
[`semits()`](https://humdrumR.ccml.gtcmt.gatech.edu/reference/semits.html)
function:

``` r

chorales |> semits() |> ppidyom()
#> ppidyom: 10 long-term group(s), N=5, model=stm, ppm=interpolation, alphabet=41
#> i is 1 in lt_groups
#>   [1/10] 0.3s elapsed, 3.0s remaining
#> i is 2 in lt_groups
#>   [2/10] 0.5s elapsed, 2.0s remaining
#> i is 3 in lt_groups
#>   [3/10] 0.6s elapsed, 1.5s remaining
#> i is 4 in lt_groups
#>   [4/10] 0.8s elapsed, 1.1s remaining
#> i is 5 in lt_groups
#>   [5/10] 1.0s elapsed, 1.0s remaining
#> i is 6 in lt_groups
#>   [6/10] 1.1s elapsed, 0.7s remaining
#> i is 7 in lt_groups
#>   [7/10] 1.5s elapsed, 0.6s remaining
#> i is 8 in lt_groups
#>   [8/10] 1.7s elapsed, 0.4s remaining
#> i is 9 in lt_groups
#>   [9/10] 1.9s elapsed, 0.2s remaining
#> i is 10 in lt_groups
#>   [10/10] 2.2s elapsed, 0.0s remaining
#> ####################### vvv chor001.krn vvv ########################
#>             1:  !!!COM: Bach, Johann Sebastian
#>             2:  !!!CDT: 1685/02/21/-1750/07/28/
#>             3:  !!!OTL@@DE: Aus meines Herzens Grunde
#>             4:  !!!OTL@EN:      From the Depths of My Heart
#>             5:  !!!SCT: BWV 269
#>             6:  !!!PC#: 1
#>             7:  !!!AGN: chorale
#>             8:               **kern             **kern             **kern    ***
#>             9:               *ICvox             *ICvox             *ICvox    ***
#>            10:               *Ibass            *Itenor             *Ialto    ***
#>            11:              *I"Bass           *I"Tenor            *I"Alto    ***
#>            12:            *>[A,A,B]          *>[A,A,B]          *>[A,A,B]    ***
#>            13:         *>norep[A,B]       *>norep[A,B]       *>norep[A,B]    ***
#>            14:                  *>A                *>A                *>A    ***
#>            15:              *clefF4           *clefGv2            *clefG2    ***
#>            16:               *k[f#]             *k[f#]             *k[f#]    ***
#>            17:                  *G:                *G:                *G:    ***
#>            18:                *M3/4              *M3/4              *M3/4    ***
#>            19:               *MM100             *MM100             *MM100    ***
#>            20:     5.35755200461808   5.35755200461808   5.35755200461808    ***
#>            21:                   =1                 =1                 =1    ***
#>            22:     6.35755200461808  0.965234581839323  0.965234581839323    ***
#>            23:     6.33985000288462   6.35755200461808   6.35755200461808    ***
#>            24:                    .   1.30065947813371                  .    ***
#>            25:     6.32192809488736   6.33985000288462   1.30065947813371    ***
#>            26:                   =2                 =2                 =2    ***
#>            27:     2.91146332539834    6.7279204545632   1.94753258010586    ***
#>            28:     7.36194377373524   6.61470984411521                  .    ***
#>            29:                    .                  .                  .    ***
#>            30:     3.34577483684173   3.46566357234881    7.4998458870832    ***
#>            31:                   =3                 =3                 =3    ***
#>            32:      7.4446008137115   4.49185309632967    2.9205655325056    ***
#>            33:                    .  0.853503382861494  0.739408770094535    ***
#>            34:      6.4757334309664   2.90128578296133    3.4964258261195    ***
#>            35:      6.4262647547021                  .   7.62205181945638    ***
#>            36:     3.99138686969529   7.56224242422107   6.74819284958946    ***
#>            37:                   =4                 =4                 =4    ***
#>            38:      4.9296106721086   3.85085656069419   3.57634937041645    ***
#>            39:     4.14867726773827  0.935551292273158  0.962271199918873    ***
#>            40:                   =5                 =5                 =5    ***
#> 41-133::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#> ####################### ^^^ chor001.krn ^^^ ########################
#> 
#>      (eight more pieces...)
#> 
#> ####################### vvv chor010.krn vvv ########################
#>   1-60::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#>            61:     5.98641093525204   2.20256455713993   3.61844140442042    ***
#>            62:     4.66859754709959   4.73762121564574    4.3840365193128    ***
#>            63:                   =9                 =9                 =9    ***
#>            64:      4.4885969720114   2.39429304108255   2.70182873761243    ***
#>            65:      3.1031988876415   2.56523811108314   5.60418508614095    ***
#>            66:     2.80898324620438                  .                  .    ***
#>            67:    0.728461472560661   3.15805566657361   2.43363848238438    ***
#>            68:                    .                  .    6.5224414161631    ***
#>            69:     2.61162409184645   1.94293682569109  0.919534946032161    ***
#>            70:                  =10                =10                =10    ***
#>            71:     2.79089245561896   8.27029532647204   1.15030480597302    ***
#>            72:                    .   6.92679015304622                  .    ***
#>            73:     5.35755200461808                  .   0.92568000857188    ***
#>            74:                    .   4.77007390597814                  .    ***
#>            75:     7.87733526481773   1.02475113147812   1.03417305722405    ***
#>            76:                  =11                =11                =11    ***
#>            77:     3.55930354554969   5.71228133078561  0.919534946032161    ***
#>            78:     5.44453274225796   4.89514538793542   3.27018912491574    ***
#>            79:     2.24336219518357   2.54044383394251   2.98476548630484    ***
#>            80:                    .                  .   3.65139815378712    ***
#>            81:                  =12                =12                =12    ***
#>            82:     4.20465434492184  0.983768729241584   2.12920171315837    ***
#>            83:    0.871072621760088   6.33985000288463   5.85738863419094    ***
#>            84:     8.70306461432186   2.40647290126152   5.85738863419094    ***
#>            85:     3.70695302509977   0.94321320118876                  .    ***
#>            86:                  =13                =13                =13    ***
#>            87:     7.76044274599664    3.5857480684187   4.98447698558761    ***
#>            88:     3.44307203819665   3.29789316304545   2.61307613693007    ***
#>            89:     7.65944707833267  0.974030086152662   1.79566469188394    ***
#>            90:                   ==                 ==                 ==    ***
#>            91:                   *-                 *-                 *-    ***
#>            92:  !!!hum2abc: -Q ''
#>            93:  !!!title: @{PC#}. @{OTL@@DE}
#>            94:  !!!YOR1: 371 vierstimmige Choralges&auml;nge von Johann Sebas***
#>            95:  !!!YOR2: 4th ed. by Alfred D&ouml;rffel (Leipzig: Breitkopf u***
#>            96:  !!!YOR2: c.1875). 178 pp. Plate "V.A.10".  reprint: J.S. Bach***
#>            97:  !!!YOR4: Chorales (New York: Associated Music Publishers, Inc***
#>            98:  !!!SMS: B&H, 4th ed, Alfred D&ouml;rffel, c.1875, plate V.A.10
#>            99:  !!!EED:  Craig Stuart Sapp
#>           100:  !!!EEV:  2009/05/22
#> ####################### ^^^ chor010.krn ^^^ ########################
#>               (***one spine/path not displayed due to screen size***)
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
#> ppidyom: 10 long-term group(s), N=5, model=stm, ppm=interpolation, alphabet=15
#> i is 1 in lt_groups
#>   [1/10] 0.1s elapsed, 1.3s remaining
#> i is 2 in lt_groups
#>   [2/10] 0.3s elapsed, 1.2s remaining
#> i is 3 in lt_groups
#>   [3/10] 0.4s elapsed, 1.0s remaining
#> i is 4 in lt_groups
#>   [4/10] 0.6s elapsed, 0.8s remaining
#> i is 5 in lt_groups
#>   [5/10] 0.8s elapsed, 0.8s remaining
#> i is 6 in lt_groups
#>   [6/10] 0.9s elapsed, 0.6s remaining
#> i is 7 in lt_groups
#>   [7/10] 1.1s elapsed, 0.5s remaining
#> i is 8 in lt_groups
#>   [8/10] 1.5s elapsed, 0.4s remaining
#> i is 9 in lt_groups
#>   [9/10] 1.7s elapsed, 0.2s remaining
#> i is 10 in lt_groups
#>   [10/10] 1.8s elapsed, 0.0s remaining
chorales |> semits() |> ppidyom() |> pull() -> atonal
#> ppidyom: 10 long-term group(s), N=5, model=stm, ppm=interpolation, alphabet=41
#> i is 1 in lt_groups
#>   [1/10] 0.2s elapsed, 1.4s remaining
#> i is 2 in lt_groups
#>   [2/10] 0.4s elapsed, 1.5s remaining
#> i is 3 in lt_groups
#>   [3/10] 0.6s elapsed, 1.3s remaining
#> i is 4 in lt_groups
#>   [4/10] 0.7s elapsed, 1.0s remaining
#> i is 5 in lt_groups
#>   [5/10] 1.0s elapsed, 1.0s remaining
#> i is 6 in lt_groups
#>   [6/10] 1.2s elapsed, 0.8s remaining
#> i is 7 in lt_groups
#>   [7/10] 1.5s elapsed, 0.6s remaining
#> i is 8 in lt_groups
#>   [8/10] 1.7s elapsed, 0.4s remaining
#> i is 9 in lt_groups
#>   [9/10] 1.9s elapsed, 0.2s remaining
#> i is 10 in lt_groups
#>   [10/10] 2.0s elapsed, 0.0s remaining

draw(tonal, atonal)
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
```

We can extract the roman numerals from the `**harm` spine, and then
apply ppidyom:

``` r

rs[[, '**harm']] |> ppidyom()
#> ppidyom: 13 long-term group(s), N=5, model=stm, ppm=interpolation, alphabet=57
#> i is 1 in lt_groups
#>   [1/13] 0.3s elapsed, 3.4s remaining
#> i is 2 in lt_groups
#>   [2/13] 0.5s elapsed, 2.5s remaining
#> i is 3 in lt_groups
#>   [3/13] 0.5s elapsed, 1.8s remaining
#> i is 4 in lt_groups
#>   [4/13] 1.0s elapsed, 2.2s remaining
#> i is 5 in lt_groups
#>   [5/13] 1.4s elapsed, 2.2s remaining
#> i is 6 in lt_groups
#>   [6/13] 1.5s elapsed, 1.7s remaining
#> i is 7 in lt_groups
#>   [7/13] 1.6s elapsed, 1.4s remaining
#> i is 8 in lt_groups
#>   [8/13] 1.8s elapsed, 1.1s remaining
#> i is 9 in lt_groups
#>   [9/13] 1.8s elapsed, 0.8s remaining
#> i is 10 in lt_groups
#>   [10/13] 2.0s elapsed, 0.6s remaining
#> i is 11 in lt_groups
#>   [11/13] 2.1s elapsed, 0.4s remaining
#> i is 12 in lt_groups
#>   [12/13] 2.3s elapsed, 0.2s remaining
#> i is 13 in lt_groups
#>   [13/13] 2.6s elapsed, 0.0s remaining
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
#>             14:      5.83289001416474    5.83289001416474
#>             15:                    =2                  =2
#>             16:                     .                   .
#>             17:                    =3                  =3
#>             18:               *>Intro             *>Intro
#>             19:                  *tb2                *tb2
#>             20:      6.83289001416474    6.83289001416474
#>             21:      6.82017896241519    6.82017896241519
#>             22:                    =4                  =4
#>             23:                  *tb1                *tb1
#>             24:       6.8073549220576     6.8073549220576
#>             25:                    =5                  =5
#>             26:                  *tb2                *tb2
#>             27:      2.93643487122253    2.93643487122253
#>             28:     0.924448966992823   0.924448966992823
#>             29:                    =6                  =6
#>             30:                  *tb1                *tb1
#>             31:     0.924448966992823   0.924448966992823
#>             32:                    =7                  =7
#>             33:                  *tb2                *tb2
#>             34:     0.838149120598603   0.838149120598603
#>             35:     0.924448966992823   0.924448966992823
#>             36:                    =8                  =8
#>             37:                  *tb1                *tb1
#>             38:     0.924448966992823   0.924448966992823
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
#>           1597:    0.0930565187065882  0.0935997270988957
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
#>           1615:    0.0904253992924302  0.0936361094785422
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
