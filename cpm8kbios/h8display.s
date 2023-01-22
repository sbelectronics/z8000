!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global h8_display_init
    .global h8_display_hook
    .global h8_set_octal_addr
    .global h8_set_octal_r
    .global h8_set_reg_r
    .global h8_dots
    .global h8_radix
    .global h8_break
    .global h8_digsel_or
    .global h8_digits
    .global h8_dotpos
    .global h8_count

	unsegm
	sect	.text

.equ DIGSEL, 0xF0
.equ DIGVAL, 0xF1

! on port 360,
!   D7 is speaker
!   D6 is enable monitor interrupts
!   D5 is music and refresh monitor LED
!   D4 is something to do with int20


! performance notes:
!  saving all 14 regs instead of 4 regs - 2.7% increase (due to bug)
!  keyboard loop  - 0.6% increase
!  updates every 32 refreshes - 0.2& increase
!  multiplex-display - 0.4% increase

!------------------------------------------------------------------------------
! h8_display_init
!

h8_display_init:
    ldb     rl0, #0xE0
    outb    #DIGSEL, rl0     ! set speaker, refresh-enable, and monitor bits
    call    h8_testpattern_2
    call    mon_start
    ret

!------------------------------------------------------------------------------
! h8_testpattern_2
!

h8_testpattern_2:
    ldb     rl0, #0x0A       ! 012
    call    h8_set_octal_l

    ldb     rl0, #0xE3       ! 343
    call    h8_set_octal_m

    ldb     rl0, #0x88       ! 210
    call    h8_set_octal_r
    ret

!------------------------------------------------------------------------------
! h8_display_hook
! 

h8_display_hook:
    ldl   rr0, h8_count        ! increment the cycle counter
    addl  rr0, #1
    ldl   h8_count, rr0

    andb  rl1, #0x1F            ! every 32 cycle counts, do an update
    jr    nz, h8_not_upd
    call  mon_update
h8_not_upd:
    call  h8_multiplex_digit

    jp    h8_scankey

!------------------------------------------------------------------------------
! h8_multiplex_digit
!  

h8_multiplex_digit:
    ld    r1, digindex         ! r1 = digit index (0-8)

    ldb   rl0, h8_digits0(r1)
    ldb   rh0, rl1
    orb   rh0, h8_digsel_or
 
    outb  #DIGSEL, rh0         ! output digit index
    outb  #DIGVAL, rl0         ! output digit value

    dec   r1, #1
    jr    nz, digindex_nowrap
    ld    r1, #9
digindex_nowrap:
    ld    digindex, r1
    ret


!------------------------------------------------------------------------------
! h8_scankey

h8_scankey:
    inb    rl0, #DIGSEL
    cpb    rl0, key_last
    jr     nz, h8_scankey_different

    incb   key_same_count, #1
    cpb    key_same_count, #10
    jr     z, key_same_enough
    ret                              ! not long enough debounce -- keep waiting

key_same_enough:
    lda    r1, scancodes+16
    ldb    rh0, #17                  ! check 17 scancodes
next_scancode:
    cpb    rl0, @r1
    jr     nz, not_this_scancode
    ldb    rl0, rh0                  ! put scancode in rl2
    decb   rl0, #1
    jp     mon_keydown
not_this_scancode:
    dec    r1, #1
    dbjnz  rh0, next_scancode
    ret                              ! no match

h8_scankey_different:
    clrb   key_same_count
    ldb    key_last, rl0
    ret

!------------------------------------------------------------------------------
! h8_set_digit
!
! input:
!   rh0 = digit number
!   rl0 = value 0-9

h8_set_digit:
    push	@r15, r0
    push	@r15, r1

    clr     r1
    ldb     rl1, rl0
    ldb     rl0, digit_7seg(r1)

    clr     r1
    ldb     rl1, rh0
    ldb     h8_digits(r1), rl0

    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! h8_set_octal_l
!
! input:
!   rl0 = value 0-255

h8_set_octal_l:
    push	@r15, r0
    push	@r15, r1

    testb   h8_radix
    jr      nz, h8_set_hex_l

    clr     r1
    ldb     rl1, rl0
    srl     r1, #6
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_l, rh0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_l+1, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_l+2, rh0
    jp      h8_set_octal_l_ret

h8_set_hex_l:
    clr     r1
    ldb     rl1, rl0
    srl     r1, #4
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_l, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_l+1, rh0

    ldb     rh0, #0b11111111
    ldb     h8_digits_l+2, rh0

h8_set_octal_l_ret:
    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! h8_set_octal_m
!
! input:
!   rl0 = value 0-255

h8_set_octal_m:
    push	@r15, r0
    push	@r15, r1

    testb   h8_radix
    jr      nz, h8_set_hex_m

    clr     r1
    ldb     rl1, rl0
    srl     r1, #6
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_m, rh0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_m+1, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_m+2, rh0
    jp      h8_set_octal_m_ret

h8_set_hex_m:
    clr     r1
    ldb     rl1, rl0
    srl     r1, #4
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_m, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_m+1, rh0

    ldb     rh0, #0b11111111
    ldb     h8_digits_m+2, rh0

h8_set_octal_m_ret:
    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! h8_set_octal_r
!
! input:
!   rl0 = value 0-255

h8_set_octal_r:
    push	@r15, r0
    push	@r15, r1

    testb   h8_radix
    jr      nz, h8_set_hex_r

    clr     r1
    ldb     rl1, rl0
    srl     r1, #6
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_r, rh0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_r+1, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_r+2, rh0
    jp      h8_set_octal_r_ret

