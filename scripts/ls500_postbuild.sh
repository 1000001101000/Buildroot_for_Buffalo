#!/bin/bash

bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

pad_dtbs

gen_appended_uImage

generate_initrd

bootfs_copy "$BINARIES_DIR/rtd-119x-nas-rescue.dtb" "rescue.nand.dtb"
bootfs_copy "$BINARIES_DIR/rtd-119x-nas-rescue.dtb" "android.nand.dtb"
bootfs_copy "../scripts/ls500_install.sh"
bootfs_copy "../scripts/checksum.py"

create_image

exit 0
