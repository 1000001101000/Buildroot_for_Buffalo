#!/bin/bash

. ../scripts/functions.sh

../scripts/common_finish

custom_module "it87ts-1.0"
echo it87ts > "$TARGET_DIR/etc/modules-load.d/sensors.conf"

#custom_module "gpio_dnv-1.0"
#echo gpio-dnv > "$TARGET_DIR/etc/modules-load.d/gpio.conf"

exit 0
