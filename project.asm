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
.def past_rotate_direction = r3 ; 1 = clockwise && 2 = anti-clockwise

.equ TRN_STATE_1 = 1 ; State = '-' ascii = 45
.equ TRN_STATE_2 = 2 ; State = '/' ascii = 47
.equ TRN_STATE_3 = 3 ; State = '|' ascii = 124
.equ TRN_STATE_4 = 4 ; State = '\' ascii = 92

;
; Other variables
;
.def temp1 = r21
.def temp2 = r22
.def door = r9 ; Current State of the door //  closed by default

.equ OPEN = 1
.equ CLOSED = 0

;
; Macros 
;
.macro callINT
		cpi debounceFlag, 0
		breq Debounced
		reti
	Debounced:
		inc debounceFlag
		clear debounceCounter
.endmacro
.macro clear
		ldi YL, low(@0)
		ldi YH, high(@0)
		clr temp
		st Y+, temp
		st Y, temp
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
		do_lcd_data 92  ; State = '\' ascii = 92

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

.dseg
;	MinuteCounter: ; total number of minutes
;		.byte 2
;	SecondCounter:	; total number of seconds
;		.byte 2
;	TempCounter:	; count to 1 second
;		.byte 2
;	DebounceCounter:; count to 0.1 second
;		.byte 2

.cseg
BEGIN:
	; reset keypad
	ldi temp1, low(RAMEND) ; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	ldi temp1, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1
	ser temp1 ; PORTC is output
	out DDRC, temp1
	
	;reset lcd
	ldi LCD_DISPLAY, low(RAMEND)
	;out SPL, LCD_DISPLAY
	ldi LCD_DISPLAY, high(RAMEND)
	;out SPH, LCD_DISPLAY
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

INIT_VAR:
	initialise_variables 

BEFORE:
	; Display stuff according to mode
	rcall DISPLAY_FROM_MODE

	; Display power on LEDs and open/closed on topmost
	rcall LED_DISPLAY


	; Make motor run if necessary
		; check if in correct mode
			; if so run motor according to power
			; otherwise do nothing

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

    ; TODO : Output door is open or closed

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

		display_lcd_data_reg ent_min
		do_lcd_data ':'
		display_lcd_data_reg ent_sec

		display_blank 10

		display_turntable

		display_second_line

		mov temp1, mode
		ldi temp2, 'A'
		add temp1, temp2
		subi temp1, 1
		do_lcd_data_reg temp1 ; DEBUGGING // display the current mode

		display_blank 14 ; put back to 15 when done

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
	ldi temp1, 0 ; temp1 holds the number of tens seconds
	mov temp2, ent_sec ; temp2 holds the number of seconds remainings t2 < 10

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

	; TODO : Door pause
	; check if door is open before you check the timer or even input
	; if door is open
		; if not in pause mode: 
			; go to pause mode
	;;;; This would mean we don't require to change anything else

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
		jmp BEFORE

	SWITCH_MODE_FINISH :
		ldi mode, FINISH_MODE
		jmp BEFORE


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