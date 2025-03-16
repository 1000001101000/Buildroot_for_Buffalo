#!/bin/sh

. /etc/buffalo_type

pwm_search()
{
  local pwms=`ls /sys/class/hwmon/*/pwm?`
  local output=""
  local fancnt=$((0))

  for y in $pwms
  do
    echo 1 > "$y""_enable"
    [ "$fancnt" -ne 0 ] && output+=","
    output+="$y"
    fancnt=$((fancnt+1))
  done
  echo "$output"
}

[ "$fan_type" = "micon" ] && /usr/bin/hdd_fan_daemon.py "miconv$micon_ver" "$micon_port"

[ "$fan_type" = "hwmon" ] && /usr/bin/hdd_fan_daemon.py "hwmon" `pwm_search`

exit 0
