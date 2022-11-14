all: clean assemble link

assemble:
	nasm -f elf64 -F dwarf -o afetch.o afetch.asm

link:
	ld afetch.o -o afetch

clean:
	rm -f afetch.o afetch