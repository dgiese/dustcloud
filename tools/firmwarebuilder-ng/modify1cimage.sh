#!/bin/bash
# Author: Dennis Giese [dgiese@dontvacuum.me]
# Copyright 2017 by Dennis Giese

BASE_DIR="."
FLAG_DIR="."
IMG_DIR="./squashfs-root"
FEATURES_DIR="./features"

if [ ! -f $BASE_DIR/update.img ]; then
    echo "File update.img not found! Decryption and unpacking was apparently unsuccessful."
    exit 1
fi

if [ ! -f $BASE_DIR/authorized_keys ]; then
    echo "authorized_keys not found"
    exit 1
fi

if [ ! -f $FLAG_DIR/devicetype ]; then
    echo "devicetype definition not found, aborting"
    exit 1
fi

if [ ! -f $FLAG_DIR/jobid ]; then
    echo "jobid not found, aborting"
    exit 1
fi

DEVICETYPE=$(cat "$FLAG_DIR/devicetype")
FRIENDLYDEVICETYPE=$(cat "$FLAG_DIR/devicetype")
jobid=$(cat "$FLAG_DIR/jobid")
jobidmd5=$(cat "$FLAG_DIR/jobid" | md5sum | awk '{print $1}')

mkdir -p $BASE_DIR/output

echo "creating temp directory and unpacking squashfs"
updatetool -unpack $BASE_DIR/update.img .
rm $BASE_DIR/update.img
unsquashfs -d $IMG_DIR $BASE_DIR/rootfs.img
mv $BASE_DIR/rootfs.img $BASE_DIR/rootfs.img.template

echo "importing mcu update"
cp $BASE_DIR/mcu.bin $IMG_DIR/mcu.bin

echo "installing dropbear keys"
mkdir -p $IMG_DIR/etc/dropbear
chown root:root $IMG_DIR/etc/dropbear
cat $BASE_DIR/dropbear_rsa_host_key > $IMG_DIR/etc/dropbear/dropbear_rsa_host_key
cat $BASE_DIR/dropbear_dss_host_key > $IMG_DIR/etc/dropbear/dropbear_dss_host_key
cat $BASE_DIR/dropbear_ecdsa_host_key > $IMG_DIR/etc/dropbear/dropbear_ecdsa_host_key
cat $BASE_DIR/dropbear_ed25519_host_key > $IMG_DIR/etc/dropbear/dropbear_ed25519_host_key

echo "installing dropbear"
install -d $IMG_DIR/usr/local/sbin
install -m 0755 $FEATURES_DIR/dropbear_1c/dropbear $IMG_DIR/usr/local/sbin
install -d $IMG_DIR/usr/local/bin
install -m 0755 $FEATURES_DIR/dropbear_1c/dbclient $IMG_DIR/usr/local/bin
install -d $IMG_DIR/usr/local/bin
install -m 0755 $FEATURES_DIR/dropbear_1c/scp $IMG_DIR/usr/local/bin
cat $BASE_DIR/authorized_keys > $IMG_DIR/authorized_keys

echo "backdooring"
sed -i -E 's/::respawn:\/usr\/bin\/getty.sh//g' $IMG_DIR/etc/inittab
sed -i -E 's/Put a getty on the serial port/\n::respawn:-\/bin\/sh/g' $IMG_DIR/etc/inittab

echo "creating hooks for scripts"
cat $FEATURES_DIR/dropbear_1c/dropbear.sh > $IMG_DIR/etc/rc.d/dropbear.sh
chmod +x $IMG_DIR/etc/rc.d/dropbear.sh
echo "" >> $IMG_DIR/etc/rc.sysinit
echo "/etc/rc.d/dropbear.sh &" >> $IMG_DIR/etc/rc.sysinit

sed -i "s/\/usr\/local\/bin/\/data\/bin:\/usr\/local\/bin/g" $IMG_DIR/etc/rc.sysinit
echo "if [[ -f /data/_root_sysconfig.sh ]]; then" >> $IMG_DIR/etc/init.d/sysconfig.sh
echo "    /data/_root_sysconfig.sh &" >> $IMG_DIR/etc/init.d/sysconfig.sh
echo "fi" >> $IMG_DIR/etc/init.d/sysconfig.sh

echo "if [[ -f /data/_root_postboot.sh ]]; then" >> $IMG_DIR/etc/rc.sysinit
echo "    /data/_root_postboot.sh &" >> $IMG_DIR/etc/rc.sysinit
echo "fi" >> $IMG_DIR/etc/rc.sysinit

if [ -f $FLAG_DIR/valetudo ]; then
	echo "copy valetudo"
	install -D -m 0755 $FEATURES_DIR/valetudo/valetudo-armv7-lowmem $BASE_DIR/valetudo
	install -m 0755 $FEATURES_DIR/fwinstaller_1c/_root_postboot.sh.tpl $BASE_DIR/_root_postboot.sh.tpl
	touch $FLAG_DIR/patch_dns
