#!/bin/sh

##poke around to figure out what this device needs for common features
/usr/bin/buffalo_system_info.sh

. /etc/buffalo_type
[ "$micon_ver" != "" ] && /usr/bin/micon_startup.py "$micon_port" "$micon_ver"


