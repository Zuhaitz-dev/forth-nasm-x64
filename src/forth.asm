
; forth.asm
; So the main reason for doing it in assembly is because some of my keys are dead.
; I have no braces, no brackets, etc. And while at home I do have a USB keyboard...
; I am mostly doing this outside. I could have used digraphs, I know, but we are not
; doing that over here.
; > Now I am wondering if clang-format can transform the digraphs into the meant symbols.

; I don't promise anything but here's the de facto standard for FORTH:
; https://www.forth.org/ansforth/ansforth.html
; THIS SHALL BE YOUR BIBLE.

%include "forth.inc"

global _start

section .text

; -> Entry point.
_start:

    ; First we set up our data stack pointer.
    ;   We point rbp to the top of the reserved memory block.
    mov dsp, data_stack_top

; > Command line argument parsing.
mov rax, [rsp]  ; grab argc.
cmp rax, 1 
jle .start_repl ; If argc <= 1 then no files passed.

mov rdi, [rsp + 16] ; Point to the filename string.

; TODO: these could be some macros.
mov rax, SYS_OPEN
xor rsi, rsi        ; O_RDONLY flag (0)
xor rdx, rdx        ; mode (0)
syscall

; Check if opened...
cmp rax, 0
jl .start_repl  ; If it fails we just ignore and start REPL 
                ; This could be improved (TODO).

; Success, so we push STDIN to the include stack.
mov rbx, [source_id]
mov rcx, [include_sp]
mov [rcx], rbx
add rcx, 8
mov [include_sp], rcx

; Then set new source_id to our newly opened file! :D 
mov [source_id], rax

.start_repl:
    ; Set our instruction pointer to our test program...
    mov ip, repl_loop

    NEXT

; > Helper subroutines.

read_line:
    push rcx 
    push r11 

    ; Only print prompt if we are reading from STDIN (0)
    mov rdi, [source_id]
    test rdi, rdi
    jnz .skip_prompt
    do_sys_write prompt_str, 2
.skip_prompt:

    ; --- THE CRITICAL FIX ---
    ; Explicitly load the current file descriptor into rdi
    mov rdi, [source_id]
    do_sys_read rdi, tib, TERMINAL_INPUT_BUFFER_SIZE
    
    ; Check if we hit EOF (0) or an error (< 0)
    cmp rax, 0
    jle .eof_reached
    
    ; Update parsing vars.
    mov [num_tib], rax      ; Total bytes read
    mov qword [to_in], 0    ; Reset >IN back to index 0

    pop r11 
    pop rcx 
    ret

.eof_reached:
    mov rdi, [source_id]
    test rdi, rdi
    jz .exit_program        ; EOF on STDIN (Ctrl+D or piped EOF) -> Exit Forth

    ; We hit EOF on a file. Close it.
    mov rax, SYS_CLOSE
    syscall                 ; rdi already contains source_id

    ; Pop previous source_id from the include stack
    mov rbx, [include_sp]
    sub rbx, 8
    mov [include_sp], rbx
    mov rcx, [rbx]
    mov [source_id], rcx

    ; We just dropped back to the previous file/stdin.
    ; We need to read a line from IT immediately to continue parsing.
    pop r11
    pop rcx
    jmp read_line           ; Loop back to the top of read_line!

.exit_program:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

; Native word reader.
; Returns: addr in r8, length in r9.
read_word_native:
.check_buffer:
    mov rcx, [to_in]
    cmp rcx, [num_tib]
    jl .skip_whitespace
    call read_line
    jmp .check_buffer
; TODO: Add a macro for this.
.skip_whitespace:
    mov rcx, [to_in]
    cmp rcx, [num_tib]
    jge .check_buffer
    mov al, [tib + rcx]
    inc qword [to_in]
    cmp al, ' '
    jle .skip_whitespace
    mov rbx, [to_in]
    dec rbx
    lea r8, [tib + rbx]
    mov r9, 1
.read_word:
    mov rcx, [to_in]
    cmp rcx, [num_tib]
    jge .word_done
    mov al, [tib + rcx]
    inc qword [to_in]
    cmp al, ' '
    jle .word_done
    inc r9
    jmp .read_word
.word_done:
    ret

; Native number parser.
; Expects: addr in r8, len in r9.
; Returns: val in rax.
parse_number_native:
    mov rcx, r9
    mov r10, r8
    xor rax, rax
    xor rbx, rbx
