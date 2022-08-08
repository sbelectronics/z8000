from __future__ import print_function
import sys
import time
import smbpi.supervisor_direct_ext

class SupervisorDirect:
    def __init__(self, verbose):
        self.verbose = verbose
        smbpi.supervisor_direct_ext.init();

    def log(self, msg):
        if self.verbose:
            print(msg, file=sys.stderr)

    def delay(self):
        time.sleep(0.001)

    def reset(self):
        pass

    def take_bus(self):
        smbpi.supervisor_direct_ext.take_bus()

    def release_bus(self, reset=False):
        smbpi.supervisor_direct_ext.release_bus()

    def mem_read(self, addr):
        return smbpi.supervisor_direct_ext.mem_read(addr)

    def mem_read_start(self, addr):
        smbpi.supervisor_direct_ext.mem_read_start(addr)

    def mem_read_end(self):
        smbpi.supervisor_direct_ext.mem_read_end()

    def mem_read_fast(self, addr):
        return smbpi.supervisor_direct_ext.mem_read_fast(addr)

    def mem_write(self, addr, val):
        smbpi.supervisor_direct_ext.mem_write(addr, val)

    def mem_write_start(self, addr):
        smbpi.supervisor_direct_ext.mem_write_start(addr)

    def mem_write_end(self):
        smbpi.supervisor_direct_ext.mem_write_end()

    def mem_write_fast(self, addr, val):
        smbpi.supervisor_direct_ext.mem_write_fast(addr, val)
