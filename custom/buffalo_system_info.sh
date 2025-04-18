

arch="$(uname -m)"
shutdown_type=""
micon_ver=""
micon_port=""
fan_type="" ## hwmon (some automatic some not), gpio (shows as hwmon), micon

if [ "$arch" == "x86_64" ]; then
  grep -q "C3338" /proc/cpuinfo ##does ws5820 etc have different?
  if [ $? -eq 0 ]; then
    ##denverton
    shutdown_type="micon"
    micon_ver=3
    micon_port="/dev/ttyS0"
    fan_type="hwmon"
  fi
  grep -qe '^model name.*Atom.*CPU D' /proc/cpuinfo
  if [ $? -eq 0 ]; then
    ##ts-vhl or ts5000
    shutdown_type="micon"
    micon_ver=2
    micon_port="/dev/ttyS1"
    fan_type="hwmon"
  fi
fi ##end X86

machinetype=`sed -n '/Hardware/ {s/^Hardware\s*:\s//;p}' /proc/cpuinfo`
machine="$machinetype"
case $machine in
        *"Device Tree)"|"")
        machine=$(cat /proc/device-tree/model)
        ;;
esac

uname -m | grep -q armv5
if [ $? -eq 0 ]; then
  ##nearly all hwmon, check for exceptions later
  fan_type="hwmon"

  ##only one variation of micon, and nothing without one even has ttyS1, just see if something responds
  micro-evtd -q -s 8083 && micon_ver=2 && micon_port="/dev/ttyS1" && shutdown_type="micon" && fan_type="micon"
  ##check micon response, are those all the same?
  case $machine in
  "Buffalo Linkstation LS-XL")
  fan_type="";;
  "Buffalo Linkstation LS-QL")
  shutdown_type="rtc";;
  "Buffalo Linkstation LS-WXL" | "Buffalo Linkstation LS-WVL" | "Buffalo Linkstation LS-QVL")
  shutdown_type="phy";;
  "Buffalo Linkstation Pro/Live"|"Buffalo Terastation Pro II/Live"|"Buffalo Terastation TS-XEL"|"Buffalo Nas WXL")
  micon_ver=2
  micon_port="/dev/ttyS1"
  shutdown_type="micon"
  fan_type="micon"
  ;;
  esac
  ##a couple linkstations have no fan
fi ##end armel

uname -m | grep -q armv7
if [ $? -eq 0 ]; then ##alpine devs
  grep -q -e '^Hardware.*AnnapurnaLabs' /proc/cpuinfo
  if [ $? -eq 0 ]; then
    shutdown_type="micon"
    micon_ver=3
    micon_port="/dev/ttyUSB0"
    fan_type="micon"
    ###parse fw_printenv params from cmdline
    cmdline="$(cat /proc/cmdline)"

    cmd2entry()
    {
      local dev="$(echo $1 | cut -d, -f4)"
      local offset="$(echo $dev | cut -d@ -f1)"
      local dev="$(echo $dev | cut -d@ -f2)"
      echo "/dev/$dev" "$(echo $1 | awk -F, '{print $1" "$2" "$2" "$3}')"
    }

    primary=""
    secondary=""

    for x in $cmdline
    do
      key="$(echo $x | cut -d= -f1)"
      if [ "$key" == "ubootenv" ]; then
        primary="$(echo $x | cut -d= -f2)"
      fi
      if [ "$key" == "ubootenv_redund" ]; then
        secondary="$(echo $x | cut -d= -f2)"
      fi
    done

    cmd2entry $primary   > /etc/fw_env.config
    cmd2entry $secondary >>/etc/fw_env.config
  fi
  if [ "$machinetype" = "Marvell Armada 370/XP (Device Tree)" ]; then
    fan_type="hwmon"
    case $machine in
    "Buffalo Terastation TS1400D"|"Buffalo Terastation TS1400R"|"Buffalo Terastation TS3200D"|"Buffalo Terastation TS3400D"|"Buffalo Terastation TS3400R")
      micon_ver=2
      micon_port="/dev/ttyS1"
      shutdown_type="micon"
      fan_type="micon"
      ;;
    "Buffalo Linkstation LS210D")
      fan_type=""
      ;;
    "Buffalo Linkstation LS420D"|"Buffalo Linkstation LS421D"|"Buffalo Linkstation LS441D"|"Buffalo Terastation TS1200D")
      shutdown_type="phy"
      ;;
    esac
  fi
fi ##end armhf

uname -m | grep -q aarch64
if [ $? -eq 0 ]; then
  fan_type="hwmon"
  ##assume some models I haven't looked at also have miconv3
fi

> /etc/buffalo_type
echo "shutdown_type=$shutdown_type" >> /etc/buffalo_type
echo "micon_ver=$micon_ver" >> /etc/buffalo_type
echo "micon_port=$micon_port" >> /etc/buffalo_type
echo "fan_type=$fan_type" >> /etc/buffalo_type
exit 0
