#!/bin/bash

##import common functions
. ../scripts/functions.sh

rootimg="$BINARIES_DIR/rootfs.ext2"

workdir="$BINARIES_DIR/boottmp"
rootfsID="$(blkid -o value -s UUID $rootimg)"

##cleanup previous run if needed
rm -r "$workdir" 2>/dev/null

##create working directory
mkdir -p "$workdir"

## copy in syslinux binaries and kernel
cp "$BINARIES_DIR"/syslinux/*.c32 "$workdir"
cp "$BINARIES_DIR"/bzImage "$workdir"

usbimg="$BINARIES_DIR/usb.img"
bootimg="$BINARIES_DIR/syslinux.img"

rootsize="$(du --apparent-size -BM "$rootimg" | cut -dM -f1)"
bootsize="100"
disksize="$((rootsize+bootsize+100))"

## generate the raw images
dd if=/dev/zero of="$usbimg" bs=1M count="$disksize" 2>/dev/null
if [ $? -ne 0 ]; then "create image failed"; exit 99; fi

dd if=/dev/zero of="$bootimg" bs=1M count="$bootsize" 2>/dev/null
if [ $? -ne 0 ]; then "create image failed"; exit 99; fi

##format boot image as vfat
mformat -F -i "$bootimg" ::

bootID="$(blkid -o value -s UUID $bootimg)"

##create boot and rootfs partitions
sgdisk -n 1:0:+"$bootsize"M "$usbimg" >/dev/null
sgdisk -n 2:0 "$usbimg" >/dev/null

##set boot and rootfs partition types
sgdisk -t 1:8300 "$usbimg" >/dev/null
sgdisk -t 2:8300 "$usbimg" >/dev/null

#set boot fs as "bootable" so syslinux can use it
sgdisk "$usbimg" --attributes=1:set:2  >/dev/null

#get sector size of partition table, should always be 512
sectorsz="$(sgdisk -p "$usbimg" | grep 'Sector size (logical):' | gawk '{print $4}')"

#get starting sector for boot, should be 2048
bootstart="$(sgdisk -i 1 "$usbimg" | grep 'First sector:' | gawk '{print $3}')"

#get starting sector for rootfs
rootstart="$(sgdisk -i 2 "$usbimg" | grep 'First sector:' | gawk '{print $3}')"

##grab partUUID for boot parameter
rootpartID="$(sgdisk -i 2 "$usbimg" | grep 'Partition unique GUID:' | gawk '{print $4}')"

if [ -z "$sectorsz" ] || [ -z "$bootstart" ] || [ -z "$rootstart" ] || [ -z "$rootpartID" ]; then
  echo "failed to determine parition information"
  exit 99
fi

generate_initrd "atom" "$rootfsID" "$bootID"

cp "$BINARIES_DIR"/initrd.gz "$workdir"

## generate syslinux.cfg
echo "
ui menu.c32
MENU RESOLUTION 1024 768
MENU TITLE Buildroot for Buffalo
DEFAULT buildroot
TIMEOUT 50

label Buildroot for Buffalo
      menu label Buildroot $BR2_VERSION
      menu default
      kernel /bzImage
      initrd /initrd.gz
      append root=PARTUUID=$rootpartID rw earlyprintk audit=0 rootwait i915.modeset=0

label Buildroot for Buffalo
      menu label Buildroot $BR2_VERSION (serial console)
      kernel /bzImage
      initrd /initrd.gz
      append root=PARTUUID=$rootpartID rw earlyprintk audit=0 rootwait console=ttyS0
" > "$workdir/syslinux.cfg"

##copy syslinux files into it
mcopy -s -i "$bootimg" "$workdir"/* ::/

## install syslinux loader to boot filesystem header
syslinux --install "$bootimg"

##write boot fs into image
dd if="$bootimg" of="$usbimg" bs="$sectorsz" seek="$bootstart" conv=notrunc 2>/dev/null
if [ $? -ne 0 ]; then "write boot image failed"; exit 99; fi

###write rootfs into image
dd if="$rootimg" of="$usbimg" bs="$sectorsz" seek="$rootstart" conv=notrunc 2>/dev/null
if [ $? -ne 0 ]; then "write boot image failed"; exit 99; fi

##write syslinux boot record to partition table.
dd conv=notrunc bs=440 count=1 if="$BINARIES_DIR/syslinux/gptmbr.bin" of="$usbimg" 2>/dev/null
if [ $? -ne 0 ]; then "write mbr image failed"; exit 99; fi