h8_set_hex_r:
    clr     r1
    ldb     rl1, rl0
    srl     r1, #4
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_r, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     h8_digits_r+1, rh0

    ldb     rh0, #0b11111111
    ldb     h8_digits_r+2, rh0

h8_set_octal_r_ret:
    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! h8_set_reg_r
!
! input:
!   rl0 = register number

h8_set_reg_r:
    push	@r15, r0
    push	@r15, r1

    clr     r1
    ldb     rl1, rl0
    sll     r1, #2

    ldb     rh0, reg_7seg(r1)
    ldb     h8_digits_r, rh0

    inc     r1, #1
    ldb     rh0, reg_7seg(r1)
    ldb     h8_digits_r+1, rh0

    inc     r1, #1
    ldb     rh0, reg_7seg(r1)
    ldb     h8_digits_r+2, rh0

    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! h8_set_octal_addr
!
! input:
!   r0 = value 0-65535

h8_set_octal_addr:
    call   h8_set_octal_m
    exb    rh0, rl0
    call   h8_set_octal_l
    exb    rh0, rl0
    ret

!------------------------------------------------------------------------------
	sect .data

    .balign  4
h8_count:
h8_count_b3:
    .byte    0
h8_count_b2:
    .byte    0
h8_count_b1:
    .byte    0
h8_count_b0:
    .byte    0

    .even
digindex:
    .word 1
h8_digits0:
    .byte 0x00                    ! dummy placeholder since first digit starts at 1
h8_digits:                           ! some non-random gibberish pattern for now
h8_digits_l:
    .byte 0x1
    .byte 0x2
    .byte 0x4
h8_digits_m:
    .byte 0x8
    .byte 0x10
    .byte 0x20
h8_digits_r:
    .byte 0x40
    .byte 0x80
    .byte 0x1F

h8_break:
    .byte 0x00

h8_radix:
    .byte 0x00

h8_dots:
    .byte 0x00

h8_dotpos:
    .byte 0x01

h8_digsel_or:
    .byte 0b11000000   ! refresh and speaker bits

key_last:
    .byte 0xFF
key_same_count:
    .byte 0x00

!------------------------------------------------------------------------------
    sect .rdata

digit_7seg:
	.byte	0b10000001	! 0
	.byte	0b11110011	! 1
	.byte	0b11001000	! 2
	.byte	0b11100000	! 3
	.byte	0b10110010	! 4
	.byte	0b10100100	! 5
	.byte	0b10000100	! 6
	.byte	0b11110001	! 7
	.byte	0b10000000	! 8
	.byte	0b10100000	! 9
    .byte   0b10010000  ! A
    .byte   0b10000110  ! B
    .byte   0b10001101  ! C
    .byte   0b11000010  ! D
    .byte   0b10001100  ! E
    .byte   0b10011100  ! F

reg_7seg:
reg_7seg_sg:
    .byte  0b11111111,  0b10100100, 0b10000101, 0b00000000
reg_7seg_pc:
    .byte  0b11111111,  0b10011000, 0b11001110, 0b00000000
reg_7seg_ps:
    .byte  0b11111111,  0b10011000, 0b10100100, 0b00000000
reg_7seg_fc:
    .byte  0b11111111,  0b10011100, 0b11001110, 0b00000000
reg_7seg_r0:
    .byte  0b11111111,  0b11011110, 0b10000001, 0b00000000
reg_7seg_r1:
    .byte  0b11111111,  0b11011110, 0b11110011, 0b00000000
reg_7seg_r2:
    .byte  0b11111111,  0b11011110, 0b11001000, 0b00000000
reg_7seg_r3:
    .byte  0b11111111,  0b11011110, 0b11100000, 0b00000000
reg_7seg_r4:
    .byte  0b11111111,  0b11011110, 0b10110010, 0b00000000
reg_7seg_r5:
    .byte  0b11111111,  0b11011110, 0b10100100, 0b00000000
reg_7seg_r6:
    .byte  0b11111111,  0b11011110, 0b10000100, 0b00000000
reg_7seg_r7:
    .byte  0b11111111,  0b11011110, 0b11110001, 0b00000000
reg_7seg_r8:
    .byte  0b11111111,  0b11011110, 0b10000000, 0b00000000
reg_7seg_r9:
    .byte  0b11111111,  0b11011110, 0b10100000, 0b00000000
reg_7seg_r10:
    .byte  0b11011110,  0b11110011, 0b10000001, 0b00000000
reg_7seg_r11:
    .byte  0b11011110,  0b11110011, 0b11110011, 0b00000000
reg_7seg_r12:
    .byte  0b11011110,  0b11110011, 0b11001000, 0b00000000
reg_7seg_r13:
    .byte  0b11011110,  0b11110011, 0b11100000, 0b00000000
reg_7seg_r14:
    .byte  0b11011110,  0b11110011, 0b10110010, 0b00000000
reg_7seg_r15:
    .byte  0b11011110,  0b11110011, 0b10100100, 0b00000000

scancodes:
    .byte 0b11111110 ! 0
    .byte 0b11111100 ! 1
    .byte 0b11111010 ! 2
    .byte 0b11111000 ! 3
    .byte 0b11110110 ! 4
    .byte 0b11110100 ! 5
    .byte 0b11110010 ! 6
    .byte 0b11110000 ! 7
    .byte 0b11101111 ! 8
    .byte 0b11001111 ! 9
    .byte 0b10101111 ! A
    .byte 0b10001111 ! B
    .byte 0b01101111 ! C
    .byte 0b01001111 ! D
    .byte 0b00101111 ! E
    .byte 0b00001111 ! F
    .byte 0b00101110 ! 0 + E



