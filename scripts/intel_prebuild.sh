#!/bin/bash
grep -q BR2_TARGET_SYSLINUX_GPT "$BR2_CONFIG"
if [ $? -ne 0 ]; then
  echo "BR2_TARGET_SYSLINUX_GPT=y" >> "$BR2_CONFIG"
fi
exit 0
