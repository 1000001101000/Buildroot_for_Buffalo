#!/bin/bash

. ../scripts/functions.sh

../scripts/common_finish

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs jessie armhf main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster armhf main "./lib/arm-linux-gnueabihf/"
debian_import libtinfo6 buster armhf main "./lib/arm-linux-gnueabihf/"

##grab older mdadm binary compatible with this kernel's interfaces
debian_import mdadm jessie armhf main "./etc/cron.daily/ ./etc/cron.d/ ./etc/logcheck/ ./lib/udev/ ./sbin/ ./usr/share/mdadm/"
sed -i 's/ root / /g' "$TARGET_DIR/etc/cron.d/mdadm"


exit 0
