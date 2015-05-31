.include "m2560def.inc"

; LCD 
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

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
.def mode = r23 ;

.equ ENTRY_MODE = 1;
.equ RUNNING_MODE = 2;
.equ PAUSE_MODE = 3;
.equ FINISH_MODE = 4;
.equ POWER_SELECTION_MODE = 5;

; Other variables
.def temp1 = r21
.def temp2 = r22
.def key_pressed = r2 ;
.def past_rotate_direction = r3 ; 1 = clockwise && 2 = anti-clockwise
.def spin_percentage = r8 ; 1 - 100%, 2 - 50%, 3 - 25%
.def door_is_open = r9 ; closed by default

.def ent_sec = r13 ; number of minutes entered
.def ent_min = r14 ; number of seconds entered
.def ent_count = r10

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


MAIN:
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

	; Display stuff according to mode
	rcall DISPLAY_FROM_MODE

	; Display power on LEDs

	; Make motor run if necessary
		; check if in correct mode
			; if so run motor according to power
			; otherwise do nothing

;
; Function that displays whatever is needed according to the given mode 
;
DISPLAY_FROM_MODE:
	cpi mode, ENTRY_MODE
	breq DISPLAY_ENTRY_MODE

	cpi mode, RUNNING_MODE
	breq DISPLAY_RUNNING_MODE

	cpi mode, PAUSE_MODE
	breq DISPLAY_PAUSE_MODE

	cpi mode, FINISH_MODE
	breq DISPLAY_FINISH_MODE

	cpi mode, POWER_SELECTION_MODE
	breq DISPLAY_POWER_SELECION_MODE

	DISPLAY_ENTRY_MODE:


	DISPLAY_RUNNING_MODE:


	DISPLAY_PAUSE_MODE:


	DISPLAY_FINSH_MODE:


	DISPLAY_POWER_SELECTION_MODE:

DISPLAY_OVER:
	ret

START_MAIN_LOOP:
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

		; check if PAUSE_MODE // letters not used in PAUSE MODE
		cpi mode, PAUSE_MODE
		breq STAR_PAUSE_JUMP

		; check if FINISH_MODE // letters not used in FINISH MODE
		cpi mode, FINISH_MODE
		breq STAR_FINISH_JUMP

		jmp main ; not used for other modes

		STAR_ENTRY_JUMP:
			jmp STAR_ENTRY
		STAR_RUNNING_JUMP:
			jmp STAR_RUNNING
		STAR_PAUSE_JUMP:
			jmp STAR_PAUSE
		STAR_FINISH_JUMP:
			jmp STAR_FINISH

	zero:
		ldi temp1, '0' ; Set to zero
		subi temp1, '0' ; transfer ASCII value to integer value
		mov key_pressed, temp1

		; check if in ENTRY_MODE
		cpi mode, ENTRY_MODE
		breq ZERO_ENTRY_JUMP

		; check if RUNNING_MODE 
		cpi mode, RUNNING_MODE
		breq NUMBER_RUNNING_JUMP

		; check if PAUSE_MODE // letters not used in PAUSE MODE
		cpi mode, PAUSE_MODE
		breq NUMBER_PAUSE_JUMP

		; check if FINISH_MODE // letters not used in FINISH MODE
		cpi mode, FINISH_MODE
		breq NUMBER_FINISH_JUMP

		jmp main ; not used for other modes

		ZERO_ENTRY_JUMP:
			jmp NUMBER_ENTRY
		NUMBER_RUNNING_JUMP:
			jmp NUMBER_RUNNING
		NUMBER_PAUSE_JUMP:
			jmp NUMBER_PAUSE
		NUMBER_FINISH_JUMP:
			jmp NUMBER_FINISH

	convert_end:
		; DO SOMETHING WITH KEY PRESSED HERE
		jmp main ; Restart main loop

ENTRY :
	LETTERS_ENTRY :
		mov temp1, key_pressed
		cpi temp1, 'A'
		breq SWITCH_MODE_PWRLVL_JUMP
		jmp main

		SWITCH_MODE_PWRLVL_JUMP:
			jmp SWITCH_MODE_PWRLVL

	HASH_ENTRY : 
		; clr entered time
		clr ent_sec 
		clr ent_min
		jmp main

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
	mov temp1, ent_count
	cpi temp1, 0
	brne FIRST_NUMBER_INPUT_END

	; first number input can't be 0
	FIRST_NUMBER_INPUT :
		mov temp1, key_pressed
		cpi temp1, 0
		breq INVALID_INPUT
	FIRST_NUMBER_INPUT_END :

	; if 4 numbers have been inputted go back to main
	mov temp1, ent_count
	cpi temp1, 4
	breq INVALID_INPUT

	; multiply number of minutes by 10
	ldi temp1, 10
	mul ent_min, temp1

	; count number of 10s of seconds
	COUNT_SEC:
		ldi temp1, 0
		mov temp2, ent_sec
		cpi temp2, 10
		brlt END_COUNT_SEC
		inc temp1
		jmp COUNT_SEC
	END_COUNT_SEC:
	; temp1 holds the number of seconds

	; add the count to number of minutes
	add ent_min, temp1

	; multiply the number of seconds by 10
	ldi temp1, 10
	mul ent_sec, temp1

	; add the input
	add ent_sec, key_pressed

	; increase entered count
	ldi temp1, 1
	add ent_count, temp1

INVALID_INPUT:
	jmp main

RUNNING :
	LETTERS_RUNNING :



	jmp main



PAUSE : 
	LETTERS_PAUSE :


	jmp main





FINISH :
	LETTERS_FINISH :



	jmp main



POWER_SELECTION : 
	POWER_SELECTION_SELECT :
		mov temp1, key_pressed
		cpi temp1, 1 ; check if 1 inputted // 100 % -- 8 LEDs Lit
		breq ADJUST_POWER_100
		cpi temp1, 2 ; check if 2 inputted // 50% -- 4 LEDs Lit
		breq ADJUST_POWER_50
		cpi temp1, 3 ; check if 3 inputted // 25% -- 2 LEDs Lit
		breq ADJUST_POWER_25
		jmp main

	POWER_SELECTION_CANCEL :

		jmp main

	ADJUST_POWER_100 : 
		; adjust spin_percentage to 1
		jmp main


	ADJUST_POWER_50 :
		; adjust spin_percentage to 2
		jmp main

	ADJUST_POWER_25 :
		; adjust spin_percentage to 3
		jmp main	



SWITCH_MODE : 
	SWITCH_MODE_PWRLVL :
		ldi mode, POWER_SELECTION_MODE
		jmp main

	SWITCH_MODE_ENTRY :
		ldi mode, ENTRY_MODE
		jmp main

	SWITCH_MODE_PAUSE :
		ldi mode, PAUSE_MODE
		jmp main

	SWITCH_MODE_RUNNING :
		ldi mode, RUNNING_MODE
		jmp main

	SWITCH_MODE_FINISH :
		ldi mode, FINISH_MODE
		jmp main


;
; Reset dipslay
;
RESET_DIPSLAY:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

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

GO_TO_SECOND_LINE:
	; R/W and R/S are already 0.
	do_lcd_command 0b10101000  ; Set DD address to 40 (start of second line).
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

HALT : ; possibly not needed ? 
	jmp HALT