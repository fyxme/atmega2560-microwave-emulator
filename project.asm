.include "m2560def.inc"

; LCD 
.equ LCD_RS = 11
.equ LCD_E = 10
.equ LCD_RW = 9
.equ LCD_BE = 8

.def LCD_DISPLAY = r16 ; LCD display


; KEYPAD .def and .equ
.def row = r20 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan

.equ PORTLDIR = 0x0F ; PL7-4: input (cols), PL3-0, output (rows)
.equ INITCOLMASK = 0xFE ; scan from the rightmost column,
.equ INITROWMASK = 0x10 ; scan from the top row
.equ ROWMASK = 0xF0 ; for obtaining input from Port D

; MODES
.def mode = r1 ;

.equ ENTRY_MODE = 1;
.equ RUNNING_MODE = 2;
.equ PAUSE_MODE = 3;
.equ FINISH_MODE = 4;
.equ POWER_REQUEST_MODE = 5;


; Other variables
.def temp1 = r26
.def temp2 = r27
.def key_pressed = r2 ;
.def past_rotate_direction = r3 ; 1 = clockwise && 2 = anti-clockwise
.def spin_percentage = r4 ; 1 - 100%, 2 - 50%, 3 - 25%
.def door_is_open = r5 ; closed by default

.def ent_sec = r22
.def ent_min = r23
.def ent_count = r6

; Macros 
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
	ldi mode, ENTRY_MODE; initialise mode // initial mode = 1 aka ENTRY_MODE

RESET:
	; KEYPAD RESET
	ldi temp1, low(RAMEND) ; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	ldi temp1, PORTLDIR ; PL7:4/PL3:0, out/in
	sts DDRL, temp1
	ser temp1 ; PORTC is output
	out DDRC, temp1
	clr temp1
	out PORTC, temp1

	; LCD RESET
	ldi LCD_DISPLAY, low(RAMEND)
	out SPL, LCD_DISPLAY
	ldi LCD_DISPLAY, high(RAMEND)
	out SPH, LCD_DISPLAY

	ser LCD_DISPLAY
	out DDRF, LCD_DISPLAY
	out DDRA, LCD_DISPLAY
	clr LCD_DISPLAY
	out PORTF, LCD_DISPLAY
	out PORTA, LCD_DISPLAY

main:
	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column

	; get input from buttons
	; display LED
	; display screen
	; timer

	colloop:
		cpi col, 4
		breq main ; If all keys are scanned, repeat.
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
		breq convert ; if bit is clear, the key is pressed
		inc row ; else move to the next row
		lsl rmask
		jmp rowloop

	nextcol: ; if row scan is over
		lsl cmask
		inc col ; increase column value
		jmp colloop ; go to the next column

	convert:
		cpi col, 3 ; If the pressed key is in col.3
		breq letters ; we have a letter
		; If the key is not in col.3 and
		cpi row, 3 ; If the key is in row3,
		breq symbols ; we have a symbol or 0
		mov key_pressed, row
		; Otherwise we have a number in 1-9
		lsl key_pressed
		add key_pressed, row
		add key_pressed, col ; key_pressed = row*3 + col
		subi key_pressed, -'1' ; Add the value of character ‘1’

		subi key_pressed, '0' ; transfer ASCII value to integer value

	numbers:
		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq NUMBER_ENTRY

		; check if in POWER_SELECTION_MODE
		cpi mode, POWER_SELECTION_MODE
		breq POWER_SELECTION_SELECT

		rjmp main ; not used by other modes


	letters:
		ldi key_pressed, 'A'
		add key_pressed, row ; Get the ASCII value for the key


		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq LETTERS_ENTRY

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq LETTERS_RUNNING

		rjmp main ; not used for other modes

	symbols:
		cpi col, 0 ; Check if we have a star
		breq star
		cpi col, 1 ; or if we have zero
		breq zero
	
	hash :
		ldi key_pressed, '#' ; if not we have hash

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq HASH_ENTRY

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq HASH_RUNNING

		; check if FINISH_MODE
		cpi mode, FINISH_MODE
		breq HASH_FINISH

		; check if POWER_SELECTION_MODE
		cpi mode, POWER_SELECTION_MODE
		breq POWER_SELECTION_CANCEL

	star:
		ldi key_pressed, '*' ; Set to star

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq STAR_ENTRY

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq STAR_RUNNING

		; check if PAUSE_MODE // letters not used in PAUSE MODE
		cpi mode, PAUSE_MODE
		breq STAR_PAUSE

		; check if FINISH_MODE // letters not used in FINISH MODE
		cpi mode, FINISH_MODE
		breq STAR_FINISH

	zero:
		ldi key_pressed, '0' ; Set to zero

		subi key_pressed, '0' ; transfer ASCII value to integer value

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq NUMBER_ENTRY

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq NUMBER_RUNNING

		; check if PAUSE_MODE // letters not used in PAUSE MODE
		cpi mode, PAUSE_MODE
		breq NUMBER_PAUSE

		; check if FINISH_MODE // letters not used in FINISH MODE
		cpi mode, FINISH_MODE
		breq NUMBER_FINISH

	convert_end:
		; DO SOMETHING WITH KEY PRESSED HERE
		jmp main ; Restart main loop

