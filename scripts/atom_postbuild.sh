#!/bin/bash

kernelcmd="rw earlyprintk audit=0 rootwait"
bootfs_type="fat32"
rootfs_type="ext4"

##import common functions
. ../scripts/functions.sh

generate_initrd

create_image

exit 0
