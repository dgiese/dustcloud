#!/bin/bash
# Author: Dennis Giese [dustcloud@1338-1.org]
# Copyright 2017 by Dennis Giese

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program. If not, see <http://www.gnu.org/licenses/>.
# Preparation:
# place english.pkg and v11_003077.pkg in this folder
# place your authorized_keys in this folder
#
if [ ! -f english.pkg ]; then
    echo "File english.pkg not found!"
fi

if [ ! -f v11_003077.pkg ]; then
    echo "File v11_003077.pkg not found!"
fi

if [ ! -f authorized_keys ]; then
    echo "File authorized_keys not found!"
fi

if [[ $EUID -ne 0 ]]; then
	echo "You must be a root user" 2>&1
	exit 1
else
	echo "decrypt soundfile"
	ccrypt -d -K r0ckrobo#23456 english.pkg
	mkdir sounds
	cd sounds
	echo "unpack soundfile"
	tar -xzvf ../english.pkg
	cd ..
	echo "decrypt firmware"
	ccrypt -d -K rockrobo v11_003077.pkg
	echo "unpack firmware"
	tar -xzvf v11_003077.pkg
	mv v11_003077.pkg v11_003077.pkg.tar.gz
	mkdir image
	mount -o loop disk.img image
	cd image
	echo "disable SSH firewall rule"
	sed -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' -i ./opt/rockrobo/watchdog/rrwatchdoge.conf
	echo "integrate SSH authorized_keys"
	mkdir ./root/.ssh
	chmod 700 ./root/.ssh
	rm ./root/.ssh/authorized_keys
	cp authorized_keys ./root/.ssh/
	chmod 600 ./root/.ssh/authorized_keys
	# comment out this section if you do not want do disable the xiaomi cloud
	# or redirect it
	echo "0.0.0.0       awsbj0-files.fds.api.xiaomi.com" >> ./etc/hosts
	echo "0.0.0.0       awsbj0.fds.api.xiaomi.com" >> ./etc/hosts
	#echo "0.0.0.0       ott.io.mi.com" >> ./etc/hosts
	#echo "0.0.0.0       ot.io.mi.com" >> ./etc/hosts
	echo "#you can add your server line by line" > ./opt/rockrobo/watchdog/ntpserver.conf
	echo "0.de.pool.ntp.org" >> ./opt/rockrobo/watchdog/ntpserver.conf
	echo "1.de.pool.ntp.org" >> ./opt/rockrobo/watchdog/ntpserver.conf
	echo "Europe/Berlin" > ./etc/timezone
	# Replace chinese soundfiles with english soundfiles
	cp ../sounds/*.wav ./opt/rockrobo/resources/sounds/prc/

	cd ..
	umount image
	rm -rf image
	rm -rf sounds
	tar -czvf v11_003077_patched.pkg disk.img
	ccrypt -e -K rockrobo v11_003077_patched.pkg
	mv v11_003077_patched.pkg.cpt v11_003077.pkg
	md5sum v11_003077.pkg > v11_003077.md5
fi

