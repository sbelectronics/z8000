!------------------------------------------------------------------------------
! tms9918.s
!   TMS9918 video driver
!   Based on RomWBW TMS driver by Douglas Goodall and Wayne Warthen
!
!   Supports for the TMS9918 and the Yamaha V9958. Note that the boards
!   themselves are much different though the registers of the 9918 are
!   pretty much a subset of the 9958.
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .global tty_init
    .global tty_dochar_rl5
    .global tms_setcolor

	unsegm
	sect	.text

.equ TMS_DATA, 0x61
.equ TMS_CMD, 0x63
.equ TMS_ACR, 0x65

.equ V9958_ROWS, 24
.equ V9958_COLS, 80
.equ V9958_FONTADDR, 0x1000

.equ TMS9918_ROWS, 24
.equ TMS9918_COLS, 40
.equ TMS9918_FONTADDR, 0x800

.macro TMS_IODELAY
   NOP
   NOP
   NOP
   NOP
   NOP
   NOP
   NOP
   NOP
   NOP
.endm
    

!------------------------------------------------------------------------------
! tms_init

tms_init:
    ld       tms_pos, #0
    ldb      tms_cursav, #0
    call     tms_crtinit
    call     tms_loadfont
    call     tms_vdares
    clr      r0
    ret

!------------------------------------------------------------------------------
! tms_vdaini

tms_vdaini:
    call     tms_vdares
    clr      r0
    ret

!------------------------------------------------------------------------------
! tms_vdaqry
! output:
!   r1, mode
!   rl2, rows
!   rh2, columns

tms_vdaqry:
    ld       r1, #0x00
    ldb      rl2, tms_rowsb
    ldb      rh2, tms_colsb
    clr      r0
    ret

!------------------------------------------------------------------------------
! tms_vdares

tms_vdares:
    clr      r1                        ! row=0, col=0
    call     tms_xy
    ldb      rl1, #0x20                ! space
    ld       r2, tms_rowsTimesCols     ! whole screen
    call     tms_fill
    clr      r1
    call     tms_xy                    ! move to r0, c0
    ldb      tms_cursav, #0xFF
    call     tms_setcur
    clr      r0
    ret

!------------------------------------------------------------------------------
! tms_vdascp - set cursor position
! input:
!    r1 = position

tms_vdascp:
   call     tms_clrcur
   call     tms_xy
   call     tms_setcur
   clr      r0
   ret

!------------------------------------------------------------------------------
! tms_vdawrc
! input:
!   rl1 = character

tms_vdawrc:
    call    tms_clrcur
    call    tms_putchar
    call    tms_setcur
    clr     r0
    ret

!------------------------------------------------------------------------------
! tms_vdafil
! input:
!    rl1, fill character
!    r2, count

tms_vdafil:
    call    tms_clrcur
    call    tms_fill
    call    tms_setcur
    clr     r0
    ret

!------------------------------------------------------------------------------
! tms_vdacpy

!tms_vdacpy:
!    call    tms_clrcur
!    call    tms_xy2idx        ! r0 = address
!    ld      r1, tms_pos
!    call    tms_blkcpy
!    call    tms_setcur
!    clr     r0
!    ret

!------------------------------------------------------------------------------
! tms_vdascr

tms_vdascr:
    call    tms_clrcur
    call    tms_scroll
    call    tms_setcur
    clr     r0
    ret

!------------------------------------------------------------------------------
! tms_set
! input:
!    rl1 - value
!    rh1 - register
! destroy:
!    rl0

tms_set:
    outb   #TMS_CMD, rl1
    TMS_IODELAY
    ldb    rl0, rh1
    orb    rl0, #0x80
    outb   #TMS_CMD, rl0
    TMS_IODELAY
    ret

!------------------------------------------------------------------------------
! tms_setcolor
! input:
!    rl5 = value
! destroy:
!    r1, r0

tms_setcolor:
    ldb    rh1, #0x07
    ldb    rl1, rl5
    jp     tms_set

    ldb    rh1, #0x08
    ldb    rl1, #0x80
    call   tms_set

    ldb    rh1, #0x09
    ldb    rl1, #0x00
    call   tms_set

    ldb    rh1, #0x0A
    ldb    rl1, #0x00
    call   tms_set

    ret

!------------------------------------------------------------------------------
! tms_wr
! input:
!    r1  - address

tms_wr:
    push	@r15, r1

    .if VIDEO_V9958 == 1
    ! CLEAR R#14 FOR V9958
    clrb    rl1
    outb    #TMS_CMD, rl1
    ldb     rl1, #0x8E
    outb    #TMS_CMD, rl1
    TMS_IODELAY
    ! restore r1 and then save it again
    pop     r1, @r15
    push	@r15, r1
    .endif

    or      r1, #0x4000    ! set write bit, bit 14
    call    tms_rd
    pop     r1, @r15
    ret

!------------------------------------------------------------------------------
! tms_rd
! input:
!    r1  - address

tms_rd:
    outb    #TMS_CMD, rl1
    TMS_IODELAY
    outb    #TMS_CMD, rh1
    TMS_IODELAY
    ret

!------------------------------------------------------------------------------
! tms_probe
! output:
!   r0 = 0 if detected, 1 if not detected
!   r1 = 0 if tms9918, 1 if V9938/V9958
! destroys:
!   r0
!   r1

