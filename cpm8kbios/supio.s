!------------------------------------------------------------------------------
! supdsk.s
!   SuperDisk - disk using raspi supervisor
!
!   Copyright(c) 2022 smbaker

	.include "biosdef.s"

    .extern	_sysseg,
	.extern puts, puthex16, putln
	.extern setdma, settrk, setsec

	.global	supdiskrd, supdiskwr, supdiskflush, supdiskinit, supdisksel

	unsegm
	sect	.text
	

!------------------------------------------------------------------------------
!  suprd
!    One sector read
!    input
!    destroys
!       rr2
!       rr4

supdiskrd:
	ld       r7, supdisk_cmd  ! pi will write 0x80, 0x81 or 0x82
	or       r7, r7
	jr       nz, rdokay
    ld       r7, 1            ! not enabled; return error
	ret

rdokay:
    call     supSecOffs       ! get byte address in rr2
    ldl      supdisk_addr, rr2
	ldl	     rr4, setdma	  ! rr4 - SRC DMA address	
	bit      r5, #0
    jr       nz, rd_hardway   ! Ugghhhh... it's not word-aligned

	ldl      supdisk_dma, rr4

	ld       supdisk_cmd, #1
	ld       r3, #0x73E7      ! magic values to wake up super
	ld       r7, #0xF912

waitrd:
	ld       supdisk_junk, r3 ! wake up super early
	ld       supdisk_junk, r7
    cp       supdisk_cmd, #0x81
	jr       nz, waitrd

	clr	r7
	ret

!------------------------------------------------------------------------------
! it wasn't word-aligned... do double-buffer

rd_hardway:
    ld       r2, _sysseg      ! supdisk will write to supdisk_buf
	lda      r3, supdisk_buf
	ldl      supdisk_dma, rr2

	ld       supdisk_cmd, #1
	ld       r3, #0x73E7      ! magic values to wake up super
	ld       r7, #0xF912

waithrd:
	ld       supdisk_junk, r3 ! wake up super early
	ld       supdisk_junk, r7
    cp       supdisk_cmd, #0x81
	jr       nz, waithrd

    ld       r2, _sysseg      ! copy from supdisk_buf to setdma
	lda      r3, supdisk_buf
    ldl      rr4, setdma
    ld       r7, #SECSZ
    SEG
    ldirb    @r4, @r2, r7     ! data copy to the DMA
    NONSEG

	clr	r7
	ret

!------------------------------------------------------------------------------
!  supwr
!    One sector write

supdiskwr:
	ld       r7, supdisk_cmd  ! pi will write 0x80, 0x81 or 0x82
	or       r7, r7	
	jr       nz, wrokay
    ld       r7, 1            ! not enabled; return error
	ret

wrokay:
    call     supSecOffs       ! get byte address in rr2
    ldl      supdisk_addr, rr2
	ldl	     rr4, setdma	  ! rr4 - SRC DMA address	
	bit      r5, #0
    jr       nz, wr_hardway   ! Ugghhhh... It's not word-aligned

	ldl      supdisk_dma, rr4

wrexec:
	ld       supdisk_cmd, #2
	ld       r3, #0x73E7      ! magic values to wake up super
	ld       r7, #0xF912	
waitwr:
	ld       supdisk_junk, r3 ! wake up super early
	ld       supdisk_junk, r7
    cp       supdisk_cmd, #0x82
	jr       nz, waitwr

    clr r7
	ret

!------------------------------------------------------------------------------
! it wasn't word-aligned... do double-buffer

wr_hardway:
    lda      r3, supdisk_buf  ! rr2 - copy to supdisk buffer address
    ld       r2, _sysseg
	ldl      supdisk_dma, rr2 ! this is also where supdisk reads from

	ldl      rr4, setdma      ! rr4 - copy from DMA address
    ld       r7, #SECSZ
    SEG
    ldirb    @r2, @r4, r7     ! data copy from DMA to buffer
    NONSEG

	jr       wrexec           ! now hop back and continue the write

!------------------------------------------------------------------------------
!  supflush
!    Does absolutely nothing...

supdiskflush:
    ld       r7, 0            ! nothing here to do...
	ret

!------------------------------------------------------------------------------
! supinit
!   print the message

supdiskinit:
	ldb     rl5, #SUPDISK_LETTER
	call    scc_out
	lda     r4, supdiskmsg
	call    puts	
	ret

!------------------------------------------------------------------------------
! supdisksel
!   input:
!     rr6 disk table entry
!     r5 disk number - preserve this!
!   exit:
!     if supdisk not initialized, clear rr6 and return
!     if supdisk is initialized, then jump back to setdsk_ok

supdisksel:
    test     supdisk_cmd      ! pi will write 0x80, 0x81 or 0x82
	jr       nz, selok
	clr      r6
	clr      r7
	ret
selok:
    jp       setdsk_ok

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

supdisk_dma:
    .space 4

supdisk_junk:       ! write stuff here to wake up the supervisor fast
    .space 2

supdisk_buf:        ! in case it's
    .space 128

!------------------------------------------------------------------------------
	sect	.rodata

supdiskmsg:
    .asciz  ": Super disk\r\n"

