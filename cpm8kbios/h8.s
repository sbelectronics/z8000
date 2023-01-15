!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global cio_init, cio_nvi
    .global cio_kb_enqueue
    .global cio_count
    .global cio_enable
    .global cio_divisor
    .global cio_khz
    .global cio_set_divisor

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
    ldb     cio_kb_caps, #0
    ldb     cio_kb_code, #0
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

    ldb     rh0, #0
    ldb     rl0, #0
    call    cio_set_digit

    ldb     rh0, #1
    ldb     rl0, #1
    call    cio_set_digit

    ldb     rh0, #2
    ldb     rl0, #2
    call    cio_set_digit

    ldb     rh0, #3
    ldb     rl0, #3
    call    cio_set_digit

    ldb     rh0, #4
    ldb     rl0, #4
    call    cio_set_digit

    ldb     rh0, #5
    ldb     rl0, #5
    call    cio_set_digit

    ldb     rh0, #6
    ldb     rl0, #6
    call    cio_set_digit

    ldb     rh0, #7
    ldb     rl0, #7
    call    cio_set_digit

    ldb     rh0, #8
    ldb     rl0, #8
    call    cio_set_digit

    ei      vi, nvi
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
    call    cio_set

    ldb     rl0, #0b00100010   ! NV, RJA
    outb    #CIO_CMD, rl0      ! we're still pointing at reg0

    ldb     rh0, #CIO_PPB
    ldb     rl0, #0xA5
    call    cio_set
    call    cio_get
    cpb     rl0, #0xA5
    jr      nz, nodetect
    ldb     rl0, #0x5A
    call    cio_set
    call    cio_get
    cpb     rl0, #0x5A
    jr      nz, nodetect
    ldb     rl0, #0x00
    call    cio_set
    clr     r0
    ret
nodetect:
    ld      r0, #1
    ret

!------------------------------------------------------------------------------
! cio_nvi
!  

cio_nvi:
    push	@r15, r0
    push	@r15, r1
    push	@r15, r2    
    push	@r15, r3        
    ldb   rh0, #CIO_PCSA
    call  cio_get
    bitb  rl0, #7               ! check IP bit
    jr    z, cio_nvi_out        ! it's not our fault

    inc   cio_count_b1, #1
    jr    nz, cio_nvi_nowrap
    inc   cio_count_b3, #1
cio_nvi_nowrap:
    call  cio_multiplex_digit

    ldb   rh0, #CIO_PCSA
    ldb   rl0, #0b10100000    ! clear IP
    call  cio_set

    ldb   rh0, #CIO_PCSA
    ldb   rl0, #0b01100000    ! clear IUS
    call  cio_set

cio_nvi_out:
    pop   r3, @r15
    pop   r2, @r15
    pop   r1, @r15
    pop   r0, @r15
    ret


!------------------------------------------------------------------------------

cio_multiplex_digit:
    ld    r1, digindex         ! r1 = digit index (0-8)

    ldb   rl0, digits(r1)
    ldb   rh0, rl1
    orb   rh0, #0xE0           ! set speaker, refresh-enable, and monitor bits

    incb  rh0, #1              ! first digit on display board is at 1, not 0
    outb  #DIGSEL, rh0         ! output digit index
    outb  #DIGVAL, rl0         ! output digit value

    inc   r1, #1
    cp    r1, #9
    jr    lt, cio_multiplex_digit_nowrap
    ld    r1, #0
cio_multiplex_digit_nowrap:
    ld    digindex, r1
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
! cio_set_octal
!
! input:
!   rl0 = value 0-255

cio_set_octal_l:
    push	@r15, r0
    push	@r15, r1

    clr     r1
    ldb     rl1, rl0
    srl     r1, #5
    and     r1, #0x07
    ldb     rl0, digit_7seg(r1)
    ldb     digits_l, rl0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rl0, digit_7seg(r1)
    ldb     digits_l+1, rl0

    clr     r1
    ldb     rl1, rl0
    srl     r1, #3
    and     r1, #0x07
    ldb     rl0, digit_7seg(r1)
    ldb     digits_l+2, rl0

    pop    r1, @r15
    pop    r0, @r15
    ret

!------------------------------------------------------------------------------
! cio_set
!
! input:
!   rh0 = register
!   rl0 = value

cio_set:
    outb   #CIO_CMD, rh0
    outb   #CIO_CMD, rl0
    ret

!------------------------------------------------------------------------------
! cio_get
!
! input:
!   rh0 = register
! output:
!   rl0 = value    

cio_get:
    outb   #CIO_CMD, rh0
    inb    rl0, #CIO_CMD
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
    call   cio_set
    ldb    rh0, #CIO_CTTC1L
    ldb    rl0, rl5
    call   cio_set
    ld     cio_divisor, r5
    ret    

!------------------------------------------------------------------------------
	sect .data

    .even

cio_enable:
    .byte    0

cio_kb_enqueue:
    .byte    0xFF

cio_kb_state:        ! note: these start with row7 and count backwards
    .word    0xFFFF
    .word    0xFFFF
    .word    0xFFFF
    .word    0xFFFF
    .word    0xFFFF

cio_kb_caps:
    .byte    0

cio_kb_code:
    .byte    0

    .even
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
    .word 0
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
	.byte	0b00000001	! 0
	.byte	0b01110011	! 1
	.byte	0b01001000	! 2
	.byte	0b01100000	! 3
	.byte	0b00110010	! 4
	.byte	0b00100100	! 5
	.byte	0b00000100	! 6
	.byte	0b01110001	! 7
	.byte	0b00000000	! 8
	.byte	0b00100000	! 9

ciomsg:
    .asciz  "CIO detected. intializing\r\n"

nociomsg:
    .asciz  "CIO not detected. not intializing\r\n"
