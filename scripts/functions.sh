#!/bin/bash
# shellcheck disable=SC2006

datesuff="$(date +%Y%m%d%H%M)"

custom_dir="$CONFIG_DIR/../custom"
bootdir="$BINARIES_DIR/boottmp"
moddir="$BINARIES_DIR/modules/"

mkdir -p "$moddir" 2>/dev/null

loadvars="BR2_LINUX_KERNEL_IMAGEGZ BR2_LINUX_KERNEL_INTREE_DTS_NAME"
loadvars+=" BR2_ARM_EABI BR2_ARM_EABIHF BR2_x86_64 BR2_aarch64"
loadvars+=" BR2_INIT_SYSTEMD BR2_INIT_OPENRC BR2_PACKAGE_FIREWALLD"
loadvars+=" BR2_TARGET_SYSLINUX BR2_PACKAGE_ZFS BR2_PACKAGE_DCRON BR2_PACKAGE_E2FSPROGS_E2SCRUB"

for x in $loadvars
do
  eval "$(grep -e "^$x=" "$BR2_CONFIG")"
done

[ "$BR2_ARM_EABI" = "y" ] && ARCH_TYPE="armel"
[ "$BR2_ARM_EABIHF" = "y" ] && ARCH_TYPE="armhf"
[ "$BR2_x86_64" = "y" ] && ARCH_TYPE="amd64"
[ "$BR2_aarch64" = "y" ] && ARCH_TYPE="arm64"

BR2_LINUX_KERNEL_INTREE_DTS_NAME=`basename "$BR2_LINUX_KERNEL_INTREE_DTS_NAME" 2>/dev/null`
dtb_prefix=`echo "$BR2_LINUX_KERNEL_INTREE_DTS_NAME" | cut -d- -f1`

bootimg="$BINARIES_DIR/boot.img"
diskimg="$BINARIES_DIR/disk.img"

if [ "$bootfs_type" = "fat32" ]; then
  bootID=`uuidgen | cut -d- -f1`
  bootID="${bootID^^}"
  bootIDnum="0x$bootID"
  bootID="${bootID:0:4}-${bootID:4:4}"
else
  bootID="$(uuidgen)"
fi

if [ "$rootfs_type" = "ext4" ] || [ "$rootfs_type" = "ext3" ] || [ "$rootfs_type" = "ext2" ]; then
  rootimg="$BINARIES_DIR/rootfs.ext2"
fi

rootfsID="$(blkid -o value -s UUID "$rootimg")"
rootpartID="$(blkid -o value -s UUID "$rootimg")"

kver=`ls -d "$BUILD_DIR"/linux-[0-9]*.[0-9]*.[0-9]* | sed 's/^.*linux-//g'`
#kver="$(ls $BUILD_DIR | grep -e ^linux-[1-9] | sed 's/linux-//g')"
kernel_dir="$BUILD_DIR/linux-$kver"
kshort=$((`echo "$kver" | cut -d. -f1`))

eval "$(grep ^CONFIG_LOCALVERSION= "$kernel_dir/.config")"
variant=`echo "$CONFIG_LOCALVERSION" | cut -d- -f2`

debian_import()
{
  local pkg=$1
  local distro=$2
  local arch=$3
  local suite=$4
  local files=$5

  local mirrors="ftp.debian.org archive.debian.org"
  local mirror=""

  if [ -z "$suite" ]; then
    suite="main"
  fi

  if [ -z "$BR2_DL_DIR" ]; then
    echo "failed to lookup download directory"
    exit 1
  fi

  local dir="$BR2_DL_DIR/deb/$distro-$arch-$suite"

  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || exit 1
  fi

  cd "$dir" >/dev/null || exit 1
  for mirror in $mirrors
  do
    wget -N "http://$mirror/debian/dists/$distro/$suite/binary-$arch/Packages.gz" 2>/dev/null && break
  done

  if [ ! -f "Packages.gz" ]; then
    echo "failed downloading package index for $distro-$arch-$suite"
    exit 1
  fi

  local re="^Package: $pkg"'$'
  local record_start="$(zcat Packages.gz | grep -m 1 -ne "$re" | cut -d: -f 1)"

  if [ -z "$record_start" ]; then
    echo "package not found in $distro-$arch-$suite index"
    exit 1
  fi

  local deb_url="$(zcat Packages.gz | tail -n +$((record_start)) | grep -m1 -e '^Filename' | gawk '{print $2}')"
  wget -N "http://$mirror/debian/$deb_url" 2>/dev/null
  local filename="$(basename "$deb_url")"

  if [ ! -f "$filename" ]; then
    echo "failed to retreive $filename"
    exit 1
  fi

  ar xf "$filename" data.tar.xz
  tar xf data.tar.xz --keep-directory-symlink -C "$TARGET_DIR" $files
  rm data.tar.xz

  cd - >/dev/null || exit 1
}

