#!/usr/bin/python3

import libmicon
import time
import sys

action=sys.argv[1]
port=sys.argv[2]
ver=sys.argv[3]

print("Signal ",action,port,ver)

if (ver == "2"):
	test = libmicon.micon_api(port)
	micon_version = test.send_read_cmd(0x83)
	micon_version=micon_version.decode('utf-8')

	##I guess make sure watchdog in known state.
	##then shutdown wait... copying from various gpl sources. 
	test.send_write_cmd(1,0x35, 0x00) ##watchdog
	test.send_write_cmd(0,0x03) ## boot_end
	test.send_write_cmd(0,0x0C) ##shutdown_wait

	if action in ["halt","poweroff"]:
		match=0
		test.set_lcd_brightness(libmicon.LCD_BRIGHT_OFF)
		test.set_lcd_buffer(0x90,"             ","             ")
		test.cmd_force_lcd_disp(libmicon.lcd_disp_buffer0)
		test.cmd_set_led(libmicon.LED_OFF,[0x00,0x07])
		test.send_write_cmd(1,0x46,0x43) ##MagicKeyHwPoff
		if (micon_version.find("TS-XEL") != -1):
			match=1
			test.send_write_cmd(1,0x46,0x00) ##clear power setting
			test.send_write_cmd(0,0x0E) ##reboot
		if (micon_version.find("TS1400") != -1):
			match=1
			test.send_write_cmd(0,0x12) ##ups_linefail_on?
		if (match==0):
			test.send_write_cmd(0,0x06) ##power_off
	else:
		test.set_lcd_buffer(0x90,"Restarting...   ","               ")
		test.cmd_force_lcd_disp(libmicon.lcd_disp_buffer0)
		test.send_write_cmd(1,0x46,0x18) ##MagicKeyReboot
		test.send_write_cmd(1,0x35, 0x00) ##set watchdog
		test.send_write_cmd(0,0x0E)  ##reboot

if (ver == "3"):
	test = libmicon.micon_api_v3(port)
	for i in range(16):
		test.set_led(i, "off")
	test.send_miconv3("LCD_CLR")
	if action in ["halt","poweroff"]:
		test.send_miconv3("POWER_OFF")
	else:
		test.send_miconv3("REBOOT")

time.sleep(2)
test.port.close()