tms_probe:
    clr     r1
    call    tms_wr
    ldb     rl0, #0xA5
    outb    #TMS_DATA, rl0
    TMS_IODELAY
    xorb    rl0, #0xFF            ! invert all bits in rl0
    outb    #TMS_DATA, rl0
    TMS_IODELAY

    clr     r1
    call    tms_rd
    inb     rl0, #TMS_DATA
    TMS_IODELAY
    cpb     rl0, #0xA5
    jr      nz, probe_nogood
    inb     rl0, #TMS_DATA
    TMS_IODELAY
    xorb    rl0, #0xFF
    cpb     rl0, #0xA5
    jr      nz, probe_nogood

    ! V9958 autodetect. We do this by reading status register 1. The
    ! TMS9918 only has a singe status register (0). Presumably if we
    ! try this on the 9918, then we'll end up reading 0 instead of 1,
    ! and we won't get the V9958 ident code. Experimentation seems to
    ! confirm this works as expected.

    ld      r1, #0x0F01        ! register 0x0F, value 0x01
    call    tms_set            ! set status register pointer to 1

    inb     rl0, #TMS_CMD      ! read the status into rl0 
    TMS_IODELAY

    srlb    rl0, #1            ! bits 1..5 are the identification
    andb    rl0, #0x1F         !  0 = V9938, 2 = V9958, (unconfirmed) 8 = tms9918

    cpb     rl0, #0x02
    jr      z, probe_V9958

    ld      r1, #0x0F00        ! register 0X0F, value 0x00
    call    tms_set            ! reset status register point to 0
    clr     r1
    jr      probe_good
probe_V9958:
    ld      r1, #0x0F00        ! register 0X0F, value 0x00
    call    tms_set            ! reset status register point to 0
    ld      r1, #1

probe_good:
    clr     r0
    ret
probe_nogood:
    ld      r0, #1
    ret

!------------------------------------------------------------------------------
! tms_crtinit
! destroys:
!    r0
!    r1
!    r2
!    r3

tms_crtinit:
    clr     r1
    call    tms_wr
    ld      r1, #0x4000
tms_crtinit1:
    clrb    rl0
    outb    #TMS_DATA, rl0
    TMS_IODELAY
    djnz    r1, tms_crtinit1

    ldb     rh1, #0                     ! start at register 0
    ld      r2, tms_initLen             ! number of regs to write
    ld      r3, tms_initAddr            ! register data to write
tms_crtinit2:
    ldb     rl1, @r3                    ! load reg data
    call    tms_set
    inc     r3, #1                      ! increment pointer
    incb    rh1, #1                     ! increment register number
    djnz    r2, tms_crtinit2
    ret

!------------------------------------------------------------------------------
! tms_loadfont
! destroys:
!    r0
!    r1
!    r2
!    r3

tms_loadfont:
    ld      r1, tms_fontAddr
    call    tms_wr

    ld      r2, tms_fontAddr
    lda     r3, tms_font
tms_loadfont1:
    ldb     rl0, @r3
    outb    #TMS_DATA, rl0
    TMS_IODELAY
    inc     r3, #1
    djnz    r2, tms_loadfont1
    ret

!------------------------------------------------------------------------------
! tms_setcur
!
! works by using character 255 to hold an inverted copy of the character at the
! current cursor position. We read the current char, then we read its font and
! invert it, and update the font for char 255.
!
! destroys:
!   r0

tms_setcur:
    push 	@r15, r1
    push    @r15, r2
    push    @r15, r3
    ld      r1, tms_pos
    call    tms_rd
    inb     rl0, #TMS_DATA            ! rl0 = character under cursor
    TMS_IODELAY
    call    tms_wr
    ldb     rh0, #0xFF
    outb    #TMS_DATA, rh0            ! write 0xFF to the cursor
    TMS_IODELAY
    cpb     rl0, tms_cursav           ! have we already setup the font
    jr      z, tms_setcur3
    ldb     tms_cursav, rl0

    clrb    rh0                       ! rh0:rl0 = character index
    sll     r0, #3                    ! multiply by 8
    ld      r1, tms_fontAddr          ! offset to start of font table
    add     r1, r0                    ! add glyph index
    call    tms_rd
    ld      r2, #8
    lda     r3, tms_buf               ! read 8 bytes into buffer
tms_setcur1:
    inb     rl0, #TMS_DATA
    TMS_IODELAY
    ldb     @r3, rl0
    inc     r3, #1
    djnz    r2, tms_setcur1

    ld      r1, tms_fontAddr
    add     r1, #(255*8)              ! offset of font for char 255
    call    tms_wr
    ld      r2, #8
    lda     r3, tms_buf
tms_setcur2:
    ldb     rl0, @r3
    inc     r3, #1
    xorb    rl0, #0xFF
    outb    #TMS_DATA, rl0
    TMS_IODELAY
    djnz    r2, tms_setcur2

tms_setcur3:
    pop 	r3, @r15
    pop 	r2, @r15
    pop 	r1, @r15
    ret

!------------------------------------------------------------------------------
! tms_clrcur
!
! Restores that which tms_setcur did
!
! destroys:
!   r0

