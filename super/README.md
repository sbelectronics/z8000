# Supervisor board for Z8000
Scott Baker, www.smbaker.com

This directory supports a raspberry pi supervisor. The supervisor can be used
to peek and poke memory locations as well as to run a disk (called "superdisk").

Surprisingly, the C-extension version (supervisor_direct.py) isn't much faster
than the plain ordinary python version.

to increase i2c speed, edit /boot/config.txt
  dtparam=i2c_arm=on -->  dtparam=i2c_arm=on,i2c_arm_baudrate=1200000
