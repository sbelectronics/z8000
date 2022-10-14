! -----------------------------------------------------------------------------
! CP/M-8000 Scott's Extended BIOS Stuff
!
!  Copyright (c) 2022, smbaker
!------------------------------------------------------------------------------
	
	.global	funcF000, funcF001, funcF002, funcF003, funcF004
	.global funcF005, funcF006, funcF007, funcF008, funcF009
	.global funcF00A, funcF00B

	.include "biosdef.s"	

	unsegm
	sect .text

!------------------------------------------------------------------------------
! funcF000
!   Returns r7=5C07, proves that extended bios is working

funcF000:
	ld      r7, 0x5C07
	ret


!------------------------------------------------------------------------------
! funcF001
!   Get CIO Installed
!   returns
!     rh7 = kbd conpiles
!     rl7 = kbd initialized

funcF001:
	clr     r7
    .if ENABLE_KBD == 1
	ldb     rh7, #1             ! rh6=1 -> KBD code is compiled
	ldb     rl7, cio_enable     ! rl6=1 -> KBD was detected and enabled
	.endif
	ret	

!------------------------------------------------------------------------------
! funcF002
!   Get Tick Count
!   returns
!     rh6 = kbd conpiles
!     rl6 = kbd initialized
!     r7 = tick count

funcF002:
    .if ENABLE_KBD == 1
	ldl     rr6, cio_count
	.else
    clr     r6
	clr     r7	
	.endif
	ret

!------------------------------------------------------------------------------
! funcF003
!   Get CIO KHz
!   returns
!     r7 = kilohertz

funcF003:
    .if ENABLE_KBD == 1
	ld     r7, cio_khz
	.else	
    clr    r7
    .endif
    ret

!------------------------------------------------------------------------------
! funcF004
!   Get CIO Divisor
!   returns	
!     r7 = divisor

funcF004:
    .if ENABLE_KBD == 1
    ld    r7, cio_divisor
	.else
	clr    r7
	.endif
    ret

!------------------------------------------------------------------------------
! funcF005
!   Set CIO Divisor
!   input
!     r5 = new divisor

funcF005:
    .if ENABLE_KBD == 1
	call   cio_set_divisor
    .endif
	clr    r7
    ret

!------------------------------------------------------------------------------
! funcF006
!   Set Video Color
!   Rl5 = color

funcF006:
    .if ENABLE_VIDEO == 1
	call    tms_setcolor
	.endif
	clr     r7
	ret

!------------------------------------------------------------------------------
! funcF007
!   Set LED State
!   Rl5 = 1 if led on, 0 if led off

funcF007:
    testb  rl5
	jr     nz, funcF007_notzero
    mres
	jr     funcF007_return
funcF007_notzero:
    mset
funcF007_return:
    clr    r7
	ret

!------------------------------------------------------------------------------
! funcF008
!   Get Button State
!   returns
!     R7 = 1 if button pressed, 0 otherwise

funcF008:
    ! TODO
    ret
	
!------------------------------------------------------------------------------
! funcF009
!   Set Display
!   input
!     rl5 = 0-3 if byte, 10-11 if word, 20 if long
!     rr6 value


funcF009:
    cpb   rl5, #0
	jr    nz, notb0
	outb  #0x50, rl7
	ret
notb0:
    cpb   rl5, #1
	jr    nz, notb1
	outb  #0x51, rl7
	ret
notb1:
    cpb   rl5, #2
	jr    nz, notb2
	outb  #0x52, rl7
	ret
notb2:
    cpb   rl5, #3
	jr    nz, notb3
	outb  #0x53, rl7
	ret
notb3:
    cpb   rl5, #0x10
	jr    nz, notw0
	outb  #0x50, rh7
	outb  #0x51, rl7
	ret
notw0:
    cpb   rl5, #0x11
	jr    nz, notw1
	outb  #0x52, rh7
	outb  #0x53, rl7
notw1:
	ret

!------------------------------------------------------------------------------
! funcF00A
!   Set Display Long
!   input
!     r5 = high word
!     r7 = low word
funcF00A:
	outb  #0x50, rh5
	outb  #0x51, rl5
	outb  #0x52, rh7
	outb  #0x53, rl7	
	ret

!------------------------------------------------------------------------------
! funcF00B
!   Input from display board
!   input

funcF00B:
    clr   r7
	inb   rl7, #0x51
	ret
