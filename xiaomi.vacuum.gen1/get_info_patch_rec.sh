#!/bin/bash
if [ ! -f /mnt/data/rec_patched ]
then
    echo "patch recovery"
	mkdir /mnt/recovery
	mount /dev/mmcblk0p7 /mnt/recovery
	cp /opt/rockrobo/resources/sounds/prc/*.wav /mnt/recovery/opt/rockrobo/resources/sounds/prc/
	mkdir /mnt/recovery/root/.ssh
	chmod 700 /mnt/recovery/root/.ssh
	cp /root/.ssh/authorized_keys /mnt/recovery/root/.ssh/authorized_keys
	chmod 600 /mnt/recovery/root/.ssh/authorized_keys
	sed -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' -i /mnt/recovery/opt/rockrobo/watchdog/rrwatchdoge.conf
	cp /mnt/recovery/etc/OS_VERSION /mnt/data/recovery_OS_VERSION
	umount /mnt/recovery
	rmdir /mnt/recovery
	touch /mnt/data/rec_patched
fi
dinfo_file=/mnt/default/device.conf
dinfo_did=`cat $dinfo_file | grep -v ^# | grep did= | tail -1 | cut -d '=' -f 2`
dinfo_key=`cat $dinfo_file | grep -v ^# | grep key= | tail -1 | cut -d '=' -f 2`
dinfo_vendor=`cat $dinfo_file | grep -v ^# | grep vendor= | tail -1 | cut -d '=' -f 2`
dinfo_mac=`cat $dinfo_file | grep -v ^# | grep mac= | tail -1 | cut -d '=' -f 2`
dinfo_model=`cat $dinfo_file | grep -v ^# | grep model= | tail -1 | cut -d '=' -f 2`
dinfo_vinda=`cat /mnt/default/vinda | base64`
dinfo_date=`stat -c %Y /mnt/default/vinda`
dinfo_recoveryver=`cat /mnt/data/recovery_OS_VERSION | grep -v ^# | grep "ro.product.device=" | tail -1 | cut -d '=' -f 2`
dinfo_cputype=`cat /mnt/data/recovery_OS_VERSION | grep -v ^# | grep "ro.sys.cputype=" | tail -1 | cut -d '=' -f 2`
echo  "did=$dinfo_did key=$dinfo_key mac=$dinfo_mac vinda=$dinfo_vinda vindadate=$dinfo_date recovery=$dinfo_recoveryver cputype=$dinfo_cputype"
