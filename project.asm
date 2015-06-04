.include "m2560def.inc"

;
; MODES
;
.def mode = r23 ;

.equ ENTRY_MODE = 1 ;
.equ RUNNING_MODE = 2 ;
.equ PAUSE_MODE = 3 ;
.equ FINISH_MODE = 4 ;
.equ POWER_SELECTION_MODE = 5 ;

;
; LCD 
;
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.def LCD_DISPLAY = r16 ; LCD display

;
; KEYPAD
;
.def row = r20 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan

.equ PORTLDIR = 0xF0 ; PD7-4: output, PD3-0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F ; for obtaining input from Port D

.def debounceFlag = r12
.def key_pressed = r2 ; value for key inputted

;
; MOTOR
;
.def spin_percentage = r8 ; 1 - 100%, 2 - 50%, 3 - 25%

;
; TIMERS
;
.def ent_sec = r13 ; number of minutes entered
.def ent_min = r14 ; number of seconds entered

;
; TURNTABLE
;
.def turntable_state = r11 ; Current state of the turntable
.def curr_rotate_direction = r3 ; 1 = clockwise && 2 = anti-clockwise
.def rotate_time_count = r10 ; number of seconds for the turnable >> when this reaches 250 turntable rotates

.equ TRN_STATE_1 = 1 ; State = '-' ascii = 45
.equ TRN_STATE_2 = 2 ; State = '/' ascii = 47
.equ TRN_STATE_3 = 3 ; State = '|' ascii = 124
.equ TRN_STATE_4 = 4 ; State = '\' ascii = 92

.equ CLOCKWISE = 0
.equ COUNTER_CLOCKWISE = 1

;
; Other variables
;
.def temp1 = r21
.def temp2 = r22
.def door = r9 ; Current State of the door //  closed by default

.equ OPEN = 1
.equ CLOSED = 0

.equ TRUE = 1
.equ FALSE = 0

;
; Macros 
;
.macro callINT
		mov temp1, debounceFlag
		cpi temp1, 0
		breq Debounced
		reti
	Debounced:
		ldi temp1, 1
		add debounceFlag, temp1
		clear debounceCounter
.endmacro
.macro clear
		ldi YL, low(@0)
		ldi YH, high(@0)
		clr temp1
		st Y+, temp1
		st Y, temp1
.endmacro
.macro do_lcd_command
	ldi LCD_DISPLAY, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi LCD_DISPLAY, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

.macro do_lcd_data_reg
	mov LCD_DISPLAY, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

; display multiple blank space
.macro display_blank
	push temp1
	ldi temp1, @0
	BLANK_LOOP:
		cpi temp1, 0
		breq END_BLANK_LOOP
		do_lcd_data ' '
		subi temp1, 1
		rjmp BLANK_LOOP
	END_BLANK_LOOP:
	pop temp1
.endmacro

.macro no_entered_input
	mov temp1, ent_sec
	cpi temp1, 0
	brne RET_FALSE
	mov temp1, ent_min
	cpi temp1, 0
	brne RET_FALSE

	ldi @0, TRUE ; return true
	rjmp END_NO_ENTERED_INPUT
	RET_FALSE:
	ldi @0, FALSE ; return false
	END_NO_ENTERED_INPUT:
.endmacro

.macro display_second_line
	; R/W and R/S are already 0.
	do_lcd_command 0b10101000  ; Set DD address to 40 (start of second line).
.endmacro

; display turntable based on current turntable_state
.macro display_turntable
	push temp1
	push temp2
	mov temp1, turntable_state
	
	cpi temp1, TRN_STATE_1
	breq DISP_T_1

	cpi temp1, TRN_STATE_2
	breq DISP_T_2

	cpi temp1, TRN_STATE_3
	breq DISP_T_3

	cpi temp1, TRN_STATE_4
	breq DISP_T_4

	DISP_T_1:
		do_lcd_data 45  ; State = '-' ascii = 45
		rjmp END_DISP_TURN

	DISP_T_2:
		do_lcd_data 47  ; State = '/' ascii = 47
		rjmp END_DISP_TURN

	DISP_T_3:
		do_lcd_data 124 ; State = '|' ascii = 124
		rjmp END_DISP_TURN

	DISP_T_4:
		; ldi temp1, 92
		; do_lcd_data_reg  ; State = '\' ascii = 92
		; backslash ascii not supported therefore use our
		; own created backslash which has been saved in 0
		do_lcd_data 0

	END_DISP_TURN:
	pop temp1
	pop temp2
