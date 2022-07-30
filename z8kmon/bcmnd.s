!------------------------------------------------------------------------------
! zcmnd.s
!   Load CP/M-8000 and run
!
!   Copyright (c) 2022 Scott M Baker
!------------------------------------------------------------------------------

	.global	bootflash_cmnd, bcmnd_usage

	sect	.text
	segm

!------------------------------------------------------------------------------
! b_cmnd
!   Load 32kB data from flash to 0x30000, and jump 
!
!   input:      rr4 --- options address 
!   destroyed:  r0, r1, r2, r3, rr4, rr12

bootflash_cmnd:
	lda	rr4, bmsg1
	call	puts

    ! Segment 40 is the start of flash
	! Segment 03 is where we want CP/M system to be
	ldl	    rr2,    #0x40000000
	ldl	    rr4,    #0x03000000
	ld      r0,     #0x4000         ! Transfer 16,384 words
    ldir    @rr4, @rr2, r0

	lda	    rr4, bmsg2
	call	puts	

	jp  	0x83000000

bcmnd_usage:
	lda	    rr4, usage
	jp	    puts

!------------------------------------------------------------------------------
	sect .rodata

bmsg1:
	.string "Boot CP/M from ROM DRive... \0"
bmsg2:
    .string "Jumping to CP/M start\r\n\0"

usage:
	.asciz	"ROM Boot\t: b (no options)\r\n"

