!------------------------------------------------------------------------------
! floppy.s
!   Floppy I/O subroutines
!
!   Copyright(c) 2022 smbaker

	unsegm
	sect	.text

.equ FDM720, 0
.equ FDM144, 1
.equ FDM360, 2
.equ FDM120, 3
.equ FDM111, 4

.equ FRC_OK,             0
.equ FRC_NOTIMPL,        1
.equ FRC_CMDERR,         2
.equ FRC_ERROR,          3
.equ FRC_ABORT,          4
.equ FRC_BUFMAX,         5
.equ FRC_ABTERM,         8
.equ FRC_INVCMD,         9
.equ FRC_DSKCHG,      0x0A
.equ FRC_ENDCYL,      0x0B
.equ FRC_DATAERR,     0x0C
.equ FRC_OVERRUN,     0x0D
.equ FRC_NODATA,      0x0E
.equ FRC_NOTWRIT,     0x0F
.equ FRC_MISADR,      0x10
.equ FRC_TOFDRRDY,    0x11
.equ FRC_TOSNDCMD,    0x12
.equ FRC_TOGETRES,    0x13
.equ FRC_TOEXEC,      0x14
.equ FRC_TOSEEKWT,    0x15
.equ FRC_OVER_DRAIN,  0x16
.equ FRC_OVER_CMDRES, 0x17
.equ FRC_TO_READRES,  0x18
.equ FRC_READ_ERROR,  0x19
.equ FRC_WRITE_ERROR, 0x20
.equ FRC_SHORT,       0x21
.equ FRC_LONG,        0x22
.equ FRC_INPROGRESS,  0x23

.equ CFD_READ,     0x06	! CMD,HDS/DS,C,H,R,N,EOT,GPL,DTL --> ST0,ST1,ST2,C,H,R,N
.equ CFD_READDEL,  0x0C	! CMD,HDS/DS,C,H,R,N,EOT,GPL,DTL --> ST0,ST1,ST2,C,H,R,N
.equ CFD_WRITE,    0x05	! CMD,HDS/DS,C,H,R,N,EOT,GPL,DTL --> ST0,ST1,ST2,C,H,R,N
.equ CFD_WRITEDEL, 0x09	! CMD,HDS/DS,C,H,R,N,EOT,GPL,DTL --> ST0,ST1,ST2,C,H,R,N
.equ CFD_READTRK,  0x02	! CMD,HDS/DS,C,H,R,N,EOT,GPL,DTL --> ST0,ST1,ST2,C,H,R,N
.equ CFD_READID,   0x0A	! CMD,HDS/DS --> ST0,ST1,ST2,C,H,R,N
.equ CFD_FMTTRK,   0x0D ! CMD,HDS/DS,N,SC,GPL,D --> ST0,ST1,ST2,C,H,R,N
.equ CFD_SCANEQ,   0x11	! CMD,HDS/DS,C,H,R,N,EOT,GPL,STP --> ST0,ST1,ST2,C,H,R,N
.equ CFD_SCANLOEQ, 0x19	! CMD,HDS/DS,C,H,R,N,EOT,GPL,STP --> ST0,ST1,ST2,C,H,R,N
.equ CFD_SCANHIEQ, 0x1D	! CMD,HDS/DS,C,H,R,N,EOT,GPL,STP --> ST0,ST1,ST2,C,H,R,N
.equ CFD_RECAL,	   0x07	! CMD,DS --> <EMPTY>
.equ CFD_SENSEINT, 0x08	! CMD --> ST0,PCN
.equ CFD_SPECIFY,  0x03	! CMD,SRT/HUT,HLT/ND --> <EMPTY>
.equ CFD_DRVSTAT,  0x04	! CMD,HDS/DS --> ST3
.equ CFD_SEEK,     0x0F	! CMD,HDS/DS --> <EMPTY>
.equ CFD_VERSION,  0x10	! CMD --> ST0

.equ DOR_INIT, 0x0C
.equ DOR_BR250, DOR_INIT
.equ DOR_BR500, DOR_INIT
.equ DCR_BR250, 1
.equ DCR_BR500, 0

.equ PORT_MSR, 0x41
.equ PORT_DATA, 0x43
.equ PORT_DOR, 0x45
.equ PORT_DCR, 0x47

! for 1.44 MB floppy
.equ NUMCYL, 0x50
.equ NUMHEAD, 0x02
.equ SOT, 1
.equ SECCOUNT, 0x12
.equ EOT, SECCOUNT
.equ N, 0x02
.equ GAPLENRW, 0x1B
.equ GAPLENFMT, 0x6C
.equ STEPRATE, 0xD0
.equ HLTND, 0x11
.equ DOR, DOR_BR500
.equ DCR, DCR_BR500

! drive select
.equ DS, 0

flop_init:
    call flop_reset
    ret

flop_reset:
	ldb	    rl0, #0x00
	outb	#PORT_DOR, rl0
    call    delay_20us
    ldb     rl0, DOR    
    outb    #PORT_DOR, rl0
    call    delay_240ms

    ldb     motorflag, #0

    ldb     rl0, flop_trk
    orb     rl0, #0xFE
    ldb     rl0, flop_trk
    ret

    ! rl0 = command
setupCommand:
    ldb    rl1, rl0
    andb   rl1, #0x5F
    ldb    fcpbuf, rl1    ! fcpBuf[0] = cmd & 0x5F
    andb   rl1, #0x1F
    ldb    fcpcmd, rl1    ! fcpCmd = cmd & 0b00011111

    ld     r1, settrk     ! rl1 = track
    andb   rl1, #1        ! rl1 = H = lsb of track
    sllb   rl1, #2
    orb    rl1, #DS
    ldb    fcpbuf+1, rl1  ! fcpBuf[1] = (head&1)<<2 | DS
    ldb    fcplen, #2
    ret

setupSeek:
    ldb    rl0, #CFD_SEEK
    call   setupCommand

    ld     r1, settrk
    srlb   rl1, #1        ! track = track >> 1 (lsb is head)
    ldb    fcpbuf+2,  rl1 ! fcpBuf[2] = track
    ldb    fcplen, #3
    ret

setupSpecify:
    ldb    rl0, #CFD_SPECIFY
    call   setupCommand

    ldb    fcpbuf+1, #STEPRATE   ! fcpBuf[1] = steprate
    ldb    fcpbuf+2, #HLTND      ! fcpBuf[2] = headLoadTimeNonDma
    ldb    fcplen, #3
    ret

setupRead:
    ldb    rl0, #CFD_READ
    orb    rl0, #0xE0
    call   setupCommand
    jp     setupIO

setupWrite:
    ldb    rl0, #CFD_WRITE
    orb    rl0, #0xC0
    call   setupCommand
    jp     setupIO

setupIO:
    ld     r1, settrk
    srlb   rl1, #1             ! track is bits 7..1 of settrk
    ldb    fcpbuf+2, rl1

    ld     r1, settrk
    andb   rl1, #1             ! head is the LSB of settrk
    ldb    fcpbuf+3, rl1

    ld     r1, setsec
    srlb   rl1, #2             ! we read 512 byte sectors, not 128
    ldb    fcpbuf+4, rl1

    ldb    fcpbuf+5, #N
    ldb    fcpbuf+6, #EOT
    ldb    fcpbuf+6, #GAPLENRW
    ldb    fcpbuf+7, #GAPLENFMT
    ldb    fcplen, #9
    ret

!-------------------------------------------------------------------------------------------

fop:
    call   drain
    call   delay_20us

    ldb    fstrc, #FRC_OK

    inb    rl0, #PORT_MSR
    andb   rl0, #0x90
    cpb    rl0, #0x90
    jr     nz, notinprog       ! idiot-check: IO should not be in progress

    ldb    fstrc, #FRC_INPROGRESS
    ret

notinprog:

    ! write command

    ldb    rl0, fcplen         ! write fcplen byte3s from fcp to the data port
    lda    r1, fcpbuf
nextfcp:
    ldb    rh0, @r1
    outb   #PORT_DATA, rh0
    inc    r1, #1
    dbjnz  rl0, nextfcp

    ! execute
    cp     fcpcmd, #CFD_READ
    jr     nz, notread
    call   read_block
    jr     readres
notread:
    cp     fcpcmd, #CFD_WRITE
    jr     nz, notwrite
    call   write_block
    jr     readres    
notwrite:

readres:
    ! read result
    ldb    frblen, #0
    lda    r1, frbbuf

resAgain:
    ldb    rl0, #PORT_MSR
    andb   rl0, #0xF0
    cpb    rl0, #0xD0          ! (MSR & 0xF0) == 0xD0 means result byte is ready to read
    jr     nz, resNotReady
    
    inb    rh0, #PORT_DATA
    ldb    @r1, rh0
    inc    r1, #1
    inc    frblen, #1
    jr     resAgain

resNotReady:
    cpb    rl0, #0x80         ! (MSR & 0xF0) == 0x80 means waiting for next command, we have result
    jr     nz, resAgain

    cpb    fcpcmd, #CFD_DRVSTAT
    jr     nz, notdrvstat
    ret                       ! driveState has nothing to evaluate
notdrvstat:
    cp     frblen, #0
    jr     nz, notzerores     ! if there's no st0, then nothing to evaluate
    ret
notzerores:

    ldb   rl0, frbbuf         !  rl0 = st0 = frbbuf[0]
    andb  rl0, #0xC0
    cpb   rl0, #0x40
    jp    nz, notabterm

    cpb   fcpcmd, #CFD_SENSEINT
    jr    nz, notsenseint
    ldb   fstrc, #FRC_ABTERM
    ret
notsenseint:
    cpb   frblen, #1
    jr    nz, notlen1
    ldb   fstrc, #FRC_ABTERM
    ret
notlen1:

    ldb   rl0, frbbuf+1       ! rl0 = st1 = frbbuf[1]
    bitb  rl0, #7
    jr    z,  notendcyl
    ldb   fstrc, #FRC_ENDCYL
    ret 
notendcyl:
    bitb  rl0, #5
    jr    z, notdataerr
    ldb   fstrc, #FRC_DATAERR
    ret
notdataerr:
    bitb  rl0, #4
    jr    z, notoverrun
    ldb   fstrc, #FRC_OVERRUN
    ret
notoverrun:
    bitb  rl0, #2
    jr    z, notnodata
    ldb   fstrc, #FRC_NODATA
    ret
notnodata:
    bitb  rl0, #1
    jr    z, notnowrit
    ldb   fstrc, #FRC_NOTWRIT
    ret
notnowrit:
    bitb  rl0, #0
    jr    z, notmisadr
    ldb   fstrc, #FRC_MISADR
    ret
notmisadr:
    ret  
notabterm:
    ! rl0 is st0 & 0xC0
    cpb   rl0, #0x80
    jr    nz, notinvcmd
    ldb   fstrc, #FRC_INVCMD
    ret
notinvcmd:
    ! rl0 is st0 & 0xC0
    cpb   rl0, #0xC0
    jr    nz, notdiskchg
    ldb   fstrc, #FRC_DSKCHG
    ret
notdiskchg:
    ! unbelievable... it's all good...
    ret

!--------------------------------------------------------------------------

read_block:
    lda   r4, secbuf
    ld    r3, #0x200

read_block_wait_msr:
    inb   rl0, #PORT_MSR
    cpb   rl0, #0xF0
    jr    nz, read_block_wait_msr

    ! TODO: There's no timeout here; we'll block forever

    inb   rl0, #PORT_DATA
    ldb   @r4, rl0
    inc   r4, #1
    djnz  r3, read_block_wait_msr
    ret

!-----------------------------------------------------------------------------

write_block:
    lda   r4, secbuf
    ld    r3, #0x200

write_block_wait_msr:
    inb   rl0, #PORT_MSR
    cpb   rl0, #0xB0
    jr    nz, write_block_wait_msr

    ! TODO: There's no timeout here; we'll block forever

    ldb   rl0, @r4
    outb  #PORT_DATA, rl0
    inc   r4, #1
    djnz  r3, write_block_wait_msr
    ret

!-----------------------------------------------------------------------------

drain:
    inb   rl0, #PORT_MSR
    andb  rl0, #0x0C
    cpb   rl0, #0x0C
    jr    nz, drain_has_data
    ret                             ! no data; return 
