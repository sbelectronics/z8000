!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global cio_init
    .global cio_reset
    .global cio_nvi
    .global cio_kb_enqueue
    .global cio_count
    .global cio_enable
    .global cio_divisor
    .global cio_khz
    .global cio_set_divisor
    .global cio_set_octal_addr
    .global cio_set_octal_r
    .global cio_set_reg_r
    .global cio_dots
    .global cio_radix
    .global cio_break
    .global cio_digsel_or
    .global digits
    .global cio_dotpos
    .global cio_nvi_min

	unsegm
	sect	.text

.equ DIGSEL, 0xF0
.equ DIGVAL, 0xF1

! on port 360,
!   D7 is speaker
!   D6 is enable monitor interrupts
!   D5 is music and refresh monitor LED
!   D4 is something to do with int20

.equ CIO_TICKS_PER_SECOND, 20
.equ CIO_DIVISOR, CIO_KHZ*1000/2/CIO_TICKS_PER_SECOND

.if CIO_DIVISOR > 0xFFFF
    .error "CIO_DIVISOR out of range"
.endif

.equ CIO_C, 0x11
.equ CIO_B, 0x13
.equ CIO_A, 0x15
.equ CIO_CMD, 0x17

.equ CIO_MICR, 0
.equ CIO_MCCR, 1

.equ CIO_PMSA, 0x20
.equ CIO_PHSA, 0x21
.equ CIO_DPPA, 0x22
.equ CIO_DDA, 0x23
.equ CIO_SIOA, 0x24
.equ CIO_PPA, 0x25
.equ CIO_PTA, 0x26
.equ CIO_PMA, 0x27
.equ CIO_PCSA, 0x08
.equ CIO_PDRA, 0x0D

.equ CIO_PMSB, 0x28
.equ CIO_PHSB, 0x29
.equ CIO_DPPB, 0x2A
.equ CIO_DDB, 0x2B
.equ CIO_SIOB, 0x2C
.equ CIO_PPB, 0x2D
.equ CIO_PTB, 0x2E
.equ CIO_PMB, 0x2F
.equ CIO_PCSB, 0x09
.equ CIO_PDRB, 0x0E

.equ CIO_DPPC, 0x05
.equ CIO_DDC, 0x06
.equ CIO_SIOC, 0x07
.equ CIO_PDRC, 0x0F

.equ CIO_CTCS1, 0x0A
.equ CIO_CTCS2, 0x0B
.equ CIO_CTCS3, 0x0C

.equ CIO_CTMS1, 0x1C
.equ CIO_CTMS2, 0x1D
.equ CIO_CTMS3, 0x1E

.equ CIO_CTCC1M, 0x10
.equ CIO_CTCC1L, 0x11
.equ CIO_CTCC2M, 0x12
.equ CIO_CTCC2L, 0x13
.equ CIO_CTCC3M, 0x14
.equ CIO_CTCC3L, 0x15

.equ CIO_CTTC1M, 0x16
.equ CIO_CTTC1L, 0x17
.equ CIO_CTTC2M, 0x18
.equ CIO_CTTC2L, 0x19
.equ CIO_CTTC3M, 0x1A
.equ CIO_CTTC3L, 0x1B

.equ CIO_IVA, 0x02
.equ CIO_IVB, 0x03
.equ CIO_IVCT, 0x04

.equ CIO_CV, 0x1F

.equ KEY_PLUS, 0x0A
.equ KEY_MINUS, 0x0B
.equ KEY_STAR, 0x0C
.equ KEY_SLASH, 0x0D
.equ KEY_POUND, 0x0E
.equ KEY_DOT, 0x0F

.equ KEY_MEM, KEY_POUND
.equ KEY_ALTER, KEY_SLASH

.equ STATE_IDLE, 0
.equ STATE_MEM_ADDR1, 1
.equ STATE_MEM_ADDR2, 2
.equ STATE_MEM_ADDR3, 3
.equ STATE_MEM_ADDR4, 4
.equ STATE_MEM_ADDR5, 5
.equ STATE_MEM_ADDR6, 6
.equ STATE_MEM_DISPLAY, 7

!   rh0 = register (input)
!   rl0 = value (output)
.macro CIO_GET
    outb   #CIO_CMD, rh0
    inb    rl0, #CIO_CMD
    .endm

