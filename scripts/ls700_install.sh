

##expected offsets based on uboot source and watching usb boot.
##there must be a better way to determine them.

##check sha1sums against file generated at creation?

kernel_offset=$((0x02860000))
initrd_offset=$((0x82001C0))
dtb_offset=$((0x02660000))

mmc="/dev/mmcblk0"

##confirm kernel is a kernel
kmagic=`dd if=$mmc bs=4 count=1 skip=${kernel_offset}B 2>/dev/null | hexdump -ve '"%4x"'`
imagic=`dd if=$mmc bs=4 count=1 skip=${initrd_offset}B 2>/dev/null | hexdump -ve '"%4x"'`
dmagic=`dd if=$mmc bs=4 count=1 skip=${dtb_offset}B 2>/dev/null | hexdump -ve '"%4x"'`

if [ "$kmagic" != "56190527" ] || [ "$imagic" != "56190527" ] || [ "$dmagic" != "edfe0dd0" ]; then
  echo "Didn't find valid firmware at expected offsets, exiting without making changes"
  exit 99
fi

###verify sizes of the files fit in the reserved areas?

dd of=$mmc if=/boot/uImage-generic.buffalo oflag=seek_bytes bs=4k seek=$kernel_offset
dd of=$mmc if=/boot/uInitrd-generic.buffalo oflag=seek_bytes bs=4k seek=$initrd_offset
dd of=$mmc if=/boot/rtd1619-ls700.dtb oflag=seek_bytes bs=4k seek=$dtb_offset

##independently determine model to choose right dtb?
### verify offsets for kernel/etc. ideally the same way the bootloader would.

## verify large unpartitioned space for rootfs.
## probably look for already installed and offer to upgrade
## create partition via sgdisk

##expand the large partition to use all available space
sgdisk -d 7 /dev/mmcblk0 2>/dev/null ##might exist from earlier install
sgdisk -d 6 /dev/mmcblk0
sgdisk -n 6 /dev/mmcblk0
sgdisk -c 6:BRROOT /dev/mmcblk0
partprobe 2>/dev/null

##mount rootfs image as install source
mkdir /mnt/install 2>/dev/null
modprobe loop
mount -o loop /boot/rootfs.squashfs /mnt/install/
mkfs.ext4 -d /mnt/install/ /dev/mmcblk0p6
umount /mnt/install
