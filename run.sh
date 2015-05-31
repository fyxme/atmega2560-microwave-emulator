#!/bin/bash


# get the usb port >> 
# ls /dev/ | grep tty.usbmodem

cleanUp() {
    rm *.lst *.err > /dev/null 2>&1
}

# check that at least 1 argument has been suplied
if [ $# -eq 0 ]
  then
    echo "No arguments supplied."
    echo "How to use : ./run <file.asm>"
    exit 1
fi

if [ "$1" == clean ]
then
    echo "Cleaning files."
    echo "..."
    cleanUp
    echo "Cleaning process finished."
    exit 1
fi


# Assemble code >>
echo '------------------------------------------------------------------------------'
echo '-------------------------------Assembling code.-------------------------------'
echo '------------------------------------------------------------------------------'
wine ./lib/avrasm2.exe -I ./lib/include -fI $1 -o test.hex
echo '------------------------------------------------------------------------------'
echo '--------------------------------Code Assembled--------------------------------'
echo '------------------------------------------------------------------------------'


# run hex file on board >> 
echo '------------------------------------------------------------------------------'
echo '--------------------------Sending hex file to board.--------------------------'
echo '------------------------------------------------------------------------------'
avrdude -c stk500v2 -p m2560 -P /dev/tty.usbmodem1421 -u -U flash:w:test.hex:i -F -D -b 115200
echo '------------------------------------------------------------------------------'
echo '---------------------------.hex file sent to board----------------------------'
echo '------------------------------------------------------------------------------'

# remove all error files as they will be displayed on the terminal window
echo '------------------------------------------------------------------------------'
echo '---------------------------Removing unwanted files----------------------------'
echo '------------------------------------------------------------------------------'
cleanUp
echo '------------------------------------------------------------------------------'
echo '---------------------------Unwanted files removed.----------------------------'
echo '------------------------------------------------------------------------------'