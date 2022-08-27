# Supervisor board for Z8000
Scott Baker, www.smbaker.com

This directory supports a raspberry pi supervisor. The supervisor can be used
to peek and poke memory locations as well as to run a disk (called "superdisk").

Surprisingly, the C-extension version (supervisor_direct.py) in and of itself
wasn't much faster than the plain ordinary python version. What did really help
was two things: 1) snooping the data bus to look for a wakeup rather than
periodically reading a memory address, and 2) getting rid of as much i2c as
possible in favor of using data buffers.

Speeding up the i2c from 100KHz to 1.2MHz will make a large difference.

to increase i2c speed, edit /boot/config.txt
  dtparam=i2c_arm=on -->  dtparam=i2c_arm=on,i2c_arm_baudrate=1200000

make sure to run raspi-config and disable spi
  otherwise, it'll pull GPIO11 down during start
