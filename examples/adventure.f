\ This is a simple text adventure game for Assembly Forth

\ > Game state variables.
VARIABLE HP
VARIABLE GOLD

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

: PLAY ( -- )
    INIT-GAME
    S" Welcome to the Assembly Dungeon!" TYPE CR
    S" Survive until you find 10 gold." TYPE CR
    
    BEGIN
        PRINT-STATUS
        S" You are in a dark room." TYPE CR
        S" Choose a path: Left (1), Right (2), or Search (3)? " TYPE
        
        \ Wait for user input.
        WORD NUMBER 
        
        \ Branching logic based on choice (I know this isn't the best game lol).
        DUP 1 = IF
            DROP
            S" You found a hidden pouch! +5 Gold." TYPE CR
            GOLD @ 5 + GOLD !
        ELSE DUP 2 = IF
            DROP
            S" A goblin jumps out of the shadows! -4 HP." TYPE CR
            HP @ 4 - HP !
        ELSE DUP 3 = IF
            DROP
            S" You search the room and find 1 Gold." TYPE CR
            GOLD @ 1 + GOLD !
        ELSE
            DROP
            S" You bump into a wall. Try 1, 2, or 3." TYPE CR
        THEN THEN THEN

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
