#!/bin/bash

bootfs_type="ext3"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

bootfs_prep

bootshim_install

##magic values for ts2pro
echo -e -n "\\x06\\x1c\\xa0\\xe3\\x30\\x10\\x81\\xe3" > "$BINARIES_DIR/machtype"
cat "$BINARIES_DIR/machtype" "$BINARIES_DIR/$ARCH_TYPE""_shim" "$BINARIES_DIR/zImage" > "$BINARIES_DIR/katkern"
mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n buildroot-kernel -d "$BINARIES_DIR/katkern" "$BINARIES_DIR/uImage.buffalo"

generate_initrd "orion5x" "$rootfsID" "$bootID"
##create a uImage out of the initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd.buffalo"

bootfs_copy "$BINARIES_DIR/initrd.buffalo"
bootfs_copy "$BINARIES_DIR/uImage.buffalo"
bootfs_dtb_copy

create_bootfs

###needs inode size fix
create_image

###hybrid gpt if we're not converting everything to mbr yet
sgdisk -h 1:EE "$diskimg" >/dev/null

exit 0
