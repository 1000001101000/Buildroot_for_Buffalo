#!/usr/bin/python3

import libmicon
import sys
import configparser
import os
import subprocess
import time

config_file="/etc/micon_fan.conf"
fan_type=sys.argv[1]
micon_port=sys.argv[2]

####some function for finding/enabling the relavant pwm devices.

def getHDDtemp():
	##can we check if drive is sleeping and skip? or otherwise prevent waking up drives to check temps?
	##maybe setup a process to spread out checks?
	##also avoid iscsi/etc?
	output = subprocess.check_output('''hddtemp /dev/sd? 2> /dev/null | cut -d: -f 3 | sort -h | tail -1 | cut -d\  -f 2''', shell=True)
	if output:
		return (int(output.splitlines()[0].decode('utf-8')))
	else:
		return False

def setMiconPWM(value):
	##wrap the variations and just take
	##if mconv2 send whatever value corresponds to %
	##if hwmon gpio or otherwise should be 0-255, quick divide, easy enough
	if (fan_type == "miconv3"):
		micondev = libmicon.micon_api_v3(micon_port)
		micondev.send_miconv3("FAN_SET 1 "+ str(value))
		micondev.port.close()

config = configparser.ConfigParser()
if os.path.exists(config_file):
	config.read(config_file)
else:
	config['FanConfig'] = {'MinPWM': '10', 'MaxPWM': '100', 'MinTemp': '28', 'MaxTemp': '45', 'Interval' : '10', 'Debug': '0'}
	with open(config_file, 'w') as configfile:
		config.write(configfile)

minpwm=int(config['FanConfig']['MinPWM'])
maxpwm=int(config['FanConfig']['MaxPWM'])
mintemp=int(config['FanConfig']['MinTemp'])
maxtemp=int(config['FanConfig']['MaxTemp'])
debug=int(config['FanConfig']['Debug'])
interval=int(config['FanConfig']['Interval'])

###check logic of min<max...etc

pwmsteps=maxpwm-minpwm
tempsteps=maxtemp-mintemp
ratio=pwmsteps/tempsteps

pwm=minpwm
setMiconPWM(pwm)

while True:
	temp = getHDDtemp()
	if temp == False:
		print("no drives?")
		time.sleep(60)
		continue

	if debug:
		print("Temp: "+str(temp))

	oldpwm = pwm

	if temp >= maxtemp:
		pwm = maxpwm
	elif temp <= mintemp:
		pwm = minpwm
	else:
		pwm = int(minpwm + ratio*(temp-mintemp))

	if debug:
		print ("PWM: "+str(pwm))

	if pwm != oldpwm:
		setMiconPWM(pwm)

	time.sleep(interval)
###catch interrupt? generally how should openrc/etc stop it?
quit()

