/* From Chuck(G)'s BSD Tape. Thanks Chuck!
 *
 * Modified by Scott Baker, www.smbaker.com, for Z8000 computer, 2022.
 * 
 * If V10 is defined, will output original format maze. If undefined,
 * will output what I observed to be V11 format (from the convervent
 * miniframe)
 * 
 * zcc maze.c
 * ld8k -w -s -o maze.z8k startup.o maze.o -lcpm
 */

#include <stdio.h>

#ifdef LINUX
#include <string.h>
#else
/* CP/M-8000 turn off stuff we don't need. It only saves about 4K. */
#include "option.h"
NOLONG NOFLOAT NOTTYIN NOFILESZ NOWILDCARDS NOASCII NOBINARY
#endif

long seed = 1;

/* random nunmber - may be machine dependent */
unsigned short roll(amount)
unsigned short amount;
{
    long int a = 16807L, m = 2147483647L, q = 127773L, r = 2836L;
    long int lo, hi, test;

    hi = seed / q;
    lo = seed % q;
    test = a * lo - r * hi;
    if (test > 0) 
		    seed = test; /* test for overflow */
    else 
		    seed = test + m;
    return(seed % amount);
}

/*  for string <a>, returns the integer value represented.  Leading blank */
/*  space is ignored.  The result is undefined if <a> contains any funny stuff*/
long fii(a)
char a[];
{
        int i,n,s;

        for(i=0; a[i]==' ' || a[i]=='\n' || a[i]=='\t'; i++);
        s=1;
        if (a[i]=='+' || a[i]=='-') {s=(a[i]=='+')?1:-1; ++i;}
        for(n=0; a[i]>='0' && a[i]<='9'; i++) n=10*n+a[i]-'0';
        n=n*s;
        if (a[i] != '.') return (n);
        ++i;
        if (a[i]>='0' && a[i]<'5') return (n);
        if (a[i]>'4' && a[i]<='9') return (n+s);
        return 0;
}

/* for string <a> , returns integer boolean indicating whether or not <a>   */
/* represents a valid number.  Leading and trailing white space is ignored. */
int vi(a)
char a[];
{
        int i;
        for(i=0; a[i]==' ' || a[i]=='\n' || a[i]=='\t'; i++) ;
        i+=a[i]=='+' || a[i]=='-';
        for(;a[i]>='0' && a[i]<='9';i++) ;
        if (a[i]=='.') {++i; for(;a[i]>='0' && a[i]<='9';i++) ;}
        for(;a[i]==' ' || a[i]=='\n' || a[i]=='\t'; i++) ;
        return (a[i]=='\0');
}

int help()
{
   printf("Maze Generator!\n\n");
   printf("syntax: maze [rows columns] [seed]\n");
   printf("        maze -h ... show help\n");
}

int main(argc,argv)
int argc; 
char *argv[];
{
	int a,c,e,f,g,i,j,k,q,r,s,t,u,v;
	int d[4],h[4],m[4],n[10000],o[4],o2[4],p[4],z[5000],w[4];
	char x,y;
	r = 40;
	c = 40;
	/* a pretty terrible command-line parser... */
	if (argc == 1) {
        /* default rows and columns */
	} else if (argc == 2) {
		if ((strcmp(argv[1], "-h")==0) || (strcmp(argv[1], "-H")==0)) {
			help();
			return -1;
		}
		seed=fii(argv[1])*vi(argv[1]);
	} else if (argc == 3) {
   	    r=fii(argv[1])*vi(argv[1]); 
	    c=fii(argv[2])*vi(argv[2]);
	} else if (argc == 4) {
   	    r=fii(argv[1])*vi(argv[1]); 
	    c=fii(argv[2])*vi(argv[2]);
		seed=fii(argv[3])*vi(argv[3]);
	} else {
		help();
		return -1;
	}
	if (r*c == 0) {
		printf("domain error\n"); 
		return -1;
	}
	i=r*c; 
	e=j=v=0; 
	for(s=0; s<i; ++s) z[s]=0;  
	for(s=0; s<i+i; ++s) n[s]=0;
	o2[3]=z[0]=u=2; 
	z[n[1]=i-1]=24; 
	for(s=0; s<4; ++s) o[s]=1<<s;
	o2[0]=4; 
	o2[1]=8; 
	o2[2]=1; 
	m[0]=1; 
	m[1]=(-c); 
	m[2]=(-1); 
	m[3]=c; 
	goto lb;
la:
	s=1+roll(k); 
	t=0; 
	for(a=0; a<4; ++a) {
		t+=p[a]&&h[a]; 
		if(s==t) break;
	}
	q=z[e=d[a]]; 
	j=(q>j)?q:j; 
	z[g]=o[a]+f;
	z[e]=o2[a]+q+(j||f<16 ?0:16); 
	if (k!=1) n[u++]=e;
lb:
	for(s=k=0; s<4; ++s) {
		t=d[s]=e+m[s]; 
		if (t<0 || t>=i) h[s]=0; 
		else {
			switch (s) {
			case 0:
			case 2: 
				h[s]=(t/c == e/c)?1:0; 
				break;
			case 1:
			case 3: 
				h[s]=1;  
			}
			f=z[e]; 
			t=z[t]; 
			k+=p[s]=h[s]&&(t==0||j<(f<16!=t<16));
		} 
	}
	g=e; 
	if (k!=0) goto la; 
	if (u==v) goto lc; 
	e=n[v++]; 
	goto lb;
lc:
	printf("  "); 
#ifdef V10
	for(s=2; s<=c; ++s) printf(" _");
#else
	for(s=2; s<=c; ++s) printf("__");
#endif
	printf("\n");
	for(s=0; s<r; ++s) { 
		for (t=0; t<c; ++t) { 
			u=z[t+s*c];
			v=u/4; 
#ifdef V10
			x=(v==(2*(v/2)))?'|':' ';
#else
			x=(v==(2*(v/2)))?'|':'_';
#endif
			v=u/8; 
			y=(v==(2*(v/2)))?'_':' ';
			printf("%c%c",x,y); 
		} 
		printf("|\n"); 
	}
}
