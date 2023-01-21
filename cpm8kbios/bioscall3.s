!------------------------------------------------------------------------------
! CP/M-8000 BIOS func8-14, 16, 21
!
!  Copyright (c) 2020, 4sun5bu
!------------------------------------------------------------------------------
	
	.extern	setsec, settrk, dphtbl, dbgbc, setdsk, setdma
	.extern	_sysseg, puthex16, putln, putsp, scc_out
	
	.global	func8, func9, func10, func11, func12
	.global	func13, func14, func16, func21, flush
	.global	secbLBA, secbvalid, secbdirty
	.global setdma, settrk, setsec                  ! for flashio.s
	.global maxdsk, sentinel, secbuf                ! for diskio.s
	.global setdsk_ok                               ! for supio.s

	.include "biosdef.s"
	
	unsegm
	sect .text

!------------------------------------------------------------------------------
! func8
!   Home
    
func8:
	ld	settrk, #0
	ret

!------------------------------------------------------------------------------
! func9
!   Select Disk Drive	

func9:
	cp	r5, maxdsk
	jr	nc, 1f
	sll	r5, #4
	lda	r7, dphtbl(r5)
	ld	r6, _sysseg
	srl r5, #4

	cp  r5, #SUPDISK_ID
	jp  eq, supdisksel     ! jump to supdisk's select routine

	cp  r5, #FLOPDISK_ID
	jp  eq, flop_sel       ! jump to floppy's select routine

	! For romdisk, ramdisk, floppy, just assume they are okay.

    ! For the CF disks, we will have decremented maxdisk if they're
	! not okay.

setdsk_ok:
	ld	setdsk, r5	
	ret
1:
	clr	r6
	clr	r7
	ret

!------------------------------------------------------------------------------
! func10
!   Set Track

func10:
	ld	settrk, r5
	ret

!------------------------------------------------------------------------------
! func11
!   Set Sector

func11:
	ld	setsec, r5
	ret

!------------------------------------------------------------------------------
! func12
!   Set DMA Address

func12:
	ldl	setdma, rr4
	ret

!------------------------------------------------------------------------------
! func13
!   Read Sector

func13:
    ld      r2, setdsk
    cp      r2, #ROMDISK_ID
	jp      eq, flashrd
    cp      r2, #RAMDISK_ID
	jp      eq, ramdiskrd
    cp      r2, #SUPDISK_ID
	jp      eq, supdiskrd	

	call	convLBA
	cpl	rr2, secbLBA
	jr	ne, 1f
	testb	secbvalid
	jr	nz, 2f
1:
	pushl	@r15, rr2	 ! read the sector into the buffer
	call	flush
	ld      r2, setdsk   ! save the current disk
	ld      secbDisk, r2 ! ... into secbDisk
	popl	rr2, @r15
	ldl	    secbLBA, rr2
	lda	    r4, secbuf

    call    diskbufrd

	ldb	    secbvalid, #1
2:
	ld	r1, setsec
	and	r1, #0x0003
	sll	r1, #7		! 128x
	lda	r7, secbuf(r1)
	ld	r6, _sysseg	! rr6 - secbuf address
	ldl	rr4, setdma	! rr4 - DMA address
	ld	r3, #SECSZ
	SEG
	ldirb	@r4, @r6, r3	! data copy to the DMA
	NONSEG
	clrb	secbdirty
	clr	r7
	ret

diskbufrd:
	cp      secbDisk, #FLOPDISK_ID    ! TODO / inefficient / memory compare
	jr      nz, readNotFloppy
	call    flop_read
	ret
readNotFloppy:
	call	diskrd
    ret


!------------------------------------------------------------------------------
! func14
!   Write Sector

func14:
    ld      r2, setdsk
    cp      r2, #ROMDISK_ID
	jp      eq, flashwr
    cp      r2, #RAMDISK_ID
	jp      eq, ramdiskwr
    cp      r2, #SUPDISK_ID
	jp      eq, supdiskwr	

!	pushl    @r15, rr0
!	pushl    @r15, rr4
!	lda      r4, writemsg
!	call     puts
!	ld       r5, r2
!	call     puthex16
!	call     putln
!	popl     rr4, @r15
!	popl     rr0, @r15	

	push 	@r15, r5
	call	convLBA
	cpl	    rr2, secbLBA
	jr	    ne, 1f
	testb	secbvalid
	jr	    nz, 2f
1:
	pushl	@r15, rr2	  ! read the sector into the buffer
	call	flush
	ld      r2, setdsk    ! save the current disk
	ld      secbDisk, r2  ! ... into secbDisk
	popl	rr2, @r15
	ldl	    secbLBA, rr2
	lda	    r4, secbuf
	call	diskbufrd
	ldb	    secbvalid, #1
