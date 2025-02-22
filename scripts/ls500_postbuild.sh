#!/bin/bash

bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

##pad the dtbs so uboot can update them
pad_dtbs

generate_initrd "ls500" "$rootfsID" "$bootID"

bootfs_copy "$BINARIES_DIR/initrd.gz" "rescue.root.nand.cpio.gz_pad.img"
bootfs_copy "$BINARIES_DIR/rtd-119x-nas-rescue.dtb" "rescue.nand.dtb"
bootfs_copy "$BINARIES_DIR/rtd-119x-nas-rescue.dtb" "android.nand.dtb"
bootfs_copy "$BINARIES_DIR/uImage" "nand.uImage"
bootfs_copy "../scripts/ls500_install.sh"
bootfs_copy "../scripts/checksum.py"

create_image

exit 0
