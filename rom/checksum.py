
f = open("combined.bin", "rb+")
data = bytearray(f.read())

data[0x0F0008] = chr(0)
data[0x0F0009] = chr(0)

even=True
sum = 0
for b in data:
    if even:
        w = b << 8
        even = False
    else:
        w = w | b
        even = True
        sum = (sum + w)

print "sum is %04X" % (sum & 0xFFFF)

# We want the checksum to be zero when we add it all up
sum = 0x10000-sum

print "checksum value is %04X" % (sum & 0xFFFF)

f.seek(0x0F0008)
f.write(chr((sum >> 8) & 0xFF))
f.write(chr(sum & 0xFF))
