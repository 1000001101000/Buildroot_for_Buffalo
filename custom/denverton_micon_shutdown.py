#!/usr/bin/python3

import libmicon
import time
import sys

print("Signal Micon shutdown")
port="/dev/ttyS0"
test = libmicon.micon_api_v3(port)
for i in range(16):
	test.set_led(i, "off")
test.send_miconv3("LCD_CLR")
if sys.argv[1] in ["halt","poweroff"]:
	test.send_miconv3("POWER_OFF")
else:
	test.send_miconv3("REBOOT")
test.port.close()


