#!/bin/bash

bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

gen_appended_uImage

generate_initrd_uboot "armadaxp" "$rootfsID" "$bootID"

bootfs_dtb_copy

create_image

exit 0
