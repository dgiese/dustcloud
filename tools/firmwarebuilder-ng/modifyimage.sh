#!/bin/bash
# Author: Dennis Giese [dgiese@dontvacuum.me]
# Copyright 2017 by Dennis Giese

BASE_DIR="."
FLAG_DIR="."
IMG_DIR="./image"
FEATURES_DIR="./features"

if [ ! -f $BASE_DIR/disk.img ]; then
    echo "File disk.img not found! Decryption and unpacking was apparently unsuccessful."
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
FRIENDLYDEVICETYPE=$(sed "s/\[s|t\]/x/g" $FLAG_DIR/devicetype)
version=$(cat "$FLAG_DIR/version")


mkdir -p $BASE_DIR/output


mkdir $BASE_DIR/image
mount -o loop disk.img $BASE_DIR/image
if [ ! -f $IMG_DIR/etc/fstab ]; then
    echo "File fstab not found. Mounting was apparently unsuccessful."
    exit 1
fi

if [ ! -f $BASE_DIR/ssh_host_rsa_key ]; then
    echo "RSA hostkey not found."
    exit 1
fi

if [ -d $IMG_DIR/etc/ssh/ ]; then
	cat $BASE_DIR/ssh_host_rsa_key > $IMG_DIR/etc/ssh/ssh_host_rsa_key
	cat $BASE_DIR/ssh_host_rsa_key.pub > $IMG_DIR/etc/ssh/ssh_host_rsa_key.pub
	cat $BASE_DIR/ssh_host_dsa_key > $IMG_DIR/etc/ssh/ssh_host_dsa_key
	cat $BASE_DIR/ssh_host_dsa_key.pub > $IMG_DIR/etc/ssh/ssh_host_dsa_key.pub
	cat $BASE_DIR/ssh_host_ecdsa_key > $IMG_DIR/etc/ssh/ssh_host_ecdsa_key
	cat $BASE_DIR/ssh_host_ecdsa_key.pub > $IMG_DIR/etc/ssh/ssh_host_ecdsa_key.pub
	cat $BASE_DIR/ssh_host_ed25519_key > $IMG_DIR/etc/ssh/ssh_host_ed25519_key
	cat $BASE_DIR/ssh_host_ed25519_key.pub > $IMG_DIR/etc/ssh/ssh_host_ed25519_key.pub
else
	cat $BASE_DIR/dropbear_rsa_host_key > $IMG_DIR/etc/dropbear/dropbear_rsa_host_key
	cat $BASE_DIR/dropbear_dss_host_key > $IMG_DIR/etc/dropbear/dropbear_dss_host_key
	cat $BASE_DIR/dropbear_ecdsa_host_key > $IMG_DIR/etc/dropbear/dropbear_ecdsa_host_key
	cat $BASE_DIR/dropbear_ed25519_host_key > $IMG_DIR/etc/dropbear/dropbear_ed25519_host_key
fi

echo "disable SSH firewall rule"
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
md5sum $IMG_DIR/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/rrlog/rrlogd
sed -i -E 's/dport 22/dport 29/' $IMG_DIR/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/' $IMG_DIR/opt/rockrobo/rrlog/rrlogd
md5sum $IMG_DIR/opt/rockrobo/watchdog/WatchDoge

echo "integrate SSH authorized_keys"
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh
cat $BASE_DIR/authorized_keys > $IMG_DIR/root/.ssh/authorized_keys
chmod 600 $IMG_DIR/root/.ssh/authorized_keys
chown root:root $IMG_DIR/root
chown root:root $IMG_DIR/root/.ssh
chown root:root $IMG_DIR/root/.ssh/authorized_keys

if [ -f "$BASE_DIR/librrlocale.so" ]; then
    echo "patch region signature checking"
    install -m 0755 "$BASE_DIR/librrlocale.so" $IMG_DIR/opt/rockrobo/cleaner/lib/librrlocale.so
fi

