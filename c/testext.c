/*
        zcc testext.c
        a:asz8k -o extbios.o extbios.8kn
        a:ld8k -w -s -o testext.z8k extbios.o testext.o -lcpm
*/

#include "stdio.h"
#include "extbios.h"

int main()
{
    setled(1);
    printf("tick count hi: %d, lo: %d\n", gtickhi(), gticklo());
    setled(0);
}
