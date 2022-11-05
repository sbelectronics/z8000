#define TICKS_PER_SECOND 50

#define DISP_0 0
#define DISP_1 1
#define DISP_2 2
#define DISP_3 3
#define DISP_W0 0x10
#define DISP_W1 0x11
#define DISP_L 0x20

int setled(x);                   /* int */
int insw();
unsigned int gticklo();
unsigned int gtickhi();
long gettick();
unsigned int getciop();
unsigned int getciok();
unsigned int getciod();
int setciod(x);                  /* int */
int setcolor(x);                 /* int */
int setdisp(digit, value);       /* char, int */
int setdisl(value);              /* long */
int indisp();
int getcon();
int getcond();
int incon();
int incond();
