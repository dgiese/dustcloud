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

if [[ $EUID -ne 0 ]]; then
	echo "You must be a root user" 2>&1
	exit 1
fi

IS_MAC=false
if [[ $OSTYPE == darwin* ]]; then
	# Mac OSX
	IS_MAC=true
	echo "Running on a Mac, adjusting commands accordingly"
fi

if [ ! -f /usr/bin/ccrypt -a "$IS_MAC" = false ]; then
    echo "Ccrypt not found! Please install it (e.g. by apt install ccrypt)"
	exit 1
fi

if [ ! -f /usr/local/bin/ccrypt -a "$IS_MAC" = true ]; then
    echo "Ccrypt not found! Please install it (e.g. by brew install ccrypt)"
	exit 1
fi

if [[ $# -eq 0 ]]; then
	cat << EOF
usage: sudo ./firmwarebuilder -f v11_003094.pkg [-s english.pkg] [-k authorized_keys] [ -t Europe/Berlin ] [--disable-xiaomi]

Options:
  -f, --firmware            path to firmware file
  -s, --soundfile           path to sound file
  -k, --authorized-keys     path to authorized-keys file
  -t, --timezone            timezone to be used in vacuum
  --disable-xiaomi          disable xiaomi servers using hosts file
  --enable-minhttp          enable minimalistiv http server (:80)

Report bugs to: https://github.com/dgiese/dustcloud/issues
EOF
	exit 0
fi

DISABLE_XIAOMI=false
while [[ $# -gt 0 ]]; do
key="$1"

case $key in
    -f|--firmware)
    FIRMWARE="$2"
    shift
    shift
    ;;
    -s|--soundfile)
    SOUNDFILE="$2"
    shift
    shift
    ;;
    -k|--authorized-keys)
    AUTHORIZED_KEYS="$2"
    shift
    shift
    ;;
    -t|--timezone)
    TIMEZONE="$2"
    shift
    shift
    ;;
    --disable-xiaomi)
    DISABLE_XIAOMI=true
    shift
    ;;
    --enable-minhttp)
    ENABLE_MINHTTP=true
    shift
    ;;
    *)
    shift
    ;;
esac
done

SOUNDFILE=${SOUNDFILE:-"english.pkg"}
AUTHORIZED_KEYS=${AUTHORIZED_KEYS:-"authorized_keys"}
TIMEZONE=${TIMEZONE:-"Europe/Berlin"}
PASSWORD_FW="rockrobo"
PASSWORD_SND="r0ckrobo#23456"

if [[ ! -f "$FIRMWARE" ]]; then
	echo "You need to specify an existing firmware file, e.g. v11_003094.pkg"
	exit 1
fi
FIRMWARE=$(readlink -f "$FIRMWARE")
BASENAME=$(basename $FIRMWARE)
FILENAME="${BASENAME%.*}"

if [ ! -f "$SOUNDFILE" ]; then
    echo "File $SOUNDFILE not found!"
	exit 1
fi
SOUNDFILE=$(readlink -f "$SOUNDFILE")

if [ ! -f "$AUTHORIZED_KEYS" ]; then
    echo "File authorized_keys not found!"
	exit 1
fi
AUTHORIZED_KEYS=$(readlink -f "$AUTHORIZED_KEYS")

# Generate SSH Host Keys
echo "Generate SSH Host Keys"
rm -f ssh_host_*
ssh-keygen -N "" -t rsa -f ssh_host_rsa_key
ssh-keygen -N "" -t dsa -f ssh_host_dsa_key
ssh-keygen -N "" -t ecdsa -f ssh_host_ecdsa_key
ssh-keygen -N "" -t ed25519 -f ssh_host_ed25519_key
echo "decrypt soundfile"
ccrypt -d -K "$PASSWORD_SND" "$SOUNDFILE"
mkdir sounds
cd sounds
echo "unpack soundfile"
tar -xzf "$SOUNDFILE"
cd ..
echo "decrypt firmware"
ccrypt -d -K "$PASSWORD_FW" "$FIRMWARE"
echo "unpack firmware"
tar -xzf "$FIRMWARE"
if [ ! -f disk.img ]; then
	echo "File disk.img not found! Decryption and unpacking was apparently unsuccessful."
	exit 1
fi
mkdir image

if [ "$IS_MAC" = true ]; then
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
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' ./opt/rockrobo/watchdog/rrwatchdoge.conf
echo "integrate SSH authorized_keys"
mkdir ./root/.ssh
chmod 700 ./root/.ssh

if [ -f ./root/.ssh/authorized_keys ]; then
	echo "removing obsolete authorized_keys from Xiaomi image"
	rm ./root/.ssh/authorized_keys
fi

cp "$AUTHORIZED_KEYS" ./root/.ssh/authorized_keys
chmod 600 ./root/.ssh/authorized_keys

if [ "$DISABLE_XIAOMI" = true ]; then
	echo "reconfiguring network traffic to xiaomi"
	# comment out this section if you do not want do disable the xiaomi cloud
	# or redirect it
	echo "0.0.0.0       awsbj0-files.fds.api.xiaomi.com" >> ./etc/hosts
	echo "0.0.0.0       awsbj0.fds.api.xiaomi.com" >> ./etc/hosts
	#echo "0.0.0.0       ott.io.mi.com" >> ./etc/hosts
	#echo "0.0.0.0       ot.io.mi.com" >> ./etc/hosts
fi

if [ "$ENABLE_MINHTTP" = true ]; then
	cat ../rc.local > ./etc/rc.local
	cp ../minimal-http-server.sh ./root/minimal-http-server.sh
	chmod +x ./root/minimal-http-server.sh
	cp ../minimal-http-server.sh ./root/minimal-http-server-content.sh
fi

echo "#you can add your server line by line" > ./opt/rockrobo/watchdog/ntpserver.conf
echo "0.de.pool.ntp.org" >> ./opt/rockrobo/watchdog/ntpserver.conf
echo "1.de.pool.ntp.org" >> ./opt/rockrobo/watchdog/ntpserver.conf
echo "$TIMEZONE" > ./etc/timezone
# Replace chinese soundfiles with english soundfiles
cp ../sounds/*.wav ./opt/rockrobo/resources/sounds/prc/

cd ..
umount image
rm -rf image
rm -rf sounds
rm -f ssh_host_*
echo "pack new firmware"
PATCHED="${FILENAME}_patched.pkg"
tar -czf "$PATCHED" disk.img
if [ ! -f "$PATCHED" ]; then
	echo "File $PATCHED not found! Packing the firmware was unsuccessful."
	exit 1
fi
rm -f disk.img
echo "encrypt firmware"
ccrypt -e -K "$PASSWORD_FW" "$PATCHED"
mkdir -p output
mv "${PATCHED}.cpt" "output/${BASENAME}"

if [ "$IS_MAC" = true ]; then
	md5 "output/${BASENAME}" > "output/${FILENAME}.md5"
else
	md5sum "output/${BASENAME}" > "output/${FILENAME}.md5"
fi

cat "output/${FILENAME}.md5"
