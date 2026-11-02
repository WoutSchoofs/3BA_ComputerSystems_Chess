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
	call checkTowerMovement, ebx, 4, 4
	;call printBoard, offset movement
	
	mov ah,0h		; wait for keystroke
    int 16h
    call setVideoMode, 13h
    ; call fillBackground, 0

    call set_up_board

    ; Wait for a key, then erase the pawn from its starting square.
    mov ah, 00h
    int 16h
    call draw_move, 4, 6, 4, 4, offset pawn_sprite, WHITE
    mov ah, 00h
    int 16h
    call draw_move, 4, 1, 4, 3, offset pawn_sprite, BLACK
    mov ah, 00h
    int 16h
    call draw_move_highlight, offset movement
    mov ah, 00h
    int 16h
    call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG


    stack 100

END main
