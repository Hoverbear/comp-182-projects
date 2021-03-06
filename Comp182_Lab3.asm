*
*  IR_sen.asm - an IR proximity sensor for the Ep2711E9 Rev. C board
*               (c)2003, EVBplus.com, Written By Wayne Chu
*
*      Modified by: Andrew Hobden, Patrick Brus
*
*     Function:	A robot application by using the IR light beam to detect
*		an object in its vicinity.
*
*     Instruction: The PD1 will be reset to low to enable the IR transmitter.
*		   The IR light beam will be bounced back by an object,
*		   so the IR receiver will receive the IR light via PD0 and
*		   display the result on the LCD display module.
*
*		   Sometime the table surface can reflect the light.
*		   For the best result, place the board near the edge of the
*		   table to reduce the reflection by the table surface.
*		   Two T1 red LEDs near the IR transceiver will indicate
*		   its status.  After running the program, make sure that
*		   the TX LED is on and the RX LED is off without an object
*		   in the front of them.  If your body is too close to them,
*		   it also will reflect the IR light, so stay 1 foot away
*		   from them. When the RX LED is off, then put your hand
*		   in the front of them and read the LCD display.

*		   The range is about 6-10 inches and can be increased by
*		   reducing the resister R11s value, but it should not be
*		   smaller than 100 Ohm.
*
portd:		equ	8
ddrd:		equ	9
REGBLK:		equ	$1000
TEN_MS:		equ	2500		; 2500 x 8 cycles = 20,000 cycles = 10ms
*
STACK:		equ	$FF
*
              	org     $0800		; EVBplus2 board I/O routines
rs485_recv:     rmb     3		; Enables rs485 recv mode
rs485_xmit:     rmb     3		; Enables rs485 xmit mode
get_date:       rmb     3		; Gets current date from PTC
get_time:       rmb     3		; Gets current time from PC
outstrg00:	rmb	3		; Outputs a string terminated by 0
lcd_ini:	rmb	3		; Initializes the 16x2 LCD module
lcd_line1:	rmb	3		; Displays 16 char on the first line
lcd_line2:	rmb	3		; Displays 16 char on the second line
sel_inst:	rmb	3		; Selects instruction before writing LCD module
sel_data:	rmb	3		; Selects data before writing the LCD module
wrt_pulse:	rmb	3		; Generates a write pulse to the LCD module
*
*
		org	$F000
		jmp	start
bcd:            fcb     0,0       	; Reserves 2 byte for bcd
bcdlength:	equ	2		; length of bcd in bytes
ASCIILength:    equ     4               ; Length of the ASCII output

delay_10ms:
		pshx
		ldx     #TEN_MS		; 2500 x 8 = 20,000 cycles = 10ms
del1:		dex			; 3 cycles, decrement register x
		nop			; 2 cycle
		bne	del1		; 3 cycles
		pulx
       		rts
*
start:		lds	#STACK
   		jsr	delay_10ms	; Delay 20ms during power up
    		jsr	delay_10ms
		ldx	#REGBLK
		ldaa	#2
		staa	ddrd,x		; PD0=input, PD1=output
		clr	portd,x		; Make PD1=0 to xmit IR light
    		jsr	lcd_ini		; Initialize the LCD

back:		ldaa	portd+$1000
		rora			; Rotate PD0 into carry bit
		bcs	no_IR_light     ; Branch if carry set
		ldx    	#MSG2		; MSG2 for line1, x points to MSG2
        	ldab    #16             ; Send out 16 characters
     		jsr	lcd_line1	; Print MSG2 to LCD line 1
*
     		ldab    #bcdlength       ; Loads the B register with 4
		ldx	#bcd		; Sets to bcd for subroutine
		jsr     BCDinc		; Increment the BCD by one and adjust as needed.
*
		ldx     #ASCIIbuff	; Loading position of MSG3 where numerical digits display.
		ldy     #bcd            ; Loading the bcd buffer.
		ldab	#ASCIILength	; Loading the number of BCD digits there are.
		jsr     ASCIIInsert	; Stepping through inserts of Digits onto the display buffer.
