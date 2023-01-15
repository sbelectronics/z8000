!------------------------------------------------------------------------------
! floppy.s
!   Floppy I/O subroutines
!
!   Copyright(c) 2022 smbaker

	.global	delay_2us, delay_1ms, delay_240ms, delay_10us

	unsegm
	sect	.text    

delay_2us:
    ! the call itself is 10 cycles
    ret      ! 10 cycles

delay_10us:
    ! the call itself is 10 cycles
    call    delay_2us
    call    delay_2us
    call    delay_2us
    call    delay_2us
    ret     ! 10 cycles

delay_1ms:
	push	@r15, r0
    ld      r0, #900                  ! 90 decimal, 0.99ms at 10MHz
delay_1ms_loop:
    djnz    r0, delay_1ms_loop        ! 11 cycles per djnz 
	pop	    r0, @r15
    ret

delay_20ms:
	push	@r15, r0
    ld      r0, #18000                ! 20 times the 1ms number
delay_20ms_loop:
    djnz    r0, delay_1ms_loop        ! 11 cycles per djnz 
	pop	    r0, @r15
    ret

delay_240ms:
	push	@r15, r0
    ld      r0, #240
delay_240ms_loop:
    call    delay_1ms
    djnz    r0, delay_240ms_loop      ! 11 cycles per djnz
	pop	    r0, @r15
    ret