.endmacro

.macro convert_seconds_to_minutes
	; check if max minutes >> if it is max -> useless to convert
	mov temp1, ent_min
	cpi temp1, 99 ; 99 = max number of minutes
	breq END_CSTM
	; if seconds < 60 dont do anything
	mov temp1, ent_sec
	cpi temp1, 60
	brlt END_CSTM
	
	; remove 60 seconds
	subi temp1, 60
	mov ent_sec, temp1
	; add 1 minute
	ldi temp1, 1
	add ent_min, temp1
	
	END_CSTM:
.endmacro

; display lcd data based on a 2 digits number
.macro display_lcd_data_reg
	push temp1
	push temp2
	; count ten's in reg
	mov temp1, @0 ; temp1 holds num of ent minutes
	ldi temp2, 0  ; temp2 holds num of tens of minutes
	TENS_LOOP:
		cpi temp1, 10
		brlt END_TENS_LOOP

		subi temp1, 10 ; remove 10 minutes	
		subi temp2, -1 ; add 1 to tens count

		rjmp TENS_LOOP
	END_TENS_LOOP:

	; get the ascii value for temp2 and temp1
	subi temp1, -'0'
	subi temp2, -'0'

	; display ten's
	do_lcd_data_reg temp2
	; display units
	do_lcd_data_reg temp1
	pop temp1
	pop temp2
.endmacro

.macro display_door_state
	push temp1
	mov temp1, door
	cpi temp1, OPEN
	breq DISP_DOOR_OPEN
	; door is closed
	do_lcd_data 'C'
	rjmp DISP_DOOR_END
	DISP_DOOR_OPEN :
		do_lcd_data 'O'
	DISP_DOOR_END:
	pop temp1
.endmacro

;
; Init variables : door and turntable not present 
; since we want to reuse this macro when the # key is pressed
;
.macro initialise_variables
	push temp1
	ldi temp1, 0
	mov ent_sec, temp1
	mov ent_min, temp1
	ldi temp1, ENTRY_MODE ; initialise mode // initial mode = 1 aka ENTRY_MODE
	mov mode, temp1
	ldi temp1, 1
	mov spin_percentage, temp1 ; 100 % speed at begining
	pop temp1
.endmacro

;
; Adds as many seconds as possible based on argument
;
.macro add_max_sec
	push temp1
	mov temp1, ent_sec
	ldi temp2, @0 ; max sec to add // used as counter

	ADD_MAX_SEC_LOOP:
		cpi temp2, 1 ; counter is done
		brlt END_ADD_MAX_SEC_LOOP
		cpi temp1, 99 ; check if max number of seconds
		brge END_ADD_MAX_SEC_LOOP
		inc temp1 ; add 1 to number of seconds
		subi temp2, 1 ; decrease count by 1
		rjmp ADD_MAX_SEC_LOOP
	END_ADD_MAX_SEC_LOOP:

	mov ent_sec, temp1
	
	pop temp1
.endmacro

;
; Remove as many seconds as possible based on argument
;
.macro remove_max_sec
	push temp1
	push temp2
	mov temp1, ent_sec ; current number of seconds // 59
	ldi temp2, @0 ; counter
	REMOVE_MAX_SEC_LOOP:
		cpi temp2, 0 ; counter is done // counter == 0 >> stop
		breq END_REMOVE_MAX_SEC_LOOP
		cpi temp1, 1 ; check if min number of seconds // current == 1 sec >> stop
		breq END_REMOVE_MAX_SEC_LOOP
		subi temp1, 1 ; reduce by 1 sec // current--
		subi temp2, 1 ; decrease count by 1 // count--
		rjmp REMOVE_MAX_SEC_LOOP
	END_REMOVE_MAX_SEC_LOOP:
	mov ent_sec, temp1
	pop temp1
	pop temp2
.endmacro

