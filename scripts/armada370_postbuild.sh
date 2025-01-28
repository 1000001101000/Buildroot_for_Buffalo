#!/bin/bash

bootfs_type="ext3"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

pad_dtbs
bootshim_install

eval "$(grep -e "^BR2_LINUX_KERNEL_INTREE_DTS_NAME" "$BR2_CONFIG")"
echo "$BR2_LINUX_KERNEL_INTREE_DTS_NAME"

cat "$BINARIES_DIR/$ARCH_TYPE""_shim" "$BINARIES_DIR/zImage.$BR2_LINUX_KERNEL_INTREE_DTS_NAME" > "$BINARIES_DIR/katkern"

mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n buildroot-kernel -d "$BINARIES_DIR/katkern" "$BINARIES_DIR/uImage.buffalo"

bootfs_prep

generate_initrd "armada370" "$rootfsID" "$bootID"

##create a uImage out of the initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd.buffalo"

bootfs_copy "$BINARIES_DIR/initrd.buffalo"
bootfs_copy "$BINARIES_DIR/uImage.buffalo"
bootfs_copy "$BINARIES_DIR/rootfs.squashfs"
bootfs_dtb_copy

create_image

exit 0
