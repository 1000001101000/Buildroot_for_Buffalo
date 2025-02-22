#!/bin/bash

bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

##pad the dtbs so uboot can update them
pad_dtbs

generate_initrd "ls700" "$rootfsID" "$bootID"

###we sure we can't generate this in the kernel build?
#gzip -f -n -9 -k "$BINARIES_DIR/Image"
#mkimage -A arm64 -O linux -T kernel -C none -a 0X2200000 -e 0X2200000 -n buildroot-kernel-$datesuff -d "$BINARIES_DIR/Image" "$BINARIES_DIR/uImage-generic.buffalo"

gzip -f -k "$BINARIES_DIR/rootfs.ext2"

bootfs_copy "$BINARIES_DIR/initrd.gz"
bootfs_copy "$BINARIES_DIR/rootfs.ext2.gz"
bootfs_copy "$BINARIES_DIR/rtd1619-ls710.dtb"
bootfs_copy "$BINARIES_DIR/rtd1619-ls720.dtb"
bootfs_copy "$BINARIES_DIR/Image"
#bootfs_copy "$BINARIES_DIR/uImage-generic.buffalo"

create_image

exit 0
