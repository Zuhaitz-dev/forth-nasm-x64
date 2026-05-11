# forth-nasm-x64

A minimal, interactive Forth compiler and interpreter written entirely in x86-64 Linux assembly.

## Some of the features
- Direct-threaded inner interpreter.
- Native x86-64 machine code implementation (via NASM).
- Turing-complete (variables, conditional branching, indefinite loops).
- Interactive REPL and file-loading capabilities.
- Custom standard library (`lib/core.f`).

> It is an ANS-inspired subset, designed for extreme simplicity and bootstrapping rather than strict historical compliance.

## Building the Compiler
To build the Forth engine (`forth`), simply run:

```bash
    make
```

## Running Forth Programs
You can drop into the interactive REPL, or pass a file as an argument to load it into the dictionary before the prompt appears.

To load the standard library and start the interactive environment:

```bash
    ./forth lib/core.f
```

## Examples
The `lib/` directory contains the core vocabulary:
- `core.f`: Implements standard words like `MAX`, `COUNTDOWN`, `ROT`, and logical operators.

> NOTE: more will be done, give me time.

## Implementation Details
The engine is written in NASM assembly and relies on minimal Linux syscalls. 

It uses a 64-bit cell size (8 bytes). The x86-64 hardware stack (`rsp`) is used directly as the Forth Return Stack (and Instruction Pointer backup), while a separate reserved memory block (`rbp`) is managed as the Data Stack. Unknown words are natively parsed as base-10 integers and compiled as inline literals.

## License
MIT

## Contributing
Feel free to do whatever you want with it!