!   rh0 = register (input)
!   rl0 = value (input)
.macro CIO_SET
    outb   #CIO_CMD, rh0
    outb   #CIO_CMD, rl0
    .endm

! performance notes:
!  saving all 14 regs instead of 4 regs - 2.7% increase (due to bug)
!  keyboard loop  - 0.6% increase
!  updates every 32 refreshes - 0.2& increase
!  multiplex-display - 0.4% increase

!------------------------------------------------------------------------------
! cio_init

cio_init:
    ldb     cio_count_b0, #0
    ldb     cio_count_b1, #0
    ldb     cio_count_b2, #0
    ldb     cio_count_b3, #0

    call    cio_detect_and_reset
    test    r0
    jr      z, cio_init_detected
    ldb     cio_enable, #0
    ldb     cio_kb_enqueue, #0xFF
    lda     r4, nociomsg
    call    puts
    ret
cio_init_detected:
    di      vi, nvi                     ! let's not get interrupted while we're setting up the CIO

    lda     r4, ciomsg
    call    puts
    ld      r2, #(ciocmde - ciocmds)    ! initialize Z8536
    ld      r3, #CIO_CMD
    ld      r4, #ciocmds
    otirb   @r3, @r4, r2
    ldb     cio_enable, #1

    ldb     rl0, #0xE0
    outb    #DIGSEL, rl0     ! set speaker, refresh-enable, and monitor bits

    call    cio_testpattern_2
    call    mon_start

    ei      vi, nvi
    ret

!------------------------------------------------------------------------------
! cio_reset

cio_reset:
    ldb    rh0, #0           ! CIO register 0
    CIO_GET                  ! read will force us into state 0
    ldb    rl0, #1           ! write bit 1 in register 0 will cause reset
    CIO_SET
    ldb    rl0, #0           ! leave reset state
    CIO_SET
    ret

!------------------------------------------------------------------------------
! cio_testpattern_2
!

cio_testpattern_2:
    ldb     rl0, #0x0A       ! 012
    call    cio_set_octal_l

    ldb     rl0, #0xE3       ! 343
    call    cio_set_octal_m

    ldb     rl0, #0x88       ! 210
    call    cio_set_octal_r
    ret

!------------------------------------------------------------------------------
! cio_detect
!
! output:
!   rl0 = 0 if detected, 1 if not detected

cio_detect_and_reset:
    inb     rl0, #CIO_CMD      ! reset the CMD etate machine

    ldb     rh0, #CIO_MICR
    ldb     rl0, #1            ! reset CIO
    CIO_SET

    ldb     rl0, #0b00100010   ! NV, RJA
    outb    #CIO_CMD, rl0      ! we're still pointing at reg0

    ldb     rh0, #CIO_PPB
    ldb     rl0, #0xA5
    CIO_SET
    CIO_GET
    cpb     rl0, #0xA5
    jr      nz, nodetect
    ldb     rl0, #0x5A
    CIO_SET
    CIO_GET
    cpb     rl0, #0x5A
    jr      nz, nodetect
    ldb     rl0, #0x00
    CIO_SET
    clr     r0
    ret
nodetect:
    ld      r0, #1
    ret

!------------------------------------------------------------------------------
! cio_nvi
!  

cio_nvi:
    ldb   rh0, #CIO_PCSA
    CIO_GET
    bitb  rl0, #5               ! check IUS bit
    ret   z                     ! it's not our fault

    ldl   rr0, cio_count        ! increment the cycle counter
    addl  rr0, #1
    ldl   cio_count, rr0

    andb  rl1, #0x1F            ! every 32 cycle counts, do an update
    jr    nz, cio_nvi_not_upd
    call  mon_update
cio_nvi_not_upd:

cio_nvi_again:
    !--------------------------------------------------  multiplex-digit
    ld    r1, digindex         ! r1 = digit index (0-8)

    ldb   rl0, digits0(r1)
    ldb   rh0, rl1
    orb   rh0, cio_digsel_or
 
    outb  #DIGSEL, rh0         ! output digit index
    outb  #DIGVAL, rl0         ! output digit value

    dec   r1, #1
    jr    nz, digindex_nowrap
    ld    r1, #9
