!------------------------------------------------------------------------------
! supdsk.s
!   SuperDisk - disk using raspi supervisor
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .extern	_sysseg,
	.extern puts, puthex16, putln
	.extern setdma, settrk, setsec

	.global	supdiskrd, supdiskwr, supdiskflush, supdiskinit

	unsegm
	sect	.text
	

!------------------------------------------------------------------------------
!  suprd
!    One sector read
!    input
!	    r4  --- Buffer Address
!    destroys
!       rr2
!       rr4

supdiskrd:
	ld       r7, supdisk_cmd  ! pi will write 0x80, 0x81 or 0x82
	or       r7, r7
	jr       nz, rdokay
	outb     #0x50, rl7
    ld       r7, 1            ! not enabled; return error
	ret

rdokay:
	outb     #0x50, rl7
    call     supSecOffs       ! get byte address in rr2
    ldl      supdisk_addr, rr2
	ld       supdisk_cmd, #1
waitrd:
    cp       supdisk_cmd, #0x81
	jr       nz, waitrd

    lda      r3, supdisk_buf  ! rr2 - SRC supdisk buffer address
	ld       r2, _sysseg
	ldl	     rr4, setdma	  ! rr4 - DMA address
	ld    	 r7, #SECSZ
	SEG
	ldirb	 @r4, @r2, r7	  ! data copy to the DMA
	NONSEG

	clr	r7
	ret

!------------------------------------------------------------------------------
!  supwr
!    One sector write
!    input
!	    r4 --- Buffer Address

supdiskwr:
	ld       r7, supdisk_cmd  ! pi will write 0x80, 0x81 or 0x82
	or       r7, r7	
	jr       nz, wrokay
    ld       r7, 1            ! not enabled; return error
	ret

wrokay:
    call     supSecOffs       ! get byte address in rr2
    ldl      supdisk_addr, rr2

    lda      r3, supdisk_buf  ! rr2 - DEST supdisk buffer address
	ld       r2, _sysseg
	ldl	     rr4, setdma	  ! rr4 - SRC DMA address
	ld    	 r7, #SECSZ
	SEG
	ldirb	 @r2, @r4, r7	  ! data copy from DMA to buffer
	NONSEG

	ld       supdisk_cmd, #2
waitwr:
    cp       supdisk_cmd, #0x82
	jr       nz, waitwr	

    clr r7
	ret

!------------------------------------------------------------------------------
!  supflush
!    Does absolutely nothing...

supdiskflush:
    ld       r7, 0            ! nothing here to do...
	ret

! erase the ramdisk. Assumes all dir entries are in the first segment
supdiskinit:
	ldb     rl5, #SUPDISK_LETTER
	call    scc_out
	lda     r4, supdiskmsg
	call    puts	
	ret


!------------------------------------------------------------------------------
supSecOffs:
	ld	    r3, settrk
	sll	    r3, #7
	ld	    r2, setsec
	add	    r3, r2
	ld      r2, #0
    ! rr2 is now 00000000-00000000-tttttttt-tsssssss
	ret

!------------------------------------------------------------------------------
	sect .data
	.even

supdisk_marker:
    .word 0x73E7    ! just makde something up to make supdisk easy to find
	.word 0xF912
	.word 0xA320
	.word 0xBB49

supdisk_cmd:
    .space 2

supdisk_addr:
    .space 4

supdisk_buf:
    .space 128

!------------------------------------------------------------------------------
	sect	.rodata

supdiskmsg:
    .asciz  ": Super disk\r\n"

