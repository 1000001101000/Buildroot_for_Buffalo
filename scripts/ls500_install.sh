
table_magic="VERONA__"
part_fw_type=("JFFS2" "YAFFS2" "SQUASH" "RAWFILE" "EXT4" "UBIFS" "NONE" "UNKOWN")
part_type_code=("RESERVED" "FW" "FS")
fw_type_code=("RESERVED" "BOOTCODE" "KERNEL\t" "RESCUE_DT\t" "KERNEL_DT\t" "RESCUE_ROOTFS" "KERNEL_ROOTFS" "AUDIO\t" "AUDIO_FILE" "VIDEO_FILE" "EXT4" "UBIFS")

mtd="/dev/mtd0"
erase_sz=$((128*1024))

FW_KERNEL="nand.uImage"
FW_KERNEL_DT="android.nand.dtb"
FW_RESCUE_DT="rescue.nand.dtb"
FW_RESCUE_ROOTFS="rescue.root.nand.cpio.gz_pad.img"
FW_AKERNEL="bluecore.audio"
FW_FWTBL="fw_table.bin"

#start with printing out the details of what we want to generate?

quick_read()
{
  local off=$1
  local sz=$2
  local format='"%X"'
  [ $sz -eq 4 ] && format='"0x%08X"'
  [ $sz -eq 32 ] && format='"%_p"'
  if [ $sz -eq 8 ]; then
    echo $(hexdump -v -s $((off+4)) -n 4 -e '"0x%08X"' "$src")$(hexdump -v -s $off -n 4 -e '"%08X"' "$src")
    return
  fi
  hexdump -v -s $1 -n $2 -e $format "$src"
}

checksum()
{
  local src="$1"
  local off=$2"B"
  local sz=$3
  local cnt=""
  [ "$sz" != "" ] && cnt="count=$sz""B"
  local limit=$((0xffffffff+0))
  local tmp=0
  local sum=0
  while read tmp
  do
    tmp="0x$tmp"
    sum=$((sum+tmp))
    [ $sum -ge $limit ] && sum=$((sum-limit))
  done< <(dd if="$src" skip=$off $cnt bs=64k status=none| xxd -p -c 1 )

  echo $sum
}

checksum_file()
{
  local chksum=$(./checksum.py "$1")
  echo -n $((chksum+0))
}

fwline()
{
  echo "#define $1 \" $2 \"" >> layout.txt
}

fwline2()
{
  echo "#define $1 $2 " >> layout.txt
}

##https://stackoverflow.com/questions/43214001/how-to-write-binary-data-in-bash
le16() { # little endian 16 bit;  1st param: integer 
  v=`awk -v n=$1 'BEGIN{printf "%04X", n;}'`
  echo -n -e "\\x${v:2:2}\\x${v:0:2}"
}

le32() { # 32 bit version
  v=`awk -v n=$1 'BEGIN{printf "%08X", n;}'`
  echo -n -e "\\x${v:6:2}\\x${v:4:2}\\x${v:2:2}\\x${v:0:2}"
}

le64() {
  v=`awk -v n=$1 'BEGIN{printf "%016X", n;}'`
  echo -n -e "\\x${v:14:2}\\x${v:12:2}\\x${v:10:2}\\x${v:8:2}\\x${v:6:2}\\x${v:4:2}\\x${v:2:2}\\x${v:0:2}"
}

uchar()
{
  echo -e -n "\\x$(printf %0.2x $1)"
}

file_len() {
  wc -c "$1" | cut -d\  -f1
}