custom_module()
{
        local mod_dir="$custom_dir/$1"
        local fullver="$kver$CONFIG_LOCALVERSION"
        local cross="$HOST_DIR/bin/$(ls output/host/bin/ | grep -e '^.*buildroot.*gcc$' | sed 's/...$//g')"

        cd "$mod_dir" || exit 98
        make clean
        make TARGET="$fullver" KERNEL_BUILD="$kernel_dir" CROSS_COMPILE="$cross" KERNEL_MODULES="$TARGET_DIR/lib/modules/$fullver"
        make modules_install TARGET="$fullver" KERNEL_BUILD="$kernel_dir" CROSS_COMPILE="$cross" KERNEL_MODULES="$TARGET_DIR/lib/modules/$fullver"
        cd - > /dev/null || exit 1
        depmod -b "$TARGET_DIR" -o "$TARGET_DIR" "$fullver"
}

r8152_config()
{
  ##setup r8152 driver with r8156 support
  mkdir -p "$TARGET_DIR/etc/modprobe.d/"
  echo "blacklist cdc_mbim" > "$TARGET_DIR/etc/modprobe.d/r8152.conf"
  echo "blacklist cdc_ncm" >> "$TARGET_DIR/etc/modprobe.d/r8152.conf"
  echo 'install r8152 /sbin/modprobe --ignore-install r8152; sleep 1; echo "0bda 8156" > /sys/bus/usb/drivers/r8152/new_id' >> "$TARGET_DIR/etc/modprobe.d/r8152.conf"
}

mail_setup()
{
  ##it seems like some programs call mail,mailx, or sendmail, or look at nail.rc..or aliases
  ln -s "/usr/bin/mailx" "$TARGET_DIR/usr/bin/mail" 2>/dev/null
  ln -s "/usr/bin/msmtp" "$TARGET_DIR/usr/sbin/sendmail" 2>/dev/null
  echo "set mta=/usr/bin/msmtp" > "$TARGET_DIR/etc/nail.rc"

  echo "
  defaults
  auth           on
  tls            on
  tls_trust_file /etc/ssl/certs/ca-certificates.crt
  logfile        /var/log/msmtp.log
  " > "$TARGET_DIR/etc/msmtprc"
}

