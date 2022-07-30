import sys

data = sys.stdin.read()

last=None
for c in data:
  if (c!=chr(0x0A)) and (last==chr(0x0D)):
    sys.stdout.write(chr(0x0D))
    sys.stdout.write(chr(0x0A))
  if c!=chr(0x0d):
    sys.stdout.write(c)
  last=c
