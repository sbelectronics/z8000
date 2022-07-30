!------------------------------------------------------------------------------
! mcmnd.s
!   Test Memory
!
!   Copyright (c) 2022 Scott M Baker
!------------------------------------------------------------------------------

	.global	memtest_cmnd, memtest_usage

	sect	.text
	segm

!------------------------------------------------------------------------------
! m_cmnd
!   Test RAM
!
!   input:      rr4 --- options address 
!   destroyed:  r0, r1, r2, r3, rr4, rr12

     ! define these for the first and last segment to test
	 ! avoid testing the segment the monitor is located in
    .equ FIRST_SEG, 1
	.equ LAST_SEG, 15

memtest_cmnd:
    ld      r8, #1                    ! r8 is number of passes to run
	ld      r9, #0                    ! r9 is the fail-halt flag. 1=halt
	testb	@rr4
	jr	    z, memtest_loop
	call	strhex16
	jp	    c, memtest_usage
	ld      r8, r0
	ld      r9, #1                    ! set the hardstop flag

memtest_loop:

    ! write whole words
	ldb    rl2, #FIRST_SEG
wseg_word_next:
	call   writeseg_word
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, wseg_word_next

    ! test whole words
    ldb    rl2, #FIRST_SEG	
testseg_word_next:
	call   testseg_word
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, testseg_word_next

    ! test reading low bytes
    ldb    rl2, #FIRST_SEG	
testseg_read_bl_next:
	call   testseg_read_bl
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, testseg_read_bl_next

    ! test reading hi bytes
    ldb    rl2, #FIRST_SEG	
testseg_read_bh_next:
	call   testseg_read_bh
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, testseg_read_bh_next		

    ! write even bytes
	ldb    rl2, #FIRST_SEG
wseg_bh_next:
	call   writeseg_bh
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, wseg_bh_next

    ! test whole words after the bh
    ldb    rl2, #FIRST_SEG	
testseg_word_bh_next:
	call   testseg_word_bh
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, testseg_word_bh_next

    ! write odd bytes
	ldb    rl2, #FIRST_SEG
wseg_bl_next:
	call   writeseg_bl
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, wseg_bl_next

    ! test whole words after the bh
    ldb    rl2, #FIRST_SEG	
testseg_word_bl_next:
	call   testseg_word_bl
	incb   rl2, #1
	cpb    rl2, #LAST_SEG
	jr     le, testseg_word_bl_next	

	djnz   r8, memtest_loop

	ret

memtest_usage:
	lda	    rr4, usage
	jp	    puts


!------------------------------------------------------------------------
writeseg_word:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, wseg_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

wseg_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rh5, rl2        ! ... the high part of the word too
	ld      @rr6, r5

	inc     r7, #2          ! increment the address/value
	djnz    r3, wseg_loop
	ret

!------------------------------------------------------------------------
testseg_word:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, testseg_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

testseg_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rh5, rl2        ! ... the high part of the word too
	ld      r4, @rr6
    cp      r5, r4
	jp      eq, testseg_loop_okay
     
	lda     rr4, testseg_error_msg
	call    puts
	ldb     rl4, rl2
	call    puthex8
	ld      r4, r7
	call    puthex16
	lda     rr4, abort_msg
	call    puts
	jp      fail            ! bail, only report 1 error per test

testseg_loop_okay:
	inc     r7, #2          ! increment the address/value
	djnz    r3, testseg_loop
	ret
	
!------------------------------------------------------------------------
testseg_read_bh:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, testseg_read_bh_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

testseg_read_bh_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rh5, rl2        ! ... the high part of the word too
	ldb     rh4, @rr6
    cpb     rh5, rh4
	jp      eq, testseg_read_bh_okay
     
	lda     rr4, testseg_error_msg
	call    puts
	ldb     rl4, rl2
	call    puthex8
	ld      r4, r7
	call    puthex16
	lda     rr4, abort_msg
	call    puts
    jp      fail            ! bail, only report 1 error per test

testseg_read_bh_okay:
	inc     r7, #2          ! increment the address/value
	djnz    r3, testseg_read_bh_loop
	ret

!------------------------------------------------------------------------
testseg_read_bl:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, testseg_read_bl_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

