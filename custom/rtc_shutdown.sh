#!/bin/bash

###just ls-ql so far, I think.
###could use tests that it actually exists etc?

if [ "$1" == "halt" ] || [ "$1" == "poweroff" ]; then
    i2cset -y -f 0 0x32 0xB0 0x43
else
    i2cset -y -f 0 0x32 0xB0 0x18
fi

exit 0
