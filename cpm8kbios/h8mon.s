!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global mon_keydown
    .global mon_update
    .global mon_start
    .global mon_test_reg, mon_test_reg_halt_loop
    .global rtm_loop

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
.equ KEY_REG, KEY_DOT
.equ KEY_RADIX, 0x03
.equ KEY_GO, 0x04
.equ KEY_RTM, 0x10

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

.equ STATE_REG_ALTER1, 0x20
.equ STATE_REG_ALTER2, 0x21
.equ STATE_REG_ALTER3, 0x22
.equ STATE_REG_ALTER4, 0x23
.equ STATE_REG_ALTER5, 0x24
.equ STATE_REG_ALTER6, 0x25
.equ STATE_REG_DISPLAY, 0x26

.equ STATE_GROUP_MEM, 0x10
.equ STATE_GROUP_REG, 0x20
.equ STATE_GROUP_MASK, 0xF0

.equ MON_REG_MAX, 17

.equ SAVED_TRAP_FRAME_SIZE, 46

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
    cpb    mon_state, #STATE_REG_ALTER1
    jp     z, mon_state_reg_alter1
    cpb    mon_state, #STATE_REG_ALTER2
    jp     z, mon_state_reg_alter2
    cpb    mon_state, #STATE_REG_ALTER3
    jp     z, mon_state_reg_alter3
    cpb    mon_state, #STATE_REG_ALTER4
    jp     z, mon_state_reg_alter4
    cpb    mon_state, #STATE_REG_ALTER5
    jp     z, mon_state_reg_alter5
    cpb    mon_state, #STATE_REG_ALTER6
    jp     z, mon_state_reg_alter6
    cpb    mon_state, #STATE_REG_DISPLAY
    jp     z, mon_state_reg_display
    ret

mon_start:
    !jp     go_state_mem_alter
    jp     go_state_mem_display

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

go_state_reg_display:
    ldb    cio_dots, #0
    ldb    mon_state, #STATE_REG_DISPLAY
    ret

go_state_reg_alter:
    ldb    cio_dots, #2
    ldb    mon_state, #STATE_REG_ALTER1
    ret


go_rtm:
    testb   cio_break
    ret     nz                              ! we're already in break state
    ldb     cio_break, #1
    setb    cio_digsel_or, #13              ! turn on the monitor LED

    ld      r0, #SAVED_TRAP_FRAME_SIZE/2    ! copy registers from trap_frame
    ld      r1, trap_frame                  ! ... to saved_trap_frame
    lda     r2, mon_saved_trap_frame
    ldir    @r2, @r1, r0


    ! trap_frame+38 would be the trap identifier. We don't care.

    ld      r1, trap_frame                  ! start at the beginning of the interrupt stack frame
    add     r1, #34                         ! now pointing at FCW

    ld      r0, @r1                         ! get the saved FCW
    res     r0, #15                         ! nonsegmented mode
    ld      @r1, r0                         ! restore modified FCW to the saved FCW

    inc     r1, #2                          ! now pointing at PCSEG
    ld      r0, #0x0300                     ! system segment
    ld      @r1, r0

    inc     r1, #2                          ! now pointing at PCOFFS
    lda     r0, rtm_loop
    ld      @r1, r0
    ret

rtm_loop:
    jr      rtm_loop

go_go:
    cpb     cio_break, #1
    ret     nz               ! we're not in break state
    clrb    cio_break
    resb    cio_digsel_or, #13              ! turn off the monitor LED

    ld      r0, #SAVED_TRAP_FRAME_SIZE/2    ! copy registers from saved_trap_frame
    ld      r1, trap_frame                  ! ... to trap_frame
    lda     r2, mon_saved_trap_frame
    ldir    @r1, @r2, r0

    ret

go_radix:
    ldb    rl0, cio_radix
    xorb   rl0, #1
    ldb    cio_radix, rl0
    ret

!------------------------------------------------------------------------------
! mon_state_idle

mon_state_idle:
    cpb    rl0, #KEY_MEM
    jp     z, go_state_mem_addr
    cpb    rl0, #KEY_REG
    jp     z, go_state_reg_display
    cpb    rl0, #KEY_RADIX
    jp     z, go_radix
mon_state_idle_not_radix:
    cpb    rl0, #KEY_RTM
    jr     z, go_rtm
    cpb    rl0, #KEY_GO
    jr     z, go_go
    ret

!------------------------------------------------------------------------------
! mon_state_addr1

mon_state_addr1:
    testb  cio_radix
    jr     nz, mon_state_addr1_hex
    cpb    rl0, #7
    jp     gt, mon_state_addr_not_oct
    ldb    rh0, mon_addr_hi
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR2
    ret