echo "replace dropbear if needed"
if [ -f $IMG_DIR/usr/sbin/dropbear ]; then
	echo "replacing"
	md5sum $IMG_DIR/usr/sbin/dropbear
	install -m 0755 $FEATURES_DIR/dropbear_rr22/dropbear $IMG_DIR/usr/sbin/dropbear
	install -m 0755 $FEATURES_DIR/dropbear_rr22/dbclient $IMG_DIR/usr/bin/dbclient
	install -m 0755 $FEATURES_DIR/dropbear_rr22/dropbearkey $IMG_DIR/usr/bin/dropbearkey
	install -m 0755 $FEATURES_DIR/dropbear_rr22/scp $IMG_DIR/usr/bin/scp
	md5sum $IMG_DIR/usr/sbin/dropbear
fi

md5sum $IMG_DIR/opt/rockrobo/miio/miio_client
if grep -q "ots_info_ack" $IMG_DIR/opt/rockrobo/miio/miio_client; then
	echo "found OTS version of miio client, replacing it with 3.5.8"
     cp $FEATURES_DIR/miio_clients/3.5.8/miio_client $IMG_DIR/opt/rockrobo/miio/miio_client
fi
md5sum $IMG_DIR/opt/rockrobo/miio/miio_client

if [ -f $FLAG_DIR/otarootkit ]; then
    echo "install otarootkit"
    cp $IMG_DIR/bin/dd $IMG_DIR/bin/ddd
    cp $FEATURES_DIR/dd $IMG_DIR/bin/dd
    chmod +x $IMG_DIR/bin/dd
fi

