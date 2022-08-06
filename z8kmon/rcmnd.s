!------------------------------------------------------------------------------
! mcmnd.s
!   Test Memory
!
!   Copyright (c) 2022 Scott M Baker
!------------------------------------------------------------------------------

	.global	romtest_cmnd, romtest_usage

	sect	.text
	segm

!------------------------------------------------------------------------------
! romtest_cmnd
!   Test Flash ROM
!
!   input:      rr4 --- options address 
!   destroyed:  r0, r1, r2, r3, rr4, rr12

     ! define these for the first and last segment to checksum
    .equ FIRST_ROM_SEG, 0x40
	.equ LAST_ROM_SEG, 0x4F

    ! this space is in z8kload/loader.s
	.equ CHECKSUM_ADDR, 0x60000008

romtest_cmnd:
    ld      r8, #1                    ! r8 is number of passes to run
	ld      r9, #0                    ! r9 is the fail-halt flag. 1=halt
	testb	@rr4
	jr	    z, romtest_loop
	call	strhex16
	jp	    c, romtest_usage
	ld      r8, r0
	ld      r9, #1                    ! set the hardstop flag

romtest_loop:
    call    romtest_once
	djnz    r8, romtest_loop
	ret

romtest_usage:
	lda	    rr4, usage
	jp	    puts

! ----------------------------------------------------------------------------

romtest_once:
    lda     rr4, checksum_msg
	call    puts

    ld      r2, #0                    ! accumulator
    ldl     rr6, #0                   ! address
	ldb     rh6, #FIRST_ROM_SEG

checksum_outer_loop:
checksum_inner_loop:
	add     r2, @rr6
	add     r7, #2
	jr      nz, checksum_inner_loop    ! if r7 goes to 0, then we wrapped

	incb    rh6, #1
	cpb     rh6, #LAST_ROM_SEG
	jr      ule, checksum_outer_loop   ! (C OR Z)=1

    clr     r6                          ! r6 = expected value
	ld      r7, r2                      ! r7 = actual value
	cp      r6, r7
    jr      eq, checksum_okay
	jp      report_16bit_error          ! report error r6 != r7
checksum_okay:
    lda     rr4, success_msg
	jp      puts

! -----------------------------------------------------------------------------
report_16bit_error:
	lda     rr4, expected_value_msg
	call    puts
	ld      r4, r6
	call    puthex16
	lda     rr4, actual_value_msg
	call    puts
	ld      r4, r7
	call    puthex16	
	call    putln
	jp      fail

!------------------------------------------------------------------------------
fail:
	or      r9, r9
	jp      z, continue
	lda     rr4, halt_msg
	call    puts
	halt
continue:
    ret	

!------------------------------------------------------------------------------
	sect .rodata

checksum_msg:
    .string "Computing ROM checksum... \0"

expected_value_msg:
    .asciz "Expected value "

actual_value_msg:
    .asciz ", but computed value "

success_msg:
    .asciz "Success\r\n"

halt_msg:
    .asciz "Halting\r\n"	

usage:
	.asciz	"Rom Test\t: r [xxxx] xxxx=repeat count\r\n"

