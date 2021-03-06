# AVR programming ATMega2560 - Microwave emulator project

Code written as part of COMP2121 - Microprocessors and Interfacing at UNSW Australia.

website url: https://webcms3.cse.unsw.edu.au/COMP2121/
course url: https://www.handbook.unsw.edu.au/undergraduate/courses/2019/COMP2121/

The objective was to write a Microwave emulator that had certain functionalities as decribed in project.pdf

Pseudo code as well as user manual can be seen further down.

# Installation

It uses `wine` to compile code and `avrdude` to flash it. Look at `run.sh` for further information on how to execute.

# A non exhaustive list of the features

>> Time display
    -- 1 minute 15 seconds should be displayed as '01:15'.

>> Number keys
    -- in entry mode allows the time to be displayed
        >> max == 99:59 (99 minutes 59 seconds)
        >> min == 00:01 (1 second)

>> Start button
    >> '1234567890' -- numbers input
    >> '*' -- start button
        >> if no value entered --> 1 minute

>> Stop button


>> More/Less buttons
    >> 'C' adds 30 seconds
    >> 'D' subs 30 seconds

>> Open and Close buttons
    

-- Entry mode 
    >> Default mode - the cooking time can be entered and menus accessed to configure microwave

-- Running mode
    >> Active and cooking food

-- Pause mode
    >> Part-way through cooking food

-- Finished mode
    >> Cooking has been completed

-- FUNCTIONS
    > timer function
    > key presses function
        >> max_input == 4 keys
            >> ignore other button presses
    > button presses function
    > mod function
    > display board
    > motorspin function

-- REGISTER
    mode = r16
    key_pressed = r17
    past_rotate_direction = r18 // 1 = clockwise && 2 = anti-clockwise
    spin_percentage = r19 // 1 - 100%, 2 - 50%, 3 - 25%
    door_is_open = r20 // closed by default

## Pseudo code

ENTRY MODE :
    // if door is open :
        // wait for user to close door_is_open
    // while input != * :
        // get input here from board
        // if numbers input 
            // store them in registers
        // elsif 'A' input -- power level selection
            // display Set Power 1/2/3'
            // wait until the '1', '2', '3' or '#' key is pressed
                // ('1', '2' and '3' >>  100%, 50% or 25%) && (# >> cancel input)
        // elsif # input :
            // clr entry time
        // elsif * input
            // if num == 0 :
                // set num = 1 minute
            // goto RUNNING MODE

RUNNING MODE :
    // set the timers to be equal to the input times from entry mode
    STARTROTATE:
    // while timers > 0 :
        // display time every second
        // spin motor
        // if time_running == 5 seconds
            // display.turntable rotate
        // if 'C' input :
            // try add 30 seconds to timer >> time cannot be more than 99:59
        // elsif 'D' input :
            // try remove 30 seconds to timer 
        // elsif '#' input :
            // goto pause
        // elsif '*' input :
            // add 1 minute
        // if button.isPressed() :
            // if open button input :
                // go to pause mode
    // go to finished mode


PAUSE MODE :
    // pause the timer
    // while 1 :
        // if (door_is_open == false) :
            // if '*' input :
                // keep counting down
            // elsif '#' input :
                // cancel time
                // return to entry mode
    // restore the timer
    // goto STARTROTATE

FINISHED MODE :
    // display 'DONE' on first level
    // display 'Remove Food' on second level
    // while 1 :
        // if '#' input or open door input :
            // goto entry mode



A hard copy of your user manual. The user manual describes how a user uses your
microwave emulator, including how to wire up the AVR lab board. Make sure you indicate
which buttons perform each action and how the LED and LCD displays should be interpreted.

User Manual :
CONGRATULATIONS ON BUYING THE MICROWAVE ULTIMATE LEGEND PRO PLUS 2.0!!!!!!!!!!!!!!!!!!!!!!
we already have your money so please do not bother us with complaints.


DISPLAY : # 16 x 2 display
C or O needed bottom right at all times
turntable to be displayed in the top right of the lcd at all times >> turntable ==  '-', '/', '|' or '\' 

>> ENTRY
;-==================-
;||00:01          -||
;||               C||
;-==================-

; timer, rotation, open/closed

>> RUNNING
-==================-
||00:01          |||
||               C||
-==================-

; timer, rotation, open/closed

>> PAUSED
-==================-
||00:01          \||
||               O||
-==================-

; timer, rotation, open/closed

>> FINISHED
-==================-
||Done           /||
||Remove food    C||
-==================-

; rotation, open/closed, message

>> POWER_SELECTION
-==================-
||Set Power      -||
||1/2/3          C||
-==================-

; rotation, open/closed, message


LEDS : All connected except second topmost
if Open
    topmost led on
else 
    topmost led off

lower 8 leds >> display power

TIMER :
>> for every second that passes we'll have to check for the turntable rotation

>> Turntable rotation :  the turntable should rotate at 3 revolutions per minute. ; to fix
        >> 1 rev every 20 sec
            >> 8 states >> 1 state every 2.5 seconds -- 250 miliseconds
    >> Each time the microwave is started, the turntable should rotate in the opposite direction to the previous run.
    >> Solution : turntable counter -- when it reaches 5 it changes the current state of the turntable based on the past_rotation