if [ -f $FLAG_DIR/tools ]; then
    echo "install preinstalled packages"
	if [ -f $IMG_DIR/usr/bin/dpkg ]; then
		  cp /usr/bin/qemu-arm-static $IMG_DIR/usr/bin
		  mount -o bind /dev $IMG_DIR/dev
		  mount -o bind /sys $IMG_DIR/sys
		  mount -t proc /proc $IMG_DIR/proc
		  mount -o bind $FEATURES_DIR/rr_tools $IMG_DIR/home

		  chroot $IMG_DIR/ qemu-arm-static /usr/bin/dpkg -i /home/nano_2.2.6-1ubuntu1_armhf.deb
		  chroot $IMG_DIR/ qemu-arm-static /usr/bin/dpkg -i /home/htop_1.0.2-3_armhf.deb
		  chroot $IMG_DIR/ qemu-arm-static /usr/bin/dpkg -i /home/wget_1.15-1ubuntu1.14.04.5_armhf.deb

		  rm $IMG_DIR/usr/bin/qemu-arm-static
		  umount $IMG_DIR/dev
		  umount $IMG_DIR/sys
		  umount $IMG_DIR/proc
		  umount $IMG_DIR/home
	else
		cp -p -r $FEATURES_DIR/rr_tools/root-dir/* $IMG_DIR/
	fi

fi


if [ -f $FLAG_DIR/adbd ]; then
    echo "replace adbd"
    rm $IMG_DIR/usr/bin/adbd
    install -m 0755 $FEATURES_DIR/adbd $IMG_DIR/usr/bin/adbd
fi

if [ -f $FLAG_DIR/valetudo_re ]; then

	echo "install valetudo_re"
	if [ ! -f $IMG_DIR/etc/inittab ]; then
		echo "Full Ubuntu install mode"
		cp /usr/bin/qemu-arm-static $IMG_DIR/usr/bin
		mount -o bind /dev $IMG_DIR/dev
		mount -o bind /sys $IMG_DIR/sys
		mount -t proc /proc $IMG_DIR/proc
		mount -o bind $FEATURES_DIR/valetudo_re $IMG_DIR/home

		chroot $IMG_DIR/ qemu-arm-static /usr/bin/dpkg -i /home/valetudo-re_armhf.deb

		rm $IMG_DIR/usr/bin/qemu-arm-static
		umount $IMG_DIR/dev
		umount $IMG_DIR/sys
		umount $IMG_DIR/proc
		umount $IMG_DIR/home
	else
		echo "Stripped Ubuntu install mode"
		install -m 0755 $FEATURES_DIR/valetudo/deployment/S10rc_local $IMG_DIR/etc/init/S10rc_local
		install -m 0755 $FEATURES_DIR/valetudo/deployment/S11valetudo-withdaemon $IMG_DIR/etc/init/S11valetudo
		install -D -m 0755 $FEATURES_DIR/valetudo/deployment/valetudo-daemon.sh $IMG_DIR/usr/local/bin/valetudo-daemon.sh

		# Copy iptables from 1048
		mkdir -p $IMG_DIR/lib/xtables/
		cp $FEATURES_DIR/iptables/xtables/*.* $IMG_DIR/lib/xtables/
		cp $FEATURES_DIR/iptables/ip6tables $IMG_DIR/sbin/

		install -D -m 0755 $FEATURES_DIR/valetudo_re/valetudo $IMG_DIR/usr/local/bin/valetudo
		install -m 0644 $FEATURES_DIR/valetudo/deployment/valetudo.conf $IMG_DIR/etc/init/valetudo.conf

		cat $FEATURES_DIR/valetudo_re/deployment/hosts >> $IMG_DIR/etc/hosts

		sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
		cat $FEATURES_DIR/valetudo_re/deployment/rc.local >> $IMG_DIR/etc/rc.local
		echo >> $IMG_DIR/etc/rc.local
		echo "exit 0" >> $IMG_DIR/etc/rc.local
		touch $FLAG_DIR/patch_logging
	fi
fi

if [ -f $FLAG_DIR/valetudo_061 ]; then
    echo "install valetudo old version"


	if [ -f "$IMG_DIR/etc/inittab" ]; then
		echo "Stripped Ubuntu install mode"
		install -m 0755 $FEATURES_DIR/valetudo/deployment/S10rc_local $IMG_DIR/etc/init/S10rc_local
		install -m 0755 $FEATURES_DIR/valetudo/deployment/S11valetudo-withdaemon $IMG_DIR/etc/init/S11valetudo
		install -D -m 0755 $FEATURES_DIR/valetudo/deployment/valetudo-daemon.sh $IMG_DIR/usr/local/bin/valetudo-daemon.sh

		# Copy iptables from 1048
		mkdir -p $IMG_DIR/lib/xtables/
		cp $FEATURES_DIR/iptables/xtables/*.* $IMG_DIR/lib/xtables/
		cp $FEATURES_DIR/iptables/ip6tables $IMG_DIR/sbin/
	fi

    install -D -m 0755 $FEATURES_DIR/valetudo_061/valetudo $IMG_DIR/usr/local/bin/valetudo
    install -m 0644 $FEATURES_DIR/valetudo/deployment/valetudo.conf $IMG_DIR/etc/init/valetudo.conf

    cat $FEATURES_DIR/valetudo/deployment/etc/hosts >> $IMG_DIR/etc/hosts

    sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
    cat $FEATURES_DIR/valetudo/deployment/etc/rc.local >> $IMG_DIR/etc/rc.local
    echo >> $IMG_DIR/etc/rc.local
    echo "exit 0" >> $IMG_DIR/etc/rc.local
    touch $FLAG_DIR/patch_logging
fi

if [ -f $FLAG_DIR/valetudo ]; then
    echo "install valetudo"

	if [ -f "$IMG_DIR/etc/inittab" ]; then
		echo "Stripped Ubuntu install mode"
		install -m 0755 $FEATURES_DIR/valetudo/deployment/S10rc_local $IMG_DIR/etc/init/S10rc_local
		install -m 0755 $FEATURES_DIR/valetudo/deployment/S11valetudo $IMG_DIR/etc/init/S11valetudo

		# Copy iptables from 1048
		mkdir -p $IMG_DIR/lib/xtables/
		cp $FEATURES_DIR/iptables/xtables/*.* $IMG_DIR/lib/xtables/
		cp $FEATURES_DIR/iptables/ip6tables $IMG_DIR/sbin/
	fi

    install -D -m 0755 $FEATURES_DIR/valetudo/valetudo-armv7 $IMG_DIR/usr/local/bin/valetudo
    install -m 0644 $FEATURES_DIR/valetudo/deployment/valetudo.conf $IMG_DIR/etc/init/valetudo.conf

    cat $FEATURES_DIR/valetudo/deployment/etc/hosts >> $IMG_DIR/etc/hosts

    sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
    cat $FEATURES_DIR/valetudo/deployment/etc/rc.local >> $IMG_DIR/etc/rc.local
    echo >> $IMG_DIR/etc/rc.local
    echo "exit 0" >> $IMG_DIR/etc/rc.local
    touch $FLAG_DIR/patch_logging
fi

if [ -f $FLAG_DIR/patch_logging ]; then
    echo "patch logging"
    # UPLOAD_METHOD=0 (no upload)
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Set LOG_LEVEL=3
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Reduce logging of miio_client
    sed -i 's/-l 2/-l 0/' $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf

    # Let the script cleanup logs
    sed -i 's/nice.*//' $IMG_DIR/opt/rockrobo/rrlog/tar_extra_file.sh

    # Disable collecting device info to /dev/shm/misc.log
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/misc.sh

    # Disable logging of 'top'
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/toprotation.sh
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/topstop.sh
    echo "patch watchdog log"
    # Disable watchdog log
    # shellcheck disable=SC2016
    sed -i -E 's/\$RR_UDATA\/rockrobo\/rrlog\/watchdog.log/\/dev\/null/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
