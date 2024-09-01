#!/bin/bash

. ../scripts/common_finish

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs jessie armhf main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster armhf main "./lib/arm-linux-gnueabihf/"
debian_import libtinfo6 buster armhf main "./lib/arm-linux-gnueabihf/"

##grab older mdadm binary compatible with this kernel's interfaces
debian_import mdadm jessie armhf main "./etc/ ./lib/udev/ ./sbin/"
##may need to move ahead of common or stage some dirs or something



exit 0
