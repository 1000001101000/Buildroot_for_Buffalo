#!/bin/bash

bootfs_type="ext3"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

gen_appended_uImage
###sanity check for 5MB limit of most orion5x uboot.

generate_initrd_uboot
###sanity check for 7MB limit of most orion5x uboot.

bootfs_dtb_copy

create_image

exit 0
