#!/bin/bash
target="$1"
custom_dir="../custom"

. ../scripts/functions.sh

##tweak to handle different ld paths for imported libs
ln -s "$target/usr/lib" "$target/usr/lib/aarch64-linux-gnu" 2>/dev/null
ln -s "$target/lib" "$target/lib/aarch64-linux-gnu" 2>/dev/null

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs jessie arm64 main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster arm64 main "./lib/aarch64-linux-gnu/"
debian_import libtinfo6 buster arm64 main "./lib/aarch64-linux-gnu/"

##byobu
debian_import byobu bookworm all main

##tweaks for r8156 nics
r8152_config

##tweak to handle cases where usb nic appears later than expected
cp "$custom_dir"/S79r8152 "$target/etc/init.d/"

##script to setup fw_printenv/etc from cmdline info
cp "$custom_dir"/S79ubootenv-single "$target/etc/init.d/S79ubootenv"

##tweaks for msmtp compatibility
mail_setup

##alpine uses openrc, grab some of their initscripts to fill in where buiildroot/debian ones don't work
for x in mdadm/mdadm mdadm/mdadm-raid rsync/rsyncd
do
  wget "https://git.alpinelinux.org/aports/plain/main/$x.confd" -O "$target/etc/conf.d/$(basename $x)" 2>/dev/null
  wget "https://git.alpinelinux.org/aports/plain/main/$x.initd" -O "$target/etc/init.d/$(basename $x)" 2>/dev/null
done

wget "https://git.alpinelinux.org/aports/plain/community/dcron/dcron.initd" -O "$target/etc/init.d/dcron" 2>/dev/null
chmod +x "$target"/etc/init.d/* 2>/dev/null

##remove/fixup any incompatabilites
rm "$target/etc/init.d/S90dcron"

##work around having /var/ entires symlinked to /tmp by moving the cron stuff
echo 'DCRON_OPTS="-S -c /var/cron/crontabs -t /var/cron/cronstamps -l info"' > "$target/etc/conf.d/dcron"
mkdir -p "$target/var/cron/crontabs" "$target/var/cron/cronstamps"
chmod -R 755 "$target/var/cron/"
echo 'crontab.orig -c /var/cron/crontabs/ "$@"' > "$target/bin/crontab"
mv "$target/usr/bin/crontab" "$target/usr/bin/crontab.orig"
chmod 755 "$target/bin/crontab"
echo "# m h  dom mon dow   command" > "$target/var/cron/crontabs/root"
sed -i 's/root test/test/g' "$target/etc/cron.d/e2scrub_all"

mkdir "$target/root/.ssh/" 2>/dev/null
cat ~/.ssh/id_rsa.pub > "$target/root/.ssh/authorized_keys"

for x in fstab exports mdadm.conf rsyncd.conf rsyncd.secrets aliases
do
  cp "$HOME/buildroot_keep/$x" "$target/etc/$x"
done
cp ~/buildroot_keep/smb.conf "$target/etc/samba/"
#cp ~/buildroot_keep/zpool.cache "$target/etc/zfs/"
cat ~/buildroot_keep/zed-config >> "$target/etc/zfs/zed.d/zed.rc"
#cp ~/buildroot_keep/saveconfig.json "$target/etc/target/"
cp ~/buildroot_keep/.msmtprc "$target/root/"
cp ~/buildroot_keep/root "$target/var/cron/crontabs/"
cat ~/buildroot_keep/authorized_keys >> "$target/root/.ssh/authorized_keys"
mkdir "$target/mnt/array" 2>/dev/null

##setup services to start at appropariate run levels
for x in mdadm mdadm-raid rsyncd zfs-import zfs-share zfs-mount zfs-load-key zfs-zed
do
  ln -s "/etc/init.d/$x" "$target/etc/runlevels/boot/$x" 2>/dev/null
done
ln -s "/etc/init.d/dcron" "$target/etc/runlevels/default/dcron" 2>/dev/null

##try to force cgroups v1 for docker compatability
echo 'rc_cgroup_mode="legacy"' >> "$target/etc/rc.conf"

##make sure we have an empty boot to mount on when booting from USB
mkdir "$target/boot/" 2>/dev/null

exit 0