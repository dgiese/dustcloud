#!/bin/ash

DEVICEMODEL="CHANGEDEVICEMODELCHANGE"
echo ""
echo "---------------------------------------------------------------------------"
echo " Rockrobo Root"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Version: ${DEVICEMODEL}"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

#/sbin/getty -L ttyS0 115200 vt100 -n -l /bin/ash

mount -o ro /dev/nandb /default
if [ $? -ne 0 ]; then
        echo "(!!!) Invalid device type. You will be reported."
        sleep 2
        echo 1 > /dev/watchdog
        exit 1
fi


grep "model=${DEVICEMODEL}" /default/device.conf
if [ $? -eq 1 ]; then
	echo "(!!!) License check failed. You will be reported."
        sleep 2
        echo 1 > /dev/watchdog
	exit 1
fi

umount /default

IMG_DIR=/squashfs-root
BASE_DIR=/

dd if=/dev/nande of=/nande
unsquashfs nande
rm nande

if [[ ! -f /squashfs-root/etc/passwd ]]; then
	echo "(!!!) Error 82. Restarting..."
        sleep 2
        echo 1 > /dev/watchdog
	exit 1
fi

echo "disable SSH firewall rule"
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/rrlog/rrlogd

echo "integrate SSH authorized_keys"
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh
cat $BASE_DIR/authorized_keys > $IMG_DIR/root/.ssh/authorized_keys
cat $BASE_DIR/authorized_keys > $IMG_DIR/etc/dropbear/authorized_keys
chmod 600 $IMG_DIR/root/.ssh/authorized_keys
chmod 600 $IMG_DIR/etc/dropbear/authorized_keys
chown root:root $IMG_DIR/root -R

echo "replacing dropbear"
cp /deployment/dropbear $IMG_DIR/usr/sbin/dropbear
chmod +x $IMG_DIR/usr/sbin/dropbear
cp /deployment/dbclient $IMG_DIR/usr/bin/dbclient
chmod +x $IMG_DIR/usr/bin/dbclient
cp /deployment/dropbearkey $IMG_DIR/usr/bin/dropbearkey
chmod +x $IMG_DIR/usr/bin/dropbearkey
cp /deployment/scp $IMG_DIR/usr/bin/scp
chmod +x $IMG_DIR/usr/bin/scp

echo "replace adbd"
cp /deployment/adbd $IMG_DIR/usr/bin/adbd
chmod +x $IMG_DIR/usr/bin/adbd

touch $IMG_DIR/build.txt
echo "root build with dustbuilder (https://builder.dontvacuum.me)" > $IMG_DIR/build.txt

echo "creating and writing rootfs"
mksquashfs $IMG_DIR/ rootfs_tmp.img -noappend -root-owned -comp gzip -b 128k
rm -rf $IMG_DIR
dd if=$BASE_DIR/rootfs_tmp.img of=$BASE_DIR/rootfs.img bs=128k conv=sync
rm $BASE_DIR/rootfs_tmp.img

echo "check image file size"
maximumsize=24117248
minimumsize=20000000
actualsize=$(wc -c < /rootfs.img)
echo $actualsize
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash. Aborting the installation"
        sleep 2
        echo 1 > /dev/watchdog
	exit 1
fi
if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation. Aborting the installation"
        sleep 2
        echo 1 > /dev/watchdog
	exit 1
fi
echo "writing firmware"
dd if=/rootfs.img of=/dev/nande
dd if=/rootfs.img of=/dev/nandf

#echo "restoring partitions"
#tar -xzvf /nand.tar.gz
#dd if=/nanda of=/dev/nanda bs=1M
#dd if=/nandg of=/dev/nandg bs=1M
#dd if=/nandh of=/dev/nandh bs=1M
#dd if=/nandi of=/dev/nandi bs=1M

sync
echo "finished, preparing for reboot"
sleep 5
echo 1 > /dev/watchdog
sleep 5
