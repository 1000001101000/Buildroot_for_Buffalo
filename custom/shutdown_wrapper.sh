
. /etc/buffalo_type

action="$1"

[ "$shutdown_type" = "rtc" ] && /usr/bin/rtc_shutdown.sh "$action"
[ "$shutdown_type" = "micon" ] && /usr/bin/micon_shutdown.py "$action" "$micon_port" "$micon_ver"
[ "$shutdown_type" = "phy" ] && /usr/bin/phy_shutdown.sh "$action"


