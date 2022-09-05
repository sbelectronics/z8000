!------------------------------------------------------------------------------
! floppy.s
!   Floppy I/O subroutines
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

	.global	flop_init, flop_read, flop_write, flop_sel

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
.equ PORT_DACK, 0x45

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

!------------------------------------------------------------------------------
! flop_sel
!   input:
!     rr6 disk table entry
!     r5 disk number - preserve this!
!   exit:
!     if supdisk not initialized, clear rr6 and return
!     if supdisk is initialized, then jump back to setdsk_ok

flop_sel:
    test     presflag
	jr       nz, selok
	clr      r6
	clr      r7
	ret
selok:
    jp       setdsk_ok

!------------------------------------------------------------------------------
! flop_sel    

flop_init:
    ldb     readyflag, #0     ! you are not prepared.
    ldb     presflag, #0      ! you're not even present.
    ldb     debugflag, #0     ! set this to 1 to TURN ON LOGGING
    ldb     superr, #0        ! suppress errors if > 0

    ld     r3, #0x1000
init_detect:
    inb    rh0, #PORT_MSR      ! wait for fdc to be ready for byte
    andb   rh0, #0xC0
    cpb    rh0, #0x80
    jr     z, flop_detected
    djnz   r3, init_detect

    lda    r4, noflop_msg
    call   puts
    ret

flop_detected:
    call    reset
    ldb     presflag, #1
	ldb     rl5, #FLOPDISK_LETTER
	call    scc_out
	lda     r4, flopdiskmsg
	call    puts	
    ret

!------------------------------------------------------------------------------

reset:
    call    resetfdc
    call    clearDiskChange
    ldb     flop_trk, #0xFF   ! need recal
    ldb     readyflag, #1
    ret

!------------------------------------------------------------------------------

resetfdc:
	ldb	    rl0, #0x00
	outb	#PORT_DOR, rl0   ! DOR = 0
    call    delay_10us
    ldb     rl0, #DOR
    outb    #PORT_DOR, rl0   ! DOR = DOR_BR500 = 0x0C
    call    delay_240ms

    ldb     motorflag, #0    ! The motor is off

    ldb     rl0, flop_trk
    orb     rl0, #0xFE       ! Force an initial seek
    ldb     flop_trk, rl0
    ret

!------------------------------------------------------------------------------

clearDiskChange:
    incb    superr, #1                  ! suppress nuisance error messages
    call    senseint
    cpb     fstrc, #FRC_DSKCHG
    jr      nz, clearDiskChange_ret
    call    senseint
    cpb     fstrc, #FRC_DSKCHG
    jr      nz, clearDiskChange_ret
    call    senseint
    cpb     fstrc, #FRC_DSKCHG
    jr      nz, clearDiskChange_ret
    call    senseint
    cpb     fstrc, #FRC_DSKCHG
    jr      nz, clearDiskChange_ret
    call    senseint
    cpb     fstrc, #FRC_DSKCHG
    jr      nz, clearDiskChange_ret                
clearDiskChange_ret:
    decb    superr, #1
    ret

    ! rl0 = command
setupCommand:
    ldb    rl1, rl0
    andb   rl1, #0x5F
    ldb    fcpbuf, rl1    ! fcpBuf[0] = cmd & 0x5F
    andb   rl1, #0x1F
    ldb    fcpcmd, rl1    ! fcpCmd = cmd & 0b00011111

    ldb    rl1, req_head  ! rl1 = head
    sllb   rl1, #2
    orb    rl1, #DS
    ldb    fcpbuf+1, rl1  ! fcpBuf[1] = (head&1)<<2 | DS
    ldb    fcplen, #2
    ret

setupSeek:
    ldb    rl0, #CFD_SEEK
    call   setupCommand

    ldb    rl1, req_trk
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
    ldb    rl1, req_trk
    ldb    fcpbuf+2, rl1       ! fcpbuf[2] = req_trk

    ldb    rl1, req_head
    ldb    fcpbuf+3, rl1       ! fcpbuf[3] = req_head

    ldb    rl1, req_sec
    ldb    fcpbuf+4, rl1       ! fcpbuf[4] = req_sec

    ldb    fcpbuf+5, #N
    ldb    fcpbuf+6, #EOT
    ldb    fcpbuf+7, #GAPLENRW
    ldb    fcpbuf+8, #GAPLENFMT
    ldb    fcplen, #9
    ret

!-------------------------------------------------------------------------------------------

fop:
    call   print_fcp
    call   drain
    call   delay_10us

    ldb    fstrc, #FRC_OK

    inb    rl0, #PORT_MSR
    andb   rl0, #0x90
    cpb    rl0, #0x90
    jr     nz, notinprog       ! idiot-check: IO should not be in progress

    ldb    fstrc, #FRC_INPROGRESS
    !call   print_fstrc
    ret

notinprog:

    ! write command

    ldb    rl0, fcplen         ! write fcplen bytes from fcp to the data port
    lda    r1, fcpbuf
nextfcp:
    inb    rh0, #PORT_MSR      ! wait for fdc to be ready for byte
    andb   rh0, #0xC0
    cpb    rh0, #0x80
    jr     nz, nextfcp

    ldb    rh0, @r1
    outb   #PORT_DATA, rh0
    inc    r1, #1
    dbjnz  rl0, nextfcp

    ! execute
    cpb    fcpcmd, #CFD_READ
    jr     nz, notread
    call   read_block
    jr     readres
notread:
    cpb    fcpcmd, #CFD_WRITE
    jr     nz, notwrite
    call   write_block
    jr     readres    
notwrite:

readres:
    ! read result
    ldb    frblen, #0
    lda    r1, frbbuf

resAgain:
    call   delay_2us
    inb    rl0, #PORT_MSR
    !call   print_rl0
    andb   rl0, #0xF0
    cpb    rl0, #0xD0          ! (MSR & 0xF0) == 0xD0 means result byte is ready to read
    jr     nz, resNotReady
    
    inb    rh0, #PORT_DATA
    ldb    @r1, rh0
    inc    r1, #1
    incb   frblen, #1
    jr     resAgain

resNotReady:
    cpb    rl0, #0x80         ! (MSR & 0xF0) == 0x80 means waiting for next command, we have result
    jr     nz, resAgain

    call   print_frb

    cpb    fcpcmd, #CFD_DRVSTAT
    jr     nz, notdrvstat
    !call   print_fstrc
    ret                       ! driveState has nothing to evaluate
notdrvstat:

    cpb    frblen, #0
    jr     nz, notzerores     ! if there's no st0, then nothing to evaluate
    !call   print_fstrc
    ret

notzerores:

    ldb   rl0, frbbuf         !  rl0 = st0 = frbbuf[0]
    !call  print_rl0
    andb  rl0, #0xC0
    cpb   rl0, #0x40
    jp    nz, notabterm

    cpb   fcpcmd, #CFD_SENSEINT
    jr    nz, notsenseint
    ldb   fstrc, #FRC_ABTERM
    !call  print_fstrc
    ret
notsenseint:
    cpb   frblen, #1
    jr    nz, notlen1
    ldb   fstrc, #FRC_ABTERM
    !call   print_fstrc
    ret
notlen1:

    ldb   rl0, frbbuf+1       ! rl0 = st1 = frbbuf[1]
    bitb  rl0, #7
    jr    z,  notendcyl
    ldb   fstrc, #FRC_ENDCYL
    !call   print_fstrc
    ret 
notendcyl:
    bitb  rl0, #5
    jr    z, notdataerr
    ldb   fstrc, #FRC_DATAERR
    !call   print_fstrc
    ret
notdataerr:
    bitb  rl0, #4
    jr    z, notoverrun
    ldb   fstrc, #FRC_OVERRUN
    !call   print_fstrc
    ret
notoverrun:
    bitb  rl0, #2
    jr    z, notnodata
    ldb   fstrc, #FRC_NODATA
    !call   print_fstrc
    ret
notnodata:
    bitb  rl0, #1
    jr    z, notnowrit
    ldb   fstrc, #FRC_NOTWRIT
    !call   print_fstrc
    ret
notnowrit:
    bitb  rl0, #0
    jr    z, notmisadr
    ldb   fstrc, #FRC_MISADR
    !call   print_fstrc
    ret
notmisadr:
    ! what's up here? We have an abterm but no bits set...
    !call   print_fstrc
    ret
notabterm:
    ! rl0 is st0 & 0xC0
    cpb   rl0, #0x80
    jr    nz, notinvcmd
    ldb   fstrc, #FRC_INVCMD
    !call  print_fstrc
    ret
notinvcmd:
    ! rl0 is st0 & 0xC0
    cpb   rl0, #0xC0
    jr    nz, notdiskchg
    ldb   fstrc, #FRC_DSKCHG
    !call   print_fstrc
    ret
notdiskchg:
    ! unbelievable... it's all good...
    !call   print_fstrc
    ret

!--------------------------------------------------------------------------

read_block:
    lda   r4, secbuf
    ld    r3, #0x200

read_block_next_byte:
    ld    r1, #0x0010               ! 16 * 64K iterations = 1024K iterations
read_block_wait_msr2:
    ld    r2, #0x0000               ! 64K iterations
read_block_wait_msr1:
    inb   rl0, #PORT_MSR
    cpb   rl0, #0xF0
    jr    z, read_block_have_byte
    call  delay_2us
    djnz  r2, read_block_wait_msr1
    djnz  r1, read_block_wait_msr2

    call  print_block_timeout
    jr    read_block_ret

read_block_have_byte:
    inb   rl0, #PORT_DATA
    ldb   @r4, rl0
    inc   r4, #1
    djnz  r3, read_block_next_byte

    inb  rl0, #PORT_DACK

read_block_ret:
    ret

!-----------------------------------------------------------------------------

write_block:
    lda   r4, secbuf
    ld    r3, #0x200

write_block_next_byte:
    ld    r1, #0x0010               ! 16 * 64K iterations = 1024K iterations
write_block_wait_msr2:
    ld    r2, #0x0000               ! 64K iterations
write_block_wait_msr1:
    inb   rl0, #PORT_MSR
    cpb   rl0, #0xB0
    jr    z, write_block_ready_byte
    call  delay_2us
    djnz  r2, write_block_wait_msr1

    call  print_block_timeout
    jr    write_block_ret

write_block_ready_byte:
    ldb   rl0, @r4
    outb  #PORT_DATA, rl0
    inc   r4, #1
    djnz  r3, write_block_next_byte

    ! pulsing dack too close after the write of the last byte causes it to
    ! not be written.
    !call  delay_10us

    inb  rl0, #PORT_DACK

write_block_ret:
    ret

!-----------------------------------------------------------------------------

drain:
    inb   rl0, #PORT_MSR
    andb  rl0, #0x0C
    cpb   rl0, #0x0C
    jr    z, drain_has_data
    ret                             ! no data; return 
drain_has_data:
    inb   rl0, #PORT_DATA           ! eat the data
    jr    drain                     ! check for more

!------------------------------------------------------------------------------

start:
    test  readyflag
    jr    nz, start_isready
    call  reset

start_isready:
    call  motoron
    cpb   flop_trk, #0xFF
    jr    nz, start_not_trk_ff
    call  drive_reset
    cpb   fstrc, #FRC_OK
    jr    z, start_reset_ok
    ret                             ! exit with fstrc set to not okay
start_reset_ok:
start_not_trk_ff:
    ldb   rl0, req_trk              ! see if the track we want...
    cpb   rl0, flop_trk             ! ... is the track we have
    jr    z, start_ret_okay         ! we're already on the right track
    call  seek
    cpb   fstrc, #FRC_OK
    jr    nz, start_ret             ! seek failed

    call  waitseek
    cpb   fstrc, #FRC_OK
    jr    nz, start_ret             ! wait for seek failed

    ldb   rl0, req_trk              
    ldb   flop_trk, rl0             ! update flop_trk with the successful seek

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

! NOTE: I'm skeptical this is working right, given the long pauses that seem
!       to happen inside of read_block / write_block.

waitseek:
    ld    r3, #0x1000
waitseek_loop:
    incb  superr, #1          ! suppress errors
    call  senseint
    decb  superr, #1
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
    jr    nz, motoron_ret            ! if motorflag!=0, then return

    ldb   motorflag, #1              ! set motorflag

    call  delay_240ms                ! delay while motor spins up
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
!    input  rr2 --- LBA

flop_read:
    call  lba_to_req

    ldb   retryCount, #3
flop_read_retry:
    call  start
    cpb   fstrc, #FRC_OK
    jr    nz, flop_read_fail

    call  setupRead
    call  fop
    cpb   fstrc, #FRC_OK
    jr    nz, flop_read_fail
    ret

flop_read_fail:
    call  print_fstrc
    decb  retryCount, #1
    jr    nz, flop_read_retry
    ret

!------------------------------------------------------------------------------
!    input  rr2 --- LBA

flop_write:
    call  lba_to_req

    ldb   retryCount, #3
flop_write_retry:    
    call  start
    cpb   fstrc, #FRC_OK
    jr    nz, flop_write_fail

    call  setupWrite
    call  fop
    cpb   fstrc, #FRC_OK
    jr    nz, flop_write_fail
    ret

flop_write_fail:
    call  print_fstrc
    decb  retryCount, #1
    jr    nz, flop_write_retry
    ret

!------------------------------------------------------------------------------
!
!    note that the LBA was designed for the CF and will have holes in it because
!    the floppy only has 72 sectors per track instead of 128. Nevertheless, we can
!    extract sector number and friends.
!
!    input  rr2 --- LBA
!		  format 00000000-000000dd-ddtttttt-tttsssss
!                   rh2      rl2      rh3     rl3
!    destroys r0

