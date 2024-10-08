#!/bin/bash
# place in /lib/systemd/system-shutdown/ for debian based systems
# other systems it's /usr/lib/systemd/system-shutdown/

#phytool="/usr/local/bin/phytool"

##I think only needed for dhcp leases file
##overlay ramfs or just link up?
mount -o remount,rw /

ifup --no-scripts --force eth0
sleep 2
mount -o remount,ro /
##can we get from devtree?
phytool write eth0/0/22 3
before="$(phytool read eth0/0/16)"
if [ "$1" == "halt" ] || [ "$1" == "poweroff" ]; then
  new="0x0881"
else
  new="0x0981"
fi
echo "phy_shutdown, try to set $new"
phytool write eth0/0/16 $new
after="$(phytool read eth0/0/16)"
phytool write eth0/0/22 0
echo "phy_shutdown: $before -> $after"

exit 0