part_desc_entry() {
  local type=$1
  local ro=$2
  local len=$3
  local fw_count=$4
  local fw_type=$5
  local mnt="$6"
  local pad=${#mnt}
  pad=$((32-pad))

  uchar $type
  uchar $((ro*0x80))
  le64 $len
  uchar $fw_count
  uchar $fw_type
  echo -n -e "\\x00\\x00\\x00\\x00"
  echo -n "$mnt"
  echo -n -e "\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00" | head -c $pad
}

fw_desc_entry() {
  local type=$1
  local ro=$2
  local version=$3
  local target_addr=$4
  local offset=$5
  local length=$6
  local paddings=$7
  local checksum=$8

  uchar $type
  uchar $((ro*0x80))
  le32 $version
  le32 $target_addr
  le32 $offset
  le32 $length
  le32 $paddings
  le32 $checksum
  echo -n -e "\\x00\\x00\\x00\\x00\\x00\\x00"
}

round_up() {
  local value=$1
  local pad=$erase_sz
  local result=$(( ((value+pad-1)/pad)*pad ))
  echo $result
}

round_up_file() {
  local len=$(file_len "$1")
  local result=$(round_up $((len)))
  echo $result
}

analyze() {
  dd if="$1" of=temp.img bs=1M count=8 2>/dev/null
  local src="temp.img"
  local table_offsets="$(grep --byte-offset --only-matching --text "$table_magic" "$src" | cut -d: -f1)"
  local table=""
  for table in $table_offsets
  do
    local result=()
    local offset=$table
    for size in 8 4 1 7 4 4 4
    do
      result+=("$(quick_read "$offset" "$size")")
      offset=$((offset+size))
    done

    local version=$(printf %i ${result[2]})

    ##possibly replace with checksum check or multi version if needed
    if [ $version -ne 1 ]; then
      continue
    fi

    local part_len=$(printf %i ${result[5]})
    local paddings=$(printf %i ${result[4]})
    local list_len=$(printf %i ${result[6]})
    local table_chksum=$(printf %0.8X ${result[1]})
    local calc_tbl_sum=$(printf %0.8X $(checksum "$src" $(($table+12)) $((part_len+list_len+19))))

    echo "Firmware Table Version $version found at offset $table"
    echo " Padding Length: $paddings"
    echo " Partition List Length: $part_len"
    echo " Firmware List Length: $list_len"
    echo " Checksum: $table_chksum $calc_tbl_sum"
    echo ""
    echo "Partitions:"
    local partitions=()
    local x=0
    while [ $x -lt $((part_len/48)) ]
    do
      local partition=()
      for size in 1 1 8 1 1 4 32
      do
        partition+=("$(quick_read "$offset" "$size")")
        offset=$((offset+size))
      done

      local type=$(printf %i 0x${partition[0]})
      local len=$(printf %i ${partition[2]})
      local fwcnt=$(printf %i 0x${partition[3]})
      local fwtype=$(printf %i 0x${partition[4]})
      local mount="${partition[6]}" # | # | xxd -r -p)" #2>/dev/null
      echo -e " #$x: Type: ${part_type_code[$type]} \tLen: $len \tfw_cnt: $fwcnt \tfw_type: ${part_fw_type[$fwtype]}\tmnt: $mount"
      x=$((x+1))
    done

    echo "FW list:"
    x=0
    local fws=()
    while [ $x -lt $((list_len/32)) ]
    do
      local fw=()
      for size in 1 1 4 4 4 4 4 4 6
      do
        fw+=("$(quick_read "$offset" "$size")")
        offset=$((offset+size))
      done
      x=$((x+1))

      local type=$(printf %i 0x${fw[0]})
      local version=${fw[2]}
      local targetaddress=${fw[3]}
      local fwoffset=${fw[4]}
      local len=$(printf %i ${fw[5]})
      local paddings=${fw[6]}
      local checksum=${fw[7]}

      echo -e " #$x: ${fw_type_code[$type]}\tVersion: $version Target: $targetaddress Offset: $fwoffset Padding: $paddings Checksum: $checksum $calcchksum Length: $len"
    done
    break
  echo
  echo
done
}

clear
echo "Welcome to the LS500 Firmware installer program"
echo
echo
sleep 0.25
echo "          Press any key to continue            "
sleep 0.5
read
echo "This process is a work in progress...and a headache"
#basically we do some checks to be reasonably sure the install will succeed.
#then we install the firmware image which contains everything but the actual rootfs.
#then we reboot and confirm the new OS loads and that the nand is now partitoned for the rootfs install
#then we format that partition and load the rootfs.
#finally we boot the whole OS from NAND
echo "          Press any key to continue            "
read
clear
echo "Analyzing NAND FW layout, please wait"


FW_KERNEL_SIZE=$(file_len "$FW_KERNEL")
FW_KERNEL_DT_SIZE=$(file_len "$FW_KERNEL_DT")
FW_RESCUE_DT_SIZE=$(file_len "$FW_RESCUE_DT")
FW_RESCUE_ROOTFS_SIZE=$(file_len "$FW_RESCUE_ROOTFS")
#FW_AKERNEL_SIZE=$(file_len "$FW_AKERNEL")
FW_AKERNEL_SIZE=$((1010368))

FW_KERNEL_PAD=$(round_up $FW_KERNEL_SIZE)
FW_KERNEL_DT_PAD=$(round_up $FW_KERNEL_DT_SIZE)
FW_RESCUE_DT_PAD=$(round_up $FW_RESCUE_DT_SIZE)
FW_RESCUE_ROOTFS_PAD=$(round_up $FW_RESCUE_ROOTFS_SIZE)
FW_AKERNEL_PAD=$(round_up $FW_AKERNEL_SIZE)

FW_KERNEL_CHK=$(checksum_file "$FW_KERNEL")
FW_RESCUE_DT_CHK=$(checksum_file "$FW_RESCUE_DT")
FW_KERNEL_DT_CHK=$(checksum_file "$FW_KERNEL_DT")
FW_RESCUE_ROOTFS_CHK=$(checksum_file "$FW_RESCUE_ROOTFS")
#FW_AKERNEL_CHK=$(checksum_file "$FW_AKERNEL")
FW_AKERNEL_CHK=$((0x04556C26))

FW_RESCUE_DT_OFFSET=$((0x00C40000+0))
FW_KERNEL_DT_OFFSET=$((FW_RESCUE_DT_OFFSET+FW_RESCUE_DT_PAD))
FW_AKERNEL_OFFSET=$((FW_KERNEL_DT_OFFSET+FW_KERNEL_DT_PAD))
FW_KERNEL_OFFSET=$((FW_AKERNEL_OFFSET+FW_AKERNEL_PAD))
FW_RESCUE_ROOTFS_OFFSET=$((FW_KERNEL_OFFSET+FW_KERNEL_PAD))

kernel_loadaddr=$((0x03000000+0))
rootfs_loadaddr=$((0x02200000+0))
fdt_loadaddr=$((0x01FF2000+0))
audio_loadaddr=$((0x01B00000+0))

### fw_desc_table_v1_t
>fw_desc.bin
fw_desc_entry 2 1 0 $kernel_loadaddr $FW_KERNEL_OFFSET $FW_KERNEL_SIZE $FW_KERNEL_PAD $FW_KERNEL_CHK >> fw_desc.bin
fw_desc_entry 3 1 0 $fdt_loadaddr $FW_RESCUE_DT_OFFSET $FW_RESCUE_DT_SIZE $FW_RESCUE_DT_PAD $FW_RESCUE_DT_CHK >> fw_desc.bin
fw_desc_entry 4 1 0 $fdt_loadaddr $FW_KERNEL_DT_OFFSET $FW_KERNEL_DT_SIZE $FW_KERNEL_DT_PAD $FW_KERNEL_DT_CHK >> fw_desc.bin
fw_desc_entry 5 1 0 $rootfs_loadaddr $FW_RESCUE_ROOTFS_OFFSET $FW_RESCUE_ROOTFS_SIZE $FW_RESCUE_ROOTFS_PAD $FW_RESCUE_ROOTFS_CHK >> fw_desc.bin
fw_desc_entry 7 1 0 $audio_loadaddr $FW_AKERNEL_OFFSET $FW_AKERNEL_SIZE $FW_AKERNEL_PAD $FW_AKERNEL_CHK >> fw_desc.bin
fw_list_len=$(file_len fw_desc.bin)

### part_desc_entry_v1_t
> part_list.bin
part_desc_entry 1 1 30539776 5 0 ""    >> part_list.bin
#part_desc_entry 2 0 130154496 1 2 "/"  >> part_list.bin
#part_desc_entry 2 0 73400320 1 5 "misc">> part_list.bin
#part_desc_entry 2 0 20971520 1 5 "etc" >> part_list.bin
part_desc_entry 2 0 224526336 1 5 "/">> part_list.bin
part_list_len=$(file_len part_list.bin)

> tmp_table.bin
uchar 1 >> tmp_table.bin ##version
echo -n -e "\\x00\\x00\\x00\\x00\\x00\\x00\\x00" >> tmp_table.bin ##reserved 0000
le32 $erase_sz >> tmp_table.bin ##technically should be round up
le32 $part_list_len >> tmp_table.bin
le32 $fw_list_len >> tmp_table.bin
cat part_list.bin fw_desc.bin >> tmp_table.bin

> fw_table.bin
echo -n $table_magic >> "$FW_FWTBL"
le32 $(checksum_file tmp_table.bin) >> "$FW_FWTBL"
cat tmp_table.bin >> "$FW_FWTBL"

rm tmp_table.bin
rm part_list.bin
rm fw_desc.bin

FW_FWTBL_SIZE=$(file_len "$FW_FWTBL")
FW_FWTBL_OFFSET=$((0x00480000+0))
FW_FWTBL_PAD=$(round_up FW_FWTBL_SIZE)

##technically could have a problem crossing midnight
> layout.txt
fwline "CREATE_DATE" "$(date "+%b %d %Y")"
fwline "CREATE_TIME" "$(date "+%H:%M:%S")"
fwline "BOOTTYPE" "BOOTTYPE_COMPLETE"
fwline2 "SSUWORKPART" 0
fwline2 "BOOTPART" 0
fwline "FW_KERNEL" "`printf "target=%x offset=%x size=%x" $kernel_loadaddr $FW_KERNEL_OFFSET $FW_KERNEL_SIZE` type=bin name=$FW_KERNEL"
fwline "FW_RESCUE_DT" "`printf "target=%x offset=%x size=%x" $fdt_loadaddr $FW_RESCUE_DT_OFFSET $FW_RESCUE_DT_SIZE` type=bin name=$FW_RESCUE_DT"
fwline "FW_KERNEL_DT" "`printf "target=%x offset=%x size=%x" $fdt_loadaddr $FW_KERNEL_DT_OFFSET $FW_KERNEL_DT_SIZE` type=bin name=$FW_KERNEL_DT"
fwline "FW_RESCUE_ROOTFS" "`printf "target=%x offset=%x size=%x" $rootfs_loadaddr $FW_RESCUE_ROOTFS_OFFSET $FW_RESCUE_ROOTFS_SIZE` type=bin name=$FW_RESCUE_ROOTFS"
fwline "FW_AKERNEL" "`printf "target=%x offset=%x size=%x" $audio_loadaddr $FW_AKERNEL_OFFSET $FW_AKERNEL_SIZE` type=bin name=$FW_AKERNEL"
fwline "FW_FWTBL" "`printf "target=%x offset=%x size=%x" 0 $FW_FWTBL_OFFSET $FW_FWTBL_SIZE` type=bin name=$FW_FWTBL"

echo "Current FW:"
analyze "$mtd"
echo
echo "Proposed FW:"
analyze "fw_table.bin"

echo
echo -n "attempt install (y/n)? "
read proceed
if [ "$proceed" != "y" ]; then
  echo "received non y response"
  exit
fi

##install the pieces where they go.
flash_erase -N $mtd $FW_FWTBL_OFFSET $((FW_FWTBL_PAD/erase_sz))
nandwrite -p -N -s $FW_FWTBL_OFFSET $mtd $FW_FWTBL

flash_erase -N $mtd $FW_RESCUE_DT_OFFSET $((FW_RESCUE_DT_PAD/erase_sz))
nandwrite -p -N -s $FW_RESCUE_DT_OFFSET $mtd $FW_RESCUE_DT

flash_erase -N $mtd $FW_KERNEL_DT_OFFSET $((FW_KERNEL_DT_PAD/erase_sz))
nandwrite -p -N -s $FW_KERNEL_DT_OFFSET $mtd $FW_KERNEL_DT

flash_erase -N $mtd $FW_KERNEL_OFFSET $((FW_KERNEL_PAD/erase_sz))
nandwrite -p -N -s $FW_KERNEL_OFFSET $mtd $FW_KERNEL

flash_erase -N $mtd $FW_RESCUE_ROOTFS_OFFSET $((FW_RESCUE_ROOTFS_PAD/erase_sz))
nandwrite -p -N -s $FW_RESCUE_ROOTFS_OFFSET $mtd $FW_RESCUE_ROOTFS

###repartition mtd to match new layout.
###delete any existing.

exit
parts=`wc -l /proc/mtd`
rootdev=`df / | tail -1 | cut -d\  -f 1`

echo $rootdev | grep -q mtd
if [ $? -eq 0 ]; then
   echo "can't re-write nand rootfs if we're already running a nand boot, usb boot and try again."
  exit 99
fi

###partitions already present, could be trouble
if [ $parts -gt 2 ]; then
  echo "could be trouble"
  echo "we can't do this from nand root"
  ###delete them first?
fi

mtdpart add /dev/mtd0 "Partition_000" 0 30539776
mtdpart add /dev/mtd0 "/" 30539776 224526336

mkdir /mnt/install
modprobe loop
mount -o loop /boot/rootfs.squashfs /mnt/install/




###make real bloody sure you've got the right mtd
# ubiformat /dev/mtd2
#ubiformat: mtd2 (nand), size 224526336 bytes (214.1 MiB), 1713 eraseblocks of 131072 bytes (128.0 KiB), min. I/O size 2048 bytes
#libscan: scanning eraseblock 1712 -- 100 % complete
#ubiformat: 1713 eraseblocks have valid erase counter, mean value is 3
#ubiformat: formatting eraseblock 1712 -- 100 % complete

# ubiattach -m 2
#UBI device number 0, total 1713 LEBs (217509888 bytes, 207.4 MiB), available 1670 LEBs (212049920 bytes, 202.2 MiB), LEB size 126976 bytes (124.0 KiB)

# ubimkvol /dev/ubi0 -m -N rootfs
#Set volume size to 212049920
#Volume ID 0, size 1670 LEBs (212049920 bytes, 202.2 MiB), LEB size 126976 bytes (124.0 KiB), dynamic, name "rootfs", alignment 1

#mkfs.ubifs -v -d /mnt/install/ /dev/ubi0_0
## mkfs.ubifs -v -d /mnt/install/ -x zlib /dev/ubi0_0
exit


