
debian_import()
{
  local pkg=$1
  local distro=$2
  local arch=$3
  local suite=$4
  local files=$5

  #echo "$pkg"

  if [ -z "$suite" ]; then
    suite="main"
  fi

  if [ "$distro" == "jessie" ]; then
    mirror="archive.debian.org"
  else
    mirror="ftp.debian.org"
  fi

  if [ "$BR2_DL_DIR" = "" ]; then
    echo "failed to lookup download directory"
    exit 1
  fi

  local dir="$BR2_DL_DIR/deb/$distro-$arch-$suite"

  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || exit 1
  fi

  cd "$dir" || exit 1
  wget -N "http://$mirror/debian/dists/$distro/$suite/binary-$arch/Packages.gz" 2>/dev/null

  deb_url="$(zcat Packages.gz | grep /"$pkg"_ | grep Filename | gawk '{print $2}')"
  wget -N "http://$mirror/debian/$deb_url" 2>/dev/null
  filename="$(basename "$deb_url")"

  ar xf "$filename" data.tar.xz
  tar xf data.tar.xz --keep-directory-symlink -C "$target" $files
  rm data.tar.xz

  cd - >/dev/null || exit 1
}

custom_module()
{
        local mod_dir="$custom_dir/$1"
        local kver="$(ls $BUILD_DIR | grep -e ^linux-[1-9] | sed 's/linux-//g')"
        local kernel_dir="$BUILD_DIR/linux-$kver"
        local cross="$HOST_DIR/bin/$(ls output/host/bin/ | grep -e '^.*buildroot.*gcc$' | sed 's/...$//g')"

        cd "$mod_dir" || exit 99
        make clean
        make TARGET="$kver" KERNEL_BUILD="$BUILD_DIR/linux-$kver" CROSS_COMPILE="$cross" KERNEL_MODULES="$TARGET_DIR/lib/modules/$kver"
        make modules_install TARGET="$kver" KERNEL_BUILD="$BUILD_DIR/linux-$kver" CROSS_COMPILE="$cross" KERNEL_MODULES="$TARGET_DIR/lib/modules/$kver"
        cd - > /dev/null
        depmod -b "$TARGET_DIR" -o "$TARGET_DIR" "$kver"
}

r8152_config()
{
  ##setup r8152 driver with r8156 support
  mkdir -p "$target/etc/modprobe.d/"
  echo "blacklist cdc_mbim" > "$target/etc/modprobe.d/r8152.conf"
  echo "blacklist cdc_ncm" >> "$target/etc/modprobe.d/r8152.conf"
  echo 'install r8152 /sbin/modprobe --ignore-install r8152; sleep 1; echo "0bda 8156" > /sys/bus/usb/drivers/r8152/new_id' >> "$target/etc/modprobe.d/r8152.conf"
}

mail_setup()
{
  ##it seems like some programs call mail,mailx, or sendmail, or look at nail.rc..or aliases
  ln -s "/usr/bin/mailx" "$target/usr/bin/mail" 2>/dev/null
  ln -s "/usr/bin/msmtp" "$target/usr/sbin/sendmail" 2>/dev/null
  echo "set mta=/usr/bin/msmtp" > "$target/etc/nail.rc"

  echo "
  defaults
  auth           on
  tls            on
  tls_trust_file /etc/ssl/certs/ca-certificates.crt
  logfile        /var/log/msmtp.log
  " > "$target/etc/msmtprc"
}

generate_initrd()
{
local arch="$(echo $MACHTYPE | cut -d\- -f1)"

local variant="$1"
local rootfsID="$2"
local bootID="$3"

local importbins="bin/busybox sbin/blkid sbin/mdadm usr/bin/micro-evtd bin/lsblk usr/bin/timeout"
local workdir="$BINARIES_DIR/initrdtmp"

##cleanup previous run if needed
rm "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd" 2>/dev/null
rm -r "$workdir" 2>/dev/null

##create working dir and enter it
mkdir "$workdir"

##create some directories that will be needed.
mkdir -p "$workdir"/{boot,proc,sys,dev,mnt/root,bin,lib,sbin,usr/bin,lib/modules}

#copy in init and make sure executable
cp ../scripts/initrd_init "$workdir/init"
chmod +x "$workdir/init"

##put the UUID of the rootfs in place for init to use
echo "$rootfsID" > "$workdir/UUID"
echo "$bootID" > "$workdir/bootUUID"
echo "$variant" > "$workdir/variant"

#pull in busybox and any needed libs from the rootfs.
importlibs=""
for x in $importbins
do
  if [ ! -e "$TARGET_DIR/$x" ]; then continue; fi
  cp "$TARGET_DIR/$x" "$workdir/$x"
  chmod +x "$workdir/$x"
  importlibs="$importlibs $(readelf -d "$TARGET_DIR/$x" | grep 'NEEDED' | cut -d[ -f2 | cut -d] -f1)"
done
importlibs="$(echo $importlibs | sort -u)"

recurse=1
while [ $recurse -eq 1 ]
do
recurse=0
for lib in $importlibs
do
  if [ ! -e "$workdir/lib/$lib" ]; then
    find "$TARGET_DIR" -name "$lib" -exec cp {} "$workdir/lib/$lib" \;
    if [ $? -eq 0 ]; then
      recurse=1
      importlibs="$importlibs $(readelf -d "$workdir/lib/$lib" | grep 'NEEDED' | cut -d[ -f2 | cut -d] -f1)"
    fi
  fi
done
done

ln -s "/lib" "$workdir/lib64"

#create symlinks for some needed commands
for x in mount umount switch_root sh cat sleep getty watch vi ip mkdir login cd ls chmod sed awk grep dd xxd printf head xargs dirname find uname insmod
do
  ln -s /bin/busybox "$workdir/bin/$x"
done

##pull in any staged modules
cd "$BINARIES_DIR/modules/"
if [ $? -eq 0 ]; then
  rsync -vr * "$workdir/"
  cd -
fi

#create a cpio archive of the directory for use as an initramfs
cd "$workdir" || exit 1
find . -print0 | cpio --null --create --verbose --format=newc > ../initrd
cd - >/dev/null || exit 1

##compress the initrd image.
gzip -n "$BINARIES_DIR/initrd"

if [ -d "$TARGET_DIR/lib/firmware/intel-ucode" ]; then
	DSTDIR="kernel/x86/microcode"
	mkdir -p "$TARGET_DIR/$DSTDIR"
        cat "$TARGET_DIR/lib/firmware/intel-ucode"/* > "$TARGET_DIR/$DSTDIR/GenuineIntel.bin"
	echo "./$DSTDIR/GenuineIntel.bin" | cpio -D "$TARGET_DIR" -o -H newc > "$BINARIES_DIR/ucode.cpio"
	mv "$BINARIES_DIR/initrd.gz" "$BINARIES_DIR/initrd.orig"
	cat "$BINARIES_DIR/ucode.cpio" "$BINARIES_DIR/initrd.orig" > "$BINARIES_DIR/initrd.gz"
fi
}

pad_dtbs()
{
  ##pad the dtb size so uboot can pass stuff where needed
  for x in $(ls "$BINARIES_DIR"/*.dtb)
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
" > "$workdir/syslinux.cfg"
}

stage_module()
{
  mkdir "$BINARIES_DIR/modules/" 2>/dev/null
  cd "$TARGET_DIR"
  find lib/ -name $1.ko | xargs -I{} rsync -vR {} "$BINARIES_DIR/modules/"
  cd -
}