mon_state_addr1_hex:
    testb  rl0
    jp     nz, mon_state_addr_not_oct    ! first digit of hex entry must be 0
    ldb    mon_state, #STATE_MEM_ADDR2
    ret

! this is where we go for all the addr states if a non-digit was pressed
mon_state_addr_not_oct:
    cpb    rl0, #KEY_ALTER
    jp     z, go_state_mem_alter
    cpb    rl0, #KEY_MEM
    jp     z, go_state_mem_display ! cancel memory address entry
    jp     mon_state_idle          ! fall-through to idle keypress processing
    ret

!------------------------------------------------------------------------------
! mon_state_addr2

mon_state_addr2:
    testb  cio_radix
    jr     nz, mon_state_addr2_hex
    cpb    rl0, #7
    jp     gt, mon_state_addr_not_oct
    ldb    rh0, mon_addr_hi
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR3
    ret
mon_state_addr2_hex:
    ldb    rh0, mon_addr_hi
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR3
    ret
    

!------------------------------------------------------------------------------
! mon_state_addr3

mon_state_addr3:
    testb  cio_radix
    jr     nz, mon_state_addr3_hex
    cpb    rl0, #7
    jp     gt, mon_state_addr_not_oct
    ldb    rh0, mon_addr_hi
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR4
    ret
mon_state_addr3_hex:
    ldb    rh0, mon_addr_hi
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    mon_addr_hi, rh0
    ldb    mon_state, #STATE_MEM_ADDR4
    ret

!------------------------------------------------------------------------------
! mon_state_addr4

mon_state_addr4:
    testb  cio_radix
    jr     nz, mon_state_addr4_hex
    cpb    rl0, #7
    jp     gt, mon_state_addr_not_oct
    ldb    rh0, mon_addr_lo
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    ldb    mon_state, #STATE_MEM_ADDR5
    ret
mon_state_addr4_hex:
    ldb    rh0, mon_addr_lo
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    ldb    mon_state, #STATE_MEM_ADDR5
    ret

!------------------------------------------------------------------------------
! mon_state_addr5

mon_state_addr5:
    testb  cio_radix
    jr     nz, mon_state_addr5_hex
    cpb    rl0, #7
    jp     gt, mon_state_addr_not_oct
    ldb    rh0, mon_addr_lo
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    ldb    mon_state, #STATE_MEM_ADDR6
    ret
mon_state_addr5_hex:
    ldb    rh0, mon_addr_lo
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    jp     go_state_mem_display
    ret

!------------------------------------------------------------------------------
! mon_state_addr6

mon_state_addr6:
    cpb    rl0, #7
    jp     gt, mon_state_addr_not_oct
    ldb    rh0, mon_addr_lo
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    mon_addr_lo, rh0
    jp     go_state_mem_display
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
    testb  cio_radix
    jr     nz, mon_state_alter1_hex
    cpb    rl0, #7
    jp     gt, mon_state_alter_not_oct
    call   mon_alter
    ldb    mon_state, #STATE_MEM_ALTER2
mon_state_alter1_hex:
    testb  rl0
    jp     nz, mon_state_alter_not_oct    ! first digit of hex entry must be 0
    ldb    mon_state, #STATE_MEM_ALTER2
    ret

! this is where we go for all the alter states if a non-digit was pressed
mon_state_alter_not_oct:
    cpb    rl0, #KEY_ALTER
    jp     z, go_state_mem_display
    jp     mon_state_idle          ! fall-through to idle keypress processing
    ret

!------------------------------------------------------------------------------
! mon_state_alter2

mon_state_alter2:
    testb  cio_radix
    jr     nz, mon_state_alter2_hex
    cpb    rl0, #7
    jp     gt, mon_state_alter_not_oct
    call   mon_alter
    ldb    mon_state, #STATE_MEM_ALTER3
    ret
mon_state_alter2_hex:
    call   mon_alter
    ldb    mon_state, #STATE_MEM_ALTER3
    ret

!------------------------------------------------------------------------------
! mon_state_alter3

mon_state_alter3:
    testb  cio_radix
    jr     nz, mon_state_alter3_hex
    cpb    rl0, #7
    jp     gt, mon_state_alter_not_oct
    call   mon_alter
    inc    mon_addr, #1                     ! go to next address
    ldb    mon_state, #STATE_MEM_ALTER1
    ret
mon_state_alter3_hex:
    call   mon_alter
    inc    mon_addr, #1                     ! go to next address
    ldb    mon_state, #STATE_MEM_ALTER1
    ret

!------------------------------------------------------------------------------
! mon_alter

