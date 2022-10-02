!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global cio_init, cio_nvi

    .global cio_count_b1, cio_count_b2, cio_count_b3, cio_count_b0, CIO_CTCS1, CIO_CMD

	unsegm
	sect	.text

.equ CIO_C, 0x69
.equ CIO_B, 0x6B
.equ CIO_A, 0x6D
.equ CIO_CMD, 0x6F

.equ CIO_MICR, 0
.equ CIO_MCCR, 1

.equ CIO_PMA, 0x20
.equ CIO_PHA, 0x21
.equ CIO_DPPA, 0x22
.equ CIO_DDA, 0x23
.equ CIO_SIOA, 0x24
.equ CIO_PPA, 0x25
.equ CIO_PTA, 0x26
.equ CIO_PMA, 0x27
.equ CIO_PCSA, 0x08
.equ CIO_PDRA, 0x0D

.equ CIO_PMB, 0x28
.equ CIO_PHB, 0x29
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
    call    cio_detect_and_reset
    jr      z, cio_init_detected
    ldb     cio_enable, #0
    lda     r4, nociomsg
    call    puts
    ret
cio_init_detected:
    lda     r4, ciomsg
    call    puts
    ld      r2, #(ciocmde - ciocmds)    ! initialize Z8536
    ld      r3, #CIO_CMD
    ld      r4, #ciocmds
    otirb   @r3, @r4, r2
    ldb     cio_enable, #1
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
    !outb    #0x50, rl0        ! debug
    cpb     rl0, #0xA5
    jr      nz, nodetect
    ldb     rl0, #0x5A
    call    cio_set
    call    cio_get
    !outb    #0x51, rl0        ! debug
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
    ldb   rh0, #CIO_CTCS1
    call  cio_get
    bitb  rl0, #7
    jr    z, cio_nvi_out        ! it's not our fault

    inc   cio_count_b1, #1
    jr    nz, cio_nvi_nowrap
    inc   cio_count_b3, #1
cio_nvi_nowrap:
    ldb   rl0, cio_count_b3
    outb  #0x50, rl0
    ldb   rl0, cio_count_b2
    outb  #0x51, rl0
    ldb   rl0, cio_count_b1
    outb  #0x52, rl0
    ldb   rl0, cio_count_b0
    outb  #0x53, rl0

    ldb   rh0, #CIO_CTCS1
    ldb   rl0, #0b10100100    ! clear IP
    call  cio_set    

    ldb   rh0, #CIO_CTCS1
    ldb   rl0, #0b01100100    ! clear IUS
    call  cio_set 

cio_nvi_out:
    pop   r0, @r15
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
! cio_fet
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
	sect .data

    .even

cio_enable:
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

!------------------------------------------------------------------------------
    sect .rdata

ciocmds:
    .byte   CIO_DDA, 0b11111111    ! PortA all inputs
    .byte   CIO_DDB, 0b11101111    ! PortB PB4 output, others inputs
    .byte   CIO_DDC, 0b11111111    ! PortC all inputs
    .byte   CIO_CTTC1M, 0xEA       ! CTR1 time constant EA60 divide by 60000 = 60 ticks/second on 6MHz oscillator
    .byte   CIO_CTTC1L, 0x60
    .byte   CIO_CTMS1, 0b11000000  ! not-Continuous, Pulse Mode, External output on PB4
    .byte   CIO_CTCS1, 0b11000000  ! Enable interrupt for CTR1
    .byte   CIO_MCCR,  0b11000000   ! Enable portB and ctr1
    .byte   CIO_CTCS1, 0b11000110  ! Set TCB and Gate to start counter
    .byte   CIO_MICR, 0b10100010   ! MIE, NV, RJA
ciocmde:

ciomsg:
    .asciz  "CIO detected. intializing\r\n"

nociomsg:
    .asciz  "CIO not detected. not intializing\r\n"

scottmsg:
    .asciz  "scott was here\r\n"

