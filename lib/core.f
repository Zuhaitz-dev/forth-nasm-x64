\ lib/core.f aka standard library for Assembly Forth

: SQUARE ( a -- a^2 ) DUP * ;
: DOUBLE ( a -- a*2 ) DUP + ;

: MAX ( a b -- max )
    2DUP > IF 
        DROP 
    ELSE 
        SWAP DROP 
    THEN 
;

: COUNTDOWN ( n -- )
    BEGIN 
        DUP . CR 
        1 - 
        DUP 0 = 
    UNTIL 
    DROP 
;

: GREETING ( -- )
    S" Welcome to Assembly Forth!" TYPE CR
;