.loop:
    test rcx, rcx
    jz .done
    mov bl, [r10]
    cmp bl, '0'
    jl .not_a_number
    cmp bl, '9'
    jg .not_a_number
    sub bl, '0'
    imul rax, 10
    add rax, rbx
    inc r10
    dec rcx
    jmp .loop
.not_a_number:
    xor rax, rax
    ret
.done:
    ret

; > DICTIONARY
;   If you want to implement yours this might be useful.
;   https://users.ece.cmu.edu/~koopman/stack_computers/appb.html

; Primitive exit.
defcode "EXIT_PROG", EXIT_PROG
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

; DUP (a -- a a )
defcode "DUP", DUP
    mov rax, [dsp]  ; Read the top item.
    sub dsp, 8      ; Grow the stack downwards.
    mov [dsp], rax  ; Then we write duplicate.
    NEXT

; 2DUP ( a b -- a b a b )
defcode "2DUP", TWODUP
    mov rax, [dsp + 8]
    mov rbx, [dsp]
    sub dsp, 16
    mov [dsp + 8], rax
    mov [dsp], rbx
    NEXT

; DROP ( a -- )
defcode "DROP", DROP
    add dsp, 8      ; Shrink stack upwards.
    NEXT

; INCLUDED ( addr len -- )
; Opens file and pushes the input source into stack.
defcode "INCLUDED", INCLUDED
    mov rcx, [dsp]
    mov rsi, [dsp + 8]
    add dsp, 16

    ; Copy string to null-terminated buffer for syscall
    mov rdi, filename_buf
    rep movsb
    mov byte [rdi], 0   ; Append null terminator

    ; Push current source_id to include_stack
    mov rax, [source_id]
    mov rbx, [include_sp]
    mov [rbx], rax
    add rbx, 8
    mov [include_sp], rbx

    ; PERHAPS, perhaps I will add a macro for this.
    mov rax, SYS_OPEN
    mov rdi, filename_buf
    xor rsi, rsi        ; O_RDONLY flag (0)
    xor rdx, rdx        ; mode (0)
    syscall

    ; Check for error.
    cmp rax, 0
    jl .file_error

    ; Set new source_id (all good).
    mov [source_id], rax
    NEXT

.file_error:
    ; If open fails, restore the stack pointer and silently fail for now
    ; (In a full system, you would THROW an exception here)
    mov rbx, [include_sp]
    sub rbx, 8
    mov [include_sp], rbx
    NEXT

; LIT ( a -- )
; Reads inline number following the LIT XT.
; Pushes it to the stack.
defcode "LIT", LIT
    lodsq   ; Read the raw number into raw and advance IP by 8...
    sub dsp, 8
    mov [dsp], rax
    NEXT

; WORD ( -- addr len )
; Parses the next space-delimited word directly from the TIB.
; NOTE: Originally we just dealt with stdin, but the thing is that
;       with the unbuffered characters directly from the OS some 
;       things happen, like:
;       > 5 5 + .
;       > > > 10 >
;       This is because it's doing each action as if they were 
;       separated. So sending it all as a string prevents this 
;       PROMPT ghost phenomenon.
defcode "WORD", WORD_PRIM
    push ip
    call read_word_native
    pop ip
    sub dsp, 8
    mov [dsp], r8
    sub dsp, 8
    mov [dsp], r9
    NEXT

; NUMBER ( addr len -- val )
; Base-10 string to integer converter.
defcode "NUMBER", NUMBER
    mov r9, [dsp]       ; length
    mov r8, [dsp + 8]   ; address
    add dsp, 16
    push ip
    call parse_number_native
    pop ip
    sub dsp, 8
    mov [dsp], rax
    NEXT

; BRANCH ( -- )
; Unconditional jump.
defcode "BRANCH", BRANCH
    lodsq       ; Read the offset into rax and advance instruction pointer. 
    add ip, rax ; Add offset to IP.
    sub ip, 8
    NEXT

; 0BRANCH ( a -- )
; Conditional jump.
defcode "0BRANCH", ZBRANCH
    mov rbx, [dsp]
    add dsp, 8

    lodsq       ; Read the inline offset into rax.

    test rbx, rbx
    jnz .skip

    add ip, rax ; If so we add the offset to take the branch.
    sub ip, 8

