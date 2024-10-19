#!/bin/bash

bootfs_type="ext3"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

pad_dtbs

bootfs_prep

generate_initrd "alpine" "$rootfsID" "$bootID"

##create a uImage out of the initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/uInitrd-generic.buffalo"

ln -s "$BINARIES_DIR/uImage" "$BINARIES_DIR/uImage-generic.buffalo" 2> /dev/null

bootfs_copy "$BINARIES_DIR/uInitrd-generic.buffalo"
bootfs_copy "$BINARIES_DIR/uImage-generic.buffalo"
bootfs_copy "$BINARIES_DIR/rootfs.squashfs"
bootfs_dtb_copy

create_image

exit 0
