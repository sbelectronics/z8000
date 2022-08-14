/****************************************************************************/
/*									    */
/*			    s e t j m p . h				    */
/*			    ---------------				    */
/*									    */
/*		Copyright 1984, Digital Research Inc.			    */
/*									    */
/*	Definitions for setjmp and longjmp non-local goto library functions.*/
/*	jmp_buf is large enough to hold copies of the eight "safe"	    */
/*	registers and a segmented return address.  Thus the last word is    */
/*	not used in non-segmented environments				    */
/*									    */
/****************************************************************************/

typedef int jmp_buf[10];

extern int setjmp(), longjmp();