.skip:
    NEXT

; + ( a b -- a+b )
defcode "+", ADD
    mov rax, [dsp]
    add dsp, 8
    add [dsp], rax
    NEXT

; - ( a b -- a-b )
defcode "-", SUB 
    mov rax, [dsp]
    add dsp, 8
    sub [dsp], rax
    NEXT

; * (a b -- a*b )
defcode "*", MULT
    mov rax, [dsp]
    add dsp, 8
    mov rbx, [dsp]
    imul rbx, rax
    mov [dsp], rbx 
    NEXT 

; = ( a b -- flag )
; Pushes -1 if equal, 0 if not.
defcode "=", EQUALS
    mov rax, [dsp]
    add dsp, 8
    mov rbx, [dsp]
    cmp rbx, rax
    sete al 
    movzx rax, al   ; Zero-extend.
    neg rax         ; -1 is true in Forth.
    mov [dsp], rax
    NEXT

; SWAP ( a b -- b a )
defcode "SWAP", SWAP
    mov rax, [dsp]
    mov rbx, [dsp + 8]
    mov [dsp + 8], rax
    mov [dsp], rbx
    NEXT

; OVER ( a b -- a b a )
defcode "OVER", OVER
    mov rax, [dsp + 8]
    sub dsp, 8
    mov [dsp], rax
    NEXT

; ! ( value address -- )
defcode "!", STORE
    mov rax, [dsp + 8]
    mov rbx, [dsp]
    mov [rbx], rax
    add dsp, 16
    NEXT

; @ ( address -- value )
defcode "@", FETCH 
    mov rax, [dsp]
    mov rbx, [rax]
    mov [dsp], rbx
    NEXT

; EMIT ( c -- )
; NOTE: I implemented '.' first, check the comments
;       from there lol.
;       This is pretty much the first part of '.print_loop'
;       for that primitive.
defcode "EMIT", EMIT
    push ip 

    do_sys_write dsp, 1

    pop ip 

    add dsp, 8
    NEXT

; KEY ( -- c )
; Reads the next character from the TIB.
defcode "KEY", KEY
    push ip

.check_buffer:
    mov rcx, [to_in]
    cmp rcx, [num_tib]
    jl .get_char            ; If >IN is less than #TIB then there are chars.
    call read_line          ; Buffer empty so fetch a new line from the OS.
    jmp .check_buffer

.get_char:
    mov rcx, [to_in]        ; Get the current >IN index.
    xor rax, rax
    mov al, [tib + rcx]     ; Read char from buffer
    inc qword [to_in]       ; Advance the >IN pointer for next read.

    pop ip
    
    sub dsp, 8
    mov [dsp], rax
    NEXT

; . ( a -- )
; NOTE: remember that this is little-endian.
;       The characters are pushed revertedly (or however it is said)
;       considering this specific detail.
defcode ".", DOT
    push ip     ; save the instruction pointer.

    mov rax, [dsp]
    add dsp, 8

    mov r12, rsp    ; Save hardware stack boundary
                    ; so we know when to stop.
    
    push 32     ; ASCII space ' '.

    ; Checking for zero.
    test rax, rax
    jnz .check_neg
    push '0'
    jmp .print_loop

.check_neg:
    mov r13, 0  ; is_negative flag.
    cmp rax, 0
    jge .div_loop
    mov r13, 1  ; is negative.
    neg rax     ; For division.

.div_loop:
    xor rdx, rdx
    mov rbx, 10
    div rbx         ; rax = rax / 10
                    ; rdx = remainder
    add rdx, '0'    ; Converting to ASCII.
    push rdx
    test rax, rax
    jnz .div_loop

    cmp r13, 1 
    jne .print_loop
    push '-'        ; If it's negative we need
                    ; the sign.

.print_loop:
    do_sys_write rsp, 1

    add rsp, 8

    cmp rsp, r12    ; Have we printed everything?
    jne .print_loop

    pop ip      ; restore the instruction pointer.
    NEXT

; CR ( -- )
; To print newlines.
defcode "CR", CR 
    push ip 

    push 10 ; ASCII newline.
    do_sys_write rsp, 1 
    add rsp, 8

    pop ip 
    NEXT

