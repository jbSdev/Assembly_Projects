program: main.o func.o
	gcc -m64 -no-pie main.o func.o -o program

main.o: main.c
	gcc -m64 -c main.c -o main.o

func.o: func.s
	nasm -f elf64 func.s -o func.o

clean:
	rm -f *.o program
