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
    ldb     cio_kb_enqueue, #0xFF
    ldb     cio_kb_caps, #0
    ldb     cio_kb_code, #0
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
    ldb   rh0, #CIO_CTCS1
    call  cio_get
    bitb  rl0, #7
    jr    z, cio_nvi_out        ! it's not our fault

    inc   cio_count_b1, #1
    jr    nz, cio_nvi_nowrap
    inc   cio_count_b3, #1
cio_nvi_nowrap:
    !ldb   rl0, cio_count_b3
    !outb  #0x50, rl0
    !ldb   rl0, cio_count_b2
    !outb  #0x51, rl0
    !ldb   rl0, cio_count_b1
    !outb  #0x52, rl0
    !ldb   rl0, cio_count_b0
    !outb  #0x53, rl0

    call  cio_scan

    ldb   rh0, #CIO_CTCS1
    ldb   rl0, #0b10100100    ! clear IP
    call  cio_set    

    ldb   rh0, #CIO_CTCS1
    ldb   rl0, #0b01100100    ! clear IUS
    call  cio_set 

cio_nvi_out:
    ret

!------------------------------------------------------------------------------
! cio_scan
! 
! notes
!   rl0 = column counter
!   rl1 = row counter
!   r2 = saved data addr
!   rh1 = scanned value (while scanning); delta (while detecting)
!   rh0 = saved value (while scanning); scancode (while detecting)
!   r3 = scancode table
cio_scan:
    .if KBD_MSX==1
    ldb    rl1, #9             ! number of rows to scan    
    .else
    ldb    rl1, #8             ! number of rows to scan
    .endif
    
    lda    r2, cio_kb_state
cio_scan_row:
    decb   rl1, #1             ! make rl1 0-based

    .if KBD_MSX==1
    ldb    rl0, rl1
    testb  cio_kb_caps
    jr     nz, cio_scan_iscaps
    orb    rl0, #0x10         ! turn off caps light
cio_scan_iscaps:
    testb  cio_kb_code
    jr     nz, cio_scan_iscode
    orb    rl0, #0x20         ! turn off code light
cio_scan_iscode:

    .else
    ! For RC2014 mini keypad. Does NOT use a BCD encoder. Needs to output a 0
    ! in whatever row is being scanned.
    clrb   rh1
    clrb   rl0
    setb   rl0, r1             ! rl0 has a 1 in the position we want to test
    comb   rl0                 ! ... and now rl0 has a 0 in that posution
    outb   #CIO_B, rl0    
    .endif

    outb   #CIO_B, rl0
    
    inb    rh1, #CIO_A         ! read the status
    ldb    rh0, @r2
    cpb    rh1, rh0            ! has it changed?
    jr     z, cio_scan_next_row   ! no, go to next row

    ldb    @r2, rh1            ! store the updated byte

    comb   rh0
    orb    rh1, rh0            ! rh1 = (rh1 | ~rh0). rh1 now has zeros only if changed to zero

    ldb    rl0, #8             ! r0 is column counter
cio_scan_col:
    decb   rl0, #1             ! make rl0 0-based
    clrb   rh0
    bitb   rh1, r0
    jr     nz, cio_scan_next_col

    ! we have a winner...
                               ! put the scancode in rh0
    ldb    rh0, rl1            ! ... start with the row
    sllb   rh0, #3             ! ... upper 3 bits are the row
    orb    rh0, rl0            ! ... lower 3 bits are the column

    !outb   #0x50, rh0        ! XXX
    !jr     cio_scan_next_col ! XXX

    bitb     scan_shift_state_byte, #scan_shift_state_bit   ! rc2014 shift is r0, c0
    jr       z, shifted

    bitb     scan_control_state_byte, #scan_control_state_bit      ! rc2014 control is r7, c1
    jr       z, control

unshifted:
    clr     r3
    ldb     rl3, rh0
    ldb     rh0, scan_unshift(r3)
    jr      enqueue

shifted:
    clr     r3
    ldb     rl3, rh0
    ldb     rh0, scan_shift(r3)
    jr      enqueue

control:
    clr     r3
    ldb     rl3, rh0
    ldb     rh0, scan_control(r3)
    jr      enqueue    

enqueue:
    cpb     rh0, #0xFF
    jr      z, cio_scan_next_col

    ldb     cio_kb_enqueue, rh0

cio_scan_next_col:
    incb    rl0, #1           ! make rl0 1-based again
    dbjnz   rl0, cio_scan_col

cio_scan_next_row:
    inc    r2, #1
    incb   rl1, #1            ! make rl1 1-based again
    dbjnz  rl1, cio_scan_row
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

!------------------------------------------------------------------------------
    sect .rdata

ciocmds:
    .byte   CIO_DDA, 0b11111111    ! PortA all inputs
    .byte   CIO_DDB, 0b00000000    ! PortB all outputs
    .byte   CIO_DDC, 0b11111111    ! PortC all inputs
    .byte   CIO_CTTC1M, CIO_DIVISOR >> 8
    .byte   CIO_CTTC1L, CIO_DIVISOR & 0xFF
    .byte   CIO_CTMS1, 0b10000000  ! Continuous, Pulse Mode, no external output
    .byte   CIO_CTCS1, 0b11000000  ! Enable interrupt for CTR1
    .byte   CIO_MCCR,  0b11000100  ! Enable portA, portB, and ctr1
    .byte   CIO_CTCS1, 0b11000110  ! Set TCB and Gate to start counter
    .byte   CIO_MICR, 0b10100010   ! MIE, NV, RJA