mon_alter:
    ldb    rh1, rl0
    clr    r2
    ldb    rh2, mon_seg_l
    ld     r3, mon_addr
	SEG
    ldb    rl1, @r2           ! using rl0 won't work because SEG/NONSEG wipe it
	NONSEG

    testb  cio_radix
    jr     z, mon_state_alter_oct
    sllb   rl1, #1            ! hex needs one more shift than octal
mon_state_alter_oct:
    sllb   rl1, #3
    orb    rl1, rh1

	SEG
    ldb    @r2, rl1           ! using rl0 won't work because SEG/NONSEG wipe it
	NONSEG
    ret

!------------------------------------------------------------------------------
! mon_state_reg_alter1

mon_state_reg_alter1:
    testb  cio_radix
    jr     nz, mon_state_reg_alter1_hex
    cpb    rl0, #7
    jp     gt, mon_state_reg_alter_not_oct
    call   mon_get_reg_addr
    ldb    rh0, @r1
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER2
    ret
mon_state_reg_alter1_hex:
    testb  rl0
    jp     nz, mon_state_reg_alter_not_oct    ! first digit of hex entry must be 0
    ldb    mon_state, #STATE_REG_ALTER2

! this is where we go for all the addr states if a non-digit was pressed
mon_state_reg_alter_not_oct:
    cpb    rl0, #KEY_ALTER
    jp     z, go_state_reg_display
    jp     mon_state_idle          ! fall-through to idle keypress processing
    ret

!------------------------------------------------------------------------------
! mon_state_reg_alter2

mon_state_reg_alter2:
    testb  cio_radix
    jr     nz, mon_state_reg_alter2_hex
    cpb    rl0, #7
    jp     gt, mon_state_reg_alter_not_oct
    call   mon_get_reg_addr
    ldb    rh0, @r1
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER3
    ret
mon_state_reg_alter2_hex:
    call   mon_get_reg_addr
    ldb    rh0, @r1
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER3
    ret

!------------------------------------------------------------------------------
! mon_state_reg_alter3

mon_state_reg_alter3:
    testb  cio_radix
    jr     nz, mon_state_reg_alter3_hex
    cpb    rl0, #7
    jp     gt, mon_state_reg_alter_not_oct
    call   mon_get_reg_addr
    ldb    rh0, @r1
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER4
    ret
mon_state_reg_alter3_hex:
    call   mon_get_reg_addr
    ldb    rh0, @r1
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER4
    ret

!------------------------------------------------------------------------------
! mon_state_reg_alter4

mon_state_reg_alter4:
    testb  cio_radix
    jr     nz, mon_state_reg_alter4_hex
    cpb    rl0, #7
    jp     gt, mon_state_reg_alter_not_oct
    call   mon_get_reg_addr
    inc    r1, #1
    ldb    rh0, @r1
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER5
    ret
mon_state_reg_alter4_hex:
    call   mon_get_reg_addr
    inc    r1, #1
    ldb    rh0, @r1
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER5
    ret

!------------------------------------------------------------------------------
! mon_state_reg_alter5

mon_state_reg_alter5:
    testb  cio_radix
    jr     nz, mon_state_reg_alter5_hex
    cpb    rl0, #7
    jp     gt, mon_state_reg_alter_not_oct
    call   mon_get_reg_addr
    inc    r1, #1
    ldb    rh0, @r1
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    @r1, rh0
    ldb    mon_state, #STATE_REG_ALTER6
    ret
mon_state_reg_alter5_hex:
    call   mon_get_reg_addr
    inc    r1, #1
    ldb    rh0, @r1
    sllb   rh0, #4
    orb    rh0, rl0
    ldb    @r1, rh0
    jp     go_state_reg_display
    ret

!------------------------------------------------------------------------------
! mon_state_reg_alter6

mon_state_reg_alter6:
    cpb    rl0, #7
    jp     gt, mon_state_reg_alter_not_oct
    call   mon_get_reg_addr
    inc    r1, #1
    ldb    rh0, @r1
    sllb   rh0, #3
    orb    rh0, rl0
    ldb    @r1, rh0
    jp     go_state_reg_display
    ret

!------------------------------------------------------------------------------
! mon_state_reg_display

mon_state_reg_display:
    cpb    rl0, #KEY_PLUS
    jr     nz, mon_state_reg_display_not_plus
    cpb    mon_reg_index, #MON_REG_MAX             ! check to see if we're at highest reg
    ret    z                                       ! yes, retrun
    incb   mon_reg_index, #1
    ret
mon_state_reg_display_not_plus:
    cpb    rl0, #KEY_MINUS
    jr     nz, mon_state_reg_display_not_minus
    testb   mon_reg_index                          ! check to see if we're at lowest reg
    ret    z                                       ! yes, return
    decb   mon_reg_index, #1
    ret
