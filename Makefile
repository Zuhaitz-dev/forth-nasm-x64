ASM = nasm
LD = ld
ASMFLAGS = -f elf64 -Isrc/ -DLINUX
LDFLAGS = 

TARGET = forth
SRC = src/forth.asm
OBJ = forth.o

all: $(TARGET)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) $(OBJ) -o $(TARGET)

$(OBJ): $(SRC)
	$(ASM) $(ASMFLAGS) $(SRC) -o $(OBJ)

clean:
	rm -f $(OBJ) $(TARGET)

run: $(TARGET)
	./$(TARGET) lib/core.f
