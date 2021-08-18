#!/usr/bin/env sh
rm -rf ./root-dir
mkdir -p ./root-dir
for f in ./*.ipk
do
tar -xzvf "$f"
tar -xzvf data.tar.gz -C  ./root-dir
done
rm *.tar.gz
chmod +x ./root-dir/* -R