generate_initrd()
{
local arch=`echo "$MACHTYPE" | cut -d- -f1`

local importbins="busybox blkid mdadm micro-evtd lsblk timeout ubiattach ubidetach"
local workdir="$BINARIES_DIR/initrdtmp"

##cleanup previous run if needed
rm "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd" 2>/dev/null
rm -r "$workdir" 2>/dev/null

##create working dir and enter it
mkdir "$workdir"

##create some directories that will be needed.
mkdir -p "$workdir"/{boot,proc,sys,dev,mnt/root,bin,lib,sbin,usr/bin,usr/sbin,lib/modules}

#copy in init and make sure executable
cp ../scripts/initrd_init "$workdir/init"
chmod +x "$workdir/init"

##put the UUID of the rootfs in place for init to use
echo "$rootfsID" > "$workdir/UUID"
echo "$bootID" > "$workdir/bootUUID"
echo "$variant" > "$workdir/variant"

#pull in busybox and any needed libs from the rootfs.
local importlibs=""
local tmppath=""
for x in $importbins
do
  tmppath=`find "$TARGET_DIR"{/usr/,/}{sbin,bin}/ -name "$x" -print -quit`
  [ -z "$tmppath" ] && continue
  cp "$tmppath" "$workdir/bin/$x"
  chmod +x "$workdir/bin/$x"
  importlibs+="`readelf -d "$tmppath" | grep 'NEEDED' | cut -d[ -f2 | cut -d] -f1`"
  importlibs+=" "
done
importlibs="`echo "$importlibs" | xargs -n1 echo | sort -u`"

local recurse=1
while [ $recurse -eq 1 ]
do
  recurse=0
  for lib in $importlibs
  do
    tmplib="$workdir/lib/$lib"
    if [ ! -e "$tmplib" ]; then
      find "$TARGET_DIR" -name "$lib" -exec cp {} "$tmplib" \; -quit
      if [ $? -eq 0 ]; then
        recurse=1
        importlibs+=" "
        importlibs+=`readelf -d "$tmplib" | grep 'NEEDED' | cut -d[ -f2 | cut -d] -f1`
      fi
    fi
  done
  importlibs="`echo "$importlibs" | xargs -n1 echo | sort -u`"
done
ln -s "/lib" "$workdir/lib64"

#create symlinks for some needed commands
for x in mount umount switch_root sh cat sleep getty watch vi ip mkdir login cd ls chmod sed awk grep dd xxd printf head xargs dirname find uname insmod reboot cut
do
  ln -s /bin/busybox "$workdir/bin/$x"
done

##pull in any staged modules
cd "$moddir" 2> /dev/null || exit 97
rsync -vr ./* "$workdir/"
cd - || exit 89

#create a cpio archive of the directory for use as an initramfs
cd "$workdir" || exit 1
find . -print0 | cpio --null --create --verbose --format=newc > ../initrd
cd - >/dev/null || exit 1

##compress the initrd image.
gzip -n "$BINARIES_DIR/initrd"

if [ -d "$BINARIES_DIR/intel-ucode" ]; then
	DSTDIR="kernel/x86/microcode"
	mkdir -p "$BINARIES_DIR/$DSTDIR"
        cat "$BINARIES_DIR/intel-ucode"/* > "$BINARIES_DIR/$DSTDIR/GenuineIntel.bin"
	echo "./$DSTDIR/GenuineIntel.bin" | cpio -D "$BINARIES_DIR" -o -H newc > "$BINARIES_DIR/ucode.cpio"
	mv "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd.orig"
	cat "$BINARIES_DIR/ucode.cpio" "$BINARIES_DIR/initrd.orig" > "$BINARIES_DIR/initrd.gz"
fi

[ "$variant" = "ls500" ] && bootfs_copy "$BINARIES_DIR/initrd.gz" rescue.root.nand.cpio.gz_pad.img
}

pad_dtbs()
{
  ##pad the dtb size so uboot can pass stuff where needed
  for x in "$BINARIES_DIR"/*.dtb
  do
    dtc -I dtb -O dtb -p 10240 -o "$x" "$x"
  done
}

syslinux_cfg()
{
echo "
ui menu.c32
MENU TITLE Buildroot for Buffalo
DEFAULT buildroot
TIMEOUT 50

label Buildroot for Buffalo
      menu label Buildroot $BR2_VERSION
      menu default
      kernel /bzImage
      initrd /initrd.gz
      append root=PARTUUID=$rootpartID $kernelcmd

label Buildroot for Buffalo
      menu label Buildroot $BR2_VERSION (serial console)
      kernel /bzImage
      initrd /initrd.gz
      append root=PARTUUID=$rootpartID $kernelcmd console=ttyS0

LABEL memtest+
    MENU LABEL Memtest86+
    LINUX /memtest86
" > "$bootdir/syslinux.cfg"
}

syslinux_setup()
{
  syslinux_cfg
  cp "$BINARIES_DIR"/syslinux/*.c32 "$bootdir"
  bootfs_copy "$BINARIES_DIR/initrd.gz"
  bootfs_copy "$BINARIES_DIR/bzImage"
  bootfs_copy "$BINARIES_DIR/memtest.bin" "memtest86" ##make optional?
}

syslinux_gpt_install()
{
  ##write syslinux boot record to partition table.
  dd bs=440 count=1 if="$BINARIES_DIR/syslinux/gptmbr.bin" of="$diskimg" conv=notrunc 2>/dev/null
  if [ $? -ne 0 ]; then echo "write mbr image failed"; exit 96; fi
  sync
}

stage_module()
{
  mkdir "$moddir" 2>/dev/null
  cd "$TARGET_DIR" || exit 95
  find lib/ -name $1.ko | xargs -I{} rsync -vR {} "$moddir"
  cd - || exit 1
}

create_image()
{
  create_bootfs
  rootsize="$(du --apparent-size -BM "$rootimg" | cut -dM -f1)"
  bootsize="$(du --apparent-size -BM "$bootimg" | cut -dM -f1)"
  disksize="$((rootsize+bootsize+100))"

  ## generate the raw images
  dd if=/dev/zero of="$diskimg" bs=1M count="$disksize" 2>/dev/null
  if [ $? -ne 0 ]; then "create image failed"; exit 94; fi

  ##create boot and rootfs partitions with precomputed partuuid
  sgdisk -n 1:0:+"$bootsize"M "$diskimg" >/dev/null
  sgdisk -c 1:BRBOOT "$diskimg" >/dev/null
  sgdisk -n 2:0 "$diskimg" -c "BRROOT" >/dev/null
  sgdisk -c 2:BRROOT "$diskimg" >/dev/null
  sgdisk -u 2:$rootpartID "$diskimg" >/dev/null

  ##set boot and rootfs partition types
  sgdisk -t 1:8300 "$diskimg" >/dev/null
  sgdisk -t 2:8300 "$diskimg" >/dev/null

  if [ "$bootfs_type" = "fat32" ]; then
    #set boot fs as "bootable" so syslinux can use it
    sgdisk "$diskimg" --attributes=1:set:2  >/dev/null
  fi

  ## if system needs hybrid gpt/mbr to boot set that up.
  if [ "$dtb_prefix" = "mv78100" ] || [ "$dtb_prefix" = "orion5x" ]; then
    sgdisk -h 1:EE "$diskimg" >/dev/null
  fi

  #get sector size of partition table, should always be 512
  sectorsz="$(sgdisk -p "$diskimg" | grep 'Sector size (logical):' | gawk '{print $4}')"

  #get starting sector for boot, should be 2048
  bootstart="$(sgdisk -i 1 "$diskimg" | grep 'First sector:' | gawk '{print $3}')"

  #get starting sector for rootfs
  rootstart="$(sgdisk -i 2 "$diskimg" | grep 'First sector:' | gawk '{print $3}')"

  if [ -z "$sectorsz" ] || [ -z "$bootstart" ] || [ -z "$rootstart" ]; then
    echo "failed to determine parition information"
    exit 93
  fi

  ##write boot fs into image
  dd if="$bootimg" of="$diskimg" bs="$sectorsz" seek="$bootstart" conv=notrunc 2>/dev/null
  if [ $? -ne 0 ]; then "write boot image failed"; exit 92; fi

  ###write rootfs into image
  dd if="$rootimg" of="$diskimg" bs="$sectorsz" seek="$rootstart" conv=notrunc 2>/dev/null
  if [ $? -ne 0 ]; then "write boot image failed"; exit 91; fi

  [ "$BR2_TARGET_SYSLINUX" = "y" ] && syslinux_gpt_install
}

debian_lib_fixup()
{
  local tuple=""
  [ "$ARCH_TYPE" = "armel" ] && tuple="arm-linux-gnueabi"
  [ "$ARCH_TYPE" = "armhf" ] && tuple="arm-linux-gnueabihf"
  [ "$ARCH_TYPE" = "arm64" ] && tuple="aarch64-linux-gnu"

  if [ -n "$tuple" ]; then
    ln -s "$TARGET_DIR/usr/lib" "$TARGET_DIR/usr/lib/$tuple" 2>/dev/null
    ln -s "$TARGET_DIR/lib" "$TARGET_DIR/lib/$tuple" 2>/dev/null
  fi
}

openrc_register_service()
{
  local runlevel="$1"
  local service="$2"
  ln -s "/etc/init.d/$service" "$TARGET_DIR/etc/runlevels/$runlevel/$service" 2>/dev/null
}

##alpine uses openrc, grab some of their initscripts to fill in where buiildroot/debian ones don't work
alpine_openrc_init()
{
  local script="$TARGET_DIR/etc/init.d/$(basename "$1")"
  wget "https://git.alpinelinux.org/aports/plain/main/$1.initd" -O "$script" 2>/dev/null
  chmod +x "$script"
}

alpine_openrc_conf()
{
  wget "https://git.alpinelinux.org/aports/plain/main/$1.confd" -O "$TARGET_DIR/etc/conf.d/$(basename "$1")" 2>/dev/null
}

network_setup()
{
  if [ "$BR2_INIT_SYSTEMD" = "y" ]; then
    cp "$custom_dir"/*.link "$TARGET_DIR/etc/systemd/network/"
  fi
  [ "$variant" = "ls700" ] && cp "$custom_dir/ls700_mac" "$TARGET_DIR/etc/network/if-pre-up.d/"
}

getty_setup()
{
  if [ "$BR2_INIT_SYSTEMD" = "y" ] && [ "$ARCH_TYPE" = "amd64" ]; then
    mkdir "$TARGET_DIR/etc/systemd/system/getty.target.wants/" 2>/dev/null
    ln -s "/usr/lib/systemd/system/getty@.service" "$TARGET_DIR/etc/systemd/system/getty.target.wants/getty@tty1.service"
  fi
}

rsyncd_setup()
{
  if [ "$BR2_INIT_OPENRC" = "y" ]; then
    alpine_openrc_init "rsync/rsyncd"
    alpine_openrc_conf "rsync/rsyncd"
    openrc_register_service "boot" "rsyncd"
  fi

  if [ "$BR2_INIT_SYSTEMD" = "y" ]; then
    debian_import rsync bookworm "$ARCH_TYPE" main "./lib/systemd/system/rsync.service"
  fi
}

mdadm_setup()
{
  if [ "$BR2_INIT_OPENRC" = "y" ]; then
    local x=""
    for x in mdadm mdadm-raid
    do
      alpine_openrc_init "mdadm/$x"
      alpine_openrc_conf "mdadm/$x"
      openrc_register_service "boot" "$x"
      mkdir /var/mdadm 2>/dev/null
    done
  fi
  ##email piece?

}

zfs_setup()
{
  [ "$BR2_PACKAGE_ZFS" = "y" ] || return
  if [ "$BR2_INIT_OPENRC" = "y" ]; then
  num=85
  for x in zfs-load-key zfs-import zfs-mount zfs-share zfs-zed
  do
    local iscript="$TARGET_DIR/etc/init.d/S$num$x"
    [ -e "$iscript" ] || ln -s "$x" "$iscript"
    num=$((num+1))
  done
  fi
}

cron_setup()
{
  [ "$BR2_PACKAGE_DCRON" = "y" ] || return
  crondir="/var/spool/cron"
  ##work around having /var/ entires symlinked to /tmp by moving the cron stuff
  if [ "$BR2_INIT_OPENRC" = "y" ]; then
    crondir="/var/cron"
    echo 'DCRON_OPTS="-S -c '"$crondir"'/crontabs -t '"$crondir"'/cronstamps -l info"' > "$TARGET_DIR/etc/conf.d/dcron"
    mkdir -p "$TARGET_DIR$crondir/crontabs" "$TARGET_DIR$crondir/cronstamps"
    chmod -R 755 "$TARGET_DIR/$crondir"
    ###real solution to adjust default at build time?
    file "$TARGET_DIR/usr/bin/crontab" | grep -q executable
    if [ $? -eq 0 ]; then
      mv "$TARGET_DIR/usr/bin/crontab" "$TARGET_DIR/sbin/crontab.orig"
      echo '/sbin/crontab.orig -c '"$crondir"'/crontabs/ "$@"' > "$TARGET_DIR/usr/bin/crontab"
      chmod 755 "$TARGET_DIR/usr/bin/crontab"
    fi

    wget "https://git.alpinelinux.org/aports/plain/community/dcron/dcron.initd" -O "$TARGET_DIR/etc/init.d/dcron" 2>/dev/null
    chmod +x "$TARGET_DIR/etc/init.d/dcron"
    sed -i 's/$DCRON_OPTS.*/$DCRON_OPTS"/g' "$TARGET_DIR/etc/init.d/dcron"
    openrc_register_service "default" "dcron"
    rm "$TARGET_DIR/etc/init.d/S90dcron"
  fi

  ##add missing items and stub crontab etc
  mkdir "$TARGET_DIR$crondir/cronstamps/" 2>/dev/null
  echo "# m h  dom mon dow   command" > "$TARGET_DIR$crondir/crontabs/root"
  [ "$BR2_PACKAGE_E2FSPROGS_E2SCRUB" = "y" ] && sed -i 's/root test/test/g' "$TARGET_DIR/etc/cron.d/e2scrub_all"
  ##what's up with that mdadm one?
}

