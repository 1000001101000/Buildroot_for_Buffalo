#!/bin/bash

. ../scripts/common_finish

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs jessie arm64 main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster arm64 main "./lib/aarch64-linux-gnu/"
debian_import libtinfo6 buster arm64 main "./lib/aarch64-linux-gnu/"

##try to force cgroups v1 for docker compatability
rc_conf="$TARGET_DIR/etc/rc.conf"
grep -q 'rc_cgroup_mode="legacy"' "$rc_conf" || echo 'rc_cgroup_mode="legacy"' >> "$rc_conf"

cp "$custom_dir"/S79r8152 "$TARGET_DIR/etc/init.d/"
exit 0
