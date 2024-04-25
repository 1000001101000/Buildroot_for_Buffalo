#!/bin/bash
target="$1"
custom_dir="../custom"

. ../scripts/functions.sh

##tweak to handle different ld paths for imported libs
ln -s "$target/usr/lib" "$target/usr/lib/arm-linux-gnueabihf" 2>/dev/null
ln -s "$target/lib" "$target/lib/arm-linux-gnueabihf" 2>/dev/null

##grab xfs programs compatabile with the older xfs version supported by kernel
##also grab readline5 library needed by some of them
debian_import xfsprogs jessie armhf main "./usr/sbin/ ./sbin/"
debian_import libreadline5 buster armhf main "./lib/arm-linux-gnueabihf/"
debian_import libtinfo6 buster armhf main "./lib/arm-linux-gnueabihf/"

##grab older mdadm binary compatible with this kernel's interfaces
debian_import mdadm jessie armhf main "./etc/ ./lib/udev/ ./sbin/"

##byobu
debian_import byobu bookworm all main

##micro-evtd
cd "$BR2_DL_DIR" || exit 1
wget -N https://github.com/1000001101000/micro-evtd/raw/master/bins/micro-evtd-armhf 2>/dev/null
cd - || exit 1
cp "$BR2_DL_DIR/micro-evtd-armhf" "$target/usr/bin/micro-evtd"
chmod +x "$target"/usr/bin/micro-evtd

###libmicon.py and python scripts
cp "$custom_dir"/libmicon.py "$target/usr/bin"
cp "$custom_dir"/alpine_micon_shutdown.py "$target/usr/bin/micon_shutdown.py"
cp "$custom_dir"/alpine_micon_startup.py "$target/usr/bin/micon_startup.py"
cp "$custom_dir"/alpine_hdd_fan_daemon.py "$target/usr/bin/hdd_fan_daemon.py"
cp "$custom_dir"/alpine_miconshutdown "$target/etc/init.d/miconshutdown"
cp "$custom_dir"/alpine_miconstartup "$target/etc/init.d/miconstartup"
cp "$custom_dir"/alpine_fandaemon "$target/etc/init.d/miconfandaemon"
chmod +x "$target"/etc/init.d/micon*
chmod +x "$target"/usr/bin/*.py

##tweaks for r8156 nics
r8152_config

##tweak to handle cases where usb nice appears later than expected
cp "$custom_dir"/S79r8152 "$target/etc/init.d/"

##script to setup fw_printenv/etc from cmdline info
cp "$custom_dir"/S79ubootenv "$target/etc/init.d/"

##tweaks for msmtp compatibility
mail_setup

##make sure dropbear can find the sftp-server binary from openssh
ln -s /usr/libexec/sftp-server "$target/usr/sbin/sftp-server" 2>/dev/null

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
rm "$target/etc/init.d/S50sshd"

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
for x in miconstartup mdadm mdadm-raid rsyncd zfs-import zfs-share zfs-mount zfs-load-key zfs-zed
do
  ln -s "/etc/init.d/$x" "$target/etc/runlevels/boot/$x" 2>/dev/null
done
ln -s "/etc/init.d/dcron" "$target/etc/runlevels/default/dcron" 2>/dev/null
ln -s "/etc/init.d/miconfandaemon" "$target/etc/runlevels/default/miconfandaemon" 2>/dev/null
ln -s "/etc/init.d/miconshutdown" "$target/etc/runlevels/shutdown/miconshutdown" 2>/dev/null

mv "$target/boot/uImage" "$target/boot/uImage-generic.buffalo"

exit 0
