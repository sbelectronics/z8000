! The job of the loader is to copy the monitor from FLASH to RAM,
! then to jump to the start of RAM. Place this loader at the start
! of page 15 in the FLASH. Follow it with the contents of the
! monitor.
!
! The loader 

        sect    .text
        segm

		.equ	DIS12, 0x0050
		.equ	DIS34, 0x0051
		.equ	DIS56, 0x0052
		.equ	DIS78, 0x0053

        sect .rstvec

        .word   0x0000                  ! reserved
        .word   0xC000                  ! FCW: Segmented Mode, System Mode
        .word   0x6000                  ! SEG = 60
        .word   _start                  ! OFS

_start:
        nop                             ! Make very sure A3 gets tripped
        nop				                ! .. so we exit boot mode
        nop
        nop                             ! It should anyway, because we're starting at
        nop                             ! address 8, but never hurts to be extra
        nop                             ! careful.
        nop
        nop

        ldb     rl4,    #0x87           ! output something to the display board
		outb    #DIS12,  rl4
        ldb     rl4,    #0x65
		outb    #DIS34,  rl4
        ldb     rl4,    #0x43
		outb    #DIS56,  rl4
        ldb     rl4,    #0x21
		outb    #DIS78,  rl4

		! should the following addrs have the high bit set? 4sun5bu makes me think yes,
		! but reading the manual tells me it's only used on operand addressing modes.

        ldl     rr4,    #0x00000000     ! Destination address 00:0000
        ldl     rr6,    #0x60000200     ! Source address 60:0200
        ld      r3,     #0x7E00         ! Transfer 32,256 words
        ldir    @rr4,   @rr6, r3

        ldb     rl4,    #0x12           ! reverse what we wrote to the display board
		outb    #DIS12,  rl4
        ldb     rl4,    #0x34
		outb    #DIS34,  rl4
        ldb     rl4,    #0x56
		outb    #DIS56,  rl4
        ldb     rl4,    #0x78
		outb    #DIS78,  rl4				

		jp       0x80000008             ! Jump to address 00:0008. high bit indicates long addr.

.org    0x200                           ! pad out to 512 bytes