2:
	ld	    r1, setsec
	and	    r1, #0x0003
	sll	    r1, #7		! 128x
	lda	    r7, secbuf(r1)
	ld	    r6, _sysseg	! rr6 - secbuf address
	ldl     rr4, setdma
	ld	    r3, #SECSZ
	SEG
	ldirb	@r6, @r4, r3
	NONSEG
	ldb	    secbdirty, #1
	pop 	r5, @r15
	cp	    r5, #1
	jr	    ne, 3f      ! XXX smbaker -- always flush
	call	flush
3:
!	pushl    @r15, rr0
!	pushl    @r15, rr4
!	lda      r4, dwmsg
!	call     puts
!	popl     rr4, @r15
!	popl     rr0, @r15
	clr	r7
	ret

!------------------------------------------------------------------------------
! func16 
!   Sector Transrate

func16:
	testl	rr6
	jr	z, 1f
	SEG
	ldb	rl7, r6(r5) 	! ldb  rl7, rr6(r5)
	clrb	rh7
	NONSEG
	ret
1:
	ld	r7, r5
	ret
	
!------------------------------------------------------------------------------
! func21 
!   Flush Buffer

func21:
	call	flush
	clr	r7
	ret

!------------------------------------------------------------------------------
! flush 
!   write back the secbuf to the disk

flush:
	testb	secbdirty
	ret	z		! not modified
	testb	secbvalid
	ret	z		! not valid

    ld      r2, secbDisk
    cp      r2, #ROMDISK_ID
	jp      eq, flashflush
    cp      r2, #RAMDISK_ID
	jp      eq, ramdiskflush
    cp      r2, #SUPDISK_ID
	jp      eq, supdiskflush	

!	pushl    @r15, rr0
!	pushl    @r15, rr4
!	lda      r4, flushmsg
!	call     puts
!	ld       r5, r2
!	call     puthex16
!	call     putln
!	popl     rr4, @r15
!	popl     rr0, @r15

	ldl	    rr2, secbLBA
	lda	    r4, secbuf
	call	diskbufwr
	clrb	secbdirty
	clrb	secbvalid

!	pushl    @r15, rr0
!	pushl    @r15, rr4
!	lda      r4, dfmsg
!	call     puts
!	popl     rr4, @r15
!	popl     rr0, @r15

	ret

diskbufwr:
	cp      secbDisk, #FLOPDISK_ID    ! TODO / inefficient / memory compare
	jr      nz, wrtNotFloppy
	call    flop_write
	ret
wrtNotFloppy:
	call	diskwr
    ret

!------------------------------------------------------------------------------
! convLBA
!   Convert secter and track to LBA
!	input	: (settrk), (setsec) and (setdsk)
!	return	: rr2 - LBA
!		  convert to 00000000-000000dd-ddtttttt-tttsssss

convLBA:
	ld	r3, settrk
	sll	r3, #5
	ld	r2, setsec
	srl	r2, #2
	add	r3, r2
	and	r3, #0x3fff
	ld	r2, setdsk
	sub r2, #FIRSTIDE
	sll	r2, #14
	add	r3, r2
	ld	r2, setdsk
	sub r2, #FIRSTIDE
	srl	r2, #2
	ret

!------------------------------------------------------------------------------
	sect .data
	.even
!------------------------------------------------------------------------------

! Preinitialized variables
maxdsk:
    .word MAXDSK_INITIAL     ! also set this in biosif.s

! Sector Translate Table
!  These parameters are based on the CP/M BIOS writen by Mr.Grant's.
!  Refer to "Grant's homebuilt electronics" Web page.
!  http://http://searle.x10host.com/cpm/index.html 

! 512 tracks total. Two reserved tracks, for boot disk 
dpb_ide:
	.word	128	! SPT	: sectors per track
	.byte	5	! BSH	: block shift
	.byte	31	! BLM	: block mask
	.byte	1	! EXM	: extent mask
	.byte	0	! Dummy
	.word	2039	! DSM	: bloks for data
	.word	511	! DRM	: size of directory
	.byte	0xf0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	0	! CKS	: checksum
	.word	2	! OFF	: Reserved track

! See http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch6.htm
! Each track is 16KB
! TotalTracks=MemKB*1024/128.0/128.0
! DataTracks=TotalTracks-2
! DataBlocks=(DataTracks*128*128/4096.0)-1   # 4K blocks
! DataBlocks=(DataTracks*128*128/2048.0)-1   # 2K blocks


