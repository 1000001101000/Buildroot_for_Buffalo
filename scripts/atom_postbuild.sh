#!/bin/bash

kernelcmd="rw earlyprintk audit=0 rootwait"
bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

bootfs_prep

generate_initrd "atom" "$rootfsID" "$bootID"

bootfs_copy "$BINARIES_DIR/initrd.gz"
bootfs_copy "$BINARIES_DIR/bzImage"
bootfs_copy "$BINARIES_DIR/memtest.bin" "memtest86"

##generate syslinux config and copy in binaries.
syslinux_setup

create_bootfs

create_image

exit 0