lba_to_req:
    ld    r0, r3
    andb  rl0, #0x1F
    incb  rl0, #1
    ldb   req_sec, rl0    ! req_sec = (bits 4..0) + 1

    ld    r0, r3
    srl   r0, #5
    andb  rl0, #1
    ldb   req_head, rl0   ! req_head = bit 5

    ld    r0, r3
    srl   r0, #6
    ldb   req_trk, rl0    ! req_trk = bits 13..6
    ret

!------------------------------------------------------------------------------

print_fcp:
    testb  debugflag
    jp     z, print_fcp_ret

print_fcp_always:
    lda    r4,  fcp_msg
    call   puts
    ldb    rl5, fcplen
    call   puthex8
    ldb	rl5, #' '
    call   scc_out     
    ldb    rl5, fcpbuf
    call   puthex8
    ldb	rl5, #' '
    call   scc_out
    ldb     rl5, fcpbuf+1
    call   puthex8
    ldb	rl5, #' '
    call   scc_out
    ldb     rl5, fcpbuf+2
    call   puthex8
    ldb	rl5, #' '
    call   scc_out
    ldb     rl5, fcpbuf+3
    call   puthex8
    ldb	rl5, #' '
    call   scc_out
    ldb     rl5, fcpbuf+4
    call   puthex8
    ldb	rl5, #' '
    call   scc_out    
    ldb     rl5, fcpbuf+5
    call   puthex8
    ldb	rl5, #' '
    call   scc_out
    ldb     rl5, fcpbuf+6
    call   puthex8 
    ldb	rl5, #' '
    call   scc_out     
    ldb     rl5, fcpbuf+7
    call   puthex8
    ldb	rl5, #' '
    call   scc_out
    ldb    rl5, fcpbuf+8
    call   puthex8 
    lda    r4, trk_msg
    call   puts  
    ldb    rl5, req_trk
    call   puthex8
    lda    r4, head_msg
    call   puts
    ldb    rl5, req_head
    call   puthex8
    lda    r4, sec_msg
    call   puts
    ldb    rl5, req_sec
    call   puthex8    
    call   putln
print_fcp_ret:
    ret

print_fstrc:
    testb  fstrc
    jr     z, print_fstrc_ret
    testb  superr
    jr     nz, print_fstrc_ret

    call   print_fcp_always
    call   print_frb_always

    call   putln
    lda    r4, fstrc_msg
    call   puts
    ldb    rl5, fstrc
    call   puthex8
    lda    r4, retry_msg
    call   puts
    ldb    rl5, retryCount
    decb   rl5, #1
    call   puthex8
    call   putln
    call   putln
print_fstrc_ret:
    ret

print_frb:
    testb  debugflag
    jr     z, print_frb_ret

print_frb_always:
    lda    r4,  frb_msg
    call   puts
    ldb    rl5, frblen
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out     
    ldb    rl5, frbbuf
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out
    ldb    rl5, frbbuf+1
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out
    ldb    rl5, frbbuf+2
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out
    ldb    rl5, frbbuf+3
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out
    ldb    rl5, frbbuf+4
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out
    ldb    rl5, frbbuf+5
    call   puthex8
    ldb	   rl5, #' '
    call   scc_out
    ldb    rl5, frbbuf+6
    call   puthex8            
    call   putln
print_frb_ret:
    ret

print_block_timeout:
    ldb    rl5, rl0
    call   puthex8
    lda    r4, to_msg
    call   puts
    ret

!------------------------------------------------------------------------------
	sect .data
	.even

flop_trk:
    .space 1

req_trk:
    .space 1

req_head:
    .space 1

req_sec:
    .space 1

fcpbuf:
    .space 9

frbbuf:
    .space 9

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

readyflag:
    .space 1

presflag:
    .space 1

superr:
    .space 1

debugflag:
    .space 1

retryCount:
    .space 1

!------------------------------------------------------------------------------
	sect	.rodata

flopdiskmsg:
    .asciz  ": floppy disk\r\n"

noflop_msg:
    .asciz " : Floppy controller not detected\r\n"

fcp_msg:
    .asciz "FCP len="

fstrc_msg:
    .asciz "FLOPPY ERROR: fstrc="

frb_msg:
    .asciz "FRB len="

reset_msg:
    .asciz "reset\r\n"

read_block_msg:
    .asciz "read block\r\n"

retry_msg:
    .asciz " retries_left="

to_msg:
    .asciz "=msr. FLOPPY ERROR: timeout\r\n"

trk_msg:
    .asciz " trk="

head_msg:
    .asciz " head="

sec_msg:
    .asciz " sec="
