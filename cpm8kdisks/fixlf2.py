from __future__ import print_function
import sys
import os

def addlf(fn):
  print(fn)
  f = open(fn, "rb")
  data_orig = f.read()
  data = data_orig

  while data[-1] == chr(0x1A):
    data = data[:-1]

  data = data + chr(0x1A)

  if fn.endswith(".sub"):
    while (len(data)%128) != 0:
      data = data + chr(0x1A)

  if data != data_orig:
    f = open(fn+".new", "wb")
    f.write(data)
    f.close()
    os.system("mv %s.new %s" % (fn, fn))

for fn in sys.argv[1:]:
  addlf(fn)
