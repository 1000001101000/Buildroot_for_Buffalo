#!/usr/bin/python3

import libmicon
import time
import sys


def shutdownV2(port):
	test = libmicon.micon_api(port)
	micon_version = test.send_read_cmd(0x83)

	micon_version=micon_version.decode('utf-8')

	if sys.argv[1] in ["halt","poweroff"]:
		#test.set_lcd_brightness(libmicon.LCD_BRIGHT_OFF)
		test.cmd_set_led(libmicon.LED_OFF,[0x00,0x07])
		test.send_write_cmd(0,0x06)
		test.send_write_cmd(1,0x46,0x18)
		test.send_write_cmd(0,0x0E)
	else:
		test.set_lcd_buffer(0x90,"Restarting...   ","               ")
		test.cmd_force_lcd_disp(libmicon.lcd_disp_buffer0)
		test.send_write_cmd(1,0x35, 0x00)
		test.send_write_cmd(0,0x03)
		test.send_write_cmd(0,0x0C)

	time.sleep(2)
	test.port.close()

for port in ["/dev/ttyS1"]:
	try:
		test = libmicon.micon_api(port)
	except:
		continue
	micon_version = test.send_read_cmd(0x83)
	if micon_version:
		test.port.close()
		shutdownV2(port)
		quit()
	test.port.close()

quit()
