#!/bin/bash

if [[ ! -f /mnt/reserve/patched.txt ]]; then
mkdir /mnt/recovery
mount /dev/mmcblk0p7 /mnt/recovery
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' /mnt/recovery/opt/rockrobo/watchdog/rrwatchdoge.conf
sed -i -E 's/dport 22/dport 29/g' /mnt/recovery/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/g' /mnt/recovery/opt/rockrobo/rrlog/rrlogd
chown root:root /mnt/recovery/root -R
chmod 700 /mnt/recovery/root -R
mkdir /mnt/recovery/root/.ssh
cat /root/.ssh/authorized_keys > /mnt/recovery/root/.ssh/authorized_keys
cp /usr/bin/adbd /mnt/recovery/usr/bin/adbd
touch /mnt/reserve/patched.txt
umount /mnt/recovery
fi
