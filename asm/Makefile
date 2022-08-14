up:
	rm -rf holding
	mkdir holding
	cp ledoff.8kn ledon.8kn holding/
	python ~/projects/pi/z8000/cpm8kdisks/addeof.py holding/*.8kn
	cpmrm -f cpm8k ~/projects/pi/z8000/super/sup.img  ledoff.8kn ledon.8kn || true
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img holding/* 0:

.PHONY: down
down:
	mkdir -p down
	rm -f down/zork.z8k
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:LEDON.Z8K down/
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img 0:LEDOFF.Z8K down/

listimg:
	cpmls -f cpm8k -D ~/projects/pi/z8000/super/sup.img
