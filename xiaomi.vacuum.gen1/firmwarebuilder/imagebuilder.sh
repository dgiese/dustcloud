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
# place english.pkg and v11_<fw_version>.pkg (e.g. v11_003077.pkg) in this folder
# place your authorized_keys in this folder
#
IS_MAC=false
FIRMWARE_VERSION=$1
SOUNDFILE=english.pkg

if [[ ! -n "$FIRMWARE_VERSION" ]]; then
	echo "You need to specify a firmware version, e.g. 003094"
	exit 1
fi

if [[ $OSTYPE == darwin* ]]; then
	# Mac OSX
	IS_MAC=true
	echo "Running on a Mac, adjusting commands accordingly"
fi

if [ ! -f /usr/bin/ccrypt ] && ! $IS_MAC; then
    echo "Ccrypt not found! Please install it (e.g. by apt-get install ccrypt)"
	exit 1
fi

if [ ! -f /usr/local/bin/ccrypt ] && $IS_MAC; then
    echo "Ccrypt not found! Please install it (e.g. by brew install ccrypt)"
	exit 1
fi

if [ ! -f $SOUNDFILE ]; then
    echo "File $SOUNDFILE not found!"
	exit 1
fi

if [ ! -f v11_$FIRMWARE_VERSION.pkg ]; then
    echo "File v11_$FIRMWARE_VERSION.pkg not found!"
	exit 1
fi

if [ ! -f authorized_keys ]; then
    echo "File authorized_keys not found!"
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
	echo "You must be a root user" 2>&1
	exit 1
else
	# Generate SSH Host Keys
	echo "Generate SSH Host Keys"
	rm ssh_host_*
	rm ssh_host_*.pub
	ssh-keygen -N "" -t rsa -f ssh_host_rsa_key
	ssh-keygen -N "" -t dsa -f ssh_host_dsa_key
	ssh-keygen -N "" -t ecdsa -f ssh_host_ecdsa_key
	ssh-keygen -N "" -t ed25519 -f ssh_host_ed25519_key
	echo "decrypt soundfile"
	ccrypt -d -K r0ckrobo#23456 $SOUNDFILE
	mkdir sounds
	cd sounds
	echo "unpack soundfile"
	tar -xzf ../$SOUNDFILE
	cd ..
	echo "decrypt firmware"
	ccrypt -d -K rockrobo v11_$FIRMWARE_VERSION.pkg
	echo "unpack firmware"
	tar -xzf v11_$FIRMWARE_VERSION.pkg
	if [ ! -f disk.img ]; then
		echo "File disk.img not found! Decryption and unpacking was apparently unsuccessful."
		exit 1
	fi
	mkdir image

	if $IS_MAC; then
		#ext4fuse doesn't support write properly
		#ext4fuse disk.img image -o force
		fuse-ext2 disk.img image -o rw+
	else
		mount -o loop disk.img image
	fi
	cd image
	echo "patch ssh host keys"
	cat ../ssh_host_rsa_key > ./etc/ssh/ssh_host_rsa_key
	cat ../ssh_host_rsa_key.pub > ./etc/ssh/ssh_host_rsa_key.pub
	cat ../ssh_host_dsa_key > ./etc/ssh/ssh_host_dsa_key
	cat ../ssh_host_dsa_key.pub > ./etc/ssh/ssh_host_dsa_key.pub
	cat ../ssh_host_ecdsa_key > ./etc/ssh/ssh_host_ecdsa_key
	cat ../ssh_host_ecdsa_key.pub > ./etc/ssh/ssh_host_ecdsa_key.pub
	cat ../ssh_host_ed25519_key > ./etc/ssh/ssh_host_ed25519_key
	cat ../ssh_host_ed25519_key.pub > ./etc/ssh/ssh_host_ed25519_key.pub
	echo "disable SSH firewall rule"
	if $IS_MAC; then
		# see https://stackoverflow.com/a/21243111
		sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' ./opt/rockrobo/watchdog/rrwatchdoge.conf
	else
		sed -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' -i ./opt/rockrobo/watchdog/rrwatchdoge.conf
	fi
	echo "integrate SSH authorized_keys"
	mkdir ./root/.ssh
	chmod 700 ./root/.ssh

	if [ -f ./root/.ssh/authorized_keys ]; then
		echo "removing obsolete authorized_keys from Xiaomi image"
		rm ./root/.ssh/authorized_keys
	fi

	cp ../authorized_keys ./root/.ssh/
	chmod 600 ./root/.ssh/authorized_keys
	echo "reconfiguring network traffic to xiaomi"
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
	echo "pack new firmware"
	tar -czf v11_$FIRMWARE_VERSION_patched.pkg disk.img
	if [ ! -f v11_$FIRMWARE_VERSION_patched.pkg ]; then
		echo "File v11_$FIRMWARE_VERSION_patched.pkg not found! Packing the firmware was unsuccessful."
		exit 1
	fi
	rm -f disk.img
	echo "encrypt firmware"
	ccrypt -e -K rockrobo v11_$FIRMWARE_VERSION_patched.pkg
	mkdir -p output
	mv v11_$FIRMWARE_VERSION_patched.pkg.cpt output/v11_$FIRMWARE_VERSION.pkg

	if $IS_MAC; then
		md5 output/v11_$FIRMWARE_VERSION.pkg > output/v11_$FIRMWARE_VERSION.md5
	else
		md5sum output/v11_$FIRMWARE_VERSION.pkg > output/v11_$FIRMWARE_VERSION.md5
	fi

	cat output/v11_$FIRMWARE_VERSION.md5
fi

