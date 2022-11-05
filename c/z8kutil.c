/*
        zcc z8kutil.c
        a:asz8k -o extbios.o extbios.8kn
        a:ld8k -w -s -o z8kutil.z8k extbios.o z8kutil.o -lcpm
*/

#include "stdio.h"
#include "extbios.h"

/* CP/M-8000 turn off stuff we don't need. It only saves about 4K. */
#include "option.h"
NOLONG NOFLOAT NOTTYIN NOFILESZ NOWILDCARDS NOASCII NOBINARY

#define islower(c) (((c)>='a') && ((c)<='z'))
#define toupper(ch) (islower(ch) ? (ch)+('A'-'a') : (ch))

int quiet = 0;
int tildisplay = 0;

/* the world's worst prime number function */
int brutprim(l)
int l;
{
    int n,d;

    for (n=3; n<=l; n++) {
        int isprime=1;
        for (d=2; d<n; d++) {
            if ((n % d) == 0) {
                isprime=0;
                break;
            }
        }
        if (isprime) {
            printf("%d", n);
        } else {
            printf(".");
        }
    }
    printf("\n");
    return 0;
}

char stricmp(s1, s2)
char *s1;
char *s2;
{
   while (toupper(*s1) == toupper(*s2))
   {
     if (*s1 == 0) {
       return 0;
     }
     s1++;
     s2++;
   }
   return toupper(*s1) - toupper(*s2);
}

long hex2long(hex)
char *hex;
{
    long val = 0;
    while (*hex) {
        char b = *hex++;

        b = toupper(b);
         
        if ((b>='0') && (b<='9')) {
            val = (val<<4) + (b-'0');
        } else if ((b>='A') && (b<='F')) {
            val = (val<<4) + (b-'A'+10);
        } else {
            break;
        }
    }
    return val;
}

long dec2long(s)
char *s;
{
    long val = 0;
    while (*s) {
        char b = (*s++);
        if ((b>='0') && (b<='9')) {
            val = val*10 + (b-'0');
        } else {
            break;
        }
    }
    return val;
}

long str2num(s)
char *s;
{
    if (*s=='$') {
        return hex2long(s+1);
    } else if ((*s=='0') && (toupper(*(s+1)))=='X') {
        return hex2long(s+2);
    } else {
        return dec2long(s);
    }
}

int banner()
{
    printf("z8kutil, by Scott M Baker, http://www.smbaker.com\n\n");
}


int usage()
{
    banner();
    printf("z8kutil info                       ... show info\n");
    printf("z8kutil led on                     ... turn on led\n");
    printf("z8kutil led off                    ... turn off led\n");
    printf("z8kutil uptime                     ... print uptime\n");
    printf("z8kutil upclock                    ... run continuous uptime clock\n");
    printf("z8kutil ticker                     ... run continuous ticker\n");
    printf("z8kutil setdivisor <n>             ... set cio divisor\n");    
    printf("z8kutil setdispb <digit> <value>   ... set display byte (0..3) to value\n");
    printf("z8kutil setdispw <word> <value>    ... set display word (0..1) to value\n");
    printf("z8kutil setdispl <value>           ... set display to hex value\n");
    printf("z8kutil indisp                     ... continuous input from display board\n");
    printf("z8kutil inswitch                     ... continuous input from cpu board switch on MI\n");    
    printf("z8kutil bench                      ... run a simple benchmarkn");    
    printf("\noptions:\n");
    printf("  -d ... debug\n");
    printf("  -t ... send stuff to TIL display where appropriate\n");
    printf("  -q ... quiet\n");
    exit(0);
    return 0;
}

int doLed(value)
int value;
{
    setled(value); /* call extended bios */
    return 0;
}

int doUptime(cont)
int cont;
{
    long uptime;
    long mpd;
    long tps;
    int days, hours, minutes, seconds;
    int lastsec;

    /* for continuous mode */
    lastsec = -1;

    /* I don't fully trust ZCC to be able to handle long constants */
    mpd = 24;
    mpd = mpd * 60;
    mpd = mpd * 60;

    tps = getciok();
    tps = tps*1000;
    tps = tps/2;
    tps = tps/getciod();

    while (1) {
        uptime = gettick();

        uptime = uptime / tps;

        days = uptime / mpd;
        uptime = uptime % mpd;

        hours = uptime / 3600;
        uptime = uptime % 3600;

        minutes = uptime / 60;
        seconds = uptime % 60;

        if (lastsec == seconds) {
            continue;
        }

        lastsec = seconds;

        if (tildisplay) {
            setdisp(0, days);
            setdisp(1, hours);
            setdisp(2, minutes);
            setdisp(3, seconds);
        }

        if (!quiet || !tildisplay) {
            if (cont) {
                printf("\r");  /* overwrite the last line */
            }

            if (days > 0) {
                printf("%d days, %02d:%02d:%02d", days, hours, minutes, seconds);
            } else {
                printf("%02d:%02d:%02d", hours, minutes, seconds);
            }
        } else {
            if ((getcon()!=0) && (incond()==3)) {
                /* make sure we can receive the CTRL-C */
                return;
            };
        }

        if (!cont) {
            /* one and done */
            printf("\n");
            return;
        }
    }

    return 0;
}

int doTicker(cont)
int cont;
{
    long ticks;
    long lastticks;

    /* for continuous mode */
    lastticks = -1;

    while (1) {
        ticks = gettick();
        if (ticks == lastticks) {
            continue;
        }

        if (tildisplay) {
            setdisl(ticks);
        }

        if (!quiet || !tildisplay) {
            if (cont) {
                printf("\r");  /* overwrite the last line */
            }

            printf("%X", ticks);
        } else {
            if ((getcon()!=0) && (incond()==3)) {
                /* make sure we can receive the CTRL-C */
                return;
            };            
        }

        if (!cont) {
            /* one and done */
            printf("\n");
            return;
        }
    }

    return 0;
}

