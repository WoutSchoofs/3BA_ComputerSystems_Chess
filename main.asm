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

INCLUDE "CHESS.INC"

EXTRN setVideoMode:PROC
EXTRN terminateProcess:PROC
EXTRN set_up_board:PROC
EXTRN draw_move:PROC
EXTRN pawn_sprite:BYTE

CODESEG

PROC main
    ; Initialize the graphics environment and ensure string operations move in
    ; the expected direction.
    sti
    cld

    push ds
    pop es

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

@@discard_pending_keys:
    mov ah, 01h
    int 16h
    jz @@wait_for_key
    mov ah, 00h
    int 16h
    jmp @@discard_pending_keys

@@wait_for_key:
    mov ah, 00h
    int 16h
    ; Replace with a wait-for-ESC routine when one is available.

    call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG


    stack 100

END main