; FIND ( addr len -- xt | 0 )
; Search for a word in the dictionary. Returns 0 if not found, XT if found.
defcode "FIND", FIND
    mov rcx, [dsp]      ; Pop length.
    mov rdi, [dsp + 8]  ; Pop address.
    add dsp, 16

    mov rdx, [latest]

.search_loop:
    test rdx, rdx
    jz .not_found

    ; Read length/flags byte (link + 8).
    movzx rbx, byte [rdx + 8]
    mov r11, rbx    ; Save the full flags byte.
    and rbx, 0x3F   ; Mask out flags.

    cmp rbx, rcx    ; We compare lengths first.
    jne .next_word

    ; Lengths match so now we compare strings
    ; (char by char).
    push rdi            ; Save original input address.
    mov r8, rdi         ; Input string.
    lea r9, [rdx + 9]   ; Dictionary name.
    mov r10, rcx        ; Counter for comparison.

.char_loop:
    mov al, [r8]
    cmp al, [r9]
    jne .mismatch
    inc r8
    inc r9
    dec r10
    jnz .char_loop

    ; Strings match.
    pop rdi     ; Clean up hardware stack...
    
    ; Calculate XT: It is the address after the name, aligned to 8 bytes.
    mov rax, rdx        ; Start at link.
    add rax, 8          ; Skip link.
    add rax, 1          ; Skip length byte.
    add rax, rbx        ; Skip name string.
    add rax, 7          ; Align to next 8-byte boundary.
    and rax, ~7
    
    sub dsp, 8          ; Push XT to data stack.
    mov [dsp], rax
    
    ; check the immediate flag.
    test r11, F_IMMED
    jnz .is_immediate 

    ; Normal word (0).
    sub dsp, 8
    mov qword [dsp], 0
    NEXT

.is_immediate:
    ; Immediate word (1).
    sub dsp, 8
    mov qword [dsp], 1 
    NEXT

.mismatch:
    pop rdi     ; Restore input address to try next word.

.next_word:
    mov rdx, [rdx]  ; Follow link pointer to previous word.
    jmp .search_loop

.not_found:
    ; Push XT = 0, Flag = 0.
    sub dsp, 16
    mov qword [dsp + 8], 0
    mov qword [dsp], 0
    NEXT

; PROMPT ( -- )
defcode "PROMPT", PROMPT
    push ip
    do_sys_write prompt_str, 2
    pop ip
    NEXT

defcode "REPL_BRANCH", REPL_BRANCH
    mov rcx, [dsp]          ; Pop immediate flag (1 or 0).
    mov rbx, [dsp + 8]      ; Pop XT or 0.
    add dsp, 16
    
    cmp qword [state], 1
    je .compile_mode
    
.interpret_mode:
    test rbx, rbx
    jz .is_number
    add dsp, 16         ; Drop string backup...
    mov [repl_stub], rbx
    mov ip, repl_stub
    NEXT
.is_number:
    mov rax, NUMBER
    mov [repl_stub], rax
    mov ip, repl_stub
    NEXT

.compile_mode:
    test rbx, rbx
    jz .compile_number
   
    ; If the flag we popped is 1, bypass the compiler and execute now...
    cmp rcx, 1
    je .execute_immediate
    
    ; Otherwise, we compile it.
    add dsp, 16
    mov rdi, [here]
    mov [rdi], rbx
    add rdi, 8
    mov [here], rdi
    NEXT
    
.execute_immediate:
    add dsp, 16
    mov [repl_stub], rbx
    mov ip, repl_stub
    NEXT
    
.compile_number:
    ; Compile a literal number: Write LIT, then write the number...
    mov r9, [dsp]       ; len.
    mov r8, [dsp + 8]   ; addr.
    add dsp, 16
    push ip
    call parse_number_native
    pop ip
    
    mov rdi, [here]
    mov rbx, LIT
    mov [rdi], rbx      ; Write LIT token.
    add rdi, 8
    mov [rdi], rax      ; Write the actual number.
    add rdi, 8
    mov [here], rdi
    NEXT

; DOCOL ( -- )
; Entry point for user-defined words.
DOCOL:
    push ip     ; Saving current IP to hardware stack.
    add w, 8    ; Move to parameter field, the first instruction.
    mov ip, w   ; Setting IP to it.
    NEXT