drain_has_data:
    inb   rl0, #PORT_DATA           ! eat the data
    jr    drain                     ! check for more

!------------------------------------------------------------------------------

start:
    call  motoron
    cpb   flop_trk, #0xFF
    jr    nz, start_not_trk_ff
    call  drive_reset
    cpb   fstrc, #FRC_OK
    jr    z, start_reset_ok
    ret                             ! exit with fstrc set to not okay
start_reset_ok:
start_not_trk_ff:
    ld    r0, settrk
    srlb  rl0, #1                   ! low bit is the head
    cpb   rl0, flop_trk
    jr    z, start_ret_okay         ! we're already on the right track
    call  seek
    cpb   fstrc, #FRC_OK
    jr    nz, start_ret             ! seek failed
    call  waitseek
    cpb   fstrc, #FRC_OK
    jr    nz, start_ret             ! wait for seek failed

start_ret_okay:
    ldb   fstrc, #FRC_OK
start_ret:
    ret

!----------------------------------------------------------------------------------

drive_reset:
    call  specify
    cpb   fstrc, #FRC_OK
    jr    nz, drive_reset_ret

    call  recal
    cpb   fstrc, #FRC_OK
    jr    nz, drive_reset_ret

    call  waitseek
    cpb   fstrc, #FRC_OK
    jr    z, drive_reset_ret      ! did we succeed! if so, exit now

    call  waitseek                ! try the waitseek again
    ! fall through with status return
drive_reset_ret:
    ret

!------------------------------------------------------------------------------

waitseek:
    ld    r3, #0x1000
waitseek_loop:
    call  senseint
    cpb   fstrc, #FRC_OK
    jr    z, waitseek_ret
    cpb   fstrc, #FRC_ABTERM
    jr    z, waitseek_ret       ! abnormal termination -- bail
    djnz  r3, waitseek_loop

    ldb   fstrc, #FRC_TOSEEKWT  ! waitout while waiting for seek

waitseek_ret:
    ret

!------------------------------------------------------------------------------

motoron:
    ldb   rl0, #DOR                  ! start with DOR
    orb   rl0, #DS                   !    bit 0 is DS, either 0 or 1
    orb   rl0, #(1 << (DS+4))        !    bit 4 and 5 are motor enable for DS0 and DS1

    outb  #PORT_DOR, rl0
    
    ldb   rl0, #DCR
    outb  #PORT_DCR, rl0

    test  motorflag
    jr    z, motoron_ret

    ldb   motorflag, #1

    call  delay_240ms
    call  delay_240ms
    call  delay_240ms
    call  delay_240ms
motoron_ret:
    ret

!------------------------------------------------------------------------------

recal:
    ldb   rl0, #CFD_RECAL
    call  setupCommand
    jp    fop

!------------------------------------------------------------------------------

senseint:
    ldb   rl0, #CFD_SENSEINT
    call  setupCommand
    ldb   fcplen, #1
    jp    fop

!------------------------------------------------------------------------------

specify:
    call  setupSpecify
    jp    fop

!------------------------------------------------------------------------------

seek:
    call  setupSeek
    jp    fop

!------------------------------------------------------------------------------

floppy_read:
    call  start
    cpb   fstrc, #FRC_OK
    jr    nz, floppy_read_fail

    call  setupRead
    call  fop
    cpb   fstrc, #FRC_OK
    jr    nz, floppy_read_fail:
    ret

floppy_read_fail:
    ! do something!
    ret

!------------------------------------------------------------------------------

floppy_write:
    call  start
    cpb   fstrc, #FRC_OK
    jr    nz, floppy_write_fail

    call  setupWrite
    call  fop
    cpb   fstrc, #FRC_OK
    jr    nz, floppy_write_fail:
    ret

floppy_write_fail:
    ! do something!
    ret

!------------------------------------------------------------------------------
	sect .data
	.even

flop_trk:
    .space 1

fcpbuf:
    .space 8

frbbuf:
    .space 8

fcplen:
    .space 1

frblen:
    .space 1

fcpcmd:
    .space 1

fstrc:
    .space 1

motorflag:
    .space 1

