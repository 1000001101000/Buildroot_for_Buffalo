#!/bin/bash

##patch to add sysbench and dependency may need to look into why never merged
wget -nc "https://marc.info/?l=buildroot&m=170021431900448&q=raw" -O "$CONFIG_DIR/../patches/buildroot_add_sysbench.patch" 2>/dev/null
wget -nc "https://marc.info/?l=buildroot&m=170021430500441&q=raw" -O "$CONFIG_DIR/../patches/buildroot_add_ck.patch" 2>/dev/null

##patches I'm working on getting into buildroot project, should be safe even if build not using that app.
for x in buildroot_zfs_initscripts buildroot_syslinux_gptmbr buildroot_mdadm_systemd buildroot_atd_dir buildroot_atd_systemd buildroot_add_sysbench buildroot_add_ck
do
  patch -N -p1 < "$CONFIG_DIR/../patches/$x.patch"
done

##add to config somewhat manually
grep -q BR2_PACKAGE_SYSBENCH "$BR2_CONFIG"
if [ $? -ne 0 ]; then
  echo "BR2_PACKAGE_CK_ARCH_SUPPORTS=y" >> "$BR2_CONFIG"
  echo "BR2_PACKAGE_CK=y" >> "$BR2_CONFIG"
  echo "BR2_PACKAGE_SYSBENCH_ARCH_SUPPORTS=y" >> "$BR2_CONFIG"
  echo "BR2_PACKAGE_SYSBENCH=y" >> "$BR2_CONFIG"
fi

##if we are configured to use syslinux mbr set the gpt option, workaround for adding config after config phase
grep -q "BR2_TARGET_SYSLINUX_MBR=y" "$BR2_CONFIG"
if [ $? -eq 0 ]; then
  grep -q "BR2_TARGET_SYSLINUX_GPT" "$BR2_CONFIG"
  if [ $? -ne 0 ]; then
    echo "BR2_TARGET_SYSLINUX_GPT=y" >> "$BR2_CONFIG"
  fi
fi

##try to ensure any config related changes get processed properly
make oldconfig
exit 0
