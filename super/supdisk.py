from __future__ import print_function
from supervisor import *

import smbus
import string
import sys
import time
from optparse import OptionParser

CMD_OFS = 0
ADDR_OFS = 2
BUF_OFS = 6

CMD_INIT = 0
CMD_READ = 1
CMD_WRITE = 2

class SuperDisk(Supervisor):
    def __init__(self, bus, addr, verbose):
        Supervisor.__init__(self, bus, addr, verbose)
        self.superAddress = self.find_super()

        self.f = open("sup.img","r+b")

    def run(self):
        while True:
            cmd = self.get_cmd()
            if cmd == CMD_READ:
                #tstart=time.time()
                self.read()
                #print(time.time() - tstart)
            elif cmd == CMD_WRITE:
                self.write()
            elif cmd == CMD_INIT:
                self.set_active()
            else:
                time.sleep(0.01)

    def read(self):
        try:
            self.take_bus()
            fileAddr = (self.mem_read(self.superAddress + ADDR_OFS) << 16) | \
                        self.mem_read(self.superAddress + ADDR_OFS+2)
            print("Read at %08X" % fileAddr)

            self.f.seek(fileAddr*128)
            buf = self.f.read(128)
            hi = True
            addr = self.superAddress + BUF_OFS
            self.mem_write_start(addr)
            for b in buf:
                if hi:
                    w = (b << 8)
                    hi = False
                else:
                    w = w | b
                    hi = True
                    self.mem_write_fast(addr, w)
                    addr += 2
            self.mem_write_end()
            print("sent %d" % (addr-self.superAddress-BUF_OFS))

            # Let CPM-8K know we're done
            self.mem_write(self.superAddress + CMD_OFS, 0x81)
        finally:
            self.release_bus()

    def write(self):
        try:
            self.take_bus()
            fileAddr = (self.mem_read(self.superAddress + ADDR_OFS) << 16) | \
                        self.mem_read(self.superAddress + ADDR_OFS+2)
            print("Write at %08X" % fileAddr)

            buf = bytearray(128)
            addr = self.superAddress + BUF_OFS
            self.mem_read_start(addr)
            for i in range(0,64):
                w = self.mem_read_fast(addr)
                buf[i*2] = w>>8
                buf[i*2+1] = w & 0xFF
                addr += 2
            self.mem_read_end()
            print("received %d" % (addr-self.superAddress-BUF_OFS))
            #print(hex_escape(buf))
            self.f.seek(fileAddr*128)
            self.f.write(buf)

            # Let CPM-8K know we're done
            self.mem_write(self.superAddress + CMD_OFS, 0x82)
        finally:
            self.release_bus()            

    def get_cmd(self):
        try:
            self.take_bus()
            cmd = self.mem_read(self.superAddress + CMD_OFS)
            return cmd
        finally:
            self.release_bus()

    def set_active(self):
        try:
            self.take_bus()
            self.mem_write(self.superAddress + CMD_OFS, 0x80)
        finally:
            self.release_bus()

    def find_super(self):
        v2 = 0
        v3 = 0
        v4 = 0
        try:
            self.take_bus()
            base = 0x030057A0  # start close to where we think it will be
            self.mem_read_start(base)
            while (base < 0x0300FFFF):
                v = self.mem_read_fast(base)
                if (v4 == 0x73E7) and (v3 == 0xF912) and (v2 == 0xA320) and (v == 0xBB49):
                    return base+2
                v4 = v3
                v3 = v2
                v2 = v
                base += 2
        finally:
            self.mem_read_end()
            self.release_bus()
        return None

def main():
    parser = OptionParser(usage="supervisor [options] command",
            description="Commands: ...")

    parser.add_option("-v", "--verbose", dest="verbose",
         help="verbose", action="store_true", default=False)
    parser.add_option("-f", "--filename", dest="filename",
         help="filename", default=None)
    parser.add_option("-n", "--norelease", dest="norelease",
         help="do not release bus", action="store_true", default=False)

    (options, args) = parser.parse_args(sys.argv[1:])

    bus = smbus.SMBus(1)
    super = SuperDisk(bus, 0x20, options.verbose)

    if super.superAddress == None:
        print("Super not found in memory")
        sys.exit(-1)
    print("Super found at %08X" % super.superAddress)

    super.run()


if __name__=="__main__":
    main()
