#!/bin/bash
# Author: Dennis Giese [dgiese@dontvacuum.me]
# Copyright 2017 by Dennis Giese

BASE_DIR="."
FLAG_DIR="."
IMG_DIR="./CRL200S-OTA/target_sys/squashfs-root"
FEATURES_DIR="./features"

if [ ! -f $BASE_DIR/upd_viomi.vacuum.v6.bin ]; then
    echo "File upd_viomi.vacuum.v6.bin not found! Decryption and unpacking was apparently unsuccessful."
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

DEVICETYPE=$(cat "$FLAG_DIR/devicetype")
FRIENDLYDEVICETYPE=$(cat "$FLAG_DIR/devicetype")

mkdir -p $BASE_DIR/output

tar -xzvf $BASE_DIR/upd_viomi.vacuum.v6.bin -C $BASE_DIR/
tar -xzvf $BASE_DIR/CRL200S-OTA/target_sys.tar.gz -C $BASE_DIR/CRL200S-OTA/
unsquashfs -d $IMG_DIR $BASE_DIR/CRL200S-OTA/target_sys/rootfs.img
rm $BASE_DIR/CRL200S-OTA/target_sys/rootfs.img
mkdir -p $IMG_DIR/etc/dropbear
chown root:root $IMG_DIR/etc/dropbear
cat $BASE_DIR/dropbear_rsa_host_key > $IMG_DIR/etc/dropbear/dropbear_rsa_host_key
cat $BASE_DIR/dropbear_dss_host_key > $IMG_DIR/etc/dropbear/dropbear_dss_host_key
cat $BASE_DIR/dropbear_ecdsa_host_key > $IMG_DIR/etc/dropbear/dropbear_ecdsa_host_key
cat $BASE_DIR/dropbear_ed25519_host_key > $IMG_DIR/etc/dropbear/dropbear_ed25519_host_key


echo "integrate SSH authorized_keys"
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh
cat $BASE_DIR/authorized_keys > $IMG_DIR/root/.ssh/authorized_keys
cat $BASE_DIR/authorized_keys > $IMG_DIR/etc/dropbear/authorized_keys
chmod 600 $IMG_DIR/root/.ssh/authorized_keys
chmod 600 $IMG_DIR/etc/dropbear/authorized_keys
chown root:root $IMG_DIR/root -R

install -m 0755 $FEATURES_DIR/viomi_tools/root-dir/usr/sbin/dropbear $IMG_DIR/usr/sbin/dropbear

ln -s /usr/sbin/dropbear $IMG_DIR/usr/bin/dbclient
ln -s /usr/sbin/dropbear $IMG_DIR/usr/bin/scp
ln -s /usr/sbin/dropbear $IMG_DIR/usr/bin/dropbearkey

install -m 0755 $FEATURES_DIR/dropbear_viomi/init.d/dropbear $IMG_DIR/etc/init.d/dropbear
install -m 0755 $FEATURES_DIR/dropbear_viomi/config/dropbear $IMG_DIR/etc/config/dropbear

ln -s ../init.d/dropbear $IMG_DIR/etc/rc.d/S50dropbear
ln -s ../init.d/dropbear $IMG_DIR/etc/rc.d/K50dropbear

sed -i -E 's/echo 0/echo 1/g' $IMG_DIR/usr/sbin/RobotApp

echo "backdooring"
sed -i -E 's/\/bin\/login/\/bin\/ash/g' $IMG_DIR/etc/inittab
sed -i -E 's/\/bin\/login/\/bin\/ash/g' $IMG_DIR/bin/adb_shell

