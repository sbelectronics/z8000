from __future__ import print_function

kmap_shift4 = {
  0x00: chr(0xFF),  # shift
  0x01: 'Z',
  0x02: 'X',
  0x03: 'C',
  0x04: 'V',
  0x10: 'A',
  0x11: 'S',
  0x12: 'D',
  0x13: 'F',
  0x14: 'G',
  0x20: 'Q',
  0x21: 'W',
  0x22: 'E',
  0x23: 'R',
  0x24: 'T',
  0x30: '1',
  0x31: '2',
  0x32: '3',
  0x33: '4',
  0x34: '5',
  0x40: '0',
  0x41: '9',
  0x42: '8',
  0x43: '7',
  0x44: '6',
  0x50: 'P',
  0x51: 'O',  
  0x52: 'I',
  0x53: 'U',
  0x54: 'Y',
  0x60: chr(0x0D),
  0x61: 'L',
  0x62: 'K',
  0x63: 'J',
  0x64: 'H',
  0x70: ' ',
  0x71: chr(0xFF),   # control
  0x72: 'M',
  0x73: 'N',
  0x74: 'B',
}

puncmap = {'1': '!',
           '2': '@',
           '3': '#',
           '4': '$',
           '5': '%',
           '6': '^',
           '7': '&',
           '8': '*',
           '9': '(',
           '0': ')',
           }

symmap = {
    '5': '%',
    '4': '$',
    '3': '#',
    '2': '@',
    '1': '!',
    'T': '>',
    'R': '<',
    'E': '>',
    'W': '=',
    'Q': '<',
    '6': '&',
    '7': '\'',
    '8': '(',
    '9': ')',
    '0': '_',
    'G': '}',
    'F': '{',
    'D': '\\',
    'S': '|',
    'A': '_',
    'Y': '[', 
    'U': ']',
    'I': '#',
    'O': ';',
    'P': '\"',
    'V': '/',
    #'C': '?',
    'C': chr(0x03),
    'X': 'E',
    'Z': ':',
    #'H': '^',
    'H': chr(0x08),
    'J': '-',
    'K': '+',
    'L': '=',
    'B': '*', 
    'N': ',',
    'M': '.'
}

kmap = {}
for k,v in kmap_shift4.items():
  k = ((k>>1) & 0x38) | (k & 0x07)
  kmap[k] = v

# shifted

codes = []
for i in range(0, 64):
  v = kmap.get(i, chr(0xFF))
  v = v.upper()
  v = puncmap.get(v,v)
  codes.append(ord(v))

print("rc2014_shift:")
while codes:
  parts = codes[:8]
  codes = codes[8:]

  parts = [("0x%02X" %x) for x in parts]
  print("   .byte %s" % ",".join(parts))

# unshifted

codes = []
for i in range(0, 64):
  v = kmap.get(i, chr(0xFF))
  v = v.lower()
  codes.append(ord(v))

print("rc2014_unshift:")
while codes:
  parts = codes[:8]
  codes = codes[8:]

  parts = [("0x%02X" % x) for x in parts]
  print("   .byte %s" % ",".join(parts))

# control

codes = []
for i in range(0, 64):
  v = kmap.get(i, chr(0xFF))
  v = v.upper()
  v = symmap.get(v,v)
  codes.append(ord(v))

print("rc2014_control:")
while codes:
  parts = codes[:8]
  codes = codes[8:]

  parts = [("0x%02X" %x) for x in parts]
  print("   .byte %s" % ",".join(parts))
