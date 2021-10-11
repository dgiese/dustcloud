#!/usr/bin/env sh
rm -rf ./root-dir
for f in ./*.deb
do
dpkg -x "$f" ./root-dir
done
rm -rf ./etc
rm -rf ./root-dir/usr/share
mkdir ./root-dir/sbin
cp resize2fs ./root-dir/sbin/
cp hexdump ./root-dir/bin/
chmod +x ./root-dir/* -R
