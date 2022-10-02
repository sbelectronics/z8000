! ************ biosdefs.s ******************************************************
! *
! *	Assembly language definitions for
! *	CP/M-8000 (tm) BIOS
! *
! * 821013 S. Savitzky (Zilog) -- created.
! *
! * 20200211 4sun5bu -- modified for assembling with GNU as 

    .include "../common/board.s"

! ******************************************************************************
! *
! * System Calls and Trap Indexes
! *
! ******************************************************************************

	.equ	XFER_SC, 1
	.equ	MEM_SC, 1
	.equ	BIOS_SC, 3
	.equ	BDOS_SC, 2

    	! * the traps use numbers similar to those in the
    	! * 68K version of P-CP/M
	.equ	NTRAPS, 48		! total number of traps
	.equ	SC0TRAP, 32	! trap # of system call 0

	! Z8000 traps
	.equ	NMITRAP, 0		! non-maskable int.
	.equ	EPUTRAP, 1		! EPU (floating pt. emulator)
	.equ	SEGTRAP, 2		! segmentation (68K bus err)
	.equ    NVITRAP, 3      ! non-vectored interrupt (XXX smbaker - no idea how to pick the number here)
	.equ	PITRAP, 8		! priviledge violation
	! Interrupts, etc.
	.equ	TRACETR, 9		! trace

! ****************************************************
! *
! * C Stack frame equates
! *
! *	A C stack frame consists of the PC on top,
! *	followed by the arguments, leftmost argument first.
! *
! *	The caller adjusts the stack on return.
! *	Returned value is in r7 (int) or rr6 (long)
! *
! ****************************************************

	.equ	PCSIZE, 2		! PC size non-segmented
	.equ	INTSIZE, 2		! INT data type size
	.equ	LONGSIZE, 4		! LONG data type size

	.equ	ARG1, PCSIZE		! integer arguments
	.equ	ARG2, ARG1+INTSIZE
	.equ	ARG3, ARG2+INTSIZE
	.equ	ARG4, ARG3+INTSIZE
	.equ	ARG5, ARG4+INTSIZE

! ******************************************************************************
! *
! * Segmented Mode Operations
! *
! *	NOTE:   segmented indirect-register operations
! *		can be done by addressing the low half
! *		of the register pair.
! *
! ******************************************************************************

! START segmented mode
! r0 destroyed.
	.macro SEG
	ldctl	r0, fcw
	set	r0, #15
	ldctl	FCW, r0
	.endm

! END segmented mode
! r0 destroyed.
	.macro NONSEG
	ldctl	r0, fcw
	res	r0, #15
	ldctl	FCW, r0
	.endm

! (segaddr) segmented CALL
	.macro scall
	.word	0x5F00
	.long	?1	! bit 31 need to be 1
	.endm

! (|segaddr|) short segmented CALL
	.macro sscall
	.word 0x5F00
	.word ?1	! bit 15 need to be 0
	.endm

! ******************************************************************************
! *
! * System Call Trap Handler Stack Frame
! *
! ******************************************************************************

	.equ	cr0, 0		! WORD	caller r0
	.equ	cr1, cr0+2	! WORD	caller r1
	.equ	cr2, cr1+2	! WORD	caller r2
	.equ	cr3, cr2+2	! WORD	caller r3
	.equ	cr4, cr3+2	! WORD	caller r4
	.equ	cr5, cr4+2	! WORD	caller r5
	.equ	cr6, cr5+2	! WORD	caller r6
	.equ	cr7, cr6+2	! WORD	caller r7
	.equ	cr8, cr7+2	! WORD	caller r8
	.equ	cr9, cr8+2	! WORD	caller r9
	.equ	cr10, cr9+2	! WORD	caller r10
	.equ	cr11, cr10+2	! WORD	caller r11
	.equ	cr12, cr11+2	! WORD	caller r12
	.equ	cr13, cr12+2	! WORD	caller r13
	.equ	nr14, cr13+2	! WORD	normal r14
	.equ	nr15, nr14+2	! WORD	normal r15
	.equ	scinst, nr15+2	! WORD	SC instruction
	.equ	scfcw, scinst+2	! WORD	caller FCW
	.equ	scseg, scfcw+2	! WORD	caller PC SEG
	.equ	scpc, scseg+2	! WORD	caller PC OFFSET

	.equ	FRAMESZ, scpc+2

!------------------------------------------------------------------------------
!  Disk parameter definitions
!
	.equ	MAXDSK_INITIAL, ENABLE_ROMDISK + ENABLE_RAMDISK + ENABLE_FLOPPY + ENABLE_SUPDISK + 4  ! number of disks

    .if ENABLE_ROMDISK == 1
	.equ    ROMDISK_ID, 0                                                ! disk number of first romdisk
	.equ    ROMDISK_LETTER, ROMDISK_ID + 'A'
	.else
	.equ    ROMDISK_ID, 0xFF
	.equ    ROMDISK_LETTER, 0xFF
	.endif

    .if ENABLE_RAMDISK == 1
	.equ    RAMDISK_ID, ENABLE_ROMDISK                                   ! disk number of first ramdisk
	.equ    RAMDISK_LETTER, RAMDISK_ID + 'A'
	.else
	.equ    RAMDISK_ID, 0xFF
	.equ    RAMDISK_LETTER, 0xFF
	.endif

    .if ENABLE_FLOPPY == 1
	.equ    FLOPDISK_ID, ENABLE_ROMDISK + ENABLE_RAMDISK                 ! disk number of first floppy
	.equ    FLOPDISK_LETTER, FLOPDISK_ID + 'A'
	.else
	.equ    FLOPDISK_ID, 0xFF	
	.equ    FLOPDISK_LETTER, 0xFF
	.endif

    .if ENABLE_SUPDISK == 1
	.equ    SUPDISK_ID, ENABLE_ROMDISK + ENABLE_RAMDISK + ENABLE_FLOPPY  ! disk number of first floppy
	.equ    SUPDISK_LETTER, SUPDISK_ID + 'A'		
	.else
	.equ    SUPDISK_ID, 0xFF
	.equ    SUPDISK_LETTER, 0xFF
	.endif	

	.equ    FIRSTIDE, ENABLE_ROMDISK + ENABLE_RAMDISK + ENABLE_FLOPPY + ENABLE_SUPDISK   ! disk number of the first IDE disk
	.equ    FIRSTIDE_LETTER, FIRSTIDE + 'A'

	.equ	SECSZ, 128                                                   ! sector size
	.equ	PSECSZ, 512                                                  ! for fetching blocks to/from IDE