mon_state_reg_display_not_minus:
    cpb    rl0, #KEY_ALTER
    jr     nz, mon_state_reg_display_not_alter
    jp     go_state_reg_alter
mon_state_reg_display_not_alter:        
    jp     mon_state_idle

!------------------------------------------------------------------------------
! mon_get_reg_addr
!
! output
!    r1: address of register in frame

mon_get_reg_addr:
    cpb    mon_reg_index, #0
    jr     nz, not_sg

    lda    r1, mon_regs
    add    r1, mon_reg_index_word
    add    r1, mon_reg_index_word
    ret

    ! to verify these, jump to mon_test_reg in DDT then look for the right
    ! signature.

not_sg:
    cpb    mon_reg_index, #1
    jr     nz, not_pc

    ld     r1, trap_frame
    add    r1, #38              ! 32 bytes for trap_frame, 6
    ret

not_pc:
    ld     r1, trap_frame
    sub    r1, #2               ! index is + 4, but the bottom 2 bytes of trap_frame are empty slot
    add    r1, mon_reg_index_word
    add    r1, mon_reg_index_word
    ret


!------------------------------------------------------------------------------
! mon_update

mon_update:
    ldb    rl0, mon_state
    andb   rl0, #STATE_GROUP_MASK
    cpb    rl0, #STATE_GROUP_MEM
    jp     z, mon_update_mem_display
    cpb    rl0, #STATE_GROUP_REG
    jp     z, mon_update_reg_display
    jp     mon_update_dots

mon_update_mem_display:
    ! show the memory address
    ld     r0, mon_addr
    call   cio_set_octal_addr

    ! show the memory value
    clr    r2
    ldb    rh2, mon_seg_l
    ld     r3, mon_addr
	SEG
    ldb    rl1, @r2           ! using rl0 won't work because SEG/NONSEG wipe it
	NONSEG
    ldb    rl0, rl1
    call   cio_set_octal_r
    jp     mon_update_dots

mon_update_reg_display:
    ! show register contents
    call   mon_get_reg_addr
    ld     r0, @r1                ! load the contents
    call   cio_set_octal_addr

    ! show register name
    ldb    rl0, mon_reg_index
    call   cio_set_reg_r
    jp     mon_update_dots

mon_update_dots:
    lda    r1, digits
    ldb    rh0, #9
    ldb    rl0, cio_dots
    testb  rl0
    ret    z                      ! no dots to light
    cpb    rl0, #1
    jr     nz, mon_update_dots_check2 
mon_update_dots_1:
    resb   @r1, #7
    inc    r1, #1
    dbjnz  rh0, mon_update_dots_1
    ret
mon_update_dots_check2:
    ldb   rl0, cio_dotpos
    decb  rl0, #1
    jr    nz, mon_dotpos_nowrap
    ldb   rl0, #9
mon_dotpos_nowrap:
    ldb   cio_dotpos, rl0
mon_update_dots_2:
    cpb    rh0, rl0
    jr     z, mon_update_dots_at_pos
    inc    r1, #1
    dbjnz  rh0, mon_update_dots_2
    ret
mon_update_dots_at_pos:
    resb   @r1, #7
    ret

mon_test_reg:
    ld     r0, #0x3300
    ld     r1, #0x3301
    ld     r2, #0x3302
    ld     r3, #0x3303
    ld     r4, #0x3304
    ld     r5, #0x3305
    ld     r6, #0x3306
    ld     r7, #0x3307
    ld     r8, #0x3308
    ld     r9, #0x3309
    ld     r10, #0x330A
    ld     r11, #0x330B
    ld     r12, #0x330C
    ld     r13, #0x330D
mon_test_reg_halt_loop:
    !halt                 ! this doesn't actually work -- the halt causes a bunch of gibberish out the serial port
    jr     mon_test_reg_halt_loop

!------------------------------------------------------------------------------
	sect .data

    .even

mon_regs:            ! this is where we will put the register frame
mon_seg:
mon_seg_h:           ! there really isn't a high byte...
    .byte 0x00
mon_seg_l:
    .byte 0x01

mon_reg_index_word:
    .byte    0x00
mon_reg_index:
    .byte    0x00

mon_state:
    .byte    STATE_MEM_DISPLAY

    .even
mon_addr:
mon_addr_hi:
    .byte 0
mon_addr_lo:
    .byte 0

!------------------------------------------------------------------------------
    sect .bss

    .even
mon_saved_trap_frame:
    .space SAVED_TRAP_FRAME_SIZE