.macro rotate_turntable
	push temp1
	; every 250 ms
	; rotate turntable
	mov temp1, rotate_time_count
   	cpi temp1, 3 ; 3 s
   	brne NOT_TIME_TO_ROTATE

   	clr rotate_time_count

   	; check current rotation state
   	mov temp1, curr_rotate_direction
   	cpi temp1, CLOCKWISE
   	breq ROTATE_CLOCK

   	mov temp1, turntable_state
   	inc temp1

   	; check if < 5 // highest possible state is equal to 4
   	cpi temp1, 5
   	brlt END_ROTATE
   	; went over 4 therefore go back to 1
   	ldi temp1, 1
   	rjmp END_ROTATE

   	ROTATE_CLOCK:
	mov temp1, turntable_state
   	dec temp1
   	; check if < 1 // lowest possible state
   	cpi temp1, TRN_STATE_1
   	brge END_ROTATE
   	; temp1 equal to 0
   	; go to 4 // max state
   	ldi temp1, 4
   	END_ROTATE:
   	mov turntable_state, temp1
   	NOT_TIME_TO_ROTATE:
   	ldi temp1, 1
   	add rotate_time_count, temp1; inc rotate_time_counter
    pop temp1
.endmacro

;
; Timer macros
;
.macro CountDownSec
	;Decreases the stored time by 1 second
	push temp1
	push temp2
	mov temp1, @0
	cpi temp1, 0 ;Check if time is ZERO
	brne DecSeconds

	rjmp CountDownEnd

	DecSeconds:
		subi temp1, 1
		rjmp CountDownEnd
	CountDownEnd:
		mov @0, temp1
		pop temp2
		pop temp1
.endmacro		
.macro CountDownMin
	;Decreases the stored time by 1 min
	push temp1
	push temp2
	
	mov temp1, @0
	cpi temp1, 0 ;Check if time is ZERO
	brne DecSeconds

	ldi mode, FINISH_MODE ; Go into 'finished' mode if time is zero
	rjmp CountDownEnd

	DecSeconds:
		subi temp1, 1
		rjmp CountDownEnd
	CountDownEnd:
		mov @0, temp1
		pop temp2
		pop temp1
.endmacro	
.macro delay2 ; ~@0 us - micro seconds
    push temp1
    push temp2
    in temp1, SREG
    push temp1

    ldi temp1, low(@0 << 1)
    ldi temp2, high(@0 << 1)

delayLoop:
	subi temp1, 1
	sbci temp2, 0
	nop
    nop
    nop
    nop
	brne delayLoop

    pop temp1
    out SREG, temp1
    pop temp2
    pop temp1
.endmacro
.macro bigDelay ; ~@0 ms - miliseconds
    push temp1
    push temp2
    in temp1, SREG
    push temp1

    ldi temp1, low(@0)
    ldi temp2, high(@0)

bigDelayLoop:
	subi temp1, 1
	sbci temp2, 0
    delay2 1000 ; ~1 ms
	brne bigDelayLoop

    pop temp1
    out SREG, temp1
    pop temp2
    pop temp1
.endmacro

.dseg
TimerCounter:
	.byte 1
DebounceCounter: ; count to 0.1 second
	.byte 2

.cseg
	.org 0x0000
		jmp RESET
	.org INT0addr
		jmp EXT_INT0
	.org INT1addr
		jmp EXT_INT1
	.org OVF0addr
		jmp TimerOverflow

RESET:
	; reset keypad
	ldi temp1, low(RAMEND) ; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	ldi temp1, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1

	; Reset LEDs
	ser temp1
	out DDRC, temp1
	out DDRB, temp1
	clr temp1
	out PORTB, temp1
	
	; reset lcd
	ldi LCD_DISPLAY, low(RAMEND)
	ldi LCD_DISPLAY, high(RAMEND)
	ser LCD_DISPLAY
	out DDRF, LCD_DISPLAY
	out DDRA, LCD_DISPLAY
	clr LCD_DISPLAY
	out PORTF, LCD_DISPLAY
	out PORTA, LCD_DISPLAY

	ldi temp1, CLOSED ; door starts as close
	mov door, temp1

	ldi temp1, TRN_STATE_1 ; initial turntable state
	mov turntable_state, temp1

	clr rotate_time_count
	ldi temp1, CLOCKWISE
	mov curr_rotate_direction, temp1

	; Reset Door Buttons
	; set INT0, INT1
	ldi temp1, 1 << INT0
	ori temp1, 1 << INT1
	out EIMSK, temp1

	; Reset timer
	ldi temp1, 0b00000000
	out TCCR0A, temp1				;Initialise timer 0
	ldi temp1, 0b00000101
	out TCCR0B, temp1				;Pre-scale to 1024
	ldi temp1, 1<<TOIE0				;Enable overflow interrupts
	sts TIMSK0, temp1

	sei

	rcall build_bslash ; replace ascii value 0 with a backslash

	; Display stuff according to mode
	rcall DISPLAY_FROM_MODE

	; Display power on LEDs and open/closed on topmost
	rcall LED_DISPLAY

