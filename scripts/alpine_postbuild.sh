#!/bin/bash

bootfs_type="ext3"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

pad_dtbs

generate_initrd_uboot "alpine" "$rootfsID" "$bootID"

ln -s "$BINARIES_DIR/uImage" "$BINARIES_DIR/uImage-generic.buffalo" 2> /dev/null

bootfs_copy "$BINARIES_DIR/uImage-generic.buffalo"
bootfs_dtb_copy

create_image

exit 0
