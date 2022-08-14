5 REM count on the TIL311 displays
10 for i=0 to 255
20 out &H50, i
30 for j=0 to 255
40 out &H51, j
50 for k=0 to 255
60 out &H52, k
70 for l=0 to 255
80 out &H53, l
90 next l
100 next k
110 next j
120 next i
