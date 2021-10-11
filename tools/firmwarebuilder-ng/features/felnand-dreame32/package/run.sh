#!/bin/sh
sunxi-fel write 0x2000 fsbl.bin
sunxi-fel exe 0x2000
echo "waiting for 3 seconds"
sleep 3
sunxi-fel -p write 0x4a000000 ub.bin
sunxi-fel -p write 0x43000000 dtb.bin
sunxi-fel -p write 0x42000000 activation.lic
sunxi-fel -p write 0x41000000 uImage
sunxi-fel exe 0x4a000000