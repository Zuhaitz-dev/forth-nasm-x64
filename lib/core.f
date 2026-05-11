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

: MAX ( a b -- max )
    2DUP > IF 
        DROP    \ If a > b, drop b and leave a.
    ELSE
        SWAP DROP \ The other way around.
    THEN
;

\ Prints a countdown from n to 1.
: COUNTDOWN ( n -- )
    BEGIN
        DUP . CR 
        1 - 
        DUP 0 =
    UNTIL
    DROP 
;