fi

if [ -f $FLAG_DIR/patch_dns ]; then
echo "patching DNS"
	sed -i -E 's/110.43.0.83/127.000.0.1/g' $IMG_DIR/opt/rockrobo/miio/miio_client
	sed -i -E 's/110.43.0.85/127.000.0.1/g' $IMG_DIR/opt/rockrobo/miio/miio_client
	sed -i 's/exec WatchDoge /\n\    ip addr add 203.0.113.1 dev lo\n    exec WatchDoge /g'  $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
	cat $FEATURES_DIR/valetudo/deployment/etc/hosts-local > $IMG_DIR/etc/hosts
fi


if [ -f $FLAG_DIR/fixresets ]; then
	if [ -f $IMG_DIR/etc/inittab ]; then
		echo "Stripped Ubuntu install mode"
	    cp $FEATURES_DIR/reset_s5/cleanflags.sh $IMG_DIR/sbin/
	    chmod a+x $IMG_DIR/sbin/cleanflags.sh
		install -m 0755 $FEATURES_DIR/reset_s5/S10cleanflags $IMG_DIR/etc/init/S10cleanflags
    else
		echo "Full Ubuntu install mode"
		install -m 0755 $FEATURES_DIR/reset_s5/cleanflags.sh $IMG_DIR/sbin/
		install -m 0755 $FEATURES_DIR/reset_s5/S20cleanflags $IMG_DIR/etc/init.d/cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc0.d/K20cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc1.d/K20cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc6.d/K20cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc2.d/S20cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc3.d/S20cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc4.d/S20cleanflags
		ln -s /etc/init.d/cleanflags $IMG_DIR/etc/rc5.d/S20cleanflags
    fi

fi

if [ -f $FLAG_DIR/patch_recovery ]; then
	if [ -f $IMG_DIR/etc/inittab ]; then
		echo "Stripped Ubuntu install mode"
	    cp $FEATURES_DIR/recoverypatcher/patch_recovery.sh $IMG_DIR/sbin/
	    chmod a+x $IMG_DIR/sbin/patch_recovery.sh
		install -m 0755 $FEATURES_DIR/reset_s5/S10cleanflags $IMG_DIR/etc/init/S10cleanflags
	else
		echo "Full Ubuntu install mode"
		install -m 0755 $FEATURES_DIR/recoverypatcher/patch_recovery.sh $IMG_DIR/sbin/
		install -m 0755 $FEATURES_DIR/reset_s5/S10cleanflags $IMG_DIR/etc/init.d/patch_recovery
		ln -s /etc/init.d/patch_recovery $IMG_DIR/etc/rc1.d/S10patch_recovery
		ln -s /etc/init.d/patch_recovery $IMG_DIR/etc/rc2.d/S10patch_recovery
		ln -s /etc/init.d/patch_recovery $IMG_DIR/etc/rc3.d/S10patch_recovery
		ln -s /etc/init.d/patch_recovery $IMG_DIR/etc/rc4.d/S10patch_recovery
		ln -s /etc/init.d/patch_recovery $IMG_DIR/etc/rc5.d/S10patch_recovery
	fi

fi

if [ -f $IMG_DIR/etc/inittab ]; then

	echo "reverting rr_login"
	sed -i -E 's/::respawn:\/sbin\/rr_login -d \/dev\/ttyS0 -b 115200 -p vt100/::respawn:\/sbin\/getty -L ttyS0 115200 vt100/g' $IMG_DIR/etc/inittab

fi

if [ -f $FLAG_DIR/hostname ]; then
echo "patching Hostname"
	cat $FLAG_DIR/hostname > $IMG_DIR/etc/hostname
