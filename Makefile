all: clean assemble link
debug: clean assemble-debug link
d: debug

assemble:
	nasm -f elf64 -o afetch.o afetch.asm

assemble-debug:
	nasm -f elf64 -F dwarf -o afetch.o afetch.asm

link:
	ld afetch.o -o afetch

clean:
	rm -f afetch.o afetch