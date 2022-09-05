!------------------------------------------------------------------------------
! floppy.s
!   Floppy I/O subroutines
!
!   Copyright(c) 2022 smbaker

	.global	delay_20us, delay_1ms, delay_240ms

	unsegm
	sect	.text    

delay_20us:
    ! the call itself is 10 cycles
    ret      ! 10 cycles

delay_1ms:
	push	@r15, r0
    ld      r0, #90                   ! 90 decimal, 0.99ms at 10MHz
delay_1ms_loop:
    djnz    r0, delay_1ms_loop        ! 11 cycles per djnz 
	pop	    0, @r15
    ret

delay_240ms:
	push	@r15, r0
    ld      r0, #21800                ! 21800 decimal. 239ms at 10MHz
delay_240ms_loop:
    djnz    r0, delay_240ms_loop      ! 11 cycles per djnz
	pop	    r0, @r15
    ret
