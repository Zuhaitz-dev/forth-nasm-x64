; forth.inc - Because having it all in one file is... spaghetti.

; > constants.
%define DATA_STACK_SIZE 8192 ; 1024 cells * 8 bytes per cell
%define TERMINAL_INPUT_BUFFER_SIZE 128
%define DICTIONARY_SIZE 8192

; > system calls.
%ifdef LINUX
    %define SYS_READ  0
    %define SYS_WRITE 1
    %define SYS_EXIT  60
    %define STDIN     0
    %define STDOUT    1 
%elifdef MACOS
    ; BSD syscalls require a 0x2000000 offset
    %define SYS_READ  0x2000003
    %define SYS_WRITE 0x2000004
    %define SYS_EXIT  0x2000001
    %define STDIN     0
    %define STDOUT    1
%else
    %error "FATAL: You must define an OS! (Pass -D LINUX or -D MACOS to nasm)"
%endif

; > register mapping.
%define w   rax     ; Working register: holds the current eXecution Token.
%define ip  rsi     ; Instruction pointer: points to next XT to execute.
%define dsp rbp     ; Data stack pointer.
; rsp is... rsp already.

; > The inner interpreter...
; Fetches the next XT and jumps to it.
%macro NEXT 0
    lodsq           ; Load 8 bytes from [rsi] into rax, advance rsi by 8.
                    ; For this instruction and similars you can check:
                    ; https://www.felixcloutier.com/x86/lods:lodsb:lodsw:lodsd:lodsq
    jmp [w]         ; Jump to the address now held in rax.
%endmacro

; > Dictionary linked list tracking.
; First we have a NULL pointer and everytime we define a word
; we update this to point to it 
%define link 0

; > Dictionary header macro 
; Usage: defcode "NAME", label, (flags)
%macro defcode 2-3 0
    align 8
name_%2:
    dq link                 ; Write pointer to previous word
    %define link name_%2    ; Update global link to point here
    db %%str_len | %3       ; Write string length ORed with flags
%%str_start:
    db %1                     ; Write actual string characters
%%str_len equ $ - %%str_start ; Calculate length
    align 8                 
%2:                         ; This label is the eXecution Token
    dq code_%2              ; Code Field points to assembly instructions
code_%2:                    ; Assembly instructions start just after this
%endmacro

; > Dictionary header macro for colon words (user-defined)
; Usage: defword "NAME", label, (flags)
%macro defword 2-3 0
    align 8
name_%2:
    dq link
    %define link name_%2
    db %%str_len | %3
%%str_start:
    db %1
%%str_len equ $ - %%str_start
    align 8
%2:
    dq DOCOL        ; This is the only difference: 
                    ; The code field points directly to DOCOL.
%endmacro

; > Syscall helper macros
%macro do_sys_read 2
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, %1         ; Buffer address.
    mov rdx, %2         ; Length.
    syscall
%endmacro

%macro do_sys_write 2
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, %1         ; Buffer address.
    mov rdx, %2         ; Length.
    syscall
%endmacro

; > flags
%define F_IMMED 0x80
%define F_HIDDEN 0x40
