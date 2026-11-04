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

CODESEG

PROC main
    ; Initialize the graphics environment and ensure string operations move in
    ; the expected direction.
    sti
    cld

    push ds
    pop es


    call getElement, 4, 4
	mov bl, 00010000b
	movzx ebx, bl
	AND ebx, eax
	;call checkRookMovement, ebx, 4, 4
	;call printBoard, offset movement
	
	mov ah,0h		; wait for keystroke
    int 16h
    call setVideoMode, 13h
    ; call fillBackground, 0

    call draw_board, offset board
    mov ah, 00h
    int 16h
    ;call draw_move_highlight, offset movement
    ;mov ah, 00h
    ;int 16h
    mov [byte ptr board+4], 00100000b
    call draw_board, offset board

    mov ah, 00h
    int 16h
    call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG


    stack 100

END main
