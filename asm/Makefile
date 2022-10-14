up:
	rm -rf holding
	mkdir holding
	cp ledoff.8kn ledon.8kn extbios.8kn testext.c z8util.c extbios.h calltest.c holding/
	python ~/projects/pi/z8000/cpm8kdisks/addeof.py holding/*.8kn holding/*.c holding/*.h
	cpmrm -f cpm8k ~/projects/pi/z8000/super/sup.img ledoff.8kn ledon.8kn extbios.8kn testext.c extbios.h z8util.c calltest.c || true
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img holding/* 0:

.PHONY: down
down:
	mkdir -p down
	rm -f down/zork.z8k
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:LEDON.Z8K down/
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:LEDOFF.Z8K down/

listimg:
	cpmls -f cpm8k -D ~/projects/pi/z8000/super/sup.img
