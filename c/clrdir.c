/*
 * clrdir.c: clrdir for z8000, scott baker
 * 
 * Based loosly on code taken from PUTBOO.C.
 * 
 * If you have stumbled on this while looking for the clrdir source
 * for Z-80 based distributions (ROMWBW, RC2014, etc) then you are
 * probably in the wrong place. This is for Z-8000 / Z8K 16-bit Zilog
 * CPUs only.
 * 
 * zcc clrdir.c
 * ld8k -w -s -o clrdir.z8k startup.o clrdir.o -lcpm
 */
#include "stdio.h"
#include "cpm.h"

/* CP/M-8000 turn off stuff we don't need. It only saves about 4K. */
#include "option.h"
NOLONG NOFLOAT NOTTYIN NOFILESZ NOWILDCARDS NOASCII NOBINARY

extern long __BDOS();   /* BDOS entry point    */

#define XADDR	long				/* 32-bit address data type */

#define CDATA	0			/* Parameter for map_adr()	    */
#define DIRSEC	1			/* Parameter for BIOS Write call    */

#define SETTRK	10			/* BIOS Function 10 = Set Track	    */
#define SETSEC	11			/* BIOS Function 11 = Set Sector    */
#define BSETDMA	12			/* BIOS Function 12 = Set DMA Addr  */
#define WSECTOR	14			/* BIOS Function 14 = Write Sector  */

#define SEL_DISK        14                      /* Select disk              */
#define RET_CDISK	    25           			/* Return current disk      */
#define GET_DPB		    31			/* Get disk parameters      */
#define BIOS_CALL       50                      /* Direct call to BIOS      */

#define _sel_disk(a)    (__BDOS(SEL_DISK, (long) (a)))
#define _ret_cdisk()	(__BDOS(RET_CDISK, (long) 0))
#define _get_dpb(a)	    (__BDOS(GET_DPB, (long) (a)))
#define _bios_call(a)   (__BDOS(BIOS_CALL, (long) (a)))

struct  dpbs                                    /* Disk parameter block     */
        {
                UWORD   spt;                    /* Sectors per track        */
                BYTE    bls;                    /* Block shift factor       */
                BYTE    bms;                    /* Block mask               */
                BYTE    exm;                    /* Extent mark              */
        /*      BYTE    filler;                  ***  Pad to align words  ***/
                UWORD   mxa;                    /* Maximum allocation (blks)*/
                UWORD   dmx;                    /* Max directory entries    */
                UWORD   dbl;                    /* Directory alloc. map     */
                UWORD   cks;                    /* Directory checksum       */
                UWORD   ofs;                    /* Track offset from track 0*/
        };

struct bios_parm                                /* BIOS parameters for BDOS */
        {                                       /*   call 50                */
                UWORD   req;                    /* BIOS request code        */
                LONG    p1;                     /* First parameter          */
                LONG    p2;                     /* Second parameter         */
        };

EXTERN XADDR map_adr();

struct	dpbs	idpb;			/* Disk Parameter Block		    */
struct	bios_parm ibp;			/* BIOS param block for BDOS call 50*/
XADDR	physibp;			    /* physical address of ibp structure*/
int	    dsknum;			        /* Drive number 0-15 = A-P  */
char    secbuf[128];

#define FILL_BYTE 0xE5

banner()
{
    printf("clrdir for Z8000, by Scott Baker\n");
}

usage()
{
    printf("syntax: clrdir <letter>\n");
    exit(1);
}

main(argc,argv)
int	argc;
char	*argv[];
{
	register int	i, j, c;
	register char	*p;
	int	curdsk;				/* Good to remember, & reset*/
    int nsec;
    int trk;
    int sec;

    banner();
	if(argc != 2) usage();

    for (i=0; i<128; i++) {
        secbuf[i] = FILL_BYTE;
    }

    physibp = map_adr( (long) &ibp, CDATA );

	if( (dsknum = **++argv - 'a') < 0 || dsknum > 15) {
		printf("clrdir: Illegal drive code %c\n", *argv[0]);
		exit(1);
	}
	curdsk = _ret_cdisk();
    _sel_disk(dsknum);
	_get_dpb(map_adr((long) &idpb, CDATA));	/* Physaddr of idpb */

    printf("Disk %d has %d sectors per track, %d directory entries, and %d reserved tracks\n", dsknum, idpb.spt, idpb.dmx, idpb.ofs);

    nsec = idpb.dmx*32/128;     /* number of sectors to write */

    ibp.req = BSETDMA;		    /* BIOS Request number 12 */
    ibp.p1 = map_adr( (long) secbuf, CDATA);
                                /* param = seg address of I/O buffer */
    _bios_call( physibp );		/* Call BIOS */    

    trk = idpb.ofs;
    sec = 0;
    for (i=0; i<nsec; i++) {
        register int	n;

        /* printf("Erasing disk %d trk %d sec %d\n", dsknum, trk, sec);  too noisy ... */

        _sel_disk(dsknum);		/* select as current disk */

	    ibp.req = SETTRK;		/* BIOS request number 10 */
	    ibp.p1 = (long) trk;	/* parameter = track # */
	    _bios_call( physibp );	/* Pass seg ibp address */

        /* PUTBOO led me to believe the sector numbers were
         * 1-based, but I found them to be 0-based. I think. It's confusing.
         */

        ibp.req = SETSEC;		/* BIOS request number 11 */
        ibp.p1 = (long) sec;    /* parameter = sector # */
        _bios_call( physibp );	/* Pass seg ibp address */

        /* Now can do a write */

        ibp.req = WSECTOR;		/* BIOS Request number 14 */
        ibp.p1 = DIRSEC;		/* Complete write immediately */
        _bios_call( physibp );  /* Do it! */

        sec++;
        if (sec >=  idpb.spt) {
            sec = 0;
            trk += 1;
        }
    }
    printf("Directory Erased\n");
    _sel_disk(curdsk);
}
