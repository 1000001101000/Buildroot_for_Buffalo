#!/usr/bin/python3

import libmicon
import platform


###make miconv2 and v3 start up tasks functions.

def startupV3(port):
	test = libmicon.micon_api_v3(port)
	version=""
	distro=""
	arch=platform.machine()[:3].upper()

	##disable watchdog
	test.send_miconv3("BOOT_END")

	with open("/etc/os-release", "r") as file:
		lines = file.readlines()
		for x in lines:
			line=x.strip().split("=")
			#print(line)
			if (line[0]=="PRETTY_NAME"):
				distro=line[1].split(" ")[0].replace('"','')[0:12]
			if (line[0]=="VERSION_ID"):
				version=line[1][0:7].strip()

	#version = version.center(16,u"\u00A0")
	title1 = distro +" " + arch
	title2 = "Version " + version

	##set LCD color
	test.set_led(3, "on")
	test.set_led(4, "on")
	test.set_led(5, "off")

	test.set_lcd(0,title1)
	test.set_lcd(1,title2)

	##just enable the drive bays for now
	for i in range(8):
		test.send_miconv3("HDD_ON "+str(i))

	for i in ["0","1","2","6"]:
		test.set_led(i, "off")

	##solid power LED
	test.set_led(0,"on")

	test.port.close()

# check for some sort of config file to avoid messing with ports each time?

##try reading micon version from each port to determine the right one
for port in ["/dev/ttyS0"]:
	try:
		test = libmicon.micon_api_v3(port)
	except:
		continue
	micon_version = test.send_miconv3("VER_GET")
	if micon_version:
		test.port.close()
		startupV3(port)
		quit()
	test.port.close()

quit()

#0 - powerled

#8 - bay 2 error led
#12 - bay 6 error led

#15 - error led?

