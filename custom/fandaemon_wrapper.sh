#!/bin/sh

. /etc/buffalo_type
[ "$micon_ver" != "" ] && /usr/bin/hdd_fan_daemon.py "miconv$micon_ver" "$micon_port"

exit 0