INIT_VAR:
	initialise_variables 
	clr debounceFlag
	; Make motor run if necessary
		; check if in correct mode
			; if so run motor according to power
			; otherwise do nothing

BEFORE:
	; Display stuff according to mode
	rcall DISPLAY_FROM_MODE

	; Display power on LEDs and open/closed on topmost
	rcall LED_DISPLAY
	rjmp main
DEBOUNCE_BUTTON_CLEAR:
	clr debounceFlag

MAIN:

	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column

	clr key_pressed

	colloop:
		cpi col, 4
		breq DEBOUNCE_BUTTON_CLEAR ; If all keys are scanned, repeat.
		sts PORTL, cmask ; Otherwise, scan a column.
		ldi temp1, 0xFF ; Slow down the scan operation.

	delay:
		dec temp1
		brne delay
		lds temp1, PINL ; Read PORTL ; CHECK
		andi temp1, ROWMASK ; Get the keypad output value
		cpi temp1, 0xF ; Check if any row is low
		breq nextcol ; If yes, find which row is low
		ldi rmask, INITROWMASK ; Initialize for row check
		clr row  ; 

	rowloop:
		cpi row, 4
		breq nextcol ; the row scan is over.
		mov temp2, temp1
		and temp2, rmask ; check un-masked bit
		brne continueRow
		mov temp1, debounceFlag
		cpi temp1, 0
		breq convert ; if bit is clear, the key is pressed
		jmp main ; so we don't read to col 4 and reset debounceFlag

	continueRow:
		inc row ; else move to the next row
		lsl rmask
		jmp rowloop
	nextcol: ; if row scan is over
		lsl cmask
		inc col ; increase column value
		jmp colloop ; go to the next column

	convert:
		ldi temp1, 1 ; a button is not yet released
		mov debounceFlag, temp1

		; check if door is open // if so don't accept any input
		; has to be placed here otherwise when we open/close the door again
		; the row scan will catch 3 input after it has closed
		ldi temp1, OPEN
		cp door, temp1
		breq MAIN

		cpi col, 3 ; If the pressed key is in col.3
		breq letters ; we have a letter
		; If the key is not in col.3 and
		cpi row, 3 ; If the key is in row3,
		breq symbols ; we have a symbol or 0
		mov temp1, row
		; Otherwise we have a number in 1-9
		lsl temp1
		add temp1, row
		add temp1, col ; key_pressed = row*3 + col
		subi temp1, -'1' ; Add the value of character ‘1’
	  	subi temp1, '0' ; transfer ASCII value to integer value
		
		mov key_pressed, temp1

	numbers:
		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq NUMBER_ENTRY_JUMP

		; check if in POWER_SELECTION_MODE
		cpi mode, POWER_SELECTION_MODE
		breq POWER_SELECTION_SELECT_JUMP

		jmp main ; not used by other modes

		NUMBER_ENTRY_JUMP:
			jmp NUMBER_ENTRY

		POWER_SELECTION_SELECT_JUMP:
			jmp POWER_SELECTION_SELECT

	letters:
		ldi temp1, 'A'
		add temp1, row ; Get the ASCII value for the key
		mov key_pressed, temp1

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq LETTERS_ENTRY_JUMP

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq LETTERS_RUNNING_JUMP

		jmp main ; not used for other modes

		LETTERS_ENTRY_JUMP:
			jmp LETTERS_ENTRY

		LETTERS_RUNNING_JUMP:
			jmp LETTERS_RUNNING

	symbols:
		cpi col, 0 ; Check if we have a star
		breq star
		cpi col, 1 ; or if we have zero
		breq zero
	
	hash :
		ldi temp1, '#' ; if not we have hash
		mov key_pressed, temp1

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq HASH_ENTRY_JUMP

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq HASH_RUNNING_JUMP

		; check if PAUSE_MODE
		cpi mode, PAUSE_MODE
		breq HASH_PAUSE_JUMP

		; check if FINISH_MODE
		cpi mode, FINISH_MODE
		breq HASH_FINISH_JUMP

		; check if POWER_SELECTION_MODE
		cpi mode, POWER_SELECTION_MODE
		breq POWER_SELECTION_CANCEL_JUMP

		jmp main ; not used for other modes

		HASH_ENTRY_JUMP:
			jmp HASH_ENTRY
		HASH_RUNNING_JUMP:
			jmp HASH_RUNNING
		HASH_PAUSE_JUMP:
			jmp HASH_PAUSE
		HASH_FINISH_JUMP:
			jmp HASH_FINISH
		POWER_SELECTION_CANCEL_JUMP:
			jmp POWER_SELECTION_CANCEL

	star:
		ldi temp1, '*' ; Set to star
		mov key_pressed, temp1

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq STAR_ENTRY_JUMP

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq STAR_RUNNING_JUMP

		; check if PAUSE_MODE 
		cpi mode, PAUSE_MODE
		breq STAR_PAUSE_JUMP

		jmp main ; not used for other modes

		STAR_ENTRY_JUMP:
			jmp STAR_ENTRY
		STAR_RUNNING_JUMP:
			jmp STAR_RUNNING
		STAR_PAUSE_JUMP:
			jmp STAR_PAUSE

	zero:
		ldi temp1, '0' ; Set to zero
		subi temp1, '0' ; transfer ASCII value to integer value
		mov key_pressed, temp1

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq ZERO_ENTRY_JUMP

		jmp main ; not used for other modes

		ZERO_ENTRY_JUMP:
			jmp NUMBER_ENTRY

	convert_end:
		; DO SOMETHING WITH KEY PRESSED HERE
		jmp DEBOUNCE_BUTTON_CLEAR ; Restart main loop


