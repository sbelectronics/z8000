up:
	rm -rf holding
	mkdir holding
	cp *.bas holding/
	python ~/projects/pi/z8000/cpm8kdisks/addeof.py holding/*.bas
	cpmrm -f cpm8k ~/projects/pi/z8000/super/sup.img *.bas || true
	cpmcp -f cpm8k ~/projects/pi/z8000/super/sup.img holding/* 0:
