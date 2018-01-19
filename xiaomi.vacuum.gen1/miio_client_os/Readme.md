miio\_client\_os
================

Open source implementation of the xiaomi vacuum miio_client. Works without cloud connection.

How to compile in chroot with qemu
----------------------------------
1. Install static linked qemu (e.g. `apt-get install qemu-user-static`)
2. extract rootfs of robot
3. `cp $(which qemu-arm-static) rootfs/usr/bin`
4. `cp /etc/resolv.conf rootfs/etc/resolv.conf` (for internet)
5. `chroot rootfs qemu-arm-static /bin/bash`
6. remove ppa from /etc/apt/sources.list
7. `apt-get update`
8. `apt-get install build-essential cmake libgcrypt-dev`
9. `cd` to miio\_cient\_os directory
9. `cmake CMakeLists.txt`
10. `make`


What isn't working
------------------
 * expect everything to be broken
 * cloud connection
 * token management (token is hard coded)

What is working
------------------
 * receiving and sending of external commands
