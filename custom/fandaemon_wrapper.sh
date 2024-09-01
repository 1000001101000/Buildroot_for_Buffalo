#!/bin/sh

. /etc/buffalo_type
[ "$micon_ver" != "" ] && /usr/bin/hdd_fan_daemon.py "$micon_port" "$micon_ver"


