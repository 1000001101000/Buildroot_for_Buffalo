#!/bin/bash
target="$1"
custom_dir="../custom"

##import common functions
. ../scripts/functions.sh

custom_module "it87ts-1.0"
echo it87ts > "$target/etc/modules-load.d/sensors.conf"

custom_module "gpio_it87ts-1.0"
echo gpio-it87ts > "$target/etc/modules-load.d/gpio.conf"
echo gpio-ich >> "$target/etc/modules-load.d/gpio.conf"

stage_module gpio-it87ts

##byobu
debian_import byobu bookworm all main

##grab ryncd service file from debian
debian_import rsync bookworm amd64 main "./lib/systemd/system/rsync.service"

##micro-evtd
cd "$BR2_DL_DIR" || exit 1
wget -N https://github.com/1000001101000/micro-evtd/raw/master/bins/micro-evtd-amd64 2>/dev/null
cd - || exit 1
cp "$BR2_DL_DIR/micro-evtd-amd64" "$target/usr/bin/micro-evtd"
chmod +x "$target"/usr/bin/micro-evtd

###libmicon.py and python scripts
cp "$custom_dir"/libmicon.py "$target/usr/bin"
cp "$custom_dir"/micon_boot.service "$target/etc/systemd/system/"
cp "$custom_dir"/atom_micon_shutdown.py "$target/usr/bin/micon_shutdown.py"
cp "$custom_dir"/atom_micon_startup.py "$target/usr/bin/micon_startup.py"
ln -s "/usr/bin/micon_shutdown.py" "$target/lib/systemd/system-shutdown/micon_shutdown"
chmod 644 "$target"/etc/systemd/system/*.service
chmod +x "$target"/usr/bin/*.py

##tweaks for r8156 nics
r8152_config

##tweaks for msmtp compatibility
mail_setup

##systemd networkd configs for common nics
cp "$custom_dir"/*.link $target/etc/systemd/network/

##tweaks for using dcron
mkdir "$target/var/spool/cron/cronstamps/" 2>/dev/null
echo "# m h  dom mon dow   command" > "$target/var/spool/cron/crontabs/root"
sed -i 's/root test/test/g' "$target/etc/cron.d/e2scrub_all"

##install the current user's ssh key as a starting point for authentication
mkdir "$target/root/.ssh/" 2>/dev/null
cat ~/.ssh/id_rsa.pub > "$target/root/.ssh/authorized_keys"

##example of installing files to keep across builds
for x in exports rsyncd.conf rsyncd.secrets aliases
do
  cp "$HOME/buildroot_keep/$x" "$target/etc/$x"
done
cp ~/buildroot_keep/smb.conf "$target/etc/samba/"
#cp ~/buildroot_keep/zpool.cache "$target/etc/zfs/"
#cp ~/buildroot_keep/saveconfig.json "$target/etc/target/"
cp ~/buildroot_keep/.msmtprc "$target/root/"
cp ~/buildroot_keep/root "$target/var/spool/cron/crontabs/"
cat ~/buildroot_keep/zed-config >> "$target/etc/zfs/zed.d/zed.rc"
cat ~/buildroot_keep/authorized_keys >> "$target/root/.ssh/authorized_keys"
mkdir "$target/mnt/array" 2>/dev/null

##setup services to start at appropariate run levels
mkdir "$target/etc/systemd/system/getty.target.wants/" 2>/dev/null
ln -s "/usr/lib/systemd/system/getty@.service" "$target/etc/systemd/system/getty.target.wants/getty@tty1.service"
exit 0