##build natively eventually.

micro_evtd_install()
{
  cd "$BR2_DL_DIR" || exit 1
  wget -N "https://github.com/1000001101000/micro-evtd/raw/master/bins/micro-evtd-$ARCH_TYPE" 2>/dev/null
  cd - 2>/dev/null || exit 1
  cp "$BR2_DL_DIR/micro-evtd-$ARCH_TYPE" "$TARGET_DIR/usr/bin/micro-evtd"
  chmod +x "$TARGET_DIR/usr/bin/micro-evtd"
}

libmicon_install()
{
  cd "$BR2_DL_DIR" || exit 1
  wget -N "https://github.com/1000001101000/Python_buffalo_libmicon/raw/master/libmicon.py" 2>/dev/null
  cd - || exit 1
  cp "$BR2_DL_DIR/libmicon.py" "$TARGET_DIR/usr/bin/"

  local source_script=""
  for source_script in micon_shutdown.py micon_startup.py hdd_fan_daemon.py shutdown_wrapper.sh startup_wrapper.sh fandaemon_wrapper.sh rtc_shutdown.sh phy_shutdown.sh buffalo_system_info.sh first_boot_test.sh
  do
    cp "$custom_dir/$source_script" "$TARGET_DIR/usr/bin/"
    chmod +x "$TARGET_DIR/usr/bin/$source_script"
  done
  if [ "$BR2_INIT_SYSTEMD" = "y" ]; then
    for source_script in custom_startup.service hdd_fan_daemon.service
    do
      cp "$custom_dir/$source_script" "$TARGET_DIR/etc/systemd/system/"
      chmod 644 "$TARGET_DIR/etc/systemd/system/$source_script"
    done
    ln -s "/usr/bin/shutdown_wrapper.sh" "$TARGET_DIR/lib/systemd/system-shutdown/shutdown_wrapper"
  fi
  if [ "$BR2_INIT_OPENRC" = "y" ]; then
    for source_script in miconshutdown miconstartup fandaemon
    do
      cp "$custom_dir/openrc_$source_script" "$TARGET_DIR/etc/init.d/$source_script"
      chmod +x "$TARGET_DIR/etc/init.d/$source_script"
      openrc_register_service "shutdown" "miconshutdown"
      openrc_register_service "boot" "miconstartup"
      openrc_register_service "default" "fandaemon"
    done
  fi
}

