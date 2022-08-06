Notes

CP/M Headers
  EE00 - nonsegmented, nonexecutable
  EE01 - segmented, executable
  EE02 - nonsegmented, nonexecutable
  EE03 - nonsegmented, executable, nonshared I & D
  EE07 - nonsegmented, executable, shared I & D
  EE0B - nonsegmented, executable, split I & D

Debugging the problem with commands not loading
  stat, zcc, pip, ddt - all EE03 type
  zcc1, zcc2, zcc3, sizez8k, ed - all EE0B type

  sizez8k.z8k (file size 16256)
    EE 0B - nonsegmented, executable, split I & D
    00 04 - four entries in segment table
    00 00 38 4C - 14412 code constant and init
    00 00 00 00 - byte count of relocation data
    00 00 06 6C - 1644 length of symbol table

    # Segment info
    00 03 33 5A - Seg 00, Code, 13146 bytes
    01 04 01 E2 - Seg 01, Constant pool, 482 bytes
    02 05 03 10 - Seg 02, Initialized data, 784 bytes
    03 01 0B 9E - Seg 03, Uninitialized data, 2574 bytes

  zcc2.z8k (file size 65920)
    EE 0B - nonsegmented, executable, split I & D
    00 04 - four entries in segment table
    00 00 EB 4E - 60238 code constant and init
    00 00 00 00 - byte count of relocation data
    00 00 15 30 - 5424 length of symbol table

    # segment info
    00 03 d2 3e - Seg 00, code, 53822 bytes
    01 04 0b d4 - Seg 01, Constant pool, 3026 bytes
    02 05 0d 3c - Seg 02, Initialized data, 3389 bytes
    03 01 35 3e - Seg 03, Uninitialized data, 13630 bytes

  tl/dr: my map_prog file was incorrect, and didn't load instr to the right shadow seg

Tools
  * ZCC - command line interpreter for C
  * ZCC1 - preprocessor
  * ZCC2 - parser
  * ZCC3 - code generator

Customization notes:
  * define a new memtbl in bioscall4.s
  * update map_prog in biosmem.s
  * define new disk parameter blocks in bioscall3.s
  * implement new disk read/write funcs in bioscall3.s

Useful links:
  * http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch6.htm

Boot sequence
  1) Read FCW from 0002
  2) Read PCSEG from 0004
  3) Read PCOFS from 0006

Bios notes
    * Function in R3
    * Parameters in RR4, RR6
    * RR6 return value
        * RL7 = byte
        * R7 = word
        * RR6 = longword
    * Must preserve R8 through R15; most BIOS preserve all but RR6

BIOS Func 9 - Select Disk
    * R5 = disk number
    * return RR6 = 00000000 if nonexistent, DPB addr if exists

BIOS Func 12 - Set DMA Addr
    * RR4 = DMA Address. Note this could be odd or even!!

BIOS Func 13 - read sector
    * return R7=0 on success, 1 on error

BIOS Func 14 - write sector
    * R5 = 0=norma, 1=dir, 2=newblock
    * return R7=0 on success, 1 on error

BIOS Func 21 - flush buffers
    * Return R7=0000 on success, R7=FFFF on error

Memtbl is described in the systemGuide
    * Reg 1 = merged program and data
    * Reg 2 = I for split I/D
    * Reg 3 = D for split I/D
    * Reg 4 = Data access to R2's I segment

SCC external clock
    WR11 D7=0   ; 0 = not a crystal oscillator
    WR14 D1=0   ; use RTxC rather than PCLK

Compile Stuff
  zcc -c -m hello.c
  a:ld8k -w -s -o hello.z8k hello.o -lcpm

  zcc -c -m wump.c
  a:ld8k -w -s -o wump.z8k wump.o startup.o -lcpm

Resources for the basic interpreter project
  * http://www.nicholson.com/rhn/basic/basic.info.html
