#!/bin/bash

##import common functions
. ../scripts/functions.sh

pad_dtbs

rootimg="$BINARIES_DIR/rootfs.ext2"
bootimg="$BINARIES_DIR/boot.ext3"
diskimg="$BINARIES_DIR/disk.img"

rootfsID="$(blkid -o value -s UUID $rootimg)"
bootID="$(uuidgen)"

##working dir for /boot
bootdir="$BINARIES_DIR/boottmp"

generate_initrd "alpine" "$rootfsID" "$bootID"

##create a uImage out of the initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/uInitrd-generic.buffalo"

ln -s "$BINARIES_DIR/uImage" "$BINARIES_DIR/uImage-generic.buffalo" 2> /dev/null

rm -rf "$bootdir" 2>/dev/null
mkdir "$bootdir"
cp "$BINARIES_DIR"/*.dtb "$bootdir"
cp "$BINARIES_DIR/uInitrd-generic.buffalo" "$bootdir"
cp "$BINARIES_DIR/uImage-generic.buffalo" "$bootdir"
cp "$BINARIES_DIR/rootfs.squashfs" "$bootdir"
cd "$bootdir" || exit 1
sha1sum * > FW_CHECKSUM.SHA1
cd - >/dev/null || exit 1

bootsize="$(du -shBM "$bootdir" | cut -dM -f1)"
bootsize=$((bootsize+100))
rootsize="$(du --apparent-size -BM "$rootimg" | cut -dM -f1)"
disksize="$((rootsize+bootsize+100))"

## generate the raw images
dd if=/dev/zero of="$diskimg" bs=1M count="$disksize" 2>/dev/null
if [ $? -ne 0 ]; then "create image failed"; exit 99; fi

dd if=/dev/zero of="$bootimg" bs=1M count="$bootsize" 2>/dev/null
if [ $? -ne 0 ]; then "create image failed"; exit 99; fi

#create boot filesystem
mkfs.ext3 -U "$bootID" -d "$bootdir" "$bootimg"

##create boot and rootfs partitions
sgdisk -n 1:0:+"$bootsize"M "$diskimg" >/dev/null
sgdisk -n 2:0 "$diskimg" >/dev/null

#get sector size of partition table, should always be 512
sectorsz="$(sgdisk -p "$diskimg" | grep 'Sector size (logical):' | gawk '{print $4}')"

#get starting sector for boot, should be 2048
bootstart="$(sgdisk -i 1 "$diskimg" | grep 'First sector:' | gawk '{print $3}')"

#get starting sector for rootfs
rootstart="$(sgdisk -i 2 "$diskimg" | grep 'First sector:' | gawk '{print $3}')"

if [ -z "$sectorsz" ] || [ -z "$bootstart" ] || [ -z "$rootstart" ]; then
  echo "failed to determine parition information"
  exit 99
fi

##write boot fs into image
dd if="$bootimg" of="$diskimg" bs="$sectorsz" seek="$bootstart" conv=notrunc 2>/dev/null
if [ $? -ne 0 ]; then "write boot image failed"; exit 99; fi

###write rootfs into image
dd if="$rootimg" of="$diskimg" bs="$sectorsz" seek="$rootstart" conv=notrunc 2>/dev/null
if [ $? -ne 0 ]; then "write boot image failed"; exit 99; fi
