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