testseg_read_bl_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rh5, rl2        ! ... the high part of the word too
	inc     r7, #1
	ldb     rl4, @rr6
	dec     r7, #1
    cpb     rl5, rl4
	jp      eq, testseg_read_bl_okay
     
	lda     rr4, testseg_error_msg
	call    puts
	ldb     rl4, rl2
	call    puthex8
	ld      r4, r7
	call    puthex16
	lda     rr4, abort_msg
	call    puts
	jp      fail            ! bail, only report 1 error per test

testseg_read_bl_okay:
	inc     r7, #2          ! increment the address/value
	djnz    r3, testseg_read_bl_loop
	ret

!------------------------------------------------------------------------
writeseg_bh:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, wsegbh_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

wsegbh_loop:
    ldl     rr4, rr6
	xorb	rh5, rl2        ! make sure each seg is a little different 
	xorb    rh5, #0x33      ! make sure the bytes are a little different than the words
	ldb     @rr6, rh5

	inc     r7, #2          ! increment the address/value
	djnz    r3, wsegbh_loop
	ret

!------------------------------------------------------------------------
testseg_word_bh:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, testseg_word_bh_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

testseg_word_bh_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rh5, rl2        ! ... the high part of the word too
	xorb    rh5, #0x33      ! make sure the bytes are a little different than the words
	ld      r4, @rr6
    cp      r5, r4
	jp      eq, testseg_word_bh_okay
     
	lda     rr4, testseg_error_msg
	call    puts
	ldb     rl4, rl2
	call    puthex8
	ld      r4, r7
	call    puthex16
	lda     rr4, abort_msg
	call    puts
	jp      fail            ! bail, only report 1 error per test

testseg_word_bh_okay:
	inc     r7, #2          ! increment the address/value
	djnz    r3, testseg_word_bh_loop
	ret	

!------------------------------------------------------------------------
writeseg_bl:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, wsegbl_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

wsegbl_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rl5, #0x66      ! make sure the bytes are a little different than the words
	inc     r7, #1
	ldb     @rr6, rl5
	dec     r7, #1

	inc     r7, #2          ! increment the address/value
	djnz    r3, wsegbl_loop
	ret

!------------------------------------------------------------------------
testseg_word_bl:
    ! input: rl2 - segment number
	! destroy:
	!   r3 - counter
	!   r4 - value
    !   rr6 - dest addr

	lda     rr4, testseg_word_bl_msg   ! Tell user what we're doing
	call    puts
	ldb     rl4, rl2
	call    puthex8
	call    putln

    clr     r6              ! zero the dest addr
	clr     r7
	ldb     rh6, rl2        ! set destination segment
	ld      r3, #0x8000     ! write 32768 words

testseg_word_bl_loop:
    ldl     rr4, rr6
	xorb	rl5, rl2        ! make sure each seg is a little different 
	xorb    rh5, rl2        ! ... the high part of the word too
	xorb    rh5, #0x33      ! make sure the bytes are a little different than the words
	xorb    rl5, #0x66      ! make sure the bytes are a little different than the words	
	ld      r4, @rr6
    cp      r5, r4
	jp      eq, testseg_word_bl_okay
     
	lda     rr4, testseg_error_msg
	call    puts
	ldb     rl4, rl2
	call    puthex8
	ld      r4, r7
	call    puthex16
	lda     rr4, abort_msg
	call    puts
    jp      fail            ! bail, only report 1 error per test

testseg_word_bl_okay:
	inc     r7, #2          ! increment the address/value
	djnz    r3, testseg_word_bl_loop
	ret

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

wseg_msg:
    .string "Writing words to segment \0"
testseg_msg:
    .string "Testing reading words in segment \0"
testseg_read_bh_msg:
    .string "Testing reading lo bytes in segment \0"	
testseg_read_bl_msg:
    .string "Testing reading hi bytes in segment \0"	

wsegbh_msg:
    .string "Writing even bytes to segment \0"
testseg_word_bh_msg:
    .string "Testing words (after even writes) in segment \0"	

wsegbl_msg:
    .string "Writing odd bytes to segment \0"
testseg_word_bl_msg:
    .string "Testing words (after odd writes) in segment \0"		

testseg_error_msg:
    .string "  Error at address \0"

abort_msg:
    .asciz  ". Aborting segment.\r\n"

halt_msg:
    .asciz "Halting\r\n"	

usage:
	.asciz	"Mem Test\t: m [xxxx] xxxx=repeat count\r\n"

