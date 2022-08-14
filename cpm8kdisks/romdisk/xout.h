struct x_hdr {
	short	x_magic;	/* magic number */
	short	x_nseg;		/* number of segments in file */
	long	x_init;		/* length of initialized part of file */
	long	x_reloc;	/* length of relocation part of file */
	long	x_symb;		/* length of symbol table part of file */
};


struct x_sg {
	char	x_sg_no;	/* assigned number of segment */
	char	x_sg_typ;	/* type of segment */
	unsigned x_sg_len;	/* length of segment */
}	x_sg[];			/* array of size x_nseg */


#define X_SU_MAGIC	0xEE00	/* segmented, non executable */
#define	X_SX_MAGIC	0xEE01	/* segmented, executable */
#define X_NU_MAGIC	0xEE02	/* non-segmented, non executable */
#define X_NXN_MAGIC	0xEE03	/* non-segmented, executable, non-shared */
#define X_NUS_MAGIC	0xEE06  /* non-segmented, non-executable shared */
#define X_NXS_MAGIC	0xEE07	/* non-segmented, executable, shared */
#define X_NUI_MAGIC 	0xEE0A	/* non-segmented, non-executable split ID */ 
#define X_NXI_MAGIC	0xEE0B	/* non-segmented, executable, split ID */

#define X_SG_BSS	1	/* non-initialized data segment */
#define X_SG_STK	2	/* stack segment, no data in file */
#define X_SG_COD	3	/* code segment */
#define X_SG_CON	4	/* constant pool */
#define X_SG_DAT	5	/* initialized data */
#define X_SG_MXU	6	/* mixed code and data, not protectable */
#define X_SG_MXP	7	/* mixed code and data, protectable */

struct x_rel {			/* relocation item */
	char	x_rl_sgn;	/* segment containing item to be relocated */
	char	x_rl_flg;	/* relocation type (see below) */
	unsigned x_rl_loc;	/* location of item to be relocated */
	unsigned x_rl_bas;	/* number of (external) element in symbol table
			          or (internal) segment by which to relocate */
};


#define X_RL_OFF	1	/* adjust a 16 bit offset value only */
#define X_RL_SSG	2	/* adjust a short form segment plus offset */
#define X_RL_LSG	3	/* adjust a long form (32 bit) seg plus off */
#define X_RL_XOF	5	/* adjust a 16 bit offset by an external */
#define X_RL_XSSG	6	/* adjust a short seg ref by an external */
#define X_RL_XLSG	7	/* adjust a long seg ref by an external */

#define XNAMELN	8		/* length of a symbol */

struct x_sym {
	char	x_sy_sg;	/* the segment number */
	char	x_sy_fl;	/* the type of entry */
	unsigned x_sy_val;	/* the value of this entry */
	char	x_sy_name[XNAMELN];	/* the symbol name, padded with 0's */
};

#define X_SY_LOC	1	/* local symbol (for debug only) */
#define X_SY_UNX	2	/* undefined external entry */
#define X_SY_GLB	3	/* global definition */
#define X_SY_SEG	4	/* segment name */

