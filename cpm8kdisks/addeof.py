from __future__ import print_function
import sys

def addlf(fn):
  print(fn)
  f = open(fn, "r+")
  data = f.read()
  if data[-1] != chr(0x1A):
    f.write(chr(0x1A))


for fn in sys.argv[1:]:
  addlf(fn)
