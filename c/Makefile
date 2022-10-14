up:
	rm -rf holding
	mkdir holding
	cp clrdir.c sieve.c z8kutil.c testext.c calltest.c extbios.h holding/
	python ~/projects/pi/z8000/cpm8kdisks/addeof.py holding/*.c holding/*.h
	cpmrm -f cpm8k ~/projects/pi/z8000/super/sup.img clrdir.c sieve.c z8kutil.c testext.c calltest.c extbios.h || true
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img holding/* 0:

.PHONY: down
down:
	mkdir -p down
	rm -f down/CLRDIR.Z8K down/Z8KUTIL.Z8K
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:CLRDIR.Z8K 0:Z8KUTIL.Z8K down/
