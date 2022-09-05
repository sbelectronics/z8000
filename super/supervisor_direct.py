from __future__ import print_function
import sys
import time
import smbpi.supervisor_direct_v2_ext

class SupervisorDirect:
    def __init__(self, verbose):
        self.verbose = verbose
        self.ext = smbpi.supervisor_direct_v2_ext
        if not self.ext.init():
            sys.exit(-1)

    def log(self, msg):
        if self.verbose:
            print(msg, file=sys.stderr)

    def delay(self):
        time.sleep(0.001)

    def reset(self):
        pass

    def take_bus(self):
        self.ext.take_bus()

    def release_bus(self, reset=False):
        self.ext.release_bus(reset)

    def is_taken(self):
        return self.ext.is_taken()

    def mem_read(self, addr):
        return self.ext.mem_read(addr)

    def mem_read_start(self, addr):
        self.ext.mem_read_start(addr)

    def mem_read_end(self):
        self.ext.mem_read_end()

    def mem_read_fast(self, addr):
        return self.ext.mem_read_fast(addr)

    def mem_write(self, addr, val):
        self.ext.mem_write(addr, val)

    def mem_write_buffer(self, addr, bytes):
        self.ext.mem_write_buffer(addr, bytes)

    def mem_write_start(self, addr):
        self.ext.mem_write_start(addr)

    def mem_write_end(self):
        self.ext.mem_write_end()

    def mem_write_fast(self, addr, val):
        self.ext.mem_write_fast(addr, val)
