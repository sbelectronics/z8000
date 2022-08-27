Scott's Z-8000 CP/M-8000 "clover computer"
http://www.smbaker.com/

Description

This is a set of boards that can be assembled to make Z8000 computer,
running the CP/M-8000 distribution. For a detailed writeup, see my
website at http://www.smbaker/com/

Prequisites

* z8kgcc
* cpmtools

Building

Run `make asm` and then `make rom`.

Ports

* 00-0F - SCC, serial I/O
* 10-1F - PIO, parallel I/O
* 20-2F - IDE, compactflash
* 30-3F - unused, optional second IDE
* 40-4F - floppy controller
* 50-53 - display board
* 58-59 - speech synthesizer

Acknowledgements:

* Digital Corporation, CP/M-8k Source Code
* 4sun5bu, Z8001 MB Project including BIOS and Monitor, https://github.com/4sun5bu/Z8001MB

License
* MIT, unless specified elsewhere