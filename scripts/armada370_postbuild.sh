#!/bin/bash

bootfs_type="ext3"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

bootfs_prep

gen_appended_uImage

generate_initrd "armada370" "$rootfsID" "$bootID"

##create a uImage out of the initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd.buffalo"

bootfs_copy "$BINARIES_DIR/initrd.buffalo"
bootfs_copy "$BINARIES_DIR/rootfs.squashfs"
bootfs_dtb_copy

create_image

exit 0
