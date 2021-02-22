#!/usr/bin/env sh
rm -rf ./root-dir
for f in ./*.deb
do
dpkg -x "$f" ./root-dir
done
rm -rf ./root-dir/usr/share/doc
rm -rf ./root-dir/usr/share/man
rm -rf ./root-dir/usr/share/info
mkdir ./root-dir/sbin
cp resize2fs ./root-dir/sbin/
