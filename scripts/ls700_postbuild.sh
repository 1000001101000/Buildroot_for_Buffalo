#!/bin/bash

bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

##pad the dtbs so uboot can update them
pad_dtbs

generate_initrd_uboot

gen_appended_uImage

bootfs_copy "$BINARIES_DIR/rtd-1619-mmnas-megingjord-2GB.dtb" "rtd1619-ls700.dtb"
bootfs_copy "../scripts/ls700_install.sh"
create_image

exit 0
