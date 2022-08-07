# makefile for cpm8k

AS = z8k-coff-as
LD = z8k-coff-ld
OBJCOPY = z8k-coff-objcopy

.SUFFIXES: .o .s 

objs = biosboot.o biosif.o biostrap.o biosmem.o\
	bios.o bioscall1.o bioscall2.o bioscall3.o bioscall4.o\
	z8530.o flashio.o diskio.o supio.o put.o\

.PHONY: all
all: cpm8k.bin

cpm8k.bin: $(objs) biosdef.s cpmsys.o libcpm.a cpmsys.x
	#$(LD) -mz8002 -T cpmsys.x -L./ -o cpm8k $(objs) cpmsys.o -lcpm
	$(LD) -mz8001 -T cpmsys.x -L./ -o cpm8k $(objs) cpmsys.o -lcpm
	$(OBJCOPY) -S -O binary cpm8k cpm8k.bin

.s.o:
	#$(AS) -z8002 -o $@ $< 
	$(AS) -o $@ -a=$<.lst $< 

.PHONY: dskimg
dskimg:
	mkfs.cpm -f cpm8krom4k -b cpm8k.bin romdisk.img 
	cpmcp -f cpm8krom4k romdisk.img romdisk/*.* 0:
	cpmcp -f cpm8krom4k romdisk.img games/*.z8k 0:
	cpmcp -f cpm8krom4k romdisk.img games/*.c 0:
	mkfs.cpm -f cpm8k -b cpm8k.bin diska.img 
	cpmcp -f cpm8k diska.img diska/*.* 0:
	mkfs.cpm -f cpm8k diskb.img
	cpmcp -f cpm8k diskb.img diskb/*.* 0:
	mkfs.cpm -f cpm8k diskc.img
	cpmcp -f cpm8k diskc.img diskc/*.* 0:
	mkfs.cpm -f cpm8k diskd.img
	cpmcp -f cpm8k diskd.img diskd/*.* 0:
	dd if=diska.img of=disk.img count=16384 bs=512 conv=notrunc
	dd if=diskb.img of=disk.img count=16384 bs=512 seek=16384 conv=notrunc
	dd if=diskc.img of=disk.img count=16384 bs=512 seek=32768 conv=notrunc
	dd if=diskd.img of=disk.img count=16384 bs=512 seek=49152 conv=notrunc

listimg:
	cpmls -f cpm8krom4k -D romdisk.img

fixlf:
	python ./fixlf.py < romdisk_fix/ctype.h > romdisk/ctype.h
	python ./fixlf.py < romdisk_fix/errno.h > romdisk/errno.h
	python ./fixlf.py < romdisk_fix/opt1.c > romdisk/opt1.c
	python ./fixlf.py < romdisk_fix/opt.c > romdisk/opt.c
	python ./fixlf.py < romdisk_fix/setjmp.h > romdisk/setjmp.h
	python ./fixlf.py < romdisk_fix/signal.h > romdisk/signal.h
	python ./fixlf.py < romdisk_fix/stdio.h > romdisk/stdio.h
	python ./fixlf.py < romdisk_fix/xout.h > romdisk/xout.h

.PHONY: clean
clean:
	$(RM) -f cpm8k cpm8k.bin cpm8k.hex $(objs) *.lst