;
; Displays the required amount of LEDS
;
LED_DISPLAY:

	push temp1
	mov temp1, door

	ldi ZL, 0b00000000 ; door light off // closed

	cpi temp1, CLOSED
	breq LED_DISPLAY_DOOR_CLOSED
	ldi ZL, 0b11111111 ; door light on // open

	LED_DISPLAY_DOOR_CLOSED:
		
	mov temp1, spin_percentage

    ldi YL, 0b11111111 
    cpi temp1, 1 ; 100 % // 1
    breq LED_DISPLAY_END

    ldi YL, 0b00001111 ; 50%
    cpi temp1, 2 ; 50 % // 2
    breq LED_DISPLAY_END

    ldi YL, 0b00000011 ;  25% // 3


LED_DISPLAY_END:
    out PORTC, YL ; output motor percentage to led
    out PORTB, ZL ; output door state
    pop temp1
    ret

;
; Displays whatever is needed according to the given mode 
;
DISPLAY_FROM_MODE:
	
	; reset the display
	rcall RESET_DISPLAY

	cpi mode, FINISH_MODE
	breq DISPLAY_FINISH_MODE_JUMP

	cpi mode, POWER_SELECTION_MODE
	breq DISPLAY_POWER_SELECTION_MODE_JUMP

	jmp DISPLAY_ENTRY_RUNNING_PAUSE_MODE

	DISPLAY_FINISH_MODE_JUMP:
		jmp DISPLAY_FINISH_MODE

	DISPLAY_POWER_SELECTION_MODE_JUMP:
		jmp DISPLAY_POWER_SELECTION_MODE

	DISPLAY_ENTRY_RUNNING_PAUSE_MODE:
		;-==================-
		;||00:01          -||
		;||               C||
		;-==================-

		; check if min and sec = 0
			; if so display nothing

		no_entered_input temp1

		cpi temp1, TRUE
		brne NO_INPUT_YET

		display_blank 15

		jmp DISPLAY_THE_REST

		NO_INPUT_YET:
		display_lcd_data_reg ent_min
		do_lcd_data ':'
		display_lcd_data_reg ent_sec

		display_blank 10

		DISPLAY_THE_REST:

		display_turntable

		display_second_line

		; mov temp1, mode
		; ldi temp2, 'A'
		; add temp1, temp2
		; subi temp1, 1
		; do_lcd_data_reg temp1 ; DEBUGGING // display the current mode

		display_blank 15 ; put back to 15 when done DEBUGGING

		display_door_state

		jmp DISPLAY_OVER

	DISPLAY_FINISH_MODE:
		;-==================-
		;||Done           /||
		;||Remove food    C||
		;-==================-

		do_lcd_data 'D'
		do_lcd_data 'o'
		do_lcd_data 'n'
		do_lcd_data 'e'

		display_blank 11

		display_turntable

		display_second_line

		do_lcd_data 'R'
		do_lcd_data 'e'
		do_lcd_data 'm'
		do_lcd_data 'o'
		do_lcd_data 'v'
		do_lcd_data 'e'
		do_lcd_data ' '
		do_lcd_data 'F'
		do_lcd_data 'o'
		do_lcd_data 'o'
		do_lcd_data 'd'

		display_blank 4

		display_door_state

		jmp DISPLAY_OVER

	DISPLAY_POWER_SELECTION_MODE:
		;-==================-
		;||Set Power      -||
		;||1/2/3          C||
		;-==================-
		
		do_lcd_data 'S'
		do_lcd_data 'e'
		do_lcd_data 't'
		do_lcd_data ' '
		do_lcd_data 'P'
		do_lcd_data 'o'
		do_lcd_data 'w'
		do_lcd_data 'e'
		do_lcd_data 'r'

		display_blank 6

		display_turntable

		display_second_line

		do_lcd_data '1'
		do_lcd_data '/'
		do_lcd_data '2'
		do_lcd_data '/'
		do_lcd_data '3'

		display_blank 10

		display_door_state

		jmp DISPLAY_OVER


