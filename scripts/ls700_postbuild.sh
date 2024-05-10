#!/bin/bash

##import common functions
. ../scripts/functions.sh

datesuff="$(date +%Y%m%d%H%M)"
bootdir="$BINARIES_DIR/boottmp"
rootimg="$BINARIES_DIR/rootfs.ext2"
bootimg="$BINARIES_DIR/boot.fat32"

##pad the dtbs so uboot can update them
pad_dtbs

gzip -f -n -9 -k "$BINARIES_DIR/Image"

##package kernel
mkimage -A arm64 -O linux -T kernel -C gzip -a 0X2200000 -e 0X2200000 -n buildroot-kernel-$datesuff -d "$BINARIES_DIR/Image.gz" "$BINARIES_DIR/uImage-generic.buffalo"

##clear out boot directory and copy in the files needed
rm -rf "$bootdir" 2>/dev/null
mkdir "$bootdir"
cp "$BINARIES_DIR"/*.dtb "$bootdir"
cp "$BINARIES_DIR/rootfs.ext2" "$bootdir"
gzip "$bootdir/rootfs.ext2"
cp "$BINARIES_DIR/Image.gz" "$bootdir"
cp "$BINARIES_DIR/uImage-generic.buffalo" "$bootdir"

##estimate size of bootfs rather than hardcode
bootsize="$(du -shBM "$bootdir" | cut -dM -f1)"
bootsize=$((bootsize+100))

##create fat32 filesystem for boot
dd if=/dev/zero of="$bootimg" bs=1M count="$bootsize" 2>/dev/null
mformat -F -i "$bootimg" ::

##grab uuids for boot and rootfs
rootfsID="$(blkid -o value -s UUID $rootimg)"
bootID="$(blkid -o value -s UUID $bootimg)"

##generate an initrd for booting that rootfs
generate_initrd "ls700" "$rootfsID" "$bootID"

##create a uImage out of the initrd
mkimage -A arm64 -O linux -T ramdisk -C none -a 0X5000000 -e 0X5000000 -n buildroot-initrd-$datesuff -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/uInitrd-generic.buffalo"

##copy in the initrd
cp "$BINARIES_DIR"/initrd.gz "$bootdir"
cp "$BINARIES_DIR/uInitrd-generic.buffalo" "$bootdir"

##generate one of those checksum files in case we need it someday
cd "$bootdir" || exit 1
sha1sum * > FW_CHECKSUM.SHA1
cd - >/dev/null || exit 1

##copy the boot files into the boot fs
mcopy -s -i "$bootimg" "$bootdir"/* ::/