digindex_nowrap:
    ld    digindex, r1
    !-------------------------------------------------- end multiplex-digit

    call  cio_scankey

    ldb   rh0, #CIO_PCSA
    ldb   rl0, #0b10100000    ! clear IP
    CIO_SET
    ldb   rl0, #0b01100000    ! clear IUS
    CIO_SET

    ! NOTE: OR-priority-encoded should have been an alternative to this, as docs claim IP cannot be
    ! reset while the pattern is present.

    ! check to see if a pattern was matched after we cleared IP
    ldb   rh0, #CIO_PCSA
    CIO_GET
    andb  rl0, #0b00100010    ! check IP and PMF
    cpb   rl0, #0b00000010
    jr    z, cio_nvi_again    ! uh oh, PMF is set but not IP. Go back and look for more interrupts.

cio_nvi_out:
    ret


cio_nvi_min:
    ldb   rh0, #CIO_PCSA
    CIO_GET
    bitb  rl0, #5               ! check IUS bit
    ret   z                     ! it's not our fault

    ldb   rh0, #CIO_PCSA
    ldb   rl0, #0b10100000    ! clear IP
    CIO_SET
    ldb   rl0, #0b01100000    ! clear IUS
    CIO_SET
    ret

!------------------------------------------------------------------------------
! cio_scankey

cio_scankey:
    inb    rl0, #DIGSEL
    cpb    rl0, key_last
    jr     nz, cio_scankey_different

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

cio_scankey_different:
    clrb   key_same_count
    ldb    key_last, rl0
    ret

!------------------------------------------------------------------------------
! cio_set_digit
!
! input:
!   rh0 = digit number
!   rl0 = value 0-9

cio_set_digit:
    push	@r15, r0
    push	@r15, r1

    clr     r1
    ldb     rl1, rl0
    ldb     rl0, digit_7seg(r1)

    clr     r1
    ldb     rl1, rh0
    ldb     digits(r1), rl0

    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! cio_set_octal_l
!
! input:
!   rl0 = value 0-255

cio_set_octal_l:
    push	@r15, r0
    push	@r15, r1

    testb   cio_radix
    jr      nz, cio_set_hex_l

    clr     r1
    ldb     rl1, rl0
    srl     r1, #6
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_l, rh0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_l+1, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_l+2, rh0
    jp      cio_set_octal_l_ret

cio_set_hex_l:
    clr     r1
    ldb     rl1, rl0
    srl     r1, #4
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     digits_l, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     digits_l+1, rh0

    ldb     rh0, #0b11111111
    ldb     digits_l+2, rh0

cio_set_octal_l_ret:
    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! cio_set_octal_m
!
! input:
!   rl0 = value 0-255

cio_set_octal_m:
    push	@r15, r0
    push	@r15, r1

    testb   cio_radix
    jr      nz, cio_set_hex_m

    clr     r1
    ldb     rl1, rl0
    srl     r1, #6
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_m, rh0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_m+1, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_m+2, rh0
    jp      cio_set_octal_m_ret

cio_set_hex_m:
    clr     r1
    ldb     rl1, rl0
    srl     r1, #4
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     digits_m, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     digits_m+1, rh0

    ldb     rh0, #0b11111111
    ldb     digits_m+2, rh0

cio_set_octal_m_ret:
    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! cio_set_octal_r
!
! input:
!   rl0 = value 0-255

cio_set_octal_r:
    push	@r15, r0
    push	@r15, r1

    testb   cio_radix
    jr      nz, cio_set_hex_r

    clr     r1
    ldb     rl1, rl0
    srl     r1, #6
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_r, rh0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_r+1, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x07
    ldb     rh0, digit_7seg(r1)
    ldb     digits_r+2, rh0
    jp      cio_set_octal_r_ret

cio_set_hex_r:
    clr     r1
    ldb     rl1, rl0
    srl     r1, #4
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     digits_r, rh0

    clr     r1
    ldb     rl1, rl0
    and     r1, #0x0F
    ldb     rh0, digit_7seg(r1)
    ldb     digits_r+1, rh0

    ldb     rh0, #0b11111111
    ldb     digits_r+2, rh0

cio_set_octal_r_ret:
    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! cio_set_reg_r
!
! input:
!   rl0 = register number

