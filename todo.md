
Make ltm counts with missing zeros, and 
  + make sure interpolation works 
	  + Would need to create P separately in each countN, then line them up later.
	
	
Can stm_counts skip zeros? 
  + Selectice expand ,or multiple expands?
  + They could be simply be removed after the fact?
	
	
Can stm experimental approach be "expanded" to fill in previous values.
  + May require normal cumsum stage, with -1 coming later.
	
	
	## big one
	
	Is t of N  always  C of N + 1 (or whatever?
	
	 Could be useful to 
	   + limit RAM usage
		 + speed up interpolation.
	 
	 Is it worthwhile?
	
	
# other big one

Can we do the rolling entropy

If we rescale counts, then the log of the square roots of the counts sum u;

log(27 + 15+3) = log(sqrt(27)) + log(sqrt(15)) + log(sqrt(3))

+ As of now, this seems to not be possible
	