if [ -f $FLAG_DIR/tools ]; then
    echo "installing tools"
    cp -r $FEATURES_DIR/viomi_tools/root-dir/* $IMG_DIR/
fi

if [ -f $FLAG_DIR/hostname ]; then
echo "patching Hostname"
	cat $FLAG_DIR/hostname > $IMG_DIR/etc/hostname
fi

if [ -f $FLAG_DIR/timezone ]; then
echo "patching Timezone"
	cat $FLAG_DIR/timezone > $IMG_DIR/etc/timezone
fi


sed -i "s/^exit 0//" $IMG_DIR/etc/rc.local
echo "if [[ -f /mnt/UDISK/_root.sh ]]; then" >> $IMG_DIR/etc/rc.local
echo "    /mnt/UDISK/_root.sh &" >> $IMG_DIR/etc/rc.local
echo "fi" >> $IMG_DIR/etc/rc.local
echo "exit 0" >> $IMG_DIR/etc/rc.local

touch $IMG_DIR/build.txt
echo "build with firmwarebuilder (https://builder.dontvacuum.me)" > $IMG_DIR/build.txt
date -u  >> $IMG_DIR/build.txt
echo "" >> $IMG_DIR/build.txt

echo "finished patching, repacking"

mksquashfs $IMG_DIR/ $BASE_DIR/CRL200S-OTA/target_sys/rootfs_tmp.img -noappend -root-owned -comp xz -b 256k -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1'
rm -rf $IMG_DIR
dd if=$BASE_DIR/CRL200S-OTA/target_sys/rootfs_tmp.img of=$BASE_DIR/CRL200S-OTA/target_sys/rootfs.img bs=128k conv=sync
rm $BASE_DIR/CRL200S-OTA/target_sys/rootfs_tmp.img
md5sum "$BASE_DIR/CRL200S-OTA/target_sys/rootfs.img" | awk '{ print $1 }' > $BASE_DIR/CRL200S-OTA/target_sys/rootfs.img.md5

echo "check image file size"
maximumsize=26000000
minimumsize=20000000
actualsize=$(wc -c < "$BASE_DIR/CRL200S-OTA/target_sys/rootfs.img")
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash."
	exit 1
fi

if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation."
	exit 1
fi

if [ -f $FLAG_DIR/livesuit ]; then
	echo "build Livesuit image"
	tar -xzvf $BASE_DIR/CRL200S-OTA/ramdisk_sys.tar.gz
	cp $BASE_DIR/CRL200S-OTA/target_sys/rootfs.img $BASE_DIR/livesuitimage/rootfs.fex
	cp $BASE_DIR/CRL200S-OTA/target_sys/boot.img $BASE_DIR/livesuitimage/boot.fex
	if [ -f $FLAG_DIR/resetsettings ]; then
		echo "create empty partitions"
		cp $BASE_DIR/livesuitimage/sys_partition_reset.fex $BASE_DIR/livesuitimage/sys_partition.fex
	fi
	cp $BASE_DIR/ramdisk_sys/boot_initramfs.img $BASE_DIR/livesuitimage/recovery.fex
	./tools/pack-bintools/FileAddSum $BASE_DIR/livesuitimage/empty.fex $BASE_DIR/livesuitimage/Vempty.fex
	./tools/pack-bintools/FileAddSum $BASE_DIR/livesuitimage/boot.fex $BASE_DIR/livesuitimage/Vboot.fex
	./tools/pack-bintools/FileAddSum $BASE_DIR/livesuitimage/rootfs.fex $BASE_DIR/livesuitimage/Vrootfs.fex
	./tools/pack-bintools/FileAddSum $BASE_DIR/livesuitimage/recovery.fex $BASE_DIR/livesuitimage/Vrecovery.fex
	./tools/pack-bintools/FileAddSum $BASE_DIR/livesuitimage/boot-resource.fex $BASE_DIR/livesuitimage/Vboot-resource.fex
	./tools/pack-bintools/dragon $BASE_DIR/livesuitimage/image.cfg
	mv $BASE_DIR/livesuitimage/FILELIST $BASE_DIR/output/${DEVICETYPE}_livesuitimage.img
	md5sum $BASE_DIR/output/${DEVICETYPE}_livesuitimage.img > $BASE_DIR/output/md5.txt
	echo "${DEVICETYPE}_livesuitimage.img" > $BASE_DIR/filename.txt
	rm -rf $BASE_DIR/ramdisk_sys/
else
	rm $BASE_DIR/CRL200S-OTA/target_sys.tar.gz
	tar -czvf $BASE_DIR/CRL200S-OTA/target_sys.tar.gz -C $BASE_DIR/CRL200S-OTA/ target_sys
	md5sum $BASE_DIR/CRL200S-OTA/target_sys.tar.gz > $BASE_DIR/CRL200S-OTA/target_sys_md5
	rm -rf $BASE_DIR/CRL200S-OTA/target_sys
	tar -czf $BASE_DIR/output/${DEVICETYPE}_fw.tar.gz CRL200S-OTA
	md5sum $BASE_DIR/output/${DEVICETYPE}_fw.tar.gz > $BASE_DIR/output/md5.txt
	echo "${DEVICETYPE}_fw.tar.gz" > $BASE_DIR/filename.txt
	touch $BASE_DIR/server.txt
fi

if [ -f $FLAG_DIR/diff ]; then
	mkdir $BASE_DIR/original
	tar -xzvf $BASE_DIR/upd_viomi.vacuum.v6.bin -C $BASE_DIR/original/
	tar -xzvf $BASE_DIR/original/CRL200S-OTA/target_sys.tar.gz -C $BASE_DIR/original/CRL200S-OTA/
	unsquashfs -d $BASE_DIR/original/CRL200S-OTA/target_sys/squashfs-root $BASE_DIR/original/CRL200S-OTA/target_sys/rootfs.img
	rm -rf $BASE_DIR/original/CRL200S-OTA/target_sys/squashfs-root/dev
	rm -rf $BASE_DIR/original/CRL200S-OTA/ramdisk_sys*	

	mkdir $BASE_DIR/modified
        mkdir -p $BASE_DIR/modified/CRL200S-OTA/target_sys/
	unsquashfs -d $BASE_DIR/modified/CRL200S-OTA/target_sys/squashfs-root $BASE_DIR/CRL200S-OTA/target_sys/rootfs.img
	rm -rf $BASE_DIR/modified/CRL200S-OTA/target_sys/squashfs-root/dev

	/usr/bin/git diff --no-index $BASE_DIR/original/ $BASE_DIR/modified/ > $BASE_DIR/output/diff.txt
	rm -rf $BASE_DIR/original
	rm -rf $BASE_DIR/modified
fi

touch $BASE_DIR/output/done