; : ( -- ) Starts compiling.
defcode ":", COLON
    push ip
    call read_word_native   ; Get name (r8 = addr, r9 = len).
    
    mov rdi, [here]         ; Grab free memory pointer.
    mov rax, [latest]
    mov [rdi], rax          ; Write link pointer...
    mov [latest], rdi       ; Update latest to point here.
    add rdi, 8
    
    mov [rdi], r9b          ; Write length byte.
    inc rdi
    
    mov rsi, r8             ; Copy name string.
    mov rcx, r9
    rep movsb
    
    add rdi, 7              ; Align to 8 bytes.
    and rdi, ~7
    
    mov rax, DOCOL          ; Write DOCOL (this is code field).
    mov [rdi], rax
    add rdi, 8
    
    mov [here], rdi         ; Update free memory ptr.
    mov qword [state], 1    ; Compiler mode on.
    
    pop ip
    NEXT

; ; ( -- ) Finish compiling.
defcode ";", SEMICOLON, F_IMMED
    mov rdi, [here]
    mov rax, EXIT
    mov [rdi], rax          ; Write EXIT token.
    add rdi, 8
    mov [here], rdi         ; Advance free memory.
    mov qword [state], 0    ; Compiler mode off.
    NEXT

; \ ( -- ) Line comment.
defcode "\", BACKLASH, F_IMMED
.scan_loop:
    mov rcx, [to_in]
    cmp rcx, [num_tib]
    jge .done   ; If we reached the end of the buffer then we are done.

    mov al, [tib + rcx] ; We read the next character.
    inc qword [to_in]   ; Advance the >IN pointer.

    cmp al, 10  ; Then we check for newlines.
    jne .scan_loop
.done:
    NEXT

; ( ( -- ) Block comment.
; NOTE: It's the same as the other one but in this case 
;       We stop at ')' not '\n'.
defcode "(", PAREN, F_IMMED
.scan_loop:
    mov rcx, [to_in]
    cmp rcx, [num_tib]
    jge .done

    mov al, [tib + rcx]
    inc qword [to_in]

    cmp al, ')'
    jne .scan_loop
.done:
    NEXT

; >R ( a -- ) (R: -- a )
; Pops the top of the data stack and pushes it to the return stack.
defcode ">R", TO_R
    mov rax, [dsp]  ; read top.
    add dsp, 8
    push rax
    NEXT

; R> ( -- a ) (R: a -- )
; Pops the top of the return stack and pushes it to the data stack.
defcode "R>", R_FROM
    pop rax 
    sub dsp, 8
    mov [dsp], rax
    NEXT

; R@ ( -- a ) (R: a -- a )
; Copies instead of popping.
defcode "R@", R_FETCH
    mov rax, [rsp]
    sub dsp, 8
    mov [dsp], rax
    NEXT

; EXIT ( -- )
; Return from colon definition.
    defcode "EXIT", EXIT
    pop ip 
    NEXT

section .bss
    align 8

    ; Allocating memory for our stack.
    resb DATA_STACK_SIZE
data_stack_top:

    ; TIB -> Terminal input buffer.
    tib: resb TERMINAL_INPUT_BUFFER_SIZE
    
    user_dict: resb DICTIONARY_SIZE

    ; > File inclusion state.
    include_stack: resq 8       ; Support up to 8 levels of nested includes.
    filename_buf:  resb 256     ; Buffer to null-terminate filenames

section .data
    latest: dq link
    prompt_str: db "> "

    ; > Forth parsing state variables.
    num_tib: dq 0       ; #TIB : The number of characters currently in the TIB.
    to_in:   dq 0       ; >IN  : Our current parsing index within the TIB.

    ; > Compiler variables.
    state: dq 0             ; 0 = Interpreting, 1 = Compiling
    here:  dq user_dict     ; Points to the next free byte in user_dict...

    ; > File inclusion variables...
    include_sp: dq include_stack
    source_id:  dq STDIN

    align 8
    ; > Infinite repl loop. 
    repl_loop:
        dq WORD_PRIM        ; Get a word.
        dq TWODUP           ; Duplicate string parameters.
        dq FIND             ; Search dictionary.
        dq REPL_BRANCH      ; Route to XT or NUMBER.
        dq BRANCH           ; Loop instruction.
        dq repl_loop - $    ; Back to top.

    align 8
    ; > Execution trampoline.
    repl_stub:
        dq 0                
        dq BRANCH           
        dq repl_loop - $
