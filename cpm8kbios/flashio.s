!------------------------------------------------------------------------------
! flashio.s
!   Disk I/O subroutines 
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .extern	_sysseg,
	.extern puts, puthex16, putln
	.extern setdma, settrk, setsec

	.global	flashrd, flashwr, flashflush, flashinit
	.global ramdiskrd, ramdiskwr, ramdiskflush, ramdiskinit

	unsegm
	sect	.text

	! segments
	.equ    FLASH_SEG, 0x40	
	

!------------------------------------------------------------------------------
!  flashrd
!    One sector read
!    input  rr2 --- LBA
!	    r4  --- Buffer Address
!    destroys
!       rr2
!       rr4

flashrd:
    call     convOffset       ! get byte address in rr2
	addb     rh2, #FLASH_SEG  ! add the base segment of the ramdisk
	ldl	     rr4, setdma	  ! rr4 - DMA address	
	ld    	 r7, #SECSZ

	SEG
	ldirb	 @r4, @r2, r7	  ! data copy to the DMA
	NONSEG

	clr	r7
	ret

!------------------------------------------------------------------------------
!  flashwr
!    One sector write
!    input rr2 --- LBA
!	    r4 --- Buffer Address

flashwr:
    ld       r7, 1            ! return error
	ret

!------------------------------------------------------------------------------
!  flashflush
!    Does absolutely nothing...

flashflush:
    ld       r7, 0            ! nothing here to do...
	ret

! erase the ramdisk. Assumes all dir entries are in the first segment
flashinit:
	ldb     rl5, #ROMDISK_LETTER
	call    scc_out
	lda     r4, romdiskmsg
	call    puts	
	ret


!------------------------------------------------------------------------------
!  ramdiskrd
!    One sector read
!    input
!	    r4  --- Buffer Address
!    destroys
!       rr2
!       rr4

ramdiskrd:
    call     convOffsetRamDisk ! get byte address in rr2

    ! diagnostics
    !pushl   @r15, rr4   ! save r4/r5
    !lda     r4, rdrammsg
	!call    puts
	!ld      r5, r2
	!call    puthex16
	!ld      r5, r3
	!call    puthex16
	!call    putln
	!popl    rr4, @r15   ! restore r4/r5

	ldl	     rr4, setdma	  ! rr4 - DMA address	
	ld    	 r7, #SECSZ

	SEG
	ldirb	 @r4, @r2, r7	  ! data copy to the DMA
	NONSEG

	clr	r7
	ret

!------------------------------------------------------------------------------
!  ramdiskwr
!    One sector write
!    input
!	    r4  --- Buffer Address
!    destroys
!       rr2
!       rr4

ramdiskwr:
    call     convOffsetRamDisk ! get byte address in rr2
	ldl	     rr4, setdma	  ! rr4 - DMA address	
	ld    	 r7, #SECSZ

	SEG
	ldirb	 @r2, @r4, r7	  ! data copy from the DMA
	NONSEG

	clr	r7
	ret

ramdiskflush:
    ld       r7, 0            ! nothing here to do...
	ret

! erase the ramdisk. Assumes all dir entries are in the first segment
ramdiskinit:
    ldl     rr2, #0x04000000
	ld      r7, 0
	SEG
nextbyte:
    ldb      @r2, #0xE5
	inc      r3, #1
	djnz     r7, nextbyte
	NONSEG
	ldb     rl5, #RAMDISK_LETTER
	call    scc_out
	lda     r4, ramdiskmsg
	call    puts	
	ret


!------------------------------------------------------------------------------
! convOffset
!   Convert secter and track to LBA
!	input	: (settrk), (setsec) and (setdsk)
!	return	: rr2 - LBA
!         0ttttttt-00000000-ttsssss0-00000000
convOffset:
	ld	    r3, settrk
	sll	    r3, #7
	ld	    r2, setsec
	add	    r3, r2
	ld      r2, #0
    ! rr2 is now 00000000-00000000-tttttttt-tsssssss
	slll    rr2, #7        ! Convert sector addr to byte addr
	! rr2 is now 00000000-0ttttttt-ttssssss-s0000000
	sll     r2, #8         ! Shift the segment into the uuper 8 bits
	! rr2 is now 0ttttttt-00000000-ttsssss0-00000000
	ret

! The ramdisk needs to avoid using the pages that we're using for regions for CPM
! programs. So, we call the same convOffset for the romdisk, and then we translate
! the segment numbers to avoid the problematic ones.
convOffsetRamDisk:
    call    convOffset
	srl     r2, #8
	ldb     rl2, ramdisk_map(r2)
	sll     r2, #8
	ret

! Funny note on the Ramdisk -- I couldn't figure out why ZCC kept failing, and
! it turned out to be because I put the ramdisk's hole at block 8 instead of
! block 9. 

!------------------------------------------------------------------------------
	sect	.rodata
ramdisk_map:
    .byte   4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15   ! hole at page 9 because that's our Data split-I/D seg

romdiskmsg:
    .asciz  ": ROM disk\r\n"
ramdiskmsg:
    .asciz  ": RAM disk\r\n"

rdrammsg:
	.asciz	"Ram Read offset "	

