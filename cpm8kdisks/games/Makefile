maze: maze.c
	gcc -DLINUX -c maze.c -o maze.o
	gcc -o maze maze.o

maze11: maze11.c
	gcc -DLINUX -c maze11.c -o maze11.o
	gcc -o maze11 maze11.o

up-maze:
	rm -rf holding
	mkdir holding
	cp maze.c holding/
	python ~/projects/pi/z8000/cpm8kdisks/addeof.py holding/*.c
	cpmrm -f cpm8k ~/projects/pi/z8000/super/sup.img maze.c || true
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img holding/* 0:

down-maze:
	mkdir -p down
	rm -f down/MAZE.Z8K
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:MAZE.Z8K down/

clean:
	rm maze.o maze
