# makefile for cpm8k disk images

ROM_FMT = cpm8krom2k

.PHONY: diskimg
dskimg:
	rm -f romdisk/*~
	rm -f romdisk/#*#
	rm -f diska/*~
	rm -f diskb/*~
	rm -f diskc/*~
	rm -f diskd/*~
	rm -rf holding
	mkdir holding
	cp romdisk/* holding/
	cp ~/projects/misc/mojozork/zork1.dat holding/
	cp games/*.z8k holding/
	cp basic/*.z8k holding/
	python ./addeof.py holding/*.h holding/*.c holding/*.sub holding/*.8kn
	mkfs.cpm -f $(ROM_FMT) -b ../cpm8kbios/cpm8k.bin romdisk.img 
	cpmcp -f $(ROM_FMT) romdisk.img holding/* 0:
	mkfs.cpm -f cpm8k -b ../cpm8kbios/cpm8k.bin diska.img 
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
	cpmls -f $(ROM_FMT) -D romdisk.img

fixlf:
	python ./fixlf.py < romdisk_fix/ctype.h > romdisk/ctype.h
	python ./fixlf.py < romdisk_fix/errno.h > romdisk/errno.h
	python ./fixlf.py < romdisk_fix/opt1.c > romdisk/opt1.c
	python ./fixlf.py < romdisk_fix/opt.c > romdisk/opt.c
	python ./fixlf.py < romdisk_fix/setjmp.h > romdisk/setjmp.h
	python ./fixlf.py < romdisk_fix/signal.h > romdisk/signal.h
	python ./fixlf.py < romdisk_fix/stdio.h > romdisk/stdio.h
	python ./fixlf.py < romdisk_fix/xout.h > romdisk/xout.h
	python ./fixlf.py < romdisk_fix/asz8k.pd > romdisk/asz8k.pd
	python ./fixlf.py < romdisk_fix/option.h > romdisk/option.h

.PHONY: clean
clean:
	$(RM) -f *.img
