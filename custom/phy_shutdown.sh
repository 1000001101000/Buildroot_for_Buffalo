#!/bin/bash

supported="mvneta"

#fixups to make sure nics are detected appropriately

for nic in `ls /sys/class/net/`
do
  driver=`readlink /sys/class/net/$nic/device/driver | xargs basename 2>/dev/null`
  [ $? -eq 0 ] || continue
  echo $supported | grep -q -w $driver || continue
  reg=`printf "%d" </sys/class/net/$nic/phydev/of_node/reg`
  phy="$nic/$reg"
  ip addr replace 10.0.0.0 dev eth0
  ip link set eth0 up
  sleep 2
  phytool write $phy/22 3
  before="$(phytool read $phy/16)"
  if [ "$1" == "halt" ] || [ "$1" == "poweroff" ]; then
    new="0x0881"
  else
    new="0x0981"
  fi
  echo "phy_shutdown, try to set $nic to $new" > /dev/console
  phytool write $phy/16 $new
  after="$(phytool read $phy/16)"
  phytool write $phy/22 0
  echo "phy_shutdown: $nic $before -> $after" > /dev/console
done
exit
