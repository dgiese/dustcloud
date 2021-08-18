cd linux-9ed

sh -c 'cd _initrd/ && find . | cpio -H newc -o' > new_rootfs.cpio
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage
cd ..
cp linux-9ed/arch/arm/boot/uImage .


#cp uImage /nfs/rockrobo-nand-stuff/rr/uImage
#cp u-boot-rr-nand.bin /nfs/rockrobo-nand-stuff/rr/u-boot-rr-nand.bin
