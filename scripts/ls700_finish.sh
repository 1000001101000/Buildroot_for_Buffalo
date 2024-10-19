#!/bin/bash

. ../scripts/functions.sh

../scripts/common_finish

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs stretch arm64 main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster arm64 main "./lib/aarch64-linux-gnu/"
debian_import libtinfo6 buster arm64 main "./lib/aarch64-linux-gnu/"

cgroupv1_tweak

cp "$custom_dir"/S79r8152 "$TARGET_DIR/etc/init.d/"
exit 0
