#!/bin/bash
set -e # exit script on any error

VERSION=v$(date +%Y.%m.%d.%H%M)
REPO=prototype-microbit-as-ultibo-peripheral
ZIPFILE=$REPO-$VERSION.zip
PATH=$HOME/hub-linux-arm-2.3.0-pre10/bin:$PATH

mkdir -p release
rm -rf release/*

rm -f *kernel*.img
LPR=microbitdemo
for CONF in RPI RPI2 RPI3
do
    ./build.sh $LPR $CONF
done
set -x
cp -a *.img release/
cp -a *.hex release/
cp -a $LPR-config.txt $LPR-cmdline.txt release/
cp -a release/$LPR-config.txt release/config.txt
echo "$REPO $VERSION" >> release/release-message.md
echo >> release/release-message.md
cat release-message.md >> release/release-message.md
cp -a firmware/boot/bootcode.bin firmware/boot/start.elf firmware/boot/fixup.dat release/
cd release
zip $ZIPFILE *
ls -lt $ZIPFILE
cd ..

hub release create -d -p -F release/release-message.md -a release/$ZIPFILE $VERSION
