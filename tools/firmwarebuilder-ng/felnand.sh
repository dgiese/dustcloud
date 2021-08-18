#!/bin/bash
# Author: Dennis Giese [dgiese@dontvacuum.me]
# Copyright 2017 by Dennis Giese

BASE_DIR="."
FLAG_DIR="."
IMG_DIR="./payload"
FEATURES_DIR="./features"

if [ ! -f $BASE_DIR/firmware.zip ]; then
    echo "File firmware.zip not found! Decryption and unpacking was apparently unsuccessful."
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
FRIENDLYDEVICETYPE=$(sed "s/\[s|t\]/x/g" $FLAG_DIR/devicetype)
version=$(cat "$FLAG_DIR/version")
jobid=$(cat "$FLAG_DIR/jobid")
jobidmd5=$(cat "$FLAG_DIR/jobid" | md5sum | awk '{print $1}')

mkdir -p $BASE_DIR/output
mkdir -p $BASE_DIR/kernel

cp -r $FEATURES_DIR/felnand/_initrd $IMG_DIR
mkdir -p $IMG_DIR/dev
mkdir -p $IMG_DIR/sys
mkdir -p $IMG_DIR/proc
mkdir -p $IMG_DIR/tmp
chmod 777 $IMG_DIR/dev
chmod 777 $IMG_DIR/sys
chmod 777 $IMG_DIR/proc
chmod 777 $IMG_DIR/tmp


echo "integrate SSH authorized_keys"
cat $BASE_DIR/authorized_keys > $IMG_DIR/authorized_keys
cat $BASE_DIR/jobid > $IMG_DIR/id

sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/felnand/_initrd/patch.sh > $IMG_DIR/patch.sh
chmod +x $IMG_DIR/patch.sh

echo "create rootfs.cpio"
sh -c 'cd payload/ && find . | cpio -H newc -o' > $BASE_DIR/kernel/rootfs.cpio

echo "copy kernel"

cp -r $FEATURES_DIR/felnand/linux-9ed/* $BASE_DIR/kernel/
cp $FEATURES_DIR/felnand/linux-9ed/configs/felnand.config $BASE_DIR/kernel/.config


echo "compile kernel"
cd $BASE_DIR/kernel/
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage
cd ..

if [ ! -f $BASE_DIR/kernel/arch/arm/boot/uImage ]; then
    echo "Kernel building failed"
	exit 1
fi

zip -j $BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fel.zip $BASE_DIR/kernel/arch/arm/boot/uImage $FEATURES_DIR/felnand/package/*.*
md5sum $BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fel.zip > $BASE_DIR/output/md5.txt
echo "$BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fel.zip" > $BASE_DIR/filename.txt

touch $BASE_DIR/output/done