fi
if [ -f $FLAG_DIR/patch_dns ]; then
	echo "patching DNS"
	cat $FEATURES_DIR/nsswitch/nsswitch.conf > $IMG_DIR/etc/nsswitch.conf
	rm $IMG_DIR/usr/bin/miio_client_helper_mjac.sh
	install -m 0755 $FEATURES_DIR/miio_clients/dreame_3.5.8/* $IMG_DIR/usr/bin
	if [ ! -f $IMG_DIR/usr/lib/libjson-c.so.2 ]; then
		install -m 0755 $FEATURES_DIR/miio_clients/3.5.8.lib/* $IMG_DIR/usr/lib
	sed -i -E 's/110.43.0.83/127.000.0.1/g' $IMG_DIR/usr/bin/miio_client
	sed -i -E 's/110.43.0.85/127.000.0.1/g' $IMG_DIR/usr/bin/miio_client
	rm $IMG_DIR/etc/hosts
	cat $FEATURES_DIR/valetudo/deployment/etc/hosts-local > $IMG_DIR/etc/hosts
	install -m 0755 $FEATURES_DIR/fwinstaller_1c/_root_postboot.sh.tpl $IMG_DIR/misc/_root_postboot.sh.tpl
	install -m 0755 $FEATURES_DIR/fwinstaller_1c/how_to_modify.txt $IMG_DIR/misc/how_to_modify.txt
fi

echo "Fix broken Dreame cronjob scripts"
sed -i -E 's/#source \/usr\/bin\/config/source \/usr\/bin\/config/g' $IMG_DIR/etc/rc.d/wifi_monitor.sh
sed -i -E 's/#source \/usr\/bin\/config/source \/usr\/bin\/config/g' $IMG_DIR/etc/rc.d/miio_monitor.sh

echo "Remove chinese DNS server"
sed -i 's/echo "nameserver 114.114.114.114" >> $RESOLV_CONF//g' $IMG_DIR/usr/share/udhcpc/default.script

echo "Reduce wifi_manager loglevel to error to save the NAND"
sed -i -E 's/-l4/-l1/g' $IMG_DIR/etc/rc.d/wifi_manager.sh

if [ -f $FLAG_DIR/tools ]; then
    echo "installing tools"
    cp -r $FEATURES_DIR/1c_tools/root-dir/* $IMG_DIR/
fi

if [ -f $FLAG_DIR/tools_pro ]; then
    echo "installing tools_pro"
    cp -r $FEATURES_DIR/1c_tools_pro/root-dir/* $IMG_DIR/
fi

if [ -f $FLAG_DIR/hostname ]; then
echo "patching Hostname"
	cat $FLAG_DIR/hostname > $IMG_DIR/etc/hostname
fi

if [ -f $FLAG_DIR/timezone ]; then
echo "patching Timezone"
	cat $FLAG_DIR/timezone > $IMG_DIR/etc/timezone
fi

if [ -f $FEATURES_DIR/fwinstaller_1c/sanitize.sh ]; then
	echo "Cleanup Dreame backdoors"
	$FEATURES_DIR/fwinstaller_1c/sanitize.sh
fi

touch $IMG_DIR/build.txt
echo "build with firmwarebuilder (https://builder.dontvacuum.me)" > $IMG_DIR/build.txt
date -u  >> $IMG_DIR/build.txt
echo "" >> $IMG_DIR/build.txt
sed -i '$ d' $IMG_DIR/etc/banner
sed -i '$ d' $IMG_DIR/etc/banner
cat $IMG_DIR/build.txt >> $IMG_DIR/etc/banner

echo "creating rootfs"
mksquashfs $IMG_DIR/ rootfs_tmp.img -noappend -root-owned -comp xz -b 256k -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1'
rm -rf $IMG_DIR
dd if=$BASE_DIR/rootfs_tmp.img of=$BASE_DIR/rootfs.img bs=128k conv=sync
rm $BASE_DIR/rootfs_tmp.img

md5sum $BASE_DIR/rootfs.img > $BASE_DIR/rootfs_md5sum
cp parameter.txt parameter
md5sum ./*.img > $BASE_DIR/firmware.md5sum


	echo "create installer package"
	if [ -f $FLAG_DIR/valetudo ]; then
		sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller_1c/install-val.sh > $BASE_DIR/install.sh
		chmod +x install.sh
		sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller_1c/install-manual.sh > $BASE_DIR/install-manual.sh
		chmod +x install-manual.sh
		tar -czf $BASE_DIR/output/${DEVICETYPE}_fw.tar.gz $BASE_DIR/*.img $BASE_DIR/mcu_md5sum mcu.bin $BASE_DIR/firmware.md5sum $BASE_DIR/install.sh $BASE_DIR/install-manual.sh $BASE_DIR/valetudo $BASE_DIR/_root_postboot.sh.tpl
	else
		sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller_1c/install.sh > $BASE_DIR/install.sh
		chmod +x install.sh
		sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller_1c/install-manual.sh > $BASE_DIR/install-manual.sh
		chmod +x install-manual.sh
		tar -czf $BASE_DIR/output/${DEVICETYPE}_fw.tar.gz $BASE_DIR/*.img $BASE_DIR/mcu_md5sum mcu.bin $BASE_DIR/firmware.md5sum $BASE_DIR/install.sh $BASE_DIR/install-manual.sh
	fi
	md5sum $BASE_DIR/output/${DEVICETYPE}_fw.tar.gz > $BASE_DIR/output/md5.txt
	echo "${DEVICETYPE}_fw.tar.gz" > $BASE_DIR/filename.txt
	touch $BASE_DIR/server.txt


touch $BASE_DIR/output/done