*
     		ldx    	#MSG3		; MSG3 for line2, x points to MSG3
        	ldab    #16             ; Send out 16 characters
     		jsr	lcd_line2	; Print MSG3 to LCD line 2
     		jsr     delay_10ms	; Take a short break!
     		jsr     delay_10ms	; Take a short break!
     		jmp	back		; Reloop.

* Inputs:
*		x = message to append to,
*		y = the bcd buffer,
*		B = the number of digits
*
ASCIIInsert:	pshx			; Pushing all buffers for safety concerns.
		pshy
		psha
		pshb
		ldab    #bcdlength      ; Load the BCD
		iny                     ; Get to the right byte.
*
ASCIILoop:	LDAA	0,y		; Loading BCD byte. (2 digits per byte)
		ANDA	#%00001111	; Remove second digit within the bye.
		ADDA	#$30		; Convert to ASCII.
		STAA	0,x		; Store within first digit of display buffer.
		LDAA	0,y		; Reload the BCD byte so we can pull the second digit of the byte.
		LSRA			; Logical Shifting so we can access the last 4 bytes and form a byte.		; 1st
		LSRA			; 									; 2nd
		LSRA			; 									; 3rd
		LSRA			; 									; 4th
		ADDA	#$30		; Converting the digit into ASCII code.
		DEX			; Moving too next digit in display buffer.
		STAA	0,x		; Writing bcd bytes.
		DEY			; Changing BCD byte.
		DEX			; Mark completed display buffer digit.
		DECB			; Mark completed BCD pair, move to next byte.
		BNE	ASCIILoop	; If B is not zero, return to begining of loop.
*
ASCIIEnd:       pulb
		pula
		puly
		pulx
		rts			; Return to subroutine.

* Provided call.
no_IR_light:
		ldx    	#MSG1		; MSG1 for line1, x points to MSG1
       		ldab    #16             ; send out 16 characters
    		jsr	lcd_line1	; Write to display buffer.
    		jsr     BCDClear        ; Clear the BCD
     		jsr	delay_10ms	; Take a break, twice!
     		jsr	delay_10ms
     		jmp	back

* Inputs:
*		x = BCDbuffer address,
*		b = Length in bytes of BCDBuff
*
BCDinc:		psha			; Push and go.
		pshx
		pshb
		abx			; Add the BCDBuff length to the address (End of smallest digit.)
		dex			; Get to the BCDbuff location we want (Right before last byte/digit-pair)
*
BCDloop:	ldaa	0,x		; Load the byte (2 digits) so we can work with it.
		ADDA	#1		; Increment the byte.
		daa			; Allow the proc to adjust for us to get a proper BCD.
		staa	0,x		; Restore the byte to it's location.
		bcc	BCDfinish	; C=0? We're done, step to finished.
*					; C=1? We need to move across more digits.
		dex			; Change x to address next largest byte.
		decb			; Reduce length by 1 so we don't overrun (We check this next step)
		bne	BCDloop		; Z=0? Continue looping.
*					; Z=1? We're done else we overrun.
*
BCDfinish:	pulb
		pulx
		pula
		rts			; Clean up and return

BCDClear:       PSHX
		LDX     #bcd            ; Loading the place of the BCD into X register
		bclr    0,x     $FF     ; Clearing all the bits in the largest pair of BCD numbers
		inx                     ; Incrementing X so we can get to the next pair
		BCLR    0,x     $FF     ; Clearing the smallest pair of BCDs
		PULX
		RTS                     ; Returning home

MSG1:   	FCC     "NO OBJECT NEARBY"
MSG2:   	FCC     "OBJECT DETECTED "
MSG3:   	FCC     "Count:          "
ASCIIbuff:	equ	#MSG3+15 ; Gets us to the desired "drop point"
       		org	$FFFE
     		fdb	start
       		end

