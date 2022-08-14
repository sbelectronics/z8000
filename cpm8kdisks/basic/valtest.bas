10 PRINT "hello"
20 PRINT "world"
30 GOSUB 1000

100 print "should print loop1 ... loop10 lines"
110 FOR I=1 TO 10
120 PRINT "loop ", I
130 NEXT I

200 i=2
210 j=3
220 k=i+j
230 l=i*j
240 m = 25/5
240 LET N=2*i+2*J
250 LET O=N
270 print "should pront 2 3 5 6 5 10 10"
280 print i, " ", j, " ", k, " ", l, " ", m, " ", n, " ", o 

999 STOP
1000 PRINT "foo"
1010 RETURN