tms_clrcur:
    push 	@r15, r1
    ld      r1, tms_pos
    call    tms_wr
    ldb     rl0, tms_cursav
    outb    #TMS_DATA, rl0
    TMS_IODELAY
    pop 	r1, @r15   
    ret

!------------------------------------------------------------------------------
! tms_xy
!
! input:
!   rl1 = row
!   rh1 = column

tms_xy:
    call    tms_xy2idx        ! r0 = address
    ld      tms_pos, r0
    ret

!------------------------------------------------------------------------------
! tms_xy2idx
!
! input:
!    rl1 = row
!    rh1 = column
! out:
!    r0 = offset

tms_xy2idx:
     pushl 	@r15, rr2         ! save r2 and r3
     clr    r2
     clr    r3
     ldb    rl3, rl1          ! rr2 = row
     mult   rr2, tms_colsw    ! XXX multiple by cols per row, r2:r3 has our result
     clr    r0
     ldb    rl0, rh1          ! r0 = col
     add    r3, r0            ! r3 = row*TMS_COLS+col
     ld     r0, r3
     popl   rr2, @r15
     ret

!------------------------------------------------------------------------------
! tms_putchar
!
! input:
!    rl1 = character

tms_putchar:
    push 	@r15, r1
    ld      r1, tms_pos
    call    tms_wr
    pop     r1, @r15
    outb    #TMS_DATA, rl1
    inc     tms_pos, #1
    ret

!------------------------------------------------------------------------------
! tms_fill
!
! input:
!    rl1 = character
!    r2 = count
! destroys:
!    r2

tms_fill:
     ex      r3, r1    ! rl3 = character
     ld      r1, tms_pos
     call    tms_wr
tms_fill1:
     outb    #TMS_DATA, rl3
     TMS_IODELAY
     djnz    r2, tms_fill1
     ex      r3, r1    ! restory r3 and r1
     ret

!------------------------------------------------------------------------------
! tms_scroll
!
! destroys:
!    r0
!    r1
!    r2
!    r3
!    r4

tms_scroll:
     clr     r1                ! r1 will hold the row pointer
     ld      r2, tms_rowsw     ! r2 counts the number of rows left to do
     decb    rl2, #1
tms_scroll0:
     add     r1, tms_colsw     ! point to next row source
     call    tms_rd
     sub     r1, tms_colsw     ! point back to destination row
     lda     r3, tms_buf       ! r3 is buffer address
     ldb     rh0, tms_colsb    ! rh0 is column counter
tms_scroll1:
     inb     rl0, #TMS_DATA    ! read byte from row n+1 into the buffer
     TMS_IODELAY
     ldb     @r3, rl0
     inc     r3, #1
     dbjnz   rh0, tms_scroll1

     call    tms_wr            ! r1 still has destination row addr
     lda     r3, tms_buf       ! r3 is buffer address
     ldb     rh0, tms_colsb    ! rh0 is column counter
tms_scroll2:                    
     ldb     rl0, @r3          ! read byte from buffer
     outb    #TMS_DATA, rl0    ! write byte from buffer to row n
     TMS_IODELAY
     inc     r3, #1
     dbjnz   rh0, tms_scroll2

     add     r1, tms_colsw     ! go to next row
     djnz    r2, tms_scroll0

                               ! r1 is now pointing to bottom row
     call    tms_wr            ! write a row of blanks
     ldb     rl0, #0x20        ! blank character
     ldb     rh0, tms_colsb
tms_scroll3:
     outb    #TMS_DATA, rl0
     TMS_IODELAY
     dbjnz   rh0, tms_scroll3
     
     ret

!------------------------------------------------------------------------------
! tty_init

tty_init:
    ldb     tty_enable, #0
    call    tms_probe
    test    r0
    jr      nz, no_tms

    test    r1
    jr      nz, tty_init_V9958
    ld      tms_initLen, #tms_init9918len         ! Load up settings that will be for 40x24
    ld      tms_initAddr, #tms_init9918           ! mode on the 9918.
    ld      tms_fontAddr, #TMS9918_FONTADDR
    ldb     tms_rowsb, #TMS9918_ROWS
    ldb     tms_colsb, #TMS9918_COLS
    ld      tms_rowsTimesCols, #(TMS9918_ROWS*TMS9918_COLS)
    lda     r4, tmsmsg
    call    puts
    jr      tty_init_0
tty_init_V9958:
    ld      tms_initLen, #tms_init9958len         ! Load up settings that will be for 80x24
    ld      tms_initAddr, #tms_init9958           ! mode on the 9958.
    ld      tms_fontAddr, #V9958_FONTADDR
    ldb     tms_rowsb, #V9958_ROWS
    ldb     tms_colsb, #V9958_COLS
    ld      tms_rowsTimesCols, #(V9958_ROWS*V9958_COLS)
    lda     r4, V9958msg
    call    puts

tty_init_0:
    call    tty_reset
    call    tms_init
    ldb     tty_enable, #1

    !jp      tms_test

    ret
no_tms:
    lda     r4, notmsmsg
    call    puts
    ret

!------------------------------------------------------------------------------
! tms_test

