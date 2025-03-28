
##verify ubi boot supported?
test=`fw_printenv -n ubiboot | wc -c`
[ $((test)) -lt 10 ] && echo "upgrade fw to enable ubiboot before proceeding" && exit

##determine which mtd device is the big one for a rootfs
##just checking for the label set by stock fw for now.
devnum=`cat /proc/mtd | grep squashfs | cut -b 4`

##mount the roofs image so we can use it to populate ubifs
mkdir /mnt/install 2>/dev/null
modprobe loop
mount -o loop /boot/rootfs.squashfs /mnt/install/
[ $? -ne 0 ] && echo "failed to mount rootfs image, aborting" && exit

[ `dd if=/dev/mtd$devnum bs=4 count=1 2>/dev/null` = "UBI#" ] && ubichk=1

##format the device as UBI if it isn't already.
##this shouldn't really happen.
[ "$ubichk" = "1" ] || ubiformat /dev/mtd$devnum
[ $? -ne 0 ] && echo "failed to format UBI device mtd$devnum, aborting" && exit

ubiattach -m $devnum -d 9
[ $? -ne 0 ] && echo "failed to attach UBI device to mtd$devnum, aborting" && exit

##likewise, shouldn't be needed.
[ "$ubichk" = "1" ] || ubimkvol /dev/ubi9 -m -N rootfs
[ $? -ne 0 ] && echo "failed to create volume on UBI device mtd$devnum, aborting" && exit

##cover either scenario of how volumes created
tmpdev="`ls /dev/ubi9_?`"

mkfs.ubifs -v -d /mnt/install/ -x zlib "$tmpdev"
[ $? -ne 0 ] && echo "failed to create UBIFS filesystem on mtd$devnum, aborting" && exit

umount /mnt/install
[ $? -ne 0 ] && echo "failed to unmount install image, aborting" && exit

mount "$tmpdev" /mnt/install
[ $? -ne 0 ] && echo "failed to mount rootfs on mtd$devnum, aborting" && exit

for x in `ls /boot/*.{buffalo,dtb}`
do
  x=`basename "$x"`
  cp -v "/boot/$x" /mnt/install/boot/
  ln -s "/boot/$x" /mnt/install/
  [ $? -ne 0 ] && echo "failed to copy $x, rootfs likely in unusable state" && exit
done

umount /mnt/install/
echo "install of OS to NAND complete"