DISPLAY_OVER:
	ret


ENTRY :
	LETTERS_ENTRY :
		mov temp1, key_pressed
		cpi temp1, 'A'
		breq SWITCH_MODE_PWRLVL_JUMP
		jmp main

		SWITCH_MODE_PWRLVL_JUMP:
			jmp SWITCH_MODE_PWRLVL

	HASH_ENTRY : 
		; clr all variables except door open/closed and turntable
		jmp INIT_VAR

	STAR_ENTRY :
			mov temp1, ent_sec
			cpi temp1, 0 ; if the number of seconds is 0
			brne time_inputted
			mov temp1, ent_min
			cpi temp1, 0 ; if the number of minutes is not 0
			brne time_inputted ; start the engines!!!
			ldi temp1, 1 ; else add 1 minute
			mov ent_min, temp1 ; store it in entered number of minutes

		TIME_INPUTTED : 
			jmp SWITCH_MODE_RUNNING

	NUMBER_ENTRY :
	push temp1
	push temp2

	; take input until a number reaches 10s of minutes
	mov temp1, ent_min
	cpi temp1, 10
	brge INVALID_INPUT

	; count number of 10s of seconds
	ldi temp1, 0 		; temp1 holds the number of tens seconds
	mov temp2, ent_sec  ; temp2 holds the number of seconds remainings t2 < 10

	COUNT_SEC:
		cpi temp2, 10
		brlt END_COUNT_SEC
		subi temp1, -1 ; increase the numbers of tens
		subi temp2, 10 ; substract 10 to the number of seconds
		jmp COUNT_SEC
	END_COUNT_SEC:

	clr ent_sec ; clear the number of seconds so we don't add over past values.

	add ent_sec, temp2 ; set to number of seconds remaining // 00:0a where a is the number of seconds

	ldi temp2, 10

	mul ent_sec, temp2 ; multiply by 10 // 00:a0 where a is the number of seconds

	mov ent_sec, r0 ; set ent_sec to the result of the multiplication

	mul ent_min, temp2 ; multiply number of minutes so we can shift the 10s of seconds up

	mov ent_min, r0 ; set ent_sec to the result of the multiplication

	add ent_min, temp1 ; shift number of 10s of seconds to units of minutes // SS:S0 -- S represents a value that is now set

	add ent_sec, key_pressed ; add the value of the key pressed to the count // SS:Sa -- a is where the value of the key pressed is put

	pop temp1
	pop temp2

INVALID_INPUT:
	jmp BEFORE

