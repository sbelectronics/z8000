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
	cp	r5, #MAXDSK
	jr	nc, 1f
	ld	setdsk, r5
	sll	r5, #4
	lda	r7, dphtbl(r5)
	ld	r6, _sysseg
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

	call	convLBA
	cpl	rr2, secbLBA
	jr	ne, 1f
	testb	secbvalid
	jr	nz, 2f
1:
	pushl	@r15, rr2	! read the sector into the buffer
	call	flush
	popl	rr2, @r15
	ldl	    secbLBA, rr2
	lda	    r4, secbuf
	call	diskrd
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

!------------------------------------------------------------------------------
! func14
!   Write Sector

func14:
    ld      r2, setdsk
    cp      r2, #ROMDISK_ID
	jp      eq, flashwr
    cp      r2, #RAMDISK_ID
	jp      eq, ramdiskwr	

	push 	@r15, r5
	call	convLBA
	cpl	rr2, secbLBA
	jr	ne, 1f
	testb	secbvalid
	jr	nz, 2f
1:
	pushl	@r15, rr2	! read the sector into the buffer
	call	flush
	popl	rr2, @r15
	ldl	    secbLBA, rr2
	lda	    r4, secbuf
	call	diskrd
	ldb	    secbvalid, #1
2:
	ld	r1, setsec
	and	r1, #0x0003
	sll	r1, #7		! 128x
	lda	r7, secbuf(r1)
	ld	r6, _sysseg	! rr6 - secbuf address
	ldl	rr4, setdma
	ld	r3, #SECSZ
	SEG
	ldirb	@r6, @r4, r3
	NONSEG
	ldb	secbdirty, #1
	pop 	r5, @r15
	cp	r5, #1
	jr	ne, 3f
	call	flush
3:
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
    ld      r2, setdsk
    cp      r2, #ROMDISK_ID
	jp      eq, flashflush
    cp      r2, #RAMDISK_ID
	jp      eq, ramdiskflush	

	testb	secbdirty
	ret	z		! not modified
	testb	secbvalid
	ret	z		! not valid
	ldl	rr2, secbLBA
	lda	r4, secbuf
	call	diskwr
	clrb	secbdirty
	clrb	secbvalid
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
	sll	r2, #14
	add	r3, r2
	ld	r2, setdsk
	srl	r2, #2
	ret

!------------------------------------------------------------------------------
	sect .data
	.even
!------------------------------------------------------------------------------
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
! Note: stat misreported free space on this one
dpb_romdisk_2k:
	.word	128	! SPT	: sectors per track
	.byte	4	! BSH	: block shift
	.byte	15	! BLM	: block mask
	.byte	0	! EXM	: extent mask
	.byte	0	! Dummy
	.word	463	! DSM	: bloks for data
	.word	511	! DRM	: size of directory
	.byte	0xff	! AL0	: directory allocation bitmap
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
	.word	511	! DRM	: size of directory
	.byte	0xf0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	0	! CKS	: checksum
	.word	2	! OFF	: Reserved track	

! Two reserved tracks, for boot disk, up to 704 KB, 44 tracks
dpb_ramdisk:
	.word	128	! SPT	: sectors per track
	.byte	5	! BSH	: block shift
	.byte	31	! BLM	: block mask
	.byte	3	! EXM	: extent mask
	.byte	0	! Dummy
	.word	176	! DSM	: bloks for data
	.word	511	! DRM	: size of directory
	.byte	0xf0	! AL0	: directory allocation bitmap
	.byte	0	! AL1
	.word	0	! CKS	: checksum
	.word	0	! OFF	: Reserved track	

!------------------------------------------------------------------------------
! Disk parameter header table

dphtbl:
    .if ENABLE_ROMDISK == 1
	.word	0, 0, 0, 0, dirbuf, dpb_romdisk_4k, csv0, alv0
	.endif

    .if ENABLE_RAMDISK == 1
	.word	0, 0, 0, 0, dirbuf, dpb_ramdisk, csv1, alv1
	.endif

    .if ENABLE_FLOPPY == 1
	! TODO ...
	.endif	

	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv3, alv3
	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv4, alv4
	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv5, alv5
	.word	0, 0, 0, 0, dirbuf, dpb_ide, csv6, alv6

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

dirbuf:
	.space SECSZ

dskerr:
	.space	2

!------------------------------------------------------------------------------
	!.space 1024
	
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
	
secbLBA:
	.space	4
	
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
