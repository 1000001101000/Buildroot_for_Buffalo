#!/usr/bin/python3

import libmicon
import platform

test = libmicon.micon_api_v3("/dev/ttyUSB0")

for fan in ["0","1"]:
	fan_spd = str(int(test.send_miconv3("FAN_GET "+fan)))
	print("FAN " + fan + ": "+fan_spd)

test.port.close()

quit()