tms_test:
    # row 0, columns 0 and 1
    ld      r1, #0x0
    call    tms_vdascp
    ldb     rl1, #0x41
    call    tms_putchar
    ld      r1, #0x0100
    call    tms_vdascp
    ldb     rl1, #0x42
    call    tms_putchar

    ! row 1, columns 2 and 3
    ld      r1, #0x0201
    call    tms_vdascp
    ldb     rl1, #0x43
    call    tms_putchar
    ld      r1, #0x0301
    call    tms_vdascp
    ldb     rl1, #0x44
    call    tms_putchar

    ! row 2, columns 4 and 5
    ld      r1, #0x0402
    call    tms_vdascp
    ldb     rl1, #0x45
    call    tms_putchar
    ld      r1, #0x0502
    call    tms_vdascp
    ldb     rl1, #0x46
    call    tms_putchar     

    ! row 3, columns 6 and 7
    ld      r1, #0x0603
    call    tms_vdascp
    ldb     rl1, #0x47
    call    tms_putchar
    ld      r1, #0x0703
    call    tms_vdascp
    ldb     rl1, #0x48
    call    tms_putchar    

    ! row 4, columns 8 and 9
    ld      r1, #0x0804
    call    tms_vdascp
    ldb     rl1, #0x49
    call    tms_putchar
    ld      r1, #0x0904
    call    tms_vdascp
    ldb     rl1, #0x4A
    call    tms_putchar

    ! now try a scroll -- we should lose AB line
    call    tms_vdascr

stuck: jr   stuck    

!------------------------------------------------------------------------------
! tty_reset

tty_reset:
    ld      tty_pos, #0
    ret

!------------------------------------------------------------------------------
! tty_dochar
!
! input:
!   rl1 - character
! destroys:
!   r1

tty_dochar:
    test   tty_enable
    jr     nz, have_tty
    ret
have_tty:
    cpb    rl1, #0x08
    jr     z, tty_bs
    cpb    rl1, #0x0C
    jr     z, tty_ff
    cpb    rl1, #0x0D
    jr     z, tty_cr
    cpb    rl1, #0x0A
    jr     z, tty_lf
    cpb    rl1, #0x20     ! some other control character
    jr     ge, not_other_ctl
    ret
not_other_ctl:
    call   tms_vdawrc
    incb   tty_col, #1
    ldb    rh1, tms_colsb
    cpb    rh1, tty_col
    jr     le, past_eol
    ret
past_eol:
    call   tty_cr
    jp     tty_lf

tty_ff:
    ld     tty_pos, #0
    call   tty_xy
    ldb    rl1, #0x20
    ld     r2, tms_rowsTimesCols
    call   tms_vdafil
    jp     tty_xy

tty_bs:
    testb  tty_col
    jr     nz, not_col_zero
    ret
not_col_zero:
    decb   tty_col, #1
    jp     tty_xy

tty_cr:
    ldb    tty_col, #0
    jp     tty_xy

tty_lf:
    ldb    rh1, tms_rowsb
    decb   rh1, #1
    cpb    rh1, tty_row
    jr     le, tty_lf1
    incb   tty_row, #1
    jp     tty_xy
tty_lf1:
    jp     tms_vdascr

tty_xy:
    ld     r1, tty_pos
    jp     tms_vdascp

!------------------------------------------------------------------------------
! tty_dochar_rl5
!
! Intended to be called from scc_out, to print everything that goes out the serial
! port also to the video display.
!
! input:
!   rl5 - character

tty_dochar_rl5:
    pushl  @r15, rr0
    pushl  @r15, rr2
    ldb    rl1, rl5
    call   tty_dochar
    popl   rr2, @r15
    popl   rr0, @r15
    ret

!------------------------------------------------------------------------------
	sect .bss
	.even

tms_pos:
    .word    0
tms_cursav:
    .byte    0
tms_buf:
    .space  256

!------------------------------------------------------------------------------

    sect .data
    .even

tms_initLen:
    .word    0
tms_initAddr:
    .word    0
tms_fontAddr:
    .word    0
tms_rowsTimesCols:
    .word    0
tms_rowsw:
    .byte    0
tms_rowsb:
    .byte    0
tms_colsw:
    .byte    0
tms_colsb:
    .byte    0

tty_pos:
tty_col:
    .byte    0
tty_row:
    .byte    0
tty_enable:
    .byte    0

!------------------------------------------------------------------------------
	sect	.rodata

.equ tms_init9958len, 11
tms_init9958:
	.byte	0x04		! REG 0 - NO EXTERNAL VID
	.byte	0x50		! REG 1 - ENABLE SCREEN, SET MODE 1
	.byte	0x03		! REG 2 - PATTERN NAME TABLE := 0
	.byte	0x00		! REG 3 - NO COLOR TABLE
	.byte	0x02		! REG 4 - SET PATTERN GENERATOR TABLE TO $800
	.byte	0x00		! REG 5 - SPRITE ATTRIBUTE IRRELEVANT
	.byte	0x00		! REG 6 - NO SPRITE GENERATOR TABLE
	.byte	0xF4		! REG 7 - WHITE ON GREEN
    .byte   0x80        ! REG 8 - COLOUR BUS INPUT, DRAM 16K
    .byte   0x00        ! REG 9
    .byte   0x00        ! REG 10 - COLOUR TABLE A14-A16 (TMS_FNTVADDR - $1000)