fi

if [ -f $FLAG_DIR/timezone ]; then
echo "patching Timezone"
	cat $FLAG_DIR/timezone > $IMG_DIR/etc/timezone
fi

touch $IMG_DIR/build.txt
echo "build with firmwarebuilder (https://builder.dontvacuum.me)" > $IMG_DIR/build.txt
date -u  >> $IMG_DIR/build.txt
if [ -f $FLAG_DIR/version ]; then
    cat $FLAG_DIR/version >> $IMG_DIR/build.txt
fi
echo "" >> $IMG_DIR/build.txt

echo "fixing executable permissions"
chmod +x $IMG_DIR/usr/bin/*
chmod +x $IMG_DIR/usr/sbin/*
chmod +x $IMG_DIR/bin/*
chmod +x $IMG_DIR/sbin/*

echo "finished patching"

# shellcheck disable=SC2046
while [ $(umount "$IMG_DIR"; echo $?) -ne 0 ]; do
    echo "waiting for unmount..."
    sleep 2
done

echo "check image file size"
maximumsize=534773761
minimumsize=50000000
echo $(wc -c < $BASE_DIR/disk.img)
actualsize=$(wc -c < $BASE_DIR/disk.img)
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash."
	exit 1
fi

if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation."
	exit 1
fi

if [ -f $FLAG_DIR/diff ]; then
	echo "create diff"
	mkdir $BASE_DIR/original
	mkdir $BASE_DIR/modified
	mkdir $BASE_DIR/foo
	mount -o loop,ro $BASE_DIR/original.img $BASE_DIR/original
	mount -o loop,ro $BASE_DIR/disk.img $BASE_DIR/modified
	mount -o bind foo $BASE_DIR/original/dev
	mount -o bind foo $BASE_DIR/modified/dev
	/usr/bin/git diff --no-index $BASE_DIR/original/ $BASE_DIR/modified/ > $BASE_DIR/output/diff.txt

	umount $BASE_DIR/original/dev
	umount $BASE_DIR/modified/dev
	# shellcheck disable=SC2046
	while [ $(umount "$BASE_DIR/original"; echo $?) -ne 0 ]; do
    		echo "waiting for unmount..."
    		sleep 2
	done
	# shellcheck disable=SC2046
	while [ $(umount "$BASE_DIR/modified"; echo $?) -ne 0 ]; do
    		echo "waiting for unmount..."
    		sleep 2
	done
	rm -rf $BASE_DIR/original
	rm -rf $BASE_DIR/modified
	rm -rf $BASE_DIR/foo
	rm $BASE_DIR/original.img
	chmod 777 diff.txt
fi

rm -rf $IMG_DIR/image

if [ -f $FLAG_DIR/resize2fs ]; then
    echo "resize2fs"
    resize2fs -f $BASE_DIR/disk.img 510M
fi

md5sum $BASE_DIR/disk.img > $BASE_DIR/firmware.md5sum

if [ -f $FLAG_DIR/installer ]; then
	sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller/install_b.sh >install_b.sh
	sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller/install_a.sh >install_a.sh
    chmod +x install_*.sh
    tar -czf $BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fw.tar.gz $BASE_DIR/disk.img $BASE_DIR/firmware.md5sum $BASE_DIR/install_b.sh $BASE_DIR/install_a.sh
	md5sum $BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fw.tar.gz > $BASE_DIR/output/md5.txt
	echo "${FRIENDLYDEVICETYPE}_${version}_fw.tar.gz" > $BASE_DIR/filename.txt
	touch $BASE_DIR/server.txt
else
	chmod 777 $BASE_DIR/disk.img
	tar -C $BASE_DIR/ -cvzf $BASE_DIR/output/v11_00${version}.img disk.img
	ccrypt -e -K rockrobo $BASE_DIR/output/v11_00${version}.img
	mv -v $BASE_DIR/output/v11_00${version}.img.cpt $BASE_DIR/output/v11_00${version}.pkg
	md5sum $BASE_DIR/output/v11_00${version}.pkg > $BASE_DIR/output/md5.txt
	echo "v11_00${version}.pkg" > $BASE_DIR/filename.txt
fi

touch $BASE_DIR/output/done