! Two reserved tracks, for boot disk, up to 960 KB, 60 tracks, 2K blocks
dpb_romdisk_2k:
	.word	128	! SPT	: sectors per track
	.byte	4	! BSH	: block shift
	.byte	15	! BLM	: block mask
	.byte	0	! EXM	: extent mask
	.byte	0	! Dummy
	.word	463	! DSM	: bloks for data
	.word	255	! DRM	: size of directory
	.byte	0xF0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	0	! CKS	: checksum
	.word	2	! OFF	: Reserved track

! Two reserved tracks, for boot disk, up to 960 KB, 60 tracks, 4k blocks
dpb_romdisk_4k:
	.word	128	! SPT	: sectors per track
	.byte	5	! BSH	: block shift
	.byte	31	! BLM	: block mask
	.byte	3	! EXM	: extent mask
	.byte	0	! Dummy
	.word	231	! DSM	: bloks for data
	.word	255	! DRM	: size of directory
	.byte	0xC0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	0	! CKS	: checksum
	.word	2	! OFF	: Reserved track	

! Zero reserved tracks, for boot disk, up to 704 KB, 44 tracks
dpb_ramdisk:
	.word	128	! SPT	: sectors per track
	.byte	5	! BSH	: block shift
	.byte	31	! BLM	: block mask
	.byte	3	! EXM	: extent mask
	.byte	0	! Dummy
	.word	176	! DSM	: bloks for data
	.word	255	! DRM	: size of directory
	.byte	0xC0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	0	! CKS	: checksum
	.word	0	! OFF	: Reserved track	

! 512 tracks total. Two reserved tracks, for boot disk 
dpb_supdisk:
	.word	128	! SPT	: sectors per track
	.byte	5	! BSH	: block shift
	.byte	31	! BLM	: block mask
	.byte	1	! EXM	: extent mask
	.byte	0	! Dummy
	.word	2039	! DSM	: bloks for data
	.word	511	! DRM	: size of directory
	.byte	0xf0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	128	! CKS	: checksum -- supdisk is "removable"
	.word	2	! OFF	: Reserved track

! Two reserved tracks, for boot disk, up to 1404 KB, 160 tracks, 2K blocks
dpb_floppy:
	.word	72	! SPT	: sectors per track (18 512B sectors)
	.byte	4	! BSH	: block shift
	.byte	15	! BLM	: block mask
	.byte	0	! EXM	: extent mask
	.byte	0	! Dummy
	.word	710	! DSM	: bloks for data
	.word	255	! DRM	: size of directory
	.byte	0xF0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	64	! CKS	: checksum
	.word	2	! OFF	: Reserved track


!------------------------------------------------------------------------------
! Disk parameter header table

dphtbl:
    .if ENABLE_ROMDISK == 1
	.word	0, 0, 0, 0, dirbuf, dpb_romdisk_2k, csv0, alv0
	.endif

    .if ENABLE_RAMDISK == 1
	.word	0, 0, 0, 0, dirbuf, dpb_ramdisk, csv1, alv1
	.endif

    .if ENABLE_FLOPPY == 1
	.word	0, 0, 0, 0, dirbuf, dpb_floppy, csv1, alv1
	.endif

    .if ENABLE_SUPDISK == 1
	.word	0, 0, 0, 0, dirbuf, dpb_supdisk, csv3, alv3
	.endif		

	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv4, alv4
	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv5, alv5
	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv6, alv6
	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv7, alv7

!------------------------------------------------------------------------------
	sect .bss

!------------------------------------------------------------------------------
! BDOS Scratchpad Area

csv0:	
	.space	128
csv1:	
	.space	128
csv2:	
	.space	128
csv3:	
	.space	128
csv4:
	.space	128
csv5:
	.space	128
csv6:
	.space	128	
csv7:
	.space	128		
	
alv0:
	.space	257
alv1:
	.space	257
alv2:
	.space	257
alv3:
	.space	257
alv4:
	.space	257
alv5:
	.space	257
alv6:
	.space	257
alv7:
	.space	257	

! stuff below better freakin' be word-alinged, or else.
!slack:
!    .space  1

dirbuf:
	.space SECSZ

dskerr:
	.space	2

!------------------------------------------------------------------------------
	
setdsk:
	.space	2
settrk:
	.space	2
setsec:
	.space	2
setdma:
	.space	4

!------------------------------------------------------------------------------
! sector buffer
!
secbuf:
	.space	PSECSZ

sentinel:
    .space  2

secbLBA:
	.space	4
secbDisk:
    .space  2
	
secbvalid:
	.space	1
secbdirty:
	.space	1
secbtrk:
	.space	2
secbdsk:
	.space	2
secbsec:
	.space	2

sect .rodata
  flushmsg:
     .asciz "Flush: "
  dfmsg:
     .asciz "Doneflush\r\n"
  writemsg:
     .asciz "Write: "
  dwmsg:
     .asciz "DoneWrite\r\n"
