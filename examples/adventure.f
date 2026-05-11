\ This is a simple text adventure game for Assembly Forth

\ --- DEPENDENCIES ---
: LOAD-CORE S" lib/core.f" INCLUDED ;
LOAD-CORE

\ > Game state variables.
VARIABLE HP
VARIABLE GOLD

VARIABLE SEED
1337 SEED ! 

: RAND ( -- n )
    SEED @ 
    1103515245 * 12345 +        
    DUP SEED !     
;

: RANDOM ( max -- n )
    RAND ABS       
    SWAP MOD       
;

: INIT-GAME ( -- )
    10 HP !
    0 GOLD ! 
;

: PRINT-STATUS ( -- )
    S" ------------------------" TYPE CR
    S" HP: " TYPE HP @ . 
    S" | GOLD: " TYPE GOLD @ . CR 
    S" ------------------------" TYPE CR
;

: RANDOM-ROOM ( -- )
    4 RANDOM 
    DUP 0 = IF DROP S" You are in a damp, mossy cavern." TYPE CR
    ELSE DUP 1 = IF DROP S" You step into a grand hall with broken chandeliers." TYPE CR
    ELSE DUP 2 = IF DROP S" You enter a cramped, bone-filled crypt." TYPE CR
    ELSE DROP S" You find yourself in a library of rotting books." TYPE CR
    THEN THEN THEN 
;

: RANDOM-EVENT 
    4 RANDOM ( Rolls 0, 1, 2, or 3 )
    
    DUP 0 = IF 
        DROP
        S" The room is completely empty. Just dust and echoes." TYPE CR
    ELSE DUP 1 = IF
        DROP
        S" TRAP! A poison dart shoots from the wall! -2 HP." TYPE CR
        HP @ 2 - HP !
    ELSE DUP 2 = IF
        DROP
        \ Goblin attack (1 to 4 damage)
        4 RANDOM 1 + 
        DUP S" A goblin drops from the ceiling! -" TYPE . S" HP." TYPE CR
        HP @ SWAP - HP !
    ELSE ( Must be 3! )
        DROP
        \ Find gold (1 to 3 gold)
        3 RANDOM 1 +
        DUP S" You find a glittering chest! +" TYPE . S" Gold." TYPE CR
        GOLD @ + GOLD !
    THEN THEN THEN 
;

: PLAY ( -- )
    INIT-GAME
    S" Welcome to the Assembly Dungeon!" TYPE CR
    S" Survive until you find 10 gold." TYPE CR
    
    BEGIN
        PRINT-STATUS
        RANDOM-ROOM
        S" Choose a path: Left (1), Right (2), or Search (3)? " TYPE
        
        \ Wait for user input.
        WORD NUMBER 
        
        DUP 1 = OVER 2 = + OVER 3 = + IF
            DROP \ Drop the input number
            RANDOM-EVENT \ Roll the dice!
        ELSE
            DROP
            S" You stare at the wall. Pick 1, 2, or 3." TYPE CR
        THEN

        \ Win/Loss condition checks.
        HP @ 1 < IF
            S" You perished in the dungeon..." TYPE CR
            1 \ Push true to exit loop.
        ELSE GOLD @ 9 > IF
            S" You collected enough gold and escaped! YOU WIN!" TYPE CR
            1
        ELSE
            0
        THEN THEN

    UNTIL
    
    S" Game Over. Thanks for playing!" TYPE CR
;