int doSDisp(digit, value)
int digit;
long value;
{
    if (digit==DISP_L) {
        setdisl(value);
    } else {
        setdisp(digit, (int) value);
    }
    return 0;
}

int doIDisp()
{
    int cur, last;
    last = -1;
    while (1) {
        cur = indisp();
        if (cur!=last) {
            printf("%02x\n", cur);
            last=cur;
        }
        if ((getcon()!=0) && (incond()==3)) {
            /* make sure we can receive the CTRL-C */
            return;
        };          
    }

    return 0;
}

int doISwitch()
{
    int cur, last;
    last = -1;
    while (1) {
        cur = insw();
        if (cur!=last) {
            printf("%02x\n", cur);
            last=cur;
        }
        if ((getcon()!=0) && (incond()==3)) {
            /* make sure we can receive the CTRL-C */
            return;
        };          
    }

    return 0;
}

int doVidColor(value)
int value;
{
    setcolor(value);
    return 0;
}

int doVidPick()
{
    int fg = 0xF;
    int bg = 0x2;
    int code;

    printf("< decrease background\n");
    printf("> increase background\n");
    printf("- decrease forefround\n");
    printf("+ increase foreground\n");

    while (1) {
        char b = incon();

        switch (b) {
            case '<':
                if (bg>0) bg--;
                break;
            case '>':
                if (bg<0xF) bg++;
                break;
            case '-':
                if (fg>0) fg--;
                break;
            case '+':
                if (fg<0xF) fg++;
                break;
            case 3:
                return;
        }

        code = (fg<<4) + bg;
        printf("foreground=%x, background=%x, code=%x\n", fg, bg, code);
        setcolor(code);
    }
    return 0;
}

int doSDiv(i)
int i;
{
    if (i==0) {
        printf("Nope. Not gonna do it.\nRefusing to set divisor to 0.\n");
    }
    setciod(i);
}

int doInfo()
{
    printf("CIO Compiled...... %u\n", getciop() >> 8);
    printf("CIO Kbd Enable.... %u\n", getciop() & 0xFF);
    printf("CIO KHz .......... %u\n", getciok());
    printf("CIO Divisor ...... %u\n", getciod());
    printf("Ticker............ %X\n", (long) gettick());
    return 0;
}

int doBench()
{
    long tstart;
    long tstop;
    long telap;
    long tps;

    /* I don't fully trust ZCC to be able to handle long constants */
    tps = getciok();
    tps = tps*1000;
    tps = tps/2;
    tps = tps/getciod();

    tstart = gettick();
    brutprim(2500);
    tstop = gettick();

    telap = tstop-tstart;

    telap = telap / tps;

    printf("%ld seconds\n", telap);
}


int main(argc, argv)
int argc;
char **argv;
{
    int fileMode = 0;
    int noninteractive = 0;
    int i;
    char *cmd = NULL;
    char *arg1 = NULL;
    char *arg2 = NULL;
    long tmpl;
    int tmpw;

    if (argc==1) {
        usage();
    }

    for (i=1; i<argc; i++) {
        if (stricmp(argv[i],"-h")==0) {
            usage();
        } else if (stricmp(argv[i],"-q")==0) {
            quiet=1;
        } else if (stricmp(argv[i],"-t")==0) {
            tildisplay=1;            
        } else {
            if (stricmp(argv[i], "led") == 0) {
                if (i>=(argc-1)) {
                    usage();
                }
                i++;
                if (stricmp(argv[i], "on") ==0) {
                    doLed(1);
                } else if (stricmp(argv[i], "off") == 0) {
                    doLed(0);
                } else {
                    usage();
                }

            } else if (stricmp(argv[i], "uptime") ==0) {
                doUptime(0);
            } else if (stricmp(argv[i], "upclock") ==0) {
                doUptime(1);
            } else if (stricmp(argv[i], "ticker") ==0) {
                doTicker(1);
            } else if (stricmp(argv[i], "setdispb") ==0) {
                if (i>=(argc-2)) {
                    usage();
                }
                i++;
                tmpw = str2num(argv[i]);
                i++;
                tmpl = str2num(argv[i]);
                doSDisp(tmpw, tmpl);
                i++;
            } else if (stricmp(argv[i], "setdispw") ==0) {
                if (i>=(argc-2)) {
                    usage();
                }
                i++;
                tmpw = str2num(argv[i]);
                i++;
                tmpl = str2num(argv[i]);
                doSDisp(DISP_W0 + tmpw, tmpl);
                i++;
            } else if (stricmp(argv[i], "setdispl") ==0) {
                if (i>=(argc-1)) {
                    usage();
                }
                i++;
                tmpl = str2num(argv[i]);
                doSDisp(DISP_L, tmpl);
            } else if (stricmp(argv[i], "vidcolor") ==0) {
                if (i>=(argc-1)) {
                    usage();
                }
                i++;
                tmpl = str2num(argv[i]);
                doVidColor((int) tmpl);
            } else if (stricmp(argv[i], "indisp") ==0) {
                doIDisp();
            } else if (stricmp(argv[i], "inswitch") ==0) {
                doISwitch();
            } else if (stricmp(argv[i], "vidcolorpick") ==0) {
                doVidPick();
            } else if (stricmp(argv[i], "info") ==0) {
                doInfo();
            } else if (stricmp(argv[i], "setdivisor") ==0) {
                i++;
                tmpw = str2num(argv[i]);
                doSDiv(tmpw);
            } else if (stricmp(argv[i], "bench") ==0) {
                doBench();
            } else {
                usage();
            }
        }
    }

    return 0;
}
