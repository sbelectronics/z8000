all: asm rom

.PHONY: asm
asm:
	cd z8kload && make
	cd z8kmon && make
	cd cpm8kbios && make

.PHONY: rom
rom:
	cd rom && make

.PYONY: clean
clean:
	cd z8kload && make clean
	cd z8kmon && make clean
	cd cpm8kbios && make clean
	cd cpm8kdisks && make clean