.equ tms_init9918len, 8
tms_init9918:
	.byte	0x00		! REG 0 - NO EXTERNAL VID
	.byte	0x50		! REG 1 - ENABLE SCREEN, SET MODE 1
	.byte	0x00		! REG 2 - PATTERN NAME TABLE := 0
	.byte	0x00		! REG 3 - NO COLOR TABLE
	.byte	0x01		! REG 4 - SET PATTERN GENERATOR TABLE TO $800
	.byte	0x00		! REG 5 - SPRITE ATTRIBUTE IRRELEVANT
	.byte	0x00		! REG 6 - NO SPRITE GENERATOR TABLE
	.byte	0xF4		! REG 7 - WHITE ON GREEN

      ! F0 = white on black
      ! F2 = white on green
      ! F4 = white on blue
      ! F6 = white on brown
      ! F8 = white on red
      ! FA = white on yellow-green?
      ! FC = white on dkgreen?
      ! FE = white on dkgreen?

tmsmsg:
    .asciz  "TMS9918 detected. intializing\r\n"
V9958msg:
    .asciz  "V9958 detected. intializing\r\n"

notmsmsg:
    .asciz  "TMS9918 or V9958 not detected. not intializing\r\n"    

tms_font:
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3C, 0x3C, 0x30, 0x30, 0x30
 .byte 0x00, 0x00, 0x00, 0xF0, 0xF0, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x3C, 0x00, 0x00, 0x00
 .byte 0x30, 0x30, 0x30, 0xF0, 0xF0, 0x00, 0x00, 0x00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30
 .byte 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x20, 0x70, 0xF8, 0x70, 0x20, 0x00, 0x00
 .byte 0xF8, 0xD8, 0x88, 0x00, 0x88, 0xD8, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x20, 0x60, 0x90, 0x60, 0x00, 0x00
 .byte 0x20, 0x50, 0x20, 0x20, 0x70, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 0x50, 0x50, 0xD8, 0x50, 0x50, 0xA8, 0x00
 .byte 0x30, 0x30, 0x30, 0xFC, 0xFC, 0x30, 0x30, 0x30, 0x10, 0x30, 0x70, 0xF0, 0x70, 0x30, 0x10, 0x00
 .byte 0x20, 0x70, 0x20, 0x20, 0x20, 0x70, 0x20, 0x00, 0x50, 0x50, 0x50, 0x50, 0x00, 0x50, 0x00, 0x00
 .byte 0x78, 0xA8, 0xA8, 0x68, 0x28, 0x28, 0x00, 0x00, 0x30, 0x30, 0x30, 0xFC, 0xFC, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0xFC, 0xFC, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0xF0, 0xF0, 0x30, 0x30, 0x30
 .byte 0x20, 0x70, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x30, 0x30, 0x30, 0x3C, 0x3C, 0x30, 0x30, 0x30
 .byte 0x00, 0x10, 0x18, 0xFC, 0x18, 0x10, 0x00, 0x00, 0x00, 0x20, 0x60, 0xFC, 0x60, 0x20, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x78, 0x78, 0x30, 0x00, 0x30, 0x00, 0x00
 .byte 0xD8, 0xD8, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x48, 0x48, 0xFC, 0x48, 0x48, 0xFC, 0x48, 0x48
 .byte 0x20, 0x78, 0xA0, 0x78, 0x24, 0xF8, 0x20, 0x00, 0x00, 0xC8, 0xD0, 0x20, 0x58, 0x98, 0x00, 0x00
 .byte 0x30, 0x48, 0x48, 0x50, 0x60, 0x90, 0x78, 0x00, 0x30, 0x30, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x10, 0x20, 0x20, 0x20, 0x20, 0x20, 0x10, 0x00, 0x20, 0x10, 0x10, 0x10, 0x10, 0x10, 0x20, 0x00
 .byte 0x20, 0xA8, 0x70, 0xF8, 0x70, 0xA8, 0x20, 0x00, 0x00, 0x20, 0x20, 0xF8, 0x20, 0x20, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x40, 0x00, 0x00, 0x00, 0x70, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x00, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x00, 0x00
 .byte 0x70, 0x98, 0xA8, 0xA8, 0xA8, 0xC8, 0x70, 0x00, 0x20, 0x60, 0x20, 0x20, 0x20, 0x20, 0xF8, 0x00
 .byte 0x70, 0x88, 0x08, 0x10, 0x60, 0x80, 0xF8, 0x00, 0x70, 0x88, 0x08, 0x70, 0x08, 0x88, 0x70, 0x00
 .byte 0x30, 0x50, 0x90, 0xF8, 0x10, 0x10, 0x10, 0x00, 0xF8, 0x80, 0x80, 0xF0, 0x08, 0x88, 0x70, 0x00
 .byte 0x38, 0x40, 0x80, 0xF0, 0x88, 0x88, 0x70, 0x00, 0xF8, 0x08, 0x10, 0x20, 0x20, 0x20, 0x20, 0x00
 .byte 0x70, 0x88, 0x88, 0x70, 0x88, 0x88, 0x70, 0x00, 0x70, 0x88, 0x88, 0x78, 0x08, 0x88, 0x70, 0x00
 .byte 0x00, 0x30, 0x30, 0x00, 0x30, 0x30, 0x00, 0x00, 0x00, 0x30, 0x30, 0x00, 0x30, 0x30, 0x60, 0x00
 .byte 0x10, 0x20, 0x40, 0x80, 0x40, 0x20, 0x10, 0x00, 0x00, 0x00, 0xFC, 0x00, 0xFC, 0x00, 0x00, 0x00
 .byte 0x40, 0x20, 0x10, 0x08, 0x10, 0x20, 0x40, 0x00, 0x70, 0x88, 0x08, 0x30, 0x20, 0x00, 0x20, 0x00
 .byte 0x70, 0x88, 0xB8, 0xB0, 0x80, 0x80, 0x70, 0x00, 0x20, 0x50, 0x88, 0xF8, 0x88, 0x88, 0x88, 0x00
 .byte 0xF0, 0x48, 0x48, 0x70, 0x48, 0x48, 0xF0, 0x00, 0x70, 0x88, 0x80, 0x80, 0x80, 0x88, 0x70, 0x00
 .byte 0xF0, 0x48, 0x48, 0x48, 0x48, 0x48, 0xF0, 0x00, 0xF8, 0x88, 0x80, 0xE0, 0x80, 0x88, 0xF8, 0x00
 .byte 0xF8, 0x88, 0x80, 0xF0, 0x80, 0x80, 0x80, 0x00, 0x70, 0x88, 0x80, 0xB8, 0x88, 0x88, 0x70, 0x00
 .byte 0x88, 0x88, 0x88, 0xF8, 0x88, 0x88, 0x88, 0x00, 0xF8, 0x20, 0x20, 0x20, 0x20, 0x20, 0xF8, 0x00
 .byte 0x1C, 0x08, 0x08, 0x08, 0x08, 0x88, 0x70, 0x00, 0x88, 0x90, 0xA0, 0xC0, 0xA0, 0x90, 0x88, 0x00
 .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x88, 0xF8, 0x00, 0x88, 0xD8, 0xA8, 0x88, 0x88, 0x88, 0x88, 0x00
 .byte 0x88, 0xC8, 0xA8, 0xA8, 0xA8, 0x98, 0x88, 0x00, 0x70, 0x88, 0x88, 0x88, 0x88, 0x88, 0x70, 0x00
 .byte 0xF0, 0x88, 0x88, 0xF0, 0x80, 0x80, 0x80, 0x00, 0x70, 0x88, 0x88, 0x88, 0xA8, 0x98, 0x78, 0x04
 .byte 0xF0, 0x88, 0x88, 0xF0, 0xA0, 0x90, 0x88, 0x00, 0x70, 0x88, 0x40, 0x20, 0x10, 0x88, 0x70, 0x00
 .byte 0xF8, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x70, 0x00
 .byte 0x88, 0x88, 0x88, 0x50, 0x50, 0x50, 0x20, 0x00, 0x88, 0x88, 0x88, 0xA8, 0xA8, 0xA8, 0x50, 0x00
 .byte 0x88, 0x88, 0x50, 0x20, 0x50, 0x88, 0x88, 0x00, 0x88, 0x88, 0x50, 0x20, 0x20, 0x20, 0x20, 0x00
 .byte 0xF8, 0x88, 0x10, 0x20, 0x40, 0x88, 0xF8, 0x00, 0x78, 0x40, 0x40, 0x40, 0x40, 0x40, 0x78, 0x00
 .byte 0x00, 0x80, 0x40, 0x20, 0x10, 0x08, 0x00, 0x00, 0x78, 0x08, 0x08, 0x08, 0x08, 0x08, 0x78, 0x00
 .byte 0x20, 0x50, 0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x00
 .byte 0x60, 0x60, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x08, 0x78, 0x88, 0x70, 0x00
 .byte 0x80, 0x80, 0x80, 0xF0, 0x88, 0x88, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x70, 0x80, 0x80, 0x70, 0x00
 .byte 0x08, 0x08, 0x08, 0x78, 0x88, 0x88, 0x78, 0x00, 0x00, 0x00, 0x70, 0x88, 0xF8, 0x80, 0x70, 0x00
 .byte 0x00, 0x30, 0x48, 0xE0, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x38, 0x48, 0x48, 0x38, 0x08, 0x70
 .byte 0x00, 0x80, 0x80, 0xB0, 0xC8, 0x88, 0x88, 0x00, 0x00, 0x00, 0x20, 0x00, 0x60, 0x20, 0x70, 0x00
 .byte 0x00, 0x08, 0x00, 0x18, 0x08, 0x08, 0x48, 0x30, 0x80, 0x80, 0x90, 0xA0, 0xC0, 0xA0, 0x90, 0x00
 .byte 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x50, 0xA8, 0xA8, 0x88, 0x00
 .byte 0x00, 0x00, 0x00, 0xB0, 0xC8, 0x88, 0x88, 0x00, 0x00, 0x00, 0x00, 0x70, 0x88, 0x88, 0x70, 0x00
 .byte 0x00, 0x00, 0x70, 0x48, 0x48, 0x70, 0x40, 0x40, 0x00, 0x60, 0x38, 0x48, 0x48, 0x38, 0x08, 0x08
 .byte 0x00, 0x00, 0x00, 0xB0, 0xC8, 0x80, 0x80, 0x00, 0x00, 0x00, 0x60, 0x80, 0x60, 0x10, 0x60, 0x00
 .byte 0x00, 0x00, 0x40, 0xE0, 0x40, 0x40, 0x20, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x68, 0x00
 .byte 0x00, 0x00, 0x00, 0x88, 0x88, 0x50, 0x20, 0x00, 0x00, 0x00, 0x00, 0x88, 0xA8, 0xA8, 0x50, 0x00
 .byte 0x00, 0x00, 0x00, 0x48, 0x30, 0x30, 0x48, 0x00, 0x00, 0x00, 0x88, 0x50, 0x20, 0x40, 0x80, 0x00
 .byte 0x00, 0x00, 0xF8, 0x10, 0x20, 0x40, 0xF8, 0x00, 0x10, 0x20, 0x20, 0x40, 0x20, 0x20, 0x10, 0x00
 .byte 0x20, 0x20, 0x20, 0x00, 0x20, 0x20, 0x20, 0x00, 0x40, 0x20, 0x20, 0x10, 0x20, 0x20, 0x40, 0x00
 .byte 0x6C, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x50, 0x50, 0x50, 0x50, 0x50, 0x70, 0x00
 .byte 0xFC, 0x80, 0xBC, 0xA0, 0xAC, 0xA8, 0xA8, 0xA8, 0xFC, 0x00, 0xFC, 0x00, 0xFC, 0x00, 0x00, 0x00
 .byte 0xFC, 0x04, 0xF4, 0x14, 0xD4, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54
 .byte 0x54, 0x54, 0x54, 0xD4, 0x14, 0xF4, 0x04, 0xFC, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF
 .byte 0xA8, 0xA8, 0xA8, 0xAC, 0xA0, 0xBC, 0x80, 0xFC, 0xA8, 0xA8, 0xA8, 0xA8, 0xA8, 0xA8, 0xA8, 0xA8
 .byte 0xA8, 0xA8, 0xAC, 0xA0, 0xAC, 0xA8, 0xA8, 0xA8, 0x54, 0x54, 0xD4, 0x14, 0xD4, 0x54, 0x54, 0x54
 .byte 0x00, 0x00, 0xFC, 0x00, 0xFC, 0x00, 0x00, 0x00, 0xFC, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80
 .byte 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04
 .byte 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0xFC
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0xFC
 .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0xFC, 0x80, 0x80, 0x80, 0x80
 .byte 0x04, 0x04, 0x04, 0xFC, 0x04, 0x04, 0x04, 0x04, 0x00, 0x00, 0x00, 0xFC, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x20, 0x40, 0xF0, 0x08, 0x78, 0x88, 0x70, 0x00, 0x10, 0x20, 0x00, 0x60, 0x20, 0x20, 0xF8, 0x00
 .byte 0x10, 0x20, 0x00, 0x70, 0x88, 0x88, 0x70, 0x00, 0x10, 0x20, 0x00, 0x88, 0x88, 0x88, 0x74, 0x00
 .byte 0x10, 0x20, 0x00, 0xB0, 0xC8, 0x88, 0x88, 0x00, 0x10, 0x20, 0x00, 0xC8, 0xA8, 0x98, 0x88, 0x00
 .byte 0x70, 0x88, 0x88, 0x7C, 0x00, 0xFC, 0x00, 0x00, 0x70, 0x88, 0x88, 0x70, 0x00, 0xFC, 0x00, 0x00
 .byte 0x20, 0x00, 0x20, 0x20, 0x40, 0x88, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x80, 0x80, 0x80
 .byte 0x00, 0x00, 0x00, 0x00, 0xFC, 0x04, 0x04, 0x04, 0x88, 0x90, 0xA8, 0x54, 0x88, 0x1C, 0x00, 0x00
 .byte 0x88, 0x90, 0xA8, 0x58, 0xB8, 0x08, 0x00, 0x00, 0x30, 0x00, 0x30, 0x78, 0x78, 0x30, 0x00, 0x00
 .byte 0x14, 0x28, 0x50, 0xA0, 0x50, 0x28, 0x14, 0x00, 0xA0, 0x50, 0x28, 0x14, 0x28, 0x50, 0xA0, 0x00
 .byte 0x54, 0xAA, 0x54, 0xAA, 0x54, 0xAA, 0x54, 0xAA, 0xAA, 0x54, 0xAA, 0x54, 0xAA, 0x54, 0xAA, 0x54
 .byte 0xB6, 0x6C, 0xDA, 0xB6, 0x6C, 0xDA, 0xB6, 0x6C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18
 .byte 0x18, 0x18, 0x18, 0x18, 0xF8, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xF8, 0x18, 0xF8, 0x18, 0x18
 .byte 0x6C, 0x6C, 0x6C, 0x6C, 0xEC, 0x6C, 0x6C, 0x6C, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x6C, 0x6C, 0x6C
 .byte 0x00, 0x00, 0x00, 0xFC, 0x6C, 0xEC, 0x6C, 0x6C, 0x6C, 0x6C, 0xEC, 0x0C, 0xEC, 0x6C, 0x6C, 0x6C
 .byte 0x6C, 0x6C, 0x6C, 0x6C, 0x6C, 0x6C, 0x6C, 0x6C, 0x00, 0x00, 0xFC, 0x0E, 0xEE, 0x6C, 0x6C, 0x6C
 .byte 0x6C, 0x6C, 0xEC, 0x0C, 0xFC, 0x00, 0x00, 0x00, 0x64, 0x64, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x30, 0x30, 0xF0, 0x30, 0x30, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x30, 0x30, 0x30
 .byte 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00, 0x00, 0x30, 0x30, 0x30, 0x30, 0xFC, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x00, 0xFC, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x30, 0x30, 0x30
 .byte 0x00, 0x00, 0x00, 0x00, 0xFC, 0x00, 0x00, 0x00, 0x30, 0x30, 0x30, 0x30, 0xFC, 0x30, 0x30, 0x30
 .byte 0x30, 0x30, 0x3C, 0x30, 0x3C, 0x30, 0x30, 0x30, 0xD8, 0xD8, 0xDC, 0xD8, 0xD8, 0xD8, 0xD8, 0xD8
 .byte 0xD8, 0xD8, 0xD8, 0xDC, 0xC0, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0xC0, 0xDC, 0xD8, 0xD8
 .byte 0xD8, 0xD8, 0xD8, 0xDC, 0xC0, 0x00, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x00
 .byte 0xD8, 0xD8, 0xD8, 0xDC, 0xC0, 0xDC, 0xD8, 0xD8, 0x00, 0x00, 0x00, 0xFC, 0x00, 0xFC, 0x00, 0x00
 .byte 0xD8, 0xD8, 0xD8, 0xDC, 0x00, 0xDC, 0xD8, 0xD8, 0x30, 0x30, 0x30, 0xFC, 0x00, 0x00, 0xFC, 0x00
 .byte 0xD8, 0xD8, 0xD8, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x00, 0x00, 0xFC, 0x30, 0x30
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0xD8, 0xD8, 0xD8, 0xD8, 0xD8, 0xFC, 0x00, 0x00, 0x00, 0x00
 .byte 0x30, 0x30, 0x30, 0x3C, 0x30, 0x30, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x30, 0x3E, 0x30, 0x30
 .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0xD8, 0xD8, 0xD8, 0xD8, 0xD8, 0xD8, 0xDC, 0xD8, 0xD8, 0xD8
 .byte 0x30, 0x30, 0xFC, 0x00, 0x00, 0xFC, 0x30, 0x30, 0x30, 0x30, 0x30, 0xF0, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC
 .byte 0x00, 0x00, 0x00, 0xFC, 0xFC, 0xFC, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0
 .byte 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0xFC, 0xFC, 0xFC, 0x00
 .byte 0x00, 0x00, 0x00, 0x68, 0x90, 0x90, 0x68, 0x00, 0x70, 0x88, 0x88, 0xB0, 0x88, 0x88, 0xF0, 0x40
 .byte 0xF0, 0x90, 0x80, 0x80, 0x80, 0x80, 0x80, 0x00, 0xF8, 0x50, 0x50, 0x50, 0x50, 0x48, 0x00, 0x00
 .byte 0xF8, 0x88, 0x40, 0x20, 0x40, 0x88, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x7C, 0x88, 0x88, 0x70, 0x00
 .byte 0x00, 0x00, 0x00, 0x88, 0x88, 0x88, 0x70, 0x80, 0x00, 0x00, 0x74, 0x98, 0x10, 0x10, 0x1C, 0x00
 .byte 0xFC, 0x10, 0x38, 0x44, 0x38, 0x10, 0xFC, 0x00, 0x30, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0x38, 0x00
 .byte 0x78, 0x84, 0x84, 0x84, 0x48, 0x48, 0x84, 0x00, 0x3C, 0x40, 0x38, 0x44, 0x44, 0x44, 0x38, 0x00
 .byte 0x00, 0x00, 0x6C, 0x92, 0x92, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x58, 0x68, 0x70, 0x00
 .byte 0x38, 0x40, 0x80, 0xF8, 0x80, 0x40, 0x38, 0x00, 0x00, 0x00, 0x30, 0xCC, 0xCC, 0xCC, 0xCC, 0x00
 .byte 0xFC, 0x00, 0x00, 0xFC, 0x00, 0x00, 0xFC, 0x00, 0x10, 0x10, 0x7C, 0x10, 0x10, 0x00, 0xFE, 0x00
 .byte 0x20, 0x10, 0x08, 0x10, 0x20, 0x00, 0xFE, 0x00, 0x10, 0x20, 0x40, 0x20, 0x10, 0x00, 0xFE, 0x00
 .byte 0x18, 0x34, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0xB0, 0x70
 .byte 0x30, 0x30, 0x00, 0xFC, 0x00, 0x30, 0x30, 0x00, 0x00, 0x64, 0x98, 0x00, 0x64, 0x98, 0x00, 0x00
 .byte 0x38, 0x44, 0x44, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00
 .byte 0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0E, 0x08, 0x08, 0x48, 0x28, 0x18, 0x08, 0x00
 .byte 0x00, 0x00, 0x00, 0xB0, 0x48, 0x48, 0x48, 0x00, 0x00, 0x00, 0xF0, 0x3C, 0x40, 0x80, 0xF8, 0x00
 .byte 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
