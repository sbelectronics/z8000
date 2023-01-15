!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global mon_keydown
    .global mon_update
    .global go_state_mem_display
    .global go_state_mem_alter

	unsegm
	sect	.text

.equ KEY_PLUS, 0x0A
.equ KEY_MINUS, 0x0B
.equ KEY_STAR, 0x0C
.equ KEY_SLASH, 0x0D
.equ KEY_POUND, 0x0E
.equ KEY_DOT, 0x0F

.equ KEY_MEM, KEY_POUND
.equ KEY_ALTER, KEY_SLASH

.equ STATE_IDLE, 0
.equ STATE_MEM_ADDR1, 0x10
.equ STATE_MEM_ADDR2, 0x11
.equ STATE_MEM_ADDR3, 0x12
.equ STATE_MEM_ADDR4, 0x13
.equ STATE_MEM_ADDR5, 0x14
.equ STATE_MEM_ADDR6, 0x15
.equ STATE_MEM_DISPLAY, 0x16

.equ STATE_MEM_ALTER1, 0x17
.equ STATE_MEM_ALTER2, 0x18
.equ STATE_MEM_ALTER3, 0x19

.equ STATE_GROUP_MEM, 0x10
.equ STATE_GROUP_MEM_ALTER, 0x10
.equ STATE_GROUP_MASK, 0xF0

!------------------------------------------------------------------------------
! mon_keydown
!
! input:
!   rl0: keypad scancode

mon_keydown:
    cpb    mon_state, #STATE_IDLE
    jp     z, mon_state_idle
    cpb    mon_state, #STATE_MEM_ADDR1
    jp     z, mon_state_addr1
    cpb    mon_state, #STATE_MEM_ADDR2
    jp     z, mon_state_addr2
    cpb    mon_state, #STATE_MEM_ADDR3
    jp     z, mon_state_addr3
    cpb    mon_state, #STATE_MEM_ADDR4
    jp     z, mon_state_addr4
    cpb    mon_state, #STATE_MEM_ADDR5
    jp     z, mon_state_addr5
    cpb    mon_state, #STATE_MEM_ADDR6
    jp     z, mon_state_addr6
    cpb    mon_state, #STATE_MEM_DISPLAY
    jp     z, mon_state_mem_display
    cpb    mon_state, #STATE_MEM_ALTER1
    jp     z, mon_state_alter1
    cpb    mon_state, #STATE_MEM_ALTER2
    jp     z, mon_state_alter2
    cpb    mon_state, #STATE_MEM_ALTER3
    jp     z, mon_state_alter3
    ret

go_state_mem_display:
    ldb    cio_dots, #0
    ldb    mon_state, #STATE_MEM_DISPLAY
    ret

go_state_mem_addr:
    ldb    cio_dots, #1
    ldb    mon_state, #STATE_MEM_ADDR1
    ret

go_state_mem_alter:
    ldb    cio_dots, #2
    ldb    mon_state, #STATE_MEM_ALTER1
    ret

!------------------------------------------------------------------------------
! mon_state_idle

mon_state_idle:
    cpb    rl0, #KEY_MEM
    jr     nz, mon_state_idle_not_mem
    jp     go_state_mem_addr
mon_state_idle_not_mem:
    ret

!------------------------------------------------------------------------------
! mon_state_addr1

mon_state_addr1:
    clr    mon_addr
    cpb    rl0, #7
    jr     gt, mon_state_addr1_not_oct
    ldb    rh0, mon_addr_hi
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR2
mon_state_addr1_not_oct:
    ret

!------------------------------------------------------------------------------
! mon_state_addr2

mon_state_addr2:
    cpb    rl0, #7
    jr     gt, mon_state_addr2_not_oct
    ldb    rh0, mon_addr_hi
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR3
mon_state_addr2_not_oct:
    ret

!------------------------------------------------------------------------------
! mon_state_addr3

mon_state_addr3:
    cpb    rl0, #7
    jr     gt, mon_state_addr3_not_oct
    ldb    rh0, mon_addr_hi
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR4
mon_state_addr3_not_oct:
    ret

!------------------------------------------------------------------------------
! mon_state_addr4

