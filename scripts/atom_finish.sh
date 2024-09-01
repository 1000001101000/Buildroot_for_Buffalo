#!/bin/bash

. ../scripts/functions.sh

../scripts/common_finish

custom_module "it87ts-1.0"
echo it87ts > "$TARGET_DIR/etc/modules-load.d/sensors.conf"

custom_module "gpio_it87ts-1.0"
echo gpio-it87ts > "$TARGET_DIR/etc/modules-load.d/gpio.conf"
echo gpio-ich >> "$TARGET_DIR/etc/modules-load.d/gpio.conf"

stage_module gpio-it87ts

##network

exit 0
