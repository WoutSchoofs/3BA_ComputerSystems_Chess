; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	N/A
; date:		N/A
; program:	N/A
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG		

; Set the video mode
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

; Terminate the program.
PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

PROC printUnsignedInteger
	ARG @@num:dword
	USES eax, ebx, ecx, edx
	
	mov eax, [@@num]
	mov ebx, 10
	xor ecx, ecx
	
	@@getNextDigit:
		inc	ecx
		xor edx, edx
		div	ebx
		push dx
		test eax, eax
		jnz	@@getNextDigit
	
		mov	ah, 2h
	@@printDigits:		
		pop dx
		add	dl,'0'
		int	21h
		loop @@printDigits
		
		mov	dl, 0Dh		; Carriage return.
		int	21h
		mov	dl, 0Ah		; New line.
		int 21h
		
		ret
ENDP printUnsignedInteger

; Geeft de memory adress terug op basis van de gegeven coordinaten
PROC getOffset
	ARG @@row:dword, @@col:dword RETURNS eax
	
	mov eax, [@@row]
	sal eax, 3 ; vermenigvuldiging met 8
	add eax, [@@col]
	add eax, offset board
	
	ret
ENDP getOffset

; Geeft het stuk dat op dat vak is, anders geeft het een 0 als vak leeg is en een 1 als vak buiten het bord is
PROC getElement
	ARG @@row:dword, @@col:dword RETURNS eax
	USES ebx
	
	; Controle of de gegeven indices
	cmp [@@row], 0
	jl @@outOfBounds
	cmp [@@row], 7
	jg @@outOfBounds
	cmp [@@col], 0
	jl @@outOfBounds
	cmp [@@col], 7
	jg @@outOfBounds
	
	; geraakt door de controles, we zitten inderdaad op het bord
	call getOffset, [@@row], [@@col]

	mov ebx, eax
	xor eax, eax
	mov al, [ebx]
	jmp @@endOfFunction
	
	@@outOfBounds:
		mov eax, 1
	
	@@endOfFunction:
	ret
ENDP getElement

; Beweegt een element van een positie naar een andere en laat een 0 achter
PROC moveElement
	ARG @@fromRow:dword, @@fromCol:dword, @@toRow:dword, @@toCol:dword
	USES eax, ebx, ecx, edx
	
	call getOffset, [@@fromRow], [@@fromCol]
	mov ebx, eax
	mov cl, [ebx]
	call getOffset, [@@toRow], [@@toCol]
	mov [eax], cl
	mov [byte ptr ebx], 0
	
	ret
ENDP moveElement

PROC loopTest
	ARG @@loopNbr:dword
	USES ebx, ecx
	
	mov ecx, [@@loopNbr]
	@@testing:
		mov ebx, [@@loopNbr]
		sub ebx, ecx
		call printUnsignedInteger, ebx
		loop @@testing
	
	ret
ENDP loopTest

	
PROC main
	sti
	cld
	
	push ds
	pop	es
	
	call setVideoMode,13h
	
	; Testen voor het verplaatsen van een element
	call getElement, 1, 1
	call printUnsignedInteger, eax
	call getElement, 1, 2
	call printUnsignedInteger, eax
	call moveElement, 1, 1, 1, 2
	call getElement, 1, 1
	call printUnsignedInteger, eax
	call getElement, 1, 2
	call printUnsignedInteger, eax
	
	; Testen voor het returnen van een 1 i/h  geval van buiten het bord te zijn
	call getElement, -1, 2
	call printUnsignedInteger, eax
	call getElement, 8, 2
	call printUnsignedInteger, eax
	call getElement, 1, -2
	call printUnsignedInteger, eax
	call getElement, 1, 9
	call printUnsignedInteger, eax
	
	; Test om een loop te hebben dat van 0 naar 4 gaat ipv 5 naar 1
	call loopTest, 5
	
	mov ah,0h		; wait for keystroke
    int 16h
	call terminateProcess
ENDP main

start:
	call main

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	board db 01000000b, 00100000b, 0, 0, 0, 0, 00110000b, 01010000b, 01100000b, 00100000b, 0, 0, 0, 0, 00110000b, 01110000b, 10000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10010000b, 10100000b, 00100000b, 0, 0, 0, 0, 00110000b, 11010000b, 11000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10110000b, 10000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10010000b, 01100000b, 00100000b, 0, 0, 0, 0, 00110000b, 01110000b, 01000000b, 00100000b, 0, 0, 0, 0, 00110000b, 01010000b
		

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
