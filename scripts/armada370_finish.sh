#!/bin/bash

. ../scripts/functions.sh

../scripts/common_finish

stage_module marvell_nand

echo "/dev/mtdblock1 0x00000 0x10000 0x10000" > "$TARGET_DIR/etc/fw_env.config"

exit 0