cio_set_reg_r:
    push	@r15, r0
    push	@r15, r1

    clr     r1
    ldb     rl1, rl0
    sll     r1, #2

    ldb     rh0, reg_7seg(r1)
    ldb     digits_r, rh0

    inc     r1, #1
    ldb     rh0, reg_7seg(r1)
    ldb     digits_r+1, rh0

    inc     r1, #1
    ldb     rh0, reg_7seg(r1)
    ldb     digits_r+2, rh0

    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! cio_set_octal_addr
!
! input:
!   r0 = value 0-65535

cio_set_octal_addr:
    call   cio_set_octal_m
    exb    rh0, rl0
    call   cio_set_octal_l
    exb    rh0, rl0
    ret


!------------------------------------------------------------------------------
! cio_set_divisor
!
! Note: may cause some hiccups in counting as it changes
!
! input:
!   r5 = divisor

cio_set_divisor:
    ldb    rh0, #CIO_CTTC1M
    ldb    rl0, rh5
    CIO_SET
    ldb    rh0, #CIO_CTTC1L
    ldb    rl0, rl5
    CIO_SET
    ld     cio_divisor, r5
    ret    

!------------------------------------------------------------------------------
	sect .data

    .even

cio_enable:
    .byte    0

cio_kb_enqueue:
    .byte    0xFF

    .balign  4
cio_count:
cio_count_b3:
    .byte    0
cio_count_b2:
    .byte    0
cio_count_b1:
    .byte    0
cio_count_b0:
    .byte    0

    .even
cio_khz:
    .word    CIO_KHZ
cio_divisor:
    .word    CIO_DIVISOR

    .even
digindex:
    .word 1
digits0:
    .byte 0x00                    ! dummy placeholder since first digit starts at 1
digits:                           ! some non-random gibberish pattern for now
digits_l:
    .byte 0x1
    .byte 0x2
    .byte 0x4
digits_m:
    .byte 0x8
    .byte 0x10
    .byte 0x20
digits_r:
    .byte 0x40
    .byte 0x80
    .byte 0x1F

cio_break:
    .byte 0x00

cio_radix:
    .byte 0x00

cio_dots:
    .byte 0x00

cio_dotpos:
    .byte 0x01

cio_digsel_or:
    .byte 0b11000000   ! refresh and speaker bits

key_last:
    .byte 0xFF
key_same_count:
    .byte 0x00

!------------------------------------------------------------------------------
    sect .rdata

ciocmds:
    .byte   CIO_DDA, 0b01111111    ! PortA D7 outputs, D0..D6 inputs
    .byte   CIO_DDB, 0b11111111    ! PortB all inputs
    .byte   CIO_DDC, 0b11111111    ! PortC all inputs
    .byte   CIO_PMA,    0b01111111  ! PortA Pattern mask enable D0..D6 
    .byte   CIO_PTA,    0b00000000  ! PortA Pattern transition set to no transition
    .byte   CIO_PPA,    0b00000000  ! PortA Pattern polarity register set to all zero
    .byte   CIO_PMSA,   0b00001100  ! 00=bitport, 0=no_itb, 0=no_singlebuffer, 1=imo, 10=ormode, 0=no_lpm
    .byte   CIO_PCSA,   0b11000000  ! PortA enable interrupts, disable interrupt-on-error
    .byte   CIO_MCCR,   0b10000100  ! Enable portA, portB
    .byte   CIO_MICR,   0b10100010  ! MIE, NV, RJA
    .byte   CIO_A,      0b00000000  ! set PortA h8 ie bit
ciocmde:

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

obsolete_reg_7seg:
reg_7seg_sp:
    .byte  0b01111111,  0b10100100, 0b10011000, 0b00000000   ! last byte is a pad, for easy multiply
reg_7seg_af:
    .byte  0b01111111,  0b10010000, 0b10011100, 0b00000000
reg_7seg_bc:
    .byte  0b01111111,  0b10000110, 0b10001101, 0b00000000
reg_7seg_de:
	.byte  0b01111111,  0b11000010, 0b10001100, 0b00000000
reg_7seg_hl:
	.byte  0b01111111,  0b10010010, 0b10001111, 0b00000000

reg_7seg:
reg_7seg_sg:
    .byte  0b11111111,  0b10100100, 0b10000101, 0b00000000
reg_7seg_pc:
    .byte  0b11111111,  0b10011000, 0b11001110, 0b00000000
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

ciomsg:
    .asciz  "CIO detected. intializing\r\n"

nociomsg:
    .asciz  "CIO not detected. not intializing\r\n"