mon_state_addr4:
    cpb    rl0, #7
    jr     gt, mon_state_addr4_not_oct
    ldb    rh0, mon_addr_lo
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    ldb    mon_state, #STATE_MEM_ADDR5
mon_state_addr4_not_oct:
    ret

!------------------------------------------------------------------------------
! mon_state_addr5

mon_state_addr5:
    cpb    rl0, #7
    jr     gt, mon_state_addr5_not_oct
    ldb    rh0, mon_addr_lo
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    ldb    mon_state, #STATE_MEM_ADDR6
mon_state_addr5_not_oct:
    ret

!------------------------------------------------------------------------------
! mon_state_addr6

mon_state_addr6:
    cpb    rl0, #7
    jr     gt, mon_state_addr6_not_oct
    ldb    rh0, mon_addr_lo
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    jp     go_state_mem_display
mon_state_addr6_not_oct:
    ret

!------------------------------------------------------------------------------
! mon_state_mem_display

mon_state_mem_display:
    cpb    rl0, #KEY_PLUS
    jr     nz, mon_state_mem_display_not_plus
    inc    mon_addr, #1
    ret
mon_state_mem_display_not_plus:
    cpb    rl0, #KEY_MINUS
    jr     nz, mon_state_mem_display_not_minus
    dec    mon_addr, #1
    ret
mon_state_mem_display_not_minus:
    cpb    rl0, #KEY_ALTER
    jr     nz, mon_state_mem_display_not_alter
    jp     go_state_mem_alter
mon_state_mem_display_not_alter:        
    jp     mon_state_idle

!------------------------------------------------------------------------------
! mon_state_alter1

mon_state_alter1:
    cpb    rl0, #7
    jp     gt, mon_state_alter_not_oct
    call   mon_alter
    ldb    mon_state, #STATE_MEM_ALTER2
    ret

! this is where we go for all the alter states if a non-digit was pressed
mon_state_alter_not_oct:
    cpb    rl0, #KEY_ALTER
    jp     z, go_state_mem_display
    cpb    rl0, #KEY_MEM
    jp     z, go_state_mem_addr
    ret

!------------------------------------------------------------------------------
! mon_state_alter2

mon_state_alter2:
    cpb    rl0, #7
    jp     gt, mon_state_alter_not_oct
    call   mon_alter
    ldb    mon_state, #STATE_MEM_ALTER3
    ret

!------------------------------------------------------------------------------
! mon_state_alter3

mon_state_alter3:
    cpb    rl0, #7
    jp     gt, mon_state_alter_not_oct
    call   mon_alter
    inc    mon_addr, #1                     ! go to next address
    ldb    mon_state, #STATE_MEM_ALTER1
    ret

!------------------------------------------------------------------------------
! mon_alter

mon_alter:
    ldb    rh1, rl0
    clr    r2
    ldb    rh2, mon_seg
    ld     r3, mon_addr
	SEG
    ldb    rl1, @r2           ! using rl0 won't work because SEG/NONSEG wipe it
	NONSEG

    sllb   rl1, #3
    orb    rl1, rh1

	SEG
    ldb    @r2, rl1           ! using rl0 won't work because SEG/NONSEG wipe it
	NONSEG
    ret

!------------------------------------------------------------------------------
! mon_update

mon_update:
    ldb    rl0, mon_state
    andb   rl0, #STATE_GROUP_MASK
    cpb    rl0, #STATE_GROUP_MEM
    jp     z, mon_update_mem_display
    ret

mon_update_mem_display:
    ! show the memory address
    ld     r0, mon_addr
    call   cio_set_octal_addr

    ! show the memory value
    clr    r2
    ldb    rh2, mon_seg
    ld     r3, mon_addr
	SEG
    ldb    rl1, @r2           ! using rl0 won't work because SEG/NONSEG wipe it
	NONSEG
    ldb    rl0, rl1
    call   cio_set_octal_r
    ret

!------------------------------------------------------------------------------
	sect .data

    .even

mon_seg:
    .byte 0x01

mon_state:
    .byte    STATE_MEM_DISPLAY

    .even
mon_addr:
mon_addr_hi:
    .byte 0
mon_addr_lo:
    .byte 0


!------------------------------------------------------------------------------
    sect .rdata


