#!/usr/bin/python3

import libmicon
import platform
import sys

port=sys.argv[1]
ver=sys.argv[2]

print("Micon Start ",port,ver)

arch=platform.machine()[:3].upper()

with open("/etc/os-release", "r") as file:
	lines = file.readlines()
	for x in lines:
		line=x.strip().split("=")
		if (line[0]=="PRETTY_NAME"):
			distro=line[1].split(" ")[0].replace('"','')[0:12]
		if (line[0]=="VERSION_ID"):
			version=line[1][0:11].strip()

title1 = distro +" " + arch
title2 = "Ver " + version

if (ver == "2"):
	test = libmicon.micon_api(port)

	title1 = title1.center(16)
	title2 = title2.center(16)

	micon_version = test.send_read_cmd(0x83)
	micon_version=micon_version.decode('utf-8')

	##disable boot watchdog
	test.send_write_cmd(0,0x03)

	##enable serial console on supported devs
	test.send_write_cmd(0,0x0F)
	test.send_write_cmd(0,0x0F)

	##turn off red drive leds
	test.cmd_set_led(libmicon.LED_OFF,[0x00,0x0F])

	test.set_lcd_buffer(0x90,title1,title2)
	test.cmd_force_lcd_disp(libmicon.lcd_disp_buffer0)
	test.send_write_cmd(1,libmicon.lcd_set_dispitem,0x20)
	test.set_lcd_brightness(libmicon.LCD_BRIGHT_FULL)

	if (micon_version.find("HTGL") == -1):
		test.set_lcd_color(libmicon.LCD_COLOR_GREEN)

	test.cmd_set_led(libmicon.LED_ON,libmicon.POWER_LED)

if (ver == "3"):
	test = libmicon.micon_api_v3(port)

	##disable watchdog
	test.send_miconv3("BOOT_END")

	title1 = title1.center(16,u"\u00A0")
	title2 = title2.center(16,u"\u00A0")

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
quit()

