from __future__ import print_function
import smbus
import string
import sys
import time
from smbpi.ioexpand import *
from optparse import OptionParser
#from hexfile import HexFile

"""
   ixAddr = A0..A15
   ixData = D0..D15
   ixControl = A16, A17, A18, A19, RAMLOCS, RAMHICS, ROMLOCS, ROMHICS, MR, MW, IOR, IOW, TX/~RX, RESET, BUSRQ, BUSAK
"""

# ixControl masks
A16=   0x01
A17=   0x02
A18=   0x04
A19=   0x08
RAML=  0x10
RAMH=  0x20
ROML=  0x40
ROMH=  0x80

MR=    0x01
MW=    0x02
IOR=   0x04
IOW=   0x08
RX=    0x10
RESET= 0x20
BUSREQ=0x40
BUSACK=0x80

LBUSREQ = (0xFF & ~BUSREQ)

A16_BANK=   0
A17_BANK=   0
A18_BANK=   0
A19_BANK=   0
RAML_BANK=  0
RAMH_BANK=  0
ROML_BANK=  0
ROMH_BANK=  0

MR_BANK=    1
MW_BANK=    1
IOR_BANK=   1
IOW_BANK=   1
RX_BANK=    1
RESET_BANK= 1
BUSREQ_BANK= 1
BUSACK_BANK= 1

LMR_LBUSREQ = ((0xFF & ~BUSREQ) & ~MR)
LMW_LBUSREQ = ((0xFF & ~BUSREQ) & ~MW)

def hex_escape(s):
    printable = string.ascii_letters + string.digits + string.punctuation + ' '
    return ''.join(c if c in printable else r'\x{0:02x}'.format(ord(c)) for c in s)

