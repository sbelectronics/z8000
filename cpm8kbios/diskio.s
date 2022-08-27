!------------------------------------------------------------------------------
! diskio.s
!   Disk I/O subroutines 
!
!   Copyright(c) 2020 4sun5bu

	.include "biosdef.s"

	.global	diskrd, diskwr, disk_init
	.extern maxdisk

	.equ	IDE_DATAW, 0x0020	! Word access
	.equ	IDE_DATAB, 0x0021	! Byte access
	.equ	IDE_ERROR, 0x0023
	.equ	IDE_FEATURES, 0x0023
	.equ	IDE_SECT_CNT, 0x0025
	.equ	IDE_SECT_NUM, 0x0027
	.equ	IDE_CYL_LOW, 0x0029
	.equ	IDE_CYL_HIGH, 0x002b
	.equ	IDE_DEV_HEAD, 0x002d
	.equ	IDE_STATUS, 0x002f
	.equ	IDE_COMND, 0x002f

	.equ	BSY_BIT, 7
	.equ	DRDY_BIT, 6
	.equ	DRQ_BIT, 3
	.equ	ERR_BIT, 0

	.macro	CHKBSY
bsy_loop\@:
	inb	rl0, #IDE_STATUS
	bitb	rl0, #BSY_BIT
	jr	nz, bsy_loop\@ 
	.endm

	.macro	CHKDRDY
drdy_loop\@:
	inb	rl0, #IDE_STATUS
	bitb	rl0, #DRDY_BIT
	jr	z, drdy_loop\@
	.endm  

	.macro	CHKDRQ
drq_loop\@:
	inb	rl0, #IDE_STATUS
	bitb	rl0, #DRQ_BIT
	jr	z, drq_loop\@
	.endm

	unsegm
	sect	.text

!------------------------------------------------------------------------------
disk_init:
	CHKBSY
	!CHKDRDY
                               ! like CHKDRDY but with a timeout
    ld       r4, 0             ! check 64K times
disk_check:
	inb	     rl0, #IDE_STATUS
	bitb	 rl0, #DRDY_BIT
	jr       nz, disk_exists
	djnz     r4, disk_check

	lda      r4, nodiskmsg
	call     puts

	dec      maxdsk, #4        ! we have 4 less disks...
	ret

disk_exists:
	ldb	rl0, #0x01		       ! Set to byte access 
	outb	#IDE_FEATURES, rl0
	ldb	rl0, #0xef		       ! 
	outb	#IDE_COMND, rl0

	ldb     rl5, #FIRSTIDE_LETTER   ! message for C:
	call    scc_out
	lda     r4, idediskmsg
	call    puts

	ldb     rl5, #FIRSTIDE_LETTER+1  ! message for D:
	call    scc_out
	lda     r4, idediskmsg
	call    puts

	ldb     rl5, #FIRSTIDE_LETTER+2  ! message for E:	
	call    scc_out
	lda     r4, idediskmsg
	call    puts

	ldb     rl5, #FIRSTIDE_LETTER+3  ! message for F:	
	call    scc_out
	lda     r4, idediskmsg
	call    puts

    ! I was up till 2am fixing this. It can get an idiot check just to make
	! sure it never happens again...
	lda     r4, secbuf
	and     r4, #1
	jr      z, itsGonnaBeAllright
	lda     r4, notAllrightMsg
	call    puts
itsGonnaBeAllright:
	ret

!------------------------------------------------------------------------------
!  diskrd
!    One sector read
!    input  rr2 --- LBA
!	    r4  --- Buffer Address

diskrd:
    !pushl  @r15, rr4
	!lda    r4, rdmsg
	!call   puts
    !ld     r5, r2
	!call   puthex16
	!ld     r5, r3
	!call   puthex16
	!ld     r5, sentinel
	!call   puthex16	
	!call   putln
	!popl   rr4, @r15

	CHKBSY
	CHKDRDY
	ldb	    rl0, #1
	outb	#IDE_SECT_CNT, rl0
	outb	#IDE_SECT_NUM, rl3
	outb	#IDE_CYL_LOW, rh3
	outb	#IDE_CYL_HIGH, rl2
	andb	rh2, #0x0f
	orb	    rh2, #0x40
	outb	#IDE_DEV_HEAD, rh2
	ldb	rl0, #0x20		! data in command
	outb	#IDE_COMND, rl0
	CHKDRQ
	!CHKBSY
	!inb	rl0, #IDE_STATUS	! Reset INTRQ

    ld      r2, #0x200      ! transfer 512 bytes
	ld      r3, #IDE_DATAB
    inirb   @r4, @r3, r2

	CHKBSY

	inb	rl0, #IDE_STATUS

    !pushl  @r15, rr4
	!ldb    rh5, rl0
	!lda    r4, stmsg
	!call   puts
	!ldb    rl5, rh5
	!call   puthex8
	!ld     r5, sentinel
	!call   puthex16
	!call   putln
	!popl   rr4, @r15

	ret
	
!------------------------------------------------------------------------------
!  diskwr
!    One sector write
!    input rr2 --- LBA
!	    r4 --- Buffer Address

diskwr:
    !pushl  @r15, rr4
	!lda    r4, wrmsg
	!call   puts
    !ld     r5, r2
	!call   puthex16
	!ld     r5, r3
	!call   puthex16
	!ld     r5, sentinel
	!call   puthex16
	!call   putln
	!popl   rr4, @r15

	CHKBSY
	CHKDRDY
	ldb	    rl0, #1
	outb	#IDE_SECT_CNT, rl0
	xorb	rl0, rl0
	outb	#IDE_SECT_NUM, rl3
	outb	#IDE_CYL_LOW, rh3
	outb	#IDE_CYL_HIGH, rl2
	andb	rh2, #0x0f
	orb	    rh2, #0x40
	outb	#IDE_DEV_HEAD, rh2
	ldb	    rl0, #0x30		! data out command
	outb	#IDE_COMND, rl0

	CHKDRQ

	!CHKBSY
	!inb	    rl0, #IDE_STATUS	! Reset INTRQ

    ld      r2, #0x200          ! transfer 512 bytes
	ld      r3, #IDE_DATAB
    otirb   @r3, @r4, r2

	CHKBSY

	inb	    rl0, #IDE_STATUS

    !pushl  @r15, rr4
	!ldb    rh5, rl0
	!lda    r4, stmsg
	!call   puts
	!ldb    rl5, rh5
	!call   puthex8
	!ld     r5, sentinel
	!call   puthex16
	!call   putln
	!popl   rr4, @r15

	ret


!------------------------------------------------------------------------------
	sect	.rodata
rdmsg:
    .asciz  "Read LBA "	
wrmsg:
    .asciz  "Write LBA "
stmsg:
    .asciz  "Status "
nodiskmsg:
	.asciz	"CompactFlash not detected\r\n"	
idediskmsg:
    .asciz  ": CompactFlash disk\r\n"
notAllrightMsg:
    .asciz  "Secbuf is not aligned. It's not gonna be allright\r\n"
