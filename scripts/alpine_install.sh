
##verify ubi boot supported?
test=`fw_printenv -n ubiboot | wc -c`
[ $((test)) -lt 10 ] && echo "upgrade fw to enable ubiboot before proceeding" && exit

##determine which mtd device is the big one for a rootfs
devnum=`cat /proc/mtd | grep squashfs | cut -b 4`

##mount the roofs image so we can use it to populate ubifs
mkdir /mnt/install 2>/dev/null
modprobe loop
mount -o loop /boot/rootfs.squashfs /mnt/install/

[ `dd if=/dev/mtd$devnum bs=4 count=1 2>/dev/null` = "UBI#" ] && ubichk=1

##format the new rootfs
##only needed the first time?
[ "$ubichk" = "1" ] || ubiformat /dev/mtd$devnum

ubiattach -m $devnum

#ubimkvol /dev/ubi0 -m -N rootfs

mkfs.ubifs -v -d /mnt/install/ -x zlib /dev/ubi0_0

umount /mnt/install

mount /dev/ubi0_0 /mnt/install

for x in `ls /boot/*.{buffalo,dtb}`
do
  x=`basename "$x"`
  cp -v "/boot/$x" /mnt/install/boot/
  ln -s "/boot/$x" /mnt/install/
done

umount /mnt/install/

##umount? prompt to reboot
