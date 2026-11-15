; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	David Blinder, Stijn Bettens
; date:		23/10/2018
; program:	Video mode 13h
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "DRAWB.INC"
INCLUDE "PLOGIC.INC"
INCLUDE "CHESS.INC"
INCLUDE "MOUSE.INC"

CODESEG

PROC wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
ENDP wait_VBLANK


PROC main
    ; Initialize the graphics environment and ensure string operations move in
    ; the expected direction.
    sti
    cld

    push ds
    pop es

	call    mouse_present
    cmp     eax, 1
    je      @@mouse_present

    mov     ah, 9
    mov     edx, offset msg_no_mouse
    int     21h

@@mouse_present:
    call setVideoMode, 13h

	gameLoop:
	call wait_VBLANK, 1
	
	;Check program exit
	mov ah,01h		; check for keystroke
    int 16h
	jnz checkQuit
	
	;First draw board
	call draw_board, offset board
	
	
	
	; Temporary game loop, doesn't work properly, more a proof of concept than anything
	
	;TODO: if a piece is selected, move highlight should be drawn on top
	cmp [selected_flag], 1
	jne checkClick
	call draw_move_highlight, offset movement
	
	checkClick:
		;When input is needed, get the input and draw mouse
		call getMouseInput, 1
		call drawMouse, ecx, edx, 10,12, 11
		;Check for mouse press, if yes then move on to what you want to do with it
		cmp ebx, 1
		jnz gameLoop ;No mouse press, restart loop
		
		call calculateIndex, ecx, edx
		call getElement, ecx, edx
		
		cmp eax, 1
		je gameLoop
		
		cmp [selected_flag], 1
		je select_square
		
		;Check of het de beurt is van deze kleur
		mov bl, 00010000b
		movzx ebx, bl
		AND ebx, eax
		cmp ebx, [current_color]
		jne gameLoop
		
		; TODO: pass element to a function that determines which check should be performed
		mov bl, 00010000b
		movzx ebx, bl
		AND ebx, eax
		call checkRookMovement, ebx, ecx, edx
		mov [selected_flag], 1
		mov [selected_row], ecx
		mov [selected_col], edx
		jmp gameLoop
		
		select_square:
			call getMovementElem, ecx, edx
			cmp eax, 1
			jne stop_selection
			call moveElement, [selected_row], [selected_col], ecx, edx
			mov bl, 11111111b
			movzx ebx, bl
			xor [current_color], ebx
			
			stop_selection:
				call clearMovement, 1
				mov [selected_flag], 0
		
	; End of temporary game loop
	
	
		
	jmp gameLoop ;Logic is over, next frame can go
	
	checkQuit:
	mov ah, 00h
	int 16h
	cmp al, 27 ;Check if ESC is pressed
	jne gameLoop
	
	call mouse_uninstall
	call terminateProcess
	

    call draw_board, offset board
    mov ah, 00h
    int 16h
    call draw_move_highlight, offset movement
    mov ah, 00h
    int 16h
    mov [byte ptr board+4], 00100000b
    call draw_board, offset board

    mov ah, 00h
    int 16h
    call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG
msg_no_mouse    db 'No mouse found!', 0dh, 0ah, '$'

msg_test    db 'Test $'

current_color dd 00010000b

selected_flag db 0
selected_row dd -1
selected_col dd -1

; -------------------------------------------------------------------
stack 100

END main
