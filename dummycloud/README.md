Dummycloud for Xiaomi vacuum robots
----
Copyright 2018 by Dustcloud Project (Author: S.)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
----

Enables 100% cloud-free operation of the robot
For use e.g. with Valetudo

Installation:
* Install binary as 0755 root:root /usr/local/bin/dummycloud (see build/)
* Install upstart config as /etc/init/dummycloud.conf (see doc/)
* Modify /etc/hosts to redirect Xiaomi endpoints to reserved IP space (see doc/)
* Modify /etc/rc.local to redirect packets back to robot (see doc/)
* You will need a privately provisioned robot with the following files:
  /mnt/default/roborock.conf
  /mnt/data/miio/wifi.conf
  /mnt/data/miio/device.uid
  /mnt/data/miio/device.country
  See dustcloud for details
* Reboot robot

Additional tips:
* You may want to edit some files on robot:
  sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' /opt/rockrobo/rrlog/rrlog.conf
  sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' /opt/rockrobo/rrlog/rrlogmt.conf
  sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/misc.sh
  sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/tar_extra_file.sh
  sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/toprotation.sh
  sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/topstop.sh
* To use only ntp.org, edit /opt/rockrobo/watchdog/ntpserver.conf
  #you can add your server line by line
  0.pool.ntp.org
  1.pool.ntp.org
  2.pool.ntp.org
  3.pool.ntp.org

Compilation using a robot image:
* Note: You will need to expand a 512MB factory image and install sources, a C compiler and libs
* mount -o loop disk.img image
* chroot image /usr/bin/qemu-arm-static /bin/bash
* export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
* make

---
Used libs/code:

pkcs7_padding.* : https://github.com/triangulum-com-au/tiny-AES128-C
aes.* : https://github.com/triangulum-com-au/tiny-AES128-C
cJSON : https://github.com/DaveGamble/cJSON
common_socket.* : https://github.com/netoptimizer/network-testing
hexdump.* : Original author: http://grapsus.net/blog/post/Hexadecimal-dump-in-C