ciocmde:

ciomsg:
    .asciz  "CIO detected. intializing\r\n"

nociomsg:
    .asciz  "CIO not detected. not intializing\r\n"

scottmsg:
    .asciz  "scott was here\r\n"
   
    ! scancode to ASCII conversion

.if KBD_MSX==1

.equ  scan_shift_state_byte, cio_kb_state+2    ! MSX shift is r6, c0
.equ  scan_shift_state_bit, 0
.equ  scan_control_state_byte, cio_kb_state+2  ! MSX control is r6, c1
.equ  scan_control_state_bit, 1


scan_shift:
   .byte 0x29,0x21,0x40,0x23,0x24,0x25,0x5E,0x26
   .byte 0x2A,0x28,0x5F,0x2B,0x5C,0x7B,0x7D,0x3A
   .byte 0x22,0x7E,0x2C,0x2E,0x3F,0xFF,0x41,0x42
   .byte 0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A
   .byte 0x4B,0x4C,0x4D,0x4E,0x4F,0x50,0x51,0x52
   .byte 0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A
   .byte 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
   .byte 0xFF,0xFF,0x1B,0x09,0xFF,0x08,0xFF,0x0D
   .byte 0x20,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
scan_unshift:
   .byte 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37
   .byte 0x38,0x39,0x2D,0x3D,0x5C,0x5B,0x5D,0x3B
   .byte 0x27,0x7E,0x2C,0x2E,0x2F,0xFF,0x61,0x62
   .byte 0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A
   .byte 0x6B,0x6C,0x6D,0x6E,0x6F,0x70,0x71,0x72
   .byte 0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A
   .byte 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
   .byte 0xFF,0xFF,0x1B,0x09,0xFF,0x08,0xFF,0x0D
   .byte 0x20,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
scan_control:
   .byte 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37
   .byte 0x38,0x39,0x2D,0x3D,0x5C,0x5B,0x5D,0x3B
   .byte 0x27,0x7E,0x2C,0x2E,0x2F,0xFF,0x01,0x02
   .byte 0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A
   .byte 0x0B,0x0C,0x0D,0x0E,0x0F,0x10,0x11,0x12
   .byte 0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A
   .byte 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
   .byte 0xFF,0xFF,0x1B,0x09,0xFF,0x08,0xFF,0x0D
   .byte 0x20,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF

.else

.equ  scan_shift_state_byte, cio_kb_state+7    ! rc2014 shift is r0, c0
.equ  scan_shift_state_bit, 0
.equ  scan_control_state_byte, cio_kb_state    ! rc2014 control is r7, c1
.equ  scan_control_state_bit, 1

scan_shift:
   .byte 0xFF,0x5A,0x58,0x43,0x56,0xFF,0xFF,0xFF
   .byte 0x41,0x53,0x44,0x46,0x47,0xFF,0xFF,0xFF
   .byte 0x51,0x57,0x45,0x52,0x54,0xFF,0xFF,0xFF
   .byte 0x21,0x40,0x23,0x24,0x25,0xFF,0xFF,0xFF
   .byte 0x29,0x28,0x2A,0x26,0x5E,0xFF,0xFF,0xFF
   .byte 0x50,0x4F,0x49,0x55,0x59,0xFF,0xFF,0xFF
   .byte 0x0D,0x4C,0x4B,0x4A,0x48,0xFF,0xFF,0xFF
   .byte 0x20,0xFF,0x4D,0x4E,0x42,0xFF,0xFF,0xFF
scan_unshift:
   .byte 0xFF,0x7A,0x78,0x63,0x76,0xFF,0xFF,0xFF
   .byte 0x61,0x73,0x64,0x66,0x67,0xFF,0xFF,0xFF
   .byte 0x71,0x77,0x65,0x72,0x74,0xFF,0xFF,0xFF
   .byte 0x31,0x32,0x33,0x34,0x35,0xFF,0xFF,0xFF
   .byte 0x30,0x39,0x38,0x37,0x36,0xFF,0xFF,0xFF
   .byte 0x70,0x6F,0x69,0x75,0x79,0xFF,0xFF,0xFF
   .byte 0x0D,0x6C,0x6B,0x6A,0x68,0xFF,0xFF,0xFF
   .byte 0x20,0xFF,0x6D,0x6E,0x62,0xFF,0xFF,0xFF
scan_control:
   .byte 0xFF,0x3A,0x45,0x03,0x2F,0xFF,0xFF,0xFF
   .byte 0x5F,0x7C,0x5C,0x7B,0x7D,0xFF,0xFF,0xFF
   .byte 0x3C,0x3D,0x3E,0x3C,0x3E,0xFF,0xFF,0xFF
   .byte 0x21,0x40,0x23,0x24,0x25,0xFF,0xFF,0xFF
   .byte 0x5F,0x29,0x28,0x27,0x26,0xFF,0xFF,0xFF
   .byte 0x22,0x3B,0x23,0x5D,0x5B,0xFF,0xFF,0xFF
   .byte 0x0D,0x3D,0x2B,0x2D,0x08,0xFF,0xFF,0xFF
   .byte 0x20,0xFF,0x2E,0x2C,0x2A,0xFF,0xFF,0xFF

.endif
