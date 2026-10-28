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

; Video mode 13h framebuffer dimensions and base address.
VMEMADR EQU 0A0000h
SCRWIDTH EQU 320
SCRHEIGHT EQU 200

; -------------------------------------------------------------------
CODESEG

; Set the video mode using the BIOS video interrupt.
PROC setVideoMode
	ARG @@VideoMode:byte
	mov al, [@@VideoMode]
	mov ah, 00h
	int 10h
	ret
ENDP setVideoMode

; Draw one 25x25 square at the requested board coordinates.
PROC DRAW_SQUARE
    ARG @@column:dword, @@row:dword
	USES eax, ebx, ecx, edx, edi
	mov ecx, 25              ; Pixels written per scanline.
	mov ebx, ecx             ; Preserve the scanline width for each row.

	; Convert board coordinates to a byte offset in the framebuffer.
	mov edi, VMEMADR
    mov eax, [@@row]
	imul eax, eax, 8000      ; 25 board pixels * 320 screen pixels per row.
    add edi, eax
    add edi, 60
    mov eax, [@@column]
    imul eax, eax, 25
    add edi, eax

	; Alternate colors by the sum of the row and column coordinates.
    mov al, 6                ; Brown is the default for odd squares.
    mov edx, [@@row]
    add edx, [@@column]
    test edx, 1
	jnz squareloop           ; Odd squares keep the brown color (6).
	mov al, 90               ; Even squares are white.

    squareloop:
	mov edx, ecx             ; Save the remaining scanline count.
	mov ecx, ebx             ; STOSB count for this 25-pixel scanline.
	rep stosb                ; Fill the scanline with the color in AL.
	mov ecx, edx             ; Restore the outer loop count.
	add edi, 295             ; Skip to the next screen row: 320 - 25 pixels.
    loop squareloop
    ret
ENDP DRAW_SQUARE

PROC terminateProcess
    USES eax
    call setVideoMode, 03h
    mov ax, 04C00h
    int 21h
    ret
ENDP terminateProcess

PROC main
    sti
    cld

    push ds
    pop es

    call setVideoMode, 13h
    ; call fillBackground, 0

    mov esi, 0
@@rowloop_main:
    mov ebx, 0
@@columnloop_main:
    call DRAW_SQUARE, ebx, esi
    inc ebx
    cmp ebx, 8
    jl @@columnloop_main

    inc esi
    cmp esi, 8
    jl @@rowloop_main

    ; call updateColourPalette, 64
    ; call drawGradient

    ; call drawRectangle, 60, 60, 60, 60, 32
    ; call drawRectangle, 80, 80, 100, 100, 63
    ; call drawRectangle, 1, 1, SCRWIDTH - 2, SCRHEIGHT - 2, 48

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
    palette db 768 dup (?)
stack 100

END main