RUNNING :
	LETTERS_RUNNING :
 	mov temp1, key_pressed

 	; // if 'C' input :
 	;      // try add 30 seconds to timer >> time cannot be more than 99:59
 	cpi temp1, 'C'
 	breq ADD_SECONDS_TO_TIMER

 	; // elsif 'D' input :
 	;      // try remove 30 seconds to timer 
 	cpi temp1, 'D'
 	breq REMOVE_SECONDS_FROM_TIMER

 	jmp main ; all other input ignored

 	ADD_SECONDS_TO_TIMER :
 	; convert seconds to minutes
 		; this is to account for user entry with seconds over 60
 	convert_seconds_to_minutes

 	; check if seconds < 30
 	mov temp1, ent_sec
 	cpi temp1, 30
 	brlt DO_ADD_SEC

 	DO_REMOVE_SEC:
 		; check if max_minutes
 		mov temp1, ent_min
 		cpi temp1, 99
 		breq DO_ADD_SEC
 			; if not max
 				; add 1 minute
 				; do ent_sec - 30
 		ldi temp1, 1
 		add ent_min, temp1
 		mov temp1, ent_sec
 		subi temp1, 30
 		mov ent_sec, temp1
 	END_DO_REMOVE_SEC:
 		jmp BEFORE

 	DO_ADD_SEC:
 		; check if max minutes
 		mov temp1, ent_min
 		cpi temp1, 99
 		brne DO_ADD_SEC_NOT_MAX

 		; add a max of 30 seconds
 		add_max_sec 30

 		jmp BEFORE
		; else
			; do ent_sec + 30
	DO_ADD_SEC_NOT_MAX:
		ldi temp1, 30
		add ent_sec, temp1
 		jmp BEFORE

 	REMOVE_SECONDS_FROM_TIMER :
 		; convert seconds to minutes
 		; this is to account for user entry with seconds over 60
 		convert_seconds_to_minutes

 		mov temp1, ent_min
 		cpi temp1, 0 ; 0 minutes
 		breq RSFT_MAX_SEC

 		; check if ent_sec >= 30
 		mov temp1, ent_sec
 		cpi temp1, 30
 		brge RSFT_REMOVE_SEC

 		; remove 1 minute
 		mov temp1, ent_min
 		subi temp1, 1
 		mov ent_min, temp1

 		; add 60 sec to sec counter
 		ldi temp1, 60
 		add ent_sec, temp1

 		; remove 30 seconds
 		RSFT_REMOVE_SEC:

 		mov temp1, ent_sec
 		subi temp1, 30 
 		mov ent_sec, temp1

 		jmp BEFORE

 		RSFT_MAX_SEC:

 		remove_max_sec 30 ; remove a maximum of 30 seconds if possible

 		jmp BEFORE

	HASH_RUNNING :
		; // elsif '#' input :
		;    // goto pause
		jmp SWITCH_MODE_PAUSE

	STAR_RUNNING :
		; // elsif '*' input :
    	;   // add 1 minute
    	mov temp1, ent_min
    	cpi temp1, 99 ; check if max number of minutes
    	breq END_STAR_RUNNING ; if so dont add the minute
    	inc temp1
    	mov ent_min, temp1
    END_STAR_RUNNING:
		jmp BEFORE


PAUSE : 
	HASH_PAUSE :
		; cancel time
		; return to entry mode
		; aka. reset all variables except door
		jmp INIT_VAR

	STAR_PAUSE :
		; return to running mode
		jmp SWITCH_MODE_RUNNING


FINISH :
	HASH_FINISH :
	; return to entry mode
	; aka. reset all variables except door
	jmp INIT_VAR


POWER_SELECTION : 
	POWER_SELECTION_SELECT :
		mov temp1, key_pressed
		cpi temp1, 1 ; check if 1 inputted // 100 % -- 8 LEDs Lit
		breq ADJUST_POWER_100
		cpi temp1, 2 ; check if 2 inputted // 50% -- 4 LEDs Lit
		breq ADJUST_POWER_50
		cpi temp1, 3 ; check if 3 inputted // 25% -- 2 LEDs Lit
		breq ADJUST_POWER_25

	POWER_SELECTION_CANCEL :
		jmp END_POWER_SELECT

	ADJUST_POWER_100 : 
		; adjust spin_percentage to 1
		ldi temp1, 1
		jmp END_ADJUST
	ADJUST_POWER_50 :
		; adjust spin_percentage to 2
		ldi temp1, 2
		jmp END_ADJUST
	ADJUST_POWER_25 :
		; adjust spin_percentage to 3
		ldi temp1, 3
	END_ADJUST:
		mov spin_percentage, temp1
	END_POWER_SELECT:
		; change Mode back to entry
		jmp SWITCH_MODE_ENTRY

;
; SWITCH between all modes 
;
SWITCH_MODE : 
	SWITCH_MODE_PWRLVL :
		ldi mode, POWER_SELECTION_MODE
		jmp BEFORE

	SWITCH_MODE_ENTRY :
		ldi mode, ENTRY_MODE
		jmp BEFORE

	SWITCH_MODE_PAUSE :
		ldi mode, PAUSE_MODE
		jmp BEFORE

	SWITCH_MODE_RUNNING :
		ldi mode, RUNNING_MODE
		; change current rotate state
		mov temp1, curr_rotate_direction
		cpi temp1, CLOCKWISE ; if not clockwise
		brne CHANGE_TO_CLOCK ; change to clockwise

		ldi temp1, COUNTER_CLOCKWISE ; otherwise change to anti-clockwise
		mov curr_rotate_direction, temp1
		jmp BEFORE

		CHANGE_TO_CLOCK:

		ldi temp1, CLOCKWISE
		mov curr_rotate_direction, temp1
		jmp BEFORE

	SWITCH_MODE_FINISH :
		ldi mode, FINISH_MODE
		jmp BEFORE


