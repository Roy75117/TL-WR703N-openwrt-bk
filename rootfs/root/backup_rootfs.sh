#!/bin/sh -e

mkdir ./rootfs
cp -r /bin ./rootfs/
cp -r /etc ./rootfs/
cp -r /lib ./rootfs/
cp -r /mnt ./rootfs/
cp -r /sbin ./rootfs/
cp -r /tmp ./rootfs/
cp -r /usr ./rootfs/
cp -r /www ./rootfs/
cp /swapfile ./rootfs/

zip -r ./rootfs_bk.zip ./rootfs
rm -rf ./rootfs
sync
