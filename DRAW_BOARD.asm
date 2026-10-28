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

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

; -------------------------------------------------------------------
CODESEG

; Set the video mode
PROC setVideoMode
	ARG @@VideoMode:byte
	mov AL, [@@VideoMode]
	mov ah, 00
	int 10h
	ret
ENDP setVideoMode

; create a gradient palette
PROC DRAW_SQUARE
    ARG @@column:dword, @@row:dword
	USES EAX, EBX, EDI, ECX, EDX
    mov al, 6;load color brown
    add eax, [@@column]
    xor edx, edx;clear edx register
    mov edi,2;divide by 2 to check if even
    div edi 
    cmp edx,0;check remainder
    jne locate_square;if odd, keep black color
    mov al, 15;if even, if even, turn white
    locate_square:
    mov ecx, 25;we want to color one square, each square is 25*25
    mov ebx, ecx;we need to keep the width here so we can print the entire row of te square
    mov edi 0A0000h;move edi to the first pixel
    add edi, [@@row]*25*320;go to the correct row
    add edi, [@@column]*25;go to the correct column
    squareloop:
    mov edx, ecx;store outerloopvalue for ecx
    mov ecx, ebx;put the number of pixels in one row in ecx
    REP stosb
    mov ecx, edx;return outerloop value to ecx
    add edi 295;next row (+320-25)
    loop squareloop
ENDP DRAW_SQUARE

PROC main
	sti
	cld
	
	push ds
	pop	es

	call	setVideoMode,13h
	; call	fillBackground, 0
	
	call 	DRAW_SQUARE 0,0
	; call	updateColourPalette, 64
	; call	drawGradient
	
	; call	drawRectangle,60,60,60,60, 32
	; call	drawRectangle,80,80,100,100, 63
	; call	drawRectangle,1,1,SCRWIDTH-2,SCRHEIGHT-2, 48
	
	mov	ah,00h
	int	16h
	; (replace by) call	waitForSpecificKeystroke, 001Bh ; keycode for ESC
	
	call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG
	palette		db 768 dup (?)
stack 100

END start