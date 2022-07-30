# makefile for z8kmon

AS = z8k-coff-as
LD = z8k-coff-ld
OBJCOPY = z8k-coff-objcopy

.SUFFIXES: .o .s 

objs = loader.o

.PHONY: all
all: z8kload.bin

z8kload.bin: $(objs) z8001mb.x
	$(LD) -mz8001 -T z8001mb.x -o z8kload $(objs)
	$(OBJCOPY) -O binary z8kload z8kload.bin

.s.o:
	$(AS) -a=$<.lst -o $@ $< 

.PHONY: clean
clean:
	$(RM) -f z8kload.bin z8kload $(objs)