install_ssh_key()
{
  mkdir "$TARGET_DIR/root/.ssh/" 2>/dev/null
  cat ~/.ssh/id_rsa.pub > "$TARGET_DIR/root/.ssh/authorized_keys"
}

bootfs_prep()
{
  rm -rf "$bootdir" 2>/dev/null
  mkdir -p "$bootdir"
}

bootfs_copy()
{
  local src="$1"
  local dst="$2"
  cp "$src" "$bootdir/$dst"
}

bootfs_dtb_copy()
{
  cp "$BINARIES_DIR"/*.dtb "$bootdir"
}

create_bootfs()
{
  local add_if_found="rootfs.squashfs"
  for found in $add_if_found
  do
    [ -f "$BINARIES_DIR/$found" ] && bootfs_copy "$BINARIES_DIR/$found"
  done

  ###copy in the syslinux binaries and config if needed
  [ "$BR2_TARGET_SYSLINUX" = "y" ] && syslinux_setup

  ##create one of the sha1 manifests of the boot dir
  cd "$bootdir" || exit 1
  sha1sum ./* > FW_CHECKSUM.SHA1
  cd - >/dev/null || exit 1

  bootsize="$(du --apparent-size -shBM "$bootdir" | cut -dM -f1)"
  bootsize=$((bootsize+100))

  dd if=/dev/zero of="$bootimg" bs=1M count="$bootsize" 2>/dev/null
  if [ "$bootfs_type" = "fat32" ]; then
    mformat -N "$bootIDnum" -F -i "$bootimg" ::
    mcopy -s -i "$bootimg" "$bootdir"/* ::/
    ##install syslinux loader to mbt/gpt
    [ "$BR2_TARGET_SYSLINUX" = "y" ] && syslinux --install "$bootimg"
  fi

  if [ "$bootfs_type" = "ext3" ]; then
    local ext3_flags=""
    ext3_flags+=" -U \"$bootID\""
    ext3_flags+=" -d \"$bootdir\""
    [ "$dtb_prefix" = "orion5x" ] && ext3_flags+=" -I 128"
    [ "$dtb_prefix" = "mv78100" ] && ext3_flags+=" -I 128"
    eval "mkfs.ext3 $ext3_flags \"$bootimg\""
  fi
}

cgroupv1_tweak()
{
  ##try to force cgroups v1 for docker compatability on kernels new enough to have cgroupv2 but old enough to have missing features
  rc_conf="$TARGET_DIR/etc/rc.conf"
  grep -q 'rc_cgroup_mode="legacy"' "$rc_conf" || echo 'rc_cgroup_mode="legacy"' >> "$rc_conf"
}

gen_appended_uImage()
{
  local kernel="zImage"
  local output="uImage.buffalo"
  local shim="$BINARIES_DIR/bootshim"
  local dtb="$BR2_LINUX_KERNEL_INTREE_DTS_NAME.dtb"
  local machfile="$BINARIES_DIR/machtype"
  local arch="arm"
  local addr="0x00008000"
  local compress="none"

  true >"$machfile"
  true >"$shim"
  true >"$BINARIES_DIR/none.dtb"

  ##handle the variations here rather than pass lots of variables
  [ "$variant" = "alpine" ] || [ "$variant" = "ls700" ] && output="uImage-generic.buffalo"
  [ "$variant" = "ls500" ] && addr="0x108000" && output="nand.uImage"
  [ "$ARCH_TYPE" = "arm64" ] && arch="arm64" && addr="0x2200000" && kernel="Image" && dtb=".dtb"
  [ "$variant" = "armada370" ] || [ "$variant" = "armadaxp" ] || [ "$variant" = "marvellv5" ] && cp "$custom_dir/$ARCH_TYPE""_shim" "$shim"
  [ "$BR2_LINUX_KERNEL_INTREE_DTS_NAME" = "kirkwood-terastation-tsxel" ] && output="uImage-88f6281.buffalo"
  [ "$BR2_LINUX_KERNEL_IMAGEGZ" ] && compress="gzip" && kernel="Image.gz"
  ##some steps redundant except when cleaing out image/target dirs for testing.

  ##copy kernel + dtb to cover some edge cases
  find "$kernel_dir" \( -name "$dtb" -o -name "$kernel" \) -exec cp -v "{}" "$BINARIES_DIR/" \;
  #find "$kernel_dir" -name "$kernel" | xargs -I{} cp -v "{}" "$BINARIES_DIR/"

  [ "$dtb" = "orion5x-terastation-ts2pro.dtb" ] && echo -e -n "\\x06\\x1c\\xa0\\xe3\\x30\\x10\\x81\\xe3" > "$machfile"
  [ "$dtb_prefix" = "mv78100" ] && echo -e -n "\\x0a\\x1c\\xa0\\xe3\\x89\\x10\\x81\\xe3" > "$machfile"

  [ "$dtb" = ".dtb" ] && dtb="none.dtb" && dtb="$BINARIES_DIR/$dtb"
  kernel="$BINARIES_DIR/$kernel"

  ##if doing non-dtb init empty the dtb ahead of append step
  [ -s "$machfile" ] && true > "$dtb"

  cat "$machfile" "$shim" "$kernel" "$dtb" > "$BINARIES_DIR/katkern"
  mkimage -A "$arch" -O linux -T kernel -C "$compress" -a "$addr" -e "$addr" -n buildroot-kernel -d "$BINARIES_DIR/katkern" "$BINARIES_DIR/$output"
  bootfs_copy "$BINARIES_DIR/$output"
  rm "$BINARIES_DIR/none.dtb" "$BINARIES_DIR/katkern" "$machfile" 2>/dev/null
}

generate_initrd_uboot()
{
  generate_initrd
  local arch="arm"
  local output="initrd.buffalo"
  local addr="0x0"

  [ "$variant" = "alpine" ] || [ "$variant" = "ls700" ] && output="uInitrd-generic.buffalo"
  [ "$ARCH_TYPE" = "arm64" ] && arch="arm64"
  mkimage -A $arch -O linux -T ramdisk -C gzip -a "$addr" -e "$addr" -n buildroot-initrd -d "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/$output"

  bootfs_copy "$BINARIES_DIR/$output"
}

old_xfs_bins()
{
  ##grab xfs programs compatabile with the older xfs version supported by kernel
  ##also grab readline5 library needed by some of them
  local dist="jessie"
  [ $((kshort)) -eq 4 ] && dist="stretch"
  debian_import xfsprogs "$dist" "$ARCH_TYPE" main "./usr/sbin/ ./sbin/"
  debian_import libreadline5 buster "$ARCH_TYPE" main "./lib/"
  debian_import libtinfo6 buster "$ARCH_TYPE" main "./lib/"
}

old_mdadm_bins()
{
  ##grab older mdadm binary compatible with this kernel's interfaces
  local dist="jessie"
  [ $((kshort)) -eq 4 ] && dist="stretch"
  debian_import mdadm "$dist" "$ARCH_TYPE" main "./etc/cron.daily/ ./etc/cron.d/ ./etc/logcheck/ ./lib/udev/ ./sbin/ ./usr/share/mdadm/"
  sed -i 's/ root / /g' "$TARGET_DIR/etc/cron.d/mdadm"
}

memory_config()
{
  ##memory tweaks based on testing
  if [ "$variant" = "armada370" ] || [ "$variant" = "armadaxp" ]; then
    echo "vm.min_free_kbytes = 10240" > "$TARGET_DIR/etc/sysctl.d/minfree.conf"
  fi
}

firewalld_errata()
{
  ##currently this package's build uses paths for things like modprobe
  ##based on the build system rather than the target system causing issues
  ##on some systems. I haven't figured out how to properly fix that yet

  [ "$BR2_PACKAGE_FIREWALLD" = "y" ] || return
  local x=""
  for x in modprobe rmmod kill sysctl xsltproc
  do
    [ ! -e "$TARGET_DIR/usr/sbin/$x" ] && [ -f "$TARGET_DIR/sbin/$x" ] && ln -s "/sbin/$x" "$TARGET_DIR/usr/sbin/$x"
  done
}