ENTRY :
	LETTERS_ENTRY :
		cpi key_pressed, 'A'
		breq SWITCH_MODE_PWRLVL
		rjmp main

	HASH_ENTRY : 
		; clr entered time
		clr ent_sec 
		clr ent_min
		rjmp main


	STAR_ENTRY :
			cpi ent_sec, 0 ; if the number of seconds is 0
			brne time_inputted
			cpi ent_min, 0 ; if the number of minutes is 0
			brne time_inputted
			; add 1 minute
			ldi ent_min, 1 ; add 1 minute

		TIME_INPUTTED : 
			rjmp SWITCH_MODE_RUNNING

	NUMBERS_ENTRY :
	cpi ent_count, 0
	brne FIRST_NUMBER_INPUT_END

	; first number input can't be 0
	FIRST_NUMBER_INPUT :
	cpi key_pressed, 0
	breq main
	FIRST_NUMBER_INPUT_END :

	; if 4 numbers have been inputted go back to main
	cpi ent_count, 4
	breq main

	; multiply number of minutes by 10
	mul ent_min, 10

	; count number of 10s of seconds
	COUNT_SEC:
		ldi temp1, 0
		cpi ent_sec, 10
		brlt END_COUNT_SEC
		inc temp1
		rjmp COUNT_SEC
	END_COUNT_SEC:
	; temp1 holds the number of seconds

	; add the count to number of minutes
	add ent_min, temp1

	; multiply the number of seconds by 10
	mul ent_sec, 10

	; add the input
	add ent_sec, key_pressed

	; increase entered count
	add ent_count, 1

	rjmp main

RUNNING :
	LETTERS_RUNNING :



	rjmp main



PAUSE : 
	LETTERS_PAUSE :


	rjmp main





FINISH :
	LETTERS_FINISH :



	rjmp main



POWER_SELECTION : 
	POWER_SELECTION_SELECT :
		cpi pressed_key, 1 ; check if 1 inputted // 100 % -- 8 LEDs Lit
		breq ADJUST_POWER_100
		cpi pressed_key, 2 ; check if 2 inputted // 50% -- 4 LEDs Lit
		breq ADJUST_POWER_50
		cpi pressed_key ; check if 3 inputted // 25% -- 2 LEDs Lit
		breq ADJUST_POWER_25
		rjmp main

	POWER_SELECTION_CANCEL :

		rjmp main

	ADJUST_POWER_100 : 
		; adjust spin_percentage to 1
		rjmp main


	ADJUST_POWER_50 :
		; adjust spin_percentage to 2
		rjmp main

	ADJUST_POWER_25 :
		; adjust spin_percentage to 3
		rjmp main	



SWITCH_MODE : 
	SWITCH_MODE_PWRLVL :
		ldi mode, POWER_REQUEST_MODE
		rjmp main

	SWITCH_MODE_ENTRY :
		ldi mode, ENTRY_MODE
		rjmp main

	SWITCH_MODE_PAUSE :
		ldi mode, PAUSE_MODE
		rjmp main

	SWITCH_MODE_RUNNING :
		ldi mode, RUNNING_MODE
		rjmp main

	SWITCH_MODE_FINISH :
		ldi mode, FINISH_MODE
		rjmp main

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
	rjmp lcd_wait_loop
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


HALT : ; possibly not needed ? 
	rjmp HALT