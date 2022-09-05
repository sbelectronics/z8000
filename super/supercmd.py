from __future__ import print_function
import smbus
import string
import sys
import time
from smbpi.ioexpand import *
from optparse import OptionParser
#from hexfile import HexFile

from supervisor import Supervisor
from supervisor_direct import SupervisorDirect

def hex_escape(s):
    printable = string.ascii_letters + string.digits + string.punctuation + ' '
    return ''.join(c if c in printable else r'\x{0:02x}'.format(ord(c)) for c in s)

def load_image(super, fn):
    addr = 0x03000000
    super.mem_write_start(addr)    
    try:
        word = 0
        odd = False
        filebytes = open(fn, "rb").read()
        for b in filebytes:
            if odd:
                word = (word << 8) | b
                super.mem_write_fast(addr, word)
                addr += 2
                odd = False
            else:
                odd = True
                word = b
    finally:
        super.mem_write_end()

def save_image(super, fn):
    addr = 0x03000000
    super.mem_read_start(addr)    
    try:
        f = open(fn, "wb")
        for i in range(0, 32768):
            word = super.mem_read_fast(addr)
            f.write(word.to_bytes(2,"big"))
            addr += 2
    finally:
        super.mem_read_end()        

def main():
    parser = OptionParser(usage="supervisor [options] command",
            description="Commands: ...")

    parser.add_option("-A", "--addr", dest="addr",
         help="address", metavar="ADDR", type="string", default=0)
    parser.add_option("-C", "--count", dest="count",
         help="count", metavar="ADDR", type="int", default=65536)
    parser.add_option("-V", "--value", dest="value",
         help="value", metavar="VAL", type="string", default=0)
    parser.add_option("-P", "--ascii", dest="ascii",
         help="print ascii value", action="store_true", default=False)
    parser.add_option("-R", "--rate", dest="rate",
         help="rate for slow clock", metavar="HERTZ", type="int", default=10)
    parser.add_option("-B", "--bank", dest="bank",
         help="bank number to select on ram-rom board", metavar="NUMBER", type="int", default=None)
    parser.add_option("-v", "--verbose", dest="verbose",
         help="verbose", action="store_true", default=False)
    parser.add_option("-f", "--filename", dest="filename",
         help="filename", default=None)
    parser.add_option("-r", "--reset", dest="reset_on_release",
         help="reset on release of bus", action="store_true", default=False)
    parser.add_option("-n", "--norelease", dest="norelease",
         help="do not release bus", action="store_true", default=False)
    parser.add_option("-i", "--indirect", dest="direct",
         help="use the python supervisor", action="store_false", default=True)

    #parser.disable_interspersed_args()

    (options, args) = parser.parse_args(sys.argv[1:])

    if len(args)==0:
        print("missing command")
        sys.exit(-1)

    cmd = args[0]
    args=args[1:]

    if options.direct:
      print("using direct supervisor")
      super = SupervisorDirect(options.verbose)
    else:
      print("using python supervisor")
      bus = smbus.SMBus(1)
      super = Supervisor(bus, 0x20, options.verbose)
    
    addr = None
    if (options.addr):
        if options.addr.startswith("0x") or options.addr.startswith("0X"):
            addr = int(options.addr[2:], 16)
        elif options.addr.startswith("$"):
            addr = int(options.addr[1:], 16)
        else:
            addr = int(options.addr)

    value = None
    if (options.value):
        if options.value.startswith("0x") or options.value.startswith("0X"):
            value = int(options.value[2:], 16)
        elif options.addr.startswith("$"):
            value = int(options.value[1:], 16)
        else:
            value = int(options.value)            

    if (cmd=="reset"):
        try:
            super.take_bus()
        finally:
            if not options.norelease:
                super.release_bus(reset=True)

    elif (cmd=="memdump"):
        try:
            super.take_bus()
            for i in range(addr,addr+options.count, 2):
                val = super.mem_read(i)
                if options.ascii:
                    print("%04X %04X %s %s" % (i, val, hex_escape(chr(val>>8), hex_escape(chr(val & 0xFF)))))
                else:
                    print("%04X %04X" % (i, val))
        finally:
            if not options.norelease:
                super.release_bus()

    elif (cmd=="peek"):
        try:
            super.take_bus()
            print("%04X" % super.mem_read(addr))
        finally:
            if not options.norelease:
                super.release_bus()

    elif (cmd=="poke"):
        try:
            super.take_bus()
            super.mem_write(addr, value)
        finally:
            if not options.norelease:
                super.release_bus()

    elif (cmd=="showint"):
        last=None
        while True:
            v = ((super.ixData.get_gpio(1)&INT) !=0)
            if v!=last:
                print(v)
                last=v

    elif (cmd=="loadimg"):
        try:
            super.take_bus()
            load_image(super, options.filename)
        finally:
            if not options.norelease:
                super.release_bus(reset=True)

    elif (cmd=="saveimg"):
        try:
            super.take_bus()
            save_image(super, options.filename)
            super.reset()
        finally:
            if not options.norelease:
                super.release_bus()                


if __name__=="__main__":
    main()