;
; OPEN AND CLOSE DOOR BUTTONS INTERRUPTS
;
EXT_INT0: ; open door
	callINT

	mov temp1, door
	cpi temp1, OPEN
	breq ALREADY_OPEN

	; check mode
	cpi mode, RUNNING_MODE
	brne NOT_RUNNING_MODE

	ldi mode, PAUSE_MODE
	jmp END_DOOR_OPEN
	
	NOT_RUNNING_MODE:
	cpi mode, FINISH_MODE
	brne END_DOOR_OPEN

	ldi temp1, OPEN
	mov door, temp1

	initialise_variables ; go back to entry_mode // reset variables

	; update both the LCD and LED Displays
	rcall DISPLAY_FROM_MODE
	rcall LED_DISPLAY 

	reti

	END_DOOR_OPEN:
		ldi temp1, OPEN
		mov door, temp1

	; update both the LCD and LED Displays
	rcall DISPLAY_FROM_MODE
	rcall LED_DISPLAY 

	ALREADY_OPEN:
		reti

EXT_INT1: ; close door
	callINT

	mov temp1, door
	cpi temp1, CLOSED
	breq ALREADY_CLOSED

	; simply close door
	ldi temp1, CLOSED
	mov door, temp1

	; update both the LCD and LED Displays
	rcall DISPLAY_FROM_MODE
	rcall LED_DISPLAY

	ALREADY_CLOSED:
		reti

backToSixty_JUMP:
	jmp backToSixty
OneSecond:
	; Code that executes once every second goes here
	mov temp1, ent_sec
	cpi temp1, 0
	breq backToSixty_JUMP
	CountDownSec ent_sec ; countdown the number of seconds
	Refresh:
	bigDelay 1000 ; 1 sec delay
	rotate_turntable
	rcall DISPLAY_FROM_MODE
	jmp TimerEnd
	BackToSixty:
		CountDownMin ent_min ; go down a minute
		ldi temp1, 60
		mov ent_sec, temp1 ; sec number of seconds to 60
		jmp OneSecond

OneSecond_JUMP:
	jmp OneSecond
TimerOverflow:   ; timer overflow interrupt comes here
	cpi mode, RUNNING_MODE
	breq START_TIMER
	reti ; the timer is paused in every mode except RUNNING_MODE
START_TIMER:
	push temp1
	in temp1, SREG
	push temp1
	push Yl
	push Yh
	
	ldi Yh, high(TimerCounter)
	ldi Yl, low(TimerCounter)
	ld temp1, Y
	cpi temp1, 61
	breq OneSecond_JUMP
	inc temp1
	st Y, temp1

	TimerEnd:
		pop Yh
		pop Yl
		pop temp1
		out SREG, temp1
		pop temp1
		reti

;
; Reset dipslay
;
RESET_DISPLAY:

	; clear display
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	ret

;
; Send a command to the LCD (LCD_DISPLAY)
;
lcd_command:
	out PORTF, LCD_DISPLAY
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret
lcd_data:
	out PORTF, LCD_DISPLAY
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret
lcd_wait:
	push LCD_DISPLAY
	clr LCD_DISPLAY
	out DDRF, LCD_DISPLAY
	out PORTF, LCD_DISPLAY
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in LCD_DISPLAY, PINF
	lcd_clr LCD_E
	sbrc LCD_DISPLAY, 7
	jmp lcd_wait_loop
	lcd_clr LCD_RW
	ser LCD_DISPLAY
	out DDRF, LCD_DISPLAY
	pop LCD_DISPLAY
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

build_bslash:
	do_lcd_command  0b01000000
	do_lcd_data 0b00000
	do_lcd_data 0b10000
	do_lcd_data 0b01000
	do_lcd_data 0b00100
	do_lcd_data 0b00010
	do_lcd_data 0b00001
	do_lcd_data 0b00000
	do_lcd_data 0b00000
ret