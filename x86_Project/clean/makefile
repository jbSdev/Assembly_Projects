program: main.o func.o
	gcc -m32 -no-pie main.o func.o -o program

main.o: main.c
	gcc -m32 -c main.c -o main.o

func.o: func.s
	nasm -f elf32 func.s -o func.o

clean:
	rm -f *.o program
