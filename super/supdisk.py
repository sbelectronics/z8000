from __future__ import print_function
from supervisor_direct import SupervisorDirect

import os
import smbus
import string
import sys
import time
from optparse import OptionParser

CMD_OFS = 0
ADDR_OFS = 2
DMA_OFS = 6

CMD_INIT = 0
CMD_READ = 1
CMD_WRITE = 2

class SuperDisk(SupervisorDirect):
    def __init__(self, verbose, stats):
        SupervisorDirect.__init__(self, verbose)
        self.superAddress = self.find_super()

        self.filename = "sup.img"
        self.f = None
        self.mtime = 0
        self.wokeCount = 0
        self.fallCount = 0
        self.falseCount = 0
        self.elap = 0.0
        self.elapCount = 0.0
        self.stats = stats

    def check_open(self):
        if self.f is not None:
            mtime = os.stat(self.filename).st_mtime
            if (mtime > self.mtime):
                print("possible file change detected")
                self.f.close()
                self.f=None
        if self.f is None:
            self.f = open("sup.img", "r+b")
            self.mtime = os.stat(self.filename).st_mtime


    """ implemented in C now... """
    def wait_for_signal(self):
        hit1=False
        hit2=False
        tStart = time.time()
        while True:
            m = self.ext.mem_snoop()
            if m == 0x73E7:
                hit1=True
            if m == 0xF912:
                hit2=True
            if hit1 and hit2:
                return True
            if (time.time()-tStart) > 0.1:
                return False

    def account(self, woke, cmd, tStart):
        if (cmd == 0):
            if woke:
                self.falseCount += 1
            else:
                # not woke, no command == idle
                return
        else:
            if woke:
                self.wokeCount += 1
            else:
                self.fallCount += 1
        
        if ((self.wokeCount + self.fallCount + self.falseCount) % 100) == 0:
            if self.elapCount > 0:
                elapsed = (self.elap/self.elapCount)
            else:
                elapsed = 0

            if self.verbose or self.stats:
                print("woke %d, fall %d, false %d, avg %0.4f" % (self.wokeCount, self.fallCount, self.falseCount, elapsed))

        if (tStart is not None) and (cmd in [1,2]):
            self.elap = self.elap + time.time() - tStart
            self.elapCount += 1

        if self.verbose:
            if tStart is not None:
                print(time.time() - tStart)

    def run(self):
        lastWoke = False
        while True:
            (cmd, fileAddr, dmaAddr) = self.get_cmd()
            if cmd == CMD_READ:
                tStart = time.time()
                self.read(fileAddr, dmaAddr)
                self.account(lastWoke, cmd, tStart)
            elif cmd == CMD_WRITE:
                tStart = time.time()                
                self.write(fileAddr, dmaAddr)
                self.account(lastWoke, cmd, tStart)
            elif cmd == CMD_INIT:
                print("set-active")
                self.set_active()
            else:
                self.account(lastWoke, 0, None)

            lastWoke = self.ext.wait_signal();

    def mapseg(self, x):
        # We will get called with segment numbers, which
        # we need to map to disk addresses. Do the same
        # thing the Memory PLD does.

        segmap = {0x10: 0x08,    # separate I/D as D
                  0x11: 0x09,
                  0x12: 0x0A,
                  0x13: 0x0B,
                  0x14: 0x0C,
                  0x15: 0x0D,
                  0x16: 0x0E,
                  0x17: 0x0F,

                  0x18: 0x00,    # I-as-D shadows
                  0x19: 0x01,
                  0x1A: 0x02,
                  0x1B: 0x03,
                  0x1C: 0x04,
                  0x1D: 0x05,
                  0x1E: 0x06,
                  0x1F: 0x07}
        seg = x >> 24
        seg = segmap.get(seg, seg)

        return (x&0x00FFFFFF | (seg << 24))

    def read(self, fileAddr, dmaAddr):
        if (not self.is_taken()):
            print("read while bus not taken");
            sys.exit(-1)

        dmaAddr = self.mapseg(dmaAddr)
        if self.verbose:      
            print("read %X %X\n" %(fileAddr, dmaAddr))

        if (dmaAddr & 1) != 0:
            print("unaligned read %X\n" % dmaAddr)
            sys.exit(-1)

        try:
            #self.take_bus()

            self.check_open()

            self.f.seek(fileAddr*128)
            buf = self.f.read(128)
            hi = True
            addr = dmaAddr
            self.mem_write_start(addr)
            self.mem_write_buffer(addr, buf)            
            self.mem_write_end()

            if self.verbose:
              print("sent %d" % (addr-self.superAddress-BUF_OFS))

            # Let CPM-8K know we're done
            self.mem_write(self.superAddress + CMD_OFS, 0x81)
        finally:
            self.release_bus()

    def write(self, fileAddr, dmaAddr):
        if (not self.is_taken()):
            print("write while bus not taken");
            sys.exit(-1)

        dmaAddr = self.mapseg(dmaAddr)
        if self.verbose:     
            print("write %X %X\n" %(fileAddr, dmaAddr))

        if (dmaAddr & 1) != 0:
            print("unaligned write %X\n" % dmaAddr)
            sys.exit(-1)

        try:
            #self.take_bus()

            self.check_open()

            buf = bytearray(128)
            addr = dmaAddr
            self.mem_read_start(addr)
            for i in range(0,64):
                w = self.mem_read_fast(addr)
                buf[i*2] = w>>8
                buf[i*2+1] = w & 0xFF
                addr += 2
            self.mem_read_end()

            if self.verbose:
              print("received %d" % (addr-self.superAddress-BUF_OFS))

            self.f.seek(fileAddr*128)
            self.f.write(buf)

            # don't detect our own change
            self.mtime = os.stat(self.filename).st_mtime + 2

            # Let CPM-8K know we're done
            self.mem_write(self.superAddress + CMD_OFS, 0x82)
        finally:
            self.release_bus()            

    def get_cmd(self):
        keep_bus = False
        try:
            self.take_bus()
            self.mem_read_start(self.superAddress)
            cmd = self.mem_read_fast(self.superAddress + CMD_OFS)
            fileAddr = None
            dmaAddr = None
            if (cmd==1) or (cmd==2):
                fileAddr = (self.mem_read_fast(self.superAddress + ADDR_OFS) << 16) | \
                            self.mem_read_fast(self.superAddress + ADDR_OFS+2)
                dmaAddr  = (self.mem_read_fast(self.superAddress + DMA_OFS) << 16) | \
                            self.mem_read_fast(self.superAddress + DMA_OFS+2)
                dmaAddr = dmaAddr & 0x7FFFFFFF
                # keep the bus for now. We're about to call _read or _write. They can release
                # the bus.
                keep_bus = True
            return (cmd, fileAddr, dmaAddr)
        finally:
            if (not keep_bus):
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
    parser.add_option("-s", "--stats", dest="stats",
         help="stats", action="store_true", default=False)
    parser.add_option("-f", "--filename", dest="filename",
         help="filename", default=None)
    parser.add_option("-n", "--norelease", dest="norelease",
         help="do not release bus", action="store_true", default=False)

    (options, args) = parser.parse_args(sys.argv[1:])

    super = SuperDisk(options.verbose, options.stats)

    if super.superAddress == None:
        print("Super not found in memory")
        sys.exit(-1)
    print("Super found at %08X" % super.superAddress)

    super.run()


if __name__=="__main__":
    main()
