#!/bin/bash

##import common functions
. ../scripts/functions.sh

rootimg="$BINARIES_DIR/rootfs.ext2"
bootimg="$BINARIES_DIR/boot.ext3"

rootfsID="$(blkid -o value -s UUID $rootimg)"
bootID="$(uuidgen)"

##working dir for /boot
bootdir="$BINARIES_DIR/boottmp"

dd if=/dev/zero of="$bootimg" bs=1M count=512

generate_initrd "alpine" "$rootfsID" "$bootID"

##create a uImage out of the initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/uInitrd-generic.buffalo"

ln -s "$BINARIES_DIR/uImage" "$BINARIES_DIR/uImage-generic.buffalo" 2> /dev/null

rm -rf "$bootdir" 2>/dev/null
mkdir "$bootdir"
cp "$BINARIES_DIR"/*.dtb "$bootdir"
cp "$BINARIES_DIR/uInitrd-generic.buffalo" "$bootdir"
cp "$BINARIES_DIR/uImage-generic.buffalo" "$bootdir"
cp "$BINARIES_DIR/rootfs.ubi" "$bootdir"
cd "$bootdir" || exit 1
sha1sum * > FW_CHECKSUM.SHA1
cd - >/dev/null || exit 1
mkfs.ext3 -U "$bootID" -d "$bootdir" "$bootimg"



