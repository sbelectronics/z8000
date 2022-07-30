import sys

data = open(sys.argv[1],"r").read()

flow = open(sys.argv[2],"w")
fhi = open(sys.argv[3],"w")

hi=True
for b in data:
  if hi:
    fhi.write(b)
    hi=False
  else:
    flow.write(b)
    hi=True
