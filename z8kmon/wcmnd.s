!------------------------------------------------------------------------------
! wcmnd.s
!   Load CP/M-8000 and run
!
!   Copyright (c) 2022 Scott M Baker
!------------------------------------------------------------------------------

	.global	warmboot_cmnd, warmboot_usage

	sect	.text
	segm

!------------------------------------------------------------------------------
! w_cmnd
!   Warm boot by directly jumping to 0x03000000
!
!   input:      rr4 --- options address 
!   destroyed:  r0, r1, r2, r3, rr4, rr12

warmboot_cmnd:
	lda	    rr4, wmsg2
	call	puts	

	jp  	0x83000000

warmboot_usage:
	lda	    rr4, usage
	jp	    puts

!------------------------------------------------------------------------------
	sect .rodata

wmsg2:
    .string "Jumping to CP/M start\r\n\0"

usage:
	.asciz	"Warm Boot\t: w (no options)\r\n"

