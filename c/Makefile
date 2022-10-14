up:
	rm -rf holding
	mkdir holding
	cp clrdir.c sieve.c holding/
	python ~/projects/pi/z8000/cpm8kdisks/addeof.py holding/*.c
	cpmrm -f cpm8k ~/projects/pi/z8000/super/sup.img clrdir.c sieve.c || true
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img holding/* 0:

down:
	mkdir -p down
	rm -f down/CLRDIR.Z8K
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:CLRDIR.Z8K down/
