#!/bin/bash

kernelcmd="rw earlyprintk audit=0 rootwait pcie_aspm=off"
bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

#bootfs_prep

generate_initrd "denverton" "$rootfsID" "$bootID"

bootfs_copy "$BINARIES_DIR/initrd.gz"
bootfs_copy "$BINARIES_DIR/bzImage"
bootfs_copy "$BINARIES_DIR/memtest.bin" "memtest86"

#create_bootfs

create_image

##install bootloader to gtp/mbr
#syslinux_install

exit 0
