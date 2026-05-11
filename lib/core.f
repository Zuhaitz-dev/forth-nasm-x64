\ lib/core.f - Our standard library.

: SQUARE ( a -- a^2 ) 
    DUP * 
;

: DOUBLE ( a -- a*2 ) 
    DUP + 
;

: QUAD ( a -- a*4 ) 
    DOUBLE DOUBLE 
;

: ROT ( a b c -- b c a )
    >R SWAP R> SWAP 
;
