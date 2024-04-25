#!/usr/bin/python3

import libmicon
import platform


###make miconv2 and v3 start up tasks functions.

def startupV2(port):
	test = libmicon.micon_api(port)

	micon_version = test.send_read_cmd(0x83)
	micon_version=micon_version.decode('utf-8')

	##disable boot watchdog
	test.send_write_cmd(0,0x03)

	#version= "BR 2023.08.2"
	#version = version.center(16)
	#title = "Terastation " + platform.machine()[:3].upper()
	arch=platform.machine()[:3].upper()

	with open("/etc/os-release", "r") as file:
		lines = file.readlines()
		for x in lines:
			line=x.strip().split("=")
			if (line[0]=="PRETTY_NAME"):
				distro=line[1].split(" ")[0].replace('"','')[0:12]
			if (line[0]=="VERSION_ID"):
				version=line[1][0:7].strip()

	title1 = distro +" " + arch
	title2 = "Version " + version

	##turn off red drive leds
	test.cmd_set_led(libmicon.LED_OFF,[0x00,0x0F])

	test.set_lcd_buffer(0x90,title1,title2)
	test.cmd_force_lcd_disp(libmicon.lcd_disp_buffer0)
	test.send_write_cmd(1,libmicon.lcd_set_dispitem,0x20)
	test.set_lcd_brightness(libmicon.LCD_BRIGHT_FULL)

	if (micon_version.find("HTGL") == -1):
		test.set_lcd_color(libmicon.LCD_COLOR_GREEN)

	test.cmd_set_led(libmicon.LED_ON,libmicon.POWER_LED)

	test.port.close()

##try reading micon version from each port to determine the right one
for port in ["/dev/ttyS1"]:
	try:
		test = libmicon.micon_api(port)
	except:
		continue
	micon_version = test.send_read_cmd(0x83)
	if micon_version:
		test.port.close()
		startupV2(port)
		quit()
	test.port.close()

quit()
