/*
        zcc calltest.c
        a:ld8k -w -s -o calltest.z8k calltest.o -lcpm
*/

/*
int func1(x,y)
char x;
int y;
{
    return x+y;
}
*/

int func2(x)
long x;
{
    long y = x+1;
    return y & 0xFFFF;
}

/*
long func3()
{
    return 0x12345678;
}
*/

int main()
{
    long l;

    l = func2();
    /* func1(); */
    l = 0x12345678;
    func2(l);
}
