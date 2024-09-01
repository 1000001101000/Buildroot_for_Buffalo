#!/usr/bin/python3

import sys

result=0
with open(sys.argv[1], "rb") as f:
	while (byte := f.read(1)):
		result+=int.from_bytes(byte, "little")
result=result%int(0x100000000)
print(hex(result))
