#!/bin/bash

. ../scripts/functions.sh

../scripts/common_finish

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs jessie armhf main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster armhf main "./lib/arm-linux-gnueabihf/"
debian_import libtinfo6 buster armhf main "./lib/arm-linux-gnueabihf/"

##grab older mdadm binary compatible with this kernel's interfaces
debian_import mdadm jessie armhf main "./etc/ ./lib/udev/ ./sbin/ ./usr/share/mdadm/"
sed -i 's/ root / /g' "$TARGET_DIR/etc/cron.d/mdadm"

##tweak to handle cases where usb nic appears later than expected
##probably better ways to deal with all that
cp "$custom_dir/S79r8152" "$TARGET_DIR/etc/init.d/"

##script to setup fw_printenv/etc from cmdline info
##not really worth it I dare say
cp "$custom_dir/S79ubootenv" "$TARGET_DIR/etc/init.d/"

##in rootfs for ubifs boot without messing with stock kernel... for no real reason
mv "$TARGET_DIR/boot/uImage" "$TARGET_DIR/boot/uImage-generic.buffalo"
exit 0
