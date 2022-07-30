all: rom

rom: 
	#cd ../cpm8k && make
	#cd ../z8kboot/z8kmon && make
	cd ../cpm8kdisks && make dskimg   
	dd bs=1024 count=1024 if=/dev/zero of=combined.bin
	dd bs=1 if=../cpm8kdisks/romdisk.img of=combined.bin seek=0 conv=notrunc
	dd bs=1 if=../z8kload/z8kload.bin of=combined.bin seek=983040 conv=notrunc
	dd bs=1 if=../z8kmon/z8kmon.bin of=combined.bin seek=983552 conv=notrunc
	python bsplit.py combined.bin low.bin hi.bin

