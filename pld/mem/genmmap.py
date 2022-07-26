NSEGS = 16
ROMCS = 0x20
RAMCS = 0x10

IMODE = 0x80
DMODE = 0x00

BOOT = 0x100

n = 0 
print "/* I-Mode: segments %02X-%02X RAM in combined I/D */" % (n, n+15)
for i in range(0, 16):
    print "%02X => %02X;" % (IMODE + n, RAMCS + i),
    if (i%4)==3:
        print ""
    n += 1

n = 0
print ""
print "/* D-Mode: segments %02X-%02X RAM in combined I/D */" % (n, n+15)
for i in range(0, 16):
    print "%02X => %02X;" % (DMODE + n, RAMCS + i),
    if (i%4)==3:
        print ""
    n += 1    

print ""
print "/* I-Mode: segments %02X-%02X RAM in separate I/D */" % (n, n+7)
for i in range(0, 8):
    print "%02X => %02X;" % (IMODE + n, RAMCS + i),
    if (i%4)==3:
        print ""
    n += 1

n -= 8
print ""
print "/* D-Mode: segments %02X-%02X RAM in separate I/D */" % (n, n+7)
for i in range(0, 8):
    print "%02X => %02X;" % (DMODE + n, RAMCS + 8 + i),
    if (i%4)==3:
        print ""
    n += 1    

print ""
print "/* D-Mode: segments %02X-%02X RAM shadows of the I */" % (n, n+7)
for i in range(0, 8):
    print "%02X => %02X;" % (DMODE + n, RAMCS + i),
    if (i%4)==3:
        print ""
    n += 1

# runs out of product terms... :(
#print ""
#print "/* D-Mode: segments %02X-%02X ramdisk */" % (n, n+11)
#for i in [4,5,6,7,9,10,11,12,13,14,15]:   # skip segments 0,1,2,3,8
#    print "%02X => %02X;" % (DMODE + n, RAMCS + i),
#    if (i%4)==3:
#        print ""
#    n += 1     


n=0x40
print ""
print "/* I-Mode: segments %02X-%02X FLASH in combined I/D */" % (n, n+15)
for i in range(0, 16):    
    print "%02X => %02X;" % (IMODE + n, ROMCS + i),
    if (i%4)==3:
        print ""
    n += 1

n=0x40
print ""
print "/* D-Mode: segments %02X-%02X FLASH in combined I/D */" % (n, n+15)
for i in range(0, 16):    
    print "%02X => %02X;" % (DMODE + n, ROMCS + i),
    if (i%4)==3:
        print ""
    n += 1

n = 0x60
print ""
print "/* D-Mode and I-Mode: segments %02X-%02X FLASH for boot segment on rom page 15*/" % (n, n)
print "%02X => %02X;" % (DMODE + n, ROMCS + 15),
print "%02X => %02X;" % (IMODE + n, ROMCS + 15),
print "%03X => %02X;" % (BOOT + DMODE + n, ROMCS + 15),
print "%03X => %02X;" % (BOOT + IMODE + n, ROMCS + 15)
n += 1

print ""
print "/* D-Mode and I-Mode: segments %02X-%02X FLASH for boot initialization vector on rom page 15*/" % (0, 0)
print "%03X => %02X;" % (BOOT + DMODE + 0, ROMCS + 15),
print "%03X => %02X;" % (BOOT + IMODE + 0, ROMCS + 15)
