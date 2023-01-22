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

	unsegm
	sect	.text

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

    call    h8_display_init

    ei      vi, nvi
    ret

!------------------------------------------------------------------------------
! cio_reset

cio_reset:
    inb     rl0, #CIO_CMD      ! reset the CMD etate machine
    ldb     rh0, #CIO_MICR
    ldb     rl0, #1            ! reset CIO
    CIO_SET
    ldb     rl0, #0b00100010   ! NV, RJA
    outb    #CIO_CMD, rl0      ! we're still pointing at MICRO
    ret

!------------------------------------------------------------------------------
! cio_detect
!
! output:
!   rl0 = 0 if detected, 1 if not detected

cio_detect_and_reset:
    call    cio_reset

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
    bitb  rl0, #5              ! check IP bit for port A
    jr    z, cio_nvi_notpcsa

    inb   rl0, #CIO_A          ! read port A to get interrupt status
    bitb  rl0, #0              ! check int1
    jr    nz, cio_nvi_notint1
    call  h8_display_hook      ! int1 - refresh display (note: if never called, will never clear interrupt)
cio_nvi_notint1:

    ldb   rh0, #CIO_PCSA
    ldb   rl0, #0b10100000    ! clear portA IP
    CIO_SET
    ldb   rl0, #0b01100000    ! clear portA IUS
    CIO_SET

cio_nvi_notpcsa:
    ldb   rh0, #CIO_CTCS1     ! check IP bit for timer1
    CIO_GET
    bitb  rl0, #5
    jr    z, cio_nvi_notctcs1

    call  cio_timer_hook

    ldb   rh0, #CIO_CTCS1
    ldb   rl0, #0b10100100    ! clear timer1 IP
    CIO_SET
    ldb   rl0, #0b01100100    ! clear timer1 IUS
    CIO_SET

cio_nvi_notctcs1:
    ret

!------------------------------------------------------------------------------
! cio_timer_hook

cio_timer_hook:
    ldl   rr0, cio_count        ! increment the cycle counter
    addl  rr0, #1
    ldl   cio_count, rr0
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

!------------------------------------------------------------------------------
    sect .rdata

ciocmds:
                                           ! Configure Port A as an interrupt controller
    .byte   CIO_DDA,    0b01111111         ! PortA D7 outputs, D0..D6 inputs
    .byte   CIO_DDB,    0b11111111         ! PortB all inputs
    .byte   CIO_DDC,    0b11111111         ! PortC all inputs
    .byte   CIO_PMA,    0b01111111         ! PortA Pattern mask enable D0..D6 
    .byte   CIO_PTA,    0b00000000         ! PortA Pattern transition set to no transition
    .byte   CIO_PPA,    0b00000000         ! PortA Pattern polarity register set to all zero
    .byte   CIO_PMSA,   0b00000110         ! 00=bitport, 0=no_itb, 0=no_singlebuffer, 0=no_imo, 11=or-priority-mode, 0=no_lpm
    .byte   CIO_PCSA,   0b11000000         ! PortA enable interrupts, disable interrupt-on-error

                                           ! Configure Timer 1 as 20 ticks per second
    .byte   CIO_CTTC1M, CIO_DIVISOR >> 8   ! divisor high byte
    .byte   CIO_CTTC1L, CIO_DIVISOR & 0xFF ! divisor low byte
    .byte   CIO_CTMS1,  0b10000000         ! Continuous, Pulse Mode, no external output
    .byte   CIO_CTCS1,  0b11000000         ! Enable interrupt for CTR1

    .byte   CIO_MCCR,   0b11000100         ! Enable portA, portB, and ctr1
    .byte   CIO_CTCS1,  0b11000110         ! Set TCB and Gate to start counter. Must be after enable
    .byte   CIO_MICR,   0b10100010         ! MIE, NV, RJA

    .byte   CIO_A,      0b00000000         ! set PortA h8 ie bit
ciocmde:

ciomsg:
    .asciz  "CIO detected. intializing\r\n"

nociomsg:
    .asciz  "CIO not detected. not intializing\r\n"


