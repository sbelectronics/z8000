! This file contains defines relating to the construction of the board itself.
! various features, baudrate and crystal selections, etc.

    ! Constants for various crystal and baud combinations. Do not edit
	! these -- go a little further down and set SCC_BRG.

    .equ SCC_BRG_4800_49152MHz, 30  ! 4800 baud using 4.9152Mhz crystal
    .equ SCC_BRG_9600_49152MHz, 14  ! 9600 baud using 4.9152Mhz crystal	
    .equ SCC_BRG_19200_49152MHz, 6  ! 19200 baud using 4.9152Mhz crystal	
    .equ SCC_BRG_38400_49152MHz, 2  ! 38400 baud using 4.9152Mhz crystal	
    .equ SCC_BRG_4800_6MHz, 37      ! 4800 baud using 6Mhz crystal
    .equ SCC_BRG_9600_6144MHz, 18   ! 9600 baud using 6.144MHz crystal
    .equ SCC_BRG_19200_6144MHz, 8   ! 19200 baud using 6.144MHz crystal
    .equ SCC_BRG_38400_6144MHz, 3   ! 38400 baud using 6.144MHz crystal
    .equ SCC_BRG_4800_73728MHz, 46  ! 4800 baud using 7.3727Mhz crystal
    .equ SCC_BRG_9600_73728MHz, 22  ! 9600 baud using 7.3727Mhz crystal
    .equ SCC_BRG_19200_73728MHz, 10 ! 19200 baud using 7.3727Mhz crystal
    .equ SCC_BRG_38400_73728MHz, 4  ! 38400 baud using 7.3727Mhz crystal
    .equ SCC_BRG_4800_9216MHz, 58   ! 4800 baud using 9.216Mhz crystal
    .equ SCC_BRG_9600_9216MHz, 28   ! 9600 baud using 9.216Mhz crystal
    .equ SCC_BRG_19200_9216MHz, 13  ! 19200 baud using 9.216Mhz crystal

	! Set the constant for the baud rate generator below to one of the
	! above.
	!
	! If you used a separate crystal for the SCC, this is the value of
	! the crystal you're using for the SCC, not the crystal for the CPU 

	.equ SCC_BRG, SCC_BRG_9600_73728MHz
	!.equ SCC_BRG, SCC_BRG_9600_49152MHz

! ******************************************************************************
!	if ID_SPLIT = 1, I and D space split supported		
! ******************************************************************************	
    .equ PLATFORM_SMBAKER, 1
	.equ ID_SPLIT, 1

! ******************************************************************************
!	Enable the disks you want to use
! ******************************************************************************	
	.equ ENABLE_ROMDISK, 1
	.equ ENABLE_RAMDISK, 1
	.equ ENABLE_FLOPPY, 0
    .equ ENABLE_SUPDISK, 1
    .equ ENABLE_CFDISK, 1
