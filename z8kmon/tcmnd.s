!------------------------------------------------------------------------------
! mcmnd.s
!   Test Memory
!
!   Copyright (c) 2022 Scott M Baker
!------------------------------------------------------------------------------

	.global	cputest_cmnd, cputest_usage

	sect	.text
	segm

!------------------------------------------------------------------------------
! t_cmnd
!   Test CPU
!
!   input:      rr4 --- options address 
!   destroyed:  r0, r1, r2, r3, rr4, rr12

cputest_cmnd:
    ld      r8, #1                    ! r8 is number of passes to run
	ld      r9, #0                    ! r9 is the fail-halt flag. 1=halt
	testb	@rr4
	jr	    z, cputest_loop
	call	strhex16
	jp	    c, cputest_usage
	ld      r8, r0
	ld      r9, #1                    ! set the hardstop flag
cputest_loop:
    call    cputest_add_16_bit
	call    cputest_mult
	call    test_many_jumps
	djnz    r8, cputest_loop
	ret

cputest_usage:
	lda	    rr4, usage
	jp	    puts

! ------------------------------------------------------------------------------

cputest_add_16_bit:
	lda     rr4, add_16bit_msg   ! Tell user what we're doing
	call    puts

    clr     r7                      ! accumulated result
	ld      r6, #0x009C             ! expected result

    ld      r2, #0x456
add_16_loop3:
    ld      r3, #0x123
add_16_loop2:
    ld      r4, #2
add_16_loop1:
    inc     r7, #7
	djnz    r4, add_16_loop1
	djnz    r3, add_16_loop2
	djnz    r2, add_16_loop3

	cp      r7, r6
	jp      eq, report_success

	jp      report_16bit_error

! ------------------------------------------------------------------------------

cputest_mult:
	lda     rr4, mult_msg   ! Tell user what we're doing
	call    puts

	ldl     rr2, #0x00000001         ! accumulated result
	ldl     rr6, #0x00014001         ! expected result - note the upper word is reset on each mult

    ld      r4, #0x9000
mult_loop:
    mult    rr2, #3
	djnz    r4, mult_loop

	cpl     rr6, rr2
	jp      eq, report_success

	jp      report_32bit_error

! ------------------------------------------------------------------------------

test_many_jumps:
	lda     rr4, add_manyjumps_msg   ! Tell user what we're doing
	call    puts

	ldl     rr2, #0x00000000         ! accumulated result
	ldl     rr6, #0x00F48000         ! expected result	

    ld      r4, #0x8000             ! execute 32768 times
many_jumps_loop:
    jr      rj1
	addl    rr2, #3
rj1:
    addl    rr2, #5
    jr      rj2
    addl    rr2, #7
rj2:
    addl    rr2, #11
	jr      rj3
    addl    rr2, #13
rj3:
	addl    rr2, #17
	jr      rj4
    addl    rr2, #19
rj4:
    addl    rr2, #23
	jp      rj5
	addl    rr2, #31
rj5:
    addl    rr2, #37
	jp      rj6
	addl    rr2, #41
rj6:
    addl    rr2, #43
	jp      aj7
	addl    rr2, #47
aj7:
    addl    rr2, #53
	jp      aj8
	addl    rr2, #59
aj8:
    addl    rr2, #61
	jp      aj9
	addl    rr2, #67
aj9:
    addl    rr2, #71
	jp      aj10
	addl    rr2, #73
aj10:
    addl    rr2, #79
	jp      aj11
	addl    rr2, #83
aj11:
    addl    rr2, #89
	jp      aj12
	addl    rr2, #97
aj12:
    djnz    r4, many_jumps_loop

	cpl     rr6, rr2
	jp      eq, report_success

	jp      report_32bit_error	

! -----------------------------------------------------------------------------
report_success:
	lda     rr4, success_msg
	jp   	puts

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

! -----------------------------------------------------------------------------
report_32bit_error:
	lda     rr4, expected_value_msg
	call    puts
	ld      r4, r6
	call    puthex16
	ld      r4, r7
	call    puthex16	
	lda     rr4, actual_value_msg
	call    puts
	ld      r4, r2
	call    puthex16
	ld      r4, r3
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

add_16bit_msg:
    .asciz "Testing add in nested loop... "

mult_msg:
    .asciz "Testing multiply in loop... "

add_manyjumps_msg:
    .asciz "Testing many jumps... "

expected_value_msg:
    .asciz "Expected value "

actual_value_msg:
    .asciz ", but computed value "

success_msg:
    .asciz "Success\r\n"

halt_msg:
    .asciz "Halting\r\n"

usage:
	.asciz	"CPU Test\t: t [xxxx] xxxx=repeat count\r\n"