class Supervisor:
    def __init__(self, bus, addr, verbose):
        self.ixData = MCP23017(bus, addr)
        self.ixAddress = MCP23017(bus, addr+1)
        self.ixControl = MCP23017(bus, addr+2)
        self.verbose = False
        self.lastMidAddr = None
        self.ixControl.set_pullup(0, 0xFF)  # weak pullups on all control lines
        self.ixControl.set_pullup(1, 0xFF)  # weak pullups on all control lines
        self.release_bus()

    def log(self, msg):
        if self.verbose:
            print(msg, file=sys.stderr)

    def delay(self):
        time.sleep(0.001)

    def reset(self):
        self.ixControl.set_gpio(RESET_BANK, LRESET)
        self.ixControl.set_iodir(RESET_BANK, LRESET)   # reset is an output
        self.delay()
        self.ixControl.set_iodir(RESET_BANK, 0xFF)   # everyone is an input

    def take_bus(self):
        self.ixControl.set_gpio(BUSREQ_BANK, LBUSREQ)   # BUSREQ low
        self.ixControl.set_iodir(BUSREQ_BANK, LBUSREQ)    # BUSREQ is an output
        self.log("wait for busack")
        while True:
            bits=self.ixControl.get_gpio(BUSACK_BANK)
            if (bits & BUSACK) == 0:
                break
        self.log("busack is received")
        self.ixAddress.set_iodir(0, 0x00)           # A0..A15 outputs
        self.ixAddress.set_iodir(1, 0x00)

        self.ixControl.set_gpio(0,  RAML | RAMH | ROML | ROMH) # chip selects high. A16..A19 low
        self.ixControl.set_iodir(0, 0x00)                     # A16..A19 and CS outputs

        self.ixControl.set_gpio(1, MR | MW | IOR | IOW)       # BUSRQ low
        self.ixControl.set_iodir(1, RX | BUSACK | RESET)      # MR, MW, IOR, IOW, BUSRQ outputs

    def release_bus(self, reset=False):
        self.ixAddress.set_iodir(0,0xFF)
        self.ixAddress.set_iodir(1,0xFF)
        self.ixData.set_iodir(0, 0xFF)        
        self.ixData.set_iodir(1, 0xFF)
        self.ixControl.set_iodir(0, 0xFF) # A16..19 and CS are inputs
        self.ixControl.set_iodir(1, 0xFF) # even BUSRQ is an input
        
        # MR | MW | IOR | IOW | RESET | RX | BUSACK) # busreq is the only output

        # Note on observed reset behavior while BUSREQ is low
        # While reset is LOW, BUSACK will go high. As soon as RESET goes back
        # high, BUSACK will go low again. There is exactly one M1 read cycle
        # at the exact time reset goes high. My assumption is that this
        # means the first instruction is fetched if RESET is pulsed while
        # busreq is held low.

        if reset:
            self.reset()

        self.log("wait for not busack")
        while True:
            bits=self.ixControl.get_gpio(BUSACK_BANK)
            if (bits & BUSACK) != 0:
                break
        self.log("not busack is received")

    def seg(self, addr):
        seg = addr>>16
        if (seg>=0x100):
            # it's one of those Z8000 segment numbers in the uppermost 8 bits
            seg = seg >> 8

        return seg

    def mem_read(self, addr):
        self.mem_read_start(addr)
        result = self.mem_read_fast(addr)
        self.mem_read_end()
        return result    

    def mem_read_start(self, addr):
        self.lastMidAddr = None
        self.ixControl.set_gpio(RAML_BANK, self.seg(addr) | ROML | ROMH )  # assert RAML and RAMH low. ROML and ROMH high

    def mem_read_end(self):
        self.ixControl.set_gpio(RAML_BANK, 0xFF)                           # release all CS and A16..A19

    def mem_read_fast(self, addr):
        midAddr = (addr>>8) & 0xFF                                         # A8..A15
        if midAddr != self.lastMidAddr:
            self.ixAddress.set_gpio(1, midAddr)
            self.lastMidAddr = midAddr

        self.ixAddress.set_gpio(0, addr & 0xFF)                            # A0..A7
        self.ixControl.set_gpio(MR_BANK, LMR_LBUSREQ)                      # assert MR and hold busreq
        result = (self.ixData.get_gpio(1)<<8) | self.ixData.get_gpio(0)
        self.ixControl.set_gpio(MR_BANK, LBUSREQ)                          # release MR and hold busreq        
        return result

    def mem_write(self, addr, val):
        self.mem_write_start(addr)
        self.mem_write_fast(addr, val)
        self.mem_write_end()

    def mem_write_start(self, addr):
        self.lastMidAddr = None
        self.ixControl.set_gpio(RAML_BANK, self.seg(addr) | ROML | ROMH )  # assert RAML and RAMH low. ROML and ROMH high
        self.ixData.set_iodir(0, 0x00)                                     # iodir to write data
        self.ixData.set_iodir(1, 0x00)                                     # iodir to write data

    def mem_write_end(self):
        self.ixData.set_iodir(0, 0xFF)                                     # iodir back to read data
        self.ixData.set_iodir(1, 0xFF)                                     # iodir back to read data           
        self.ixControl.set_gpio(RAML_BANK, 0xFF)                           # release all CS and A16..A19          

    def mem_write_fast(self, addr, val):
        midAddr = (addr>>8) & 0xFF                                         # A8..A15
        if midAddr != self.lastMidAddr:
            self.ixAddress.set_gpio(1, midAddr)
            self.lastMidAddr = midAddr

        self.ixAddress.set_gpio(0, addr & 0xFF)                            # A0..A7
        self.ixData.set_gpio(0, val & 0xFF)
        self.ixData.set_gpio(1, val >> 8)        
        self.ixControl.set_gpio(MW_BANK, LMW_LBUSREQ)                      # assert MW and hold busreq
        self.ixControl.set_gpio(MW_BANK, LBUSREQ)                          # release MW and hold busreq

def main():
    parser = OptionParser(usage="supervisor [options] command",
            description="Commands: ...")

    parser.add_option("-A", "--addr", dest="addr",
         help="address", metavar="ADDR", type="string", default=0)
    parser.add_option("-C", "--count", dest="count",
         help="count", metavar="ADDR", type="int", default=65536)
    parser.add_option("-V", "--value", dest="value",
         help="value", metavar="VAL", type="int", default=0)
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

    #parser.disable_interspersed_args()

    (options, args) = parser.parse_args(sys.argv[1:])

    if len(args)==0:
        print("missing command")
        sys.exit(-1)

    cmd = args[0]
    args=args[1:]

    bus = smbus.SMBus(1)
    super = Supervisor(bus, 0x20, options.verbose)

    if (options.addr):
        if options.addr.startswith("0x") or options.addr.startswith("0X"):
            addr = int(options.addr[2:], 16)
        elif options.addr.startswith("$"):
            addr = int(options.addr[1:], 16)
        else:
            addr = int(options.addr)

    if (cmd=="reset"):
        super.reset()

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
            super.mem_write(addr, options.value)
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


if __name__=="__main__":
    main()
