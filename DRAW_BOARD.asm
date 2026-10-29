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
TILESIDE EQU 25
BOARD_ROW_BYTES EQU TILESIDE * SCRWIDTH        ; 25 pixels * 320 bytes per scanline.
BOARD_X_OFFSET EQU 60                          ; Board origin inside the VGA framebuffer.
NEXT_ROW_OFFSET EQU SCRWIDTH - TILESIDE        ; 320 - 25, to advance from one tile row to the next.

; Color constants used by the board and sprite drawing code.
; These are the piece colors used in the sprite mask logic.
BLACK EQU 18
WHITE EQU 15
BLACK_OUTLINE EQU 0

; These values were previously written directly as literals for background tiles.
BROWN_SQUARE EQU 6
WHITE_SQUARE EQU 90

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
; The sprite mask stored in @@25X25array is interpreted as follows:
;   0 => leave the background color untouched
;   1 => paint using @@color
; >1 => paint black (0)
PROC DRAW_SQUARE
    ARG @@column:dword, @@row:dword, @@25X25array: dword, @@color: byte
	USES eax, ecx, edx, edi, esi
	mov ecx, TILESIDE            ; Number of rows still to paint in this tile.

	; Convert board coordinates to a byte offset in the framebuffer.
	; Each board row is 25 pixels high and 320 pixels wide, so one row is
	; 25 * 320 = 8000 bytes in VGA memory.
	mov edi, VMEMADR
    mov eax, [@@row]
	imul eax, eax, BOARD_ROW_BYTES
    add edi, eax
    add edi, BOARD_X_OFFSET
    mov eax, [@@column]
    imul eax, eax, TILESIDE
    add edi, eax

	; Alternate colors by the sum of the row and column coordinates.
    mov al, BROWN_SQUARE    ; Brown is the default for odd squares.
    mov esi, [@@row]
    add esi, [@@column]
    test esi, 1
    mov esi, 0
	jnz @@rowloop             ; Odd squares keep the brown color.
	mov al, WHITE_SQUARE   ; Even squares are white.

    @@rowloop:
    push ecx                   ; Save the remaining scanline count.
    mov ecx, TILESIDE          ; Number of pixels in the current 25-pixel row.
    mov edx, [@@25X25array]
    add edx, esi
    @@columnloop:                ; Fill the scanline using the sprite mask in the array.
    push eax
    cmp [byte ptr edx], 1
    jb @@printpixel
    mov al, [@@color]
    je @@printpixel
    mov al, BLACK_OUTLINE
    @@printpixel:
    mov [edi], al
    pop eax
    inc edi
    inc edx
    loop @@columnloop  
    add esi, 25
	pop ecx                    ; Restore the outer row count.
	add edi, NEXT_ROW_OFFSET    ; Advance to the next screen row: 320 - 25 pixels.
    loop @@rowloop
    ret
ENDP DRAW_SQUARE

PROC terminateProcess
    USES eax
    call setVideoMode, 03h
    mov ax, 04C00h
    int 21h
    ret
ENDP terminateProcess

; Draw the board and place the kings and pawns in their starting squares.
; Black starts at the top (rows 0 and 1); white starts at the bottom (rows 6 and 7).
PROC set_up_board
    USES ebx, esi

    ; Paint all 64 squares before drawing the pieces.
    mov esi, 0
@@setup_column:
    mov ebx, 2
@@setup_row:
    call DRAW_SQUARE, esi, ebx, offset empty_sprite, BLACK
    inc ebx
    cmp ebx, 6
    jl @@setup_row
    inc esi
    cmp esi, 8
    jl @@setup_column

    ; Black pawns occupy row 1.
    mov ebx, 0
@@black_pawns:
    call DRAW_SQUARE, ebx, 1, offset pawn_sprite, BLACK
    inc ebx
    cmp ebx, 8
    jl @@black_pawns

    ; White pawns occupy row 6.
    mov ebx, 0
@@white_pawns:
    call DRAW_SQUARE, ebx, 6, offset pawn_sprite, WHITE
    inc ebx
    cmp ebx, 8
    jl @@white_pawns

@@black_rooks:
    call DRAW_SQUARE, 0, 0, offset rook_sprite, BLACK
    call DRAW_SQUARE, 7, 0, offset rook_sprite, BLACK

@@white_rooks:
    call DRAW_SQUARE, 0, 7, offset rook_sprite, WHITE
    call DRAW_SQUARE, 7, 7, offset rook_sprite, WHITE

@@black_knights:
    call DRAW_SQUARE, 1, 0, offset knight_sprite, BLACK
    call DRAW_SQUARE, 6, 0, offset knight_sprite, BLACK

@@white_knights:
    call DRAW_SQUARE, 1, 7, offset knight_sprite, WHITE
    call DRAW_SQUARE, 6, 7, offset knight_sprite, WHITE
    
@@black_bishops:
    call DRAW_SQUARE, 2, 0, offset bishop_sprite, BLACK
    call DRAW_SQUARE, 5, 0, offset bishop_sprite, BLACK

@@white_bishops:
    call DRAW_SQUARE, 2, 7, offset bishop_sprite, WHITE
    call DRAW_SQUARE, 5, 7, offset bishop_sprite, WHITE

    ; Kings start on the e-file: column 4, with one king for each side.
@@kings_and_queens:
    call DRAW_SQUARE, 4, 0, offset king_sprite, BLACK
    call DRAW_SQUARE, 4, 7, offset king_sprite, WHITE
    call DRAW_SQUARE, 3, 0, offset queen_sprite, BLACK
    call DRAW_SQUARE, 3, 7, offset queen_sprite, WHITE
    ret
ENDP set_up_board

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

    ; call updateColourPalette, 64
    ; call drawGradient

    ; call drawRectangle, 60, 60, 60, 60, 32
    ; call drawRectangle, 80, 80, 100, 100, 63
    ; call drawRectangle, 1, 1, SCRWIDTH - 2, SCRHEIGHT - 2, 48

    ; Drain any pending keyboard input so the program only resumes after the next
    ; key press, matching the original wait-loop behavior.
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
    empty_sprite db 625 dup (0)
    king_sprite db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; 0 is transparant, 1 is de kleur van het stuk, en 2 is een zwarte rand rond het stuk
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,2,2,1,2,2,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,2,2,1,2,2,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0
                db 0,0,0,0,0,2,1,1,1,2,1,2,1,2,1,2,1,1,1,2,0,0,0,0,0
                db 0,0,0,0,2,1,1,2,2,1,1,2,1,2,1,1,2,2,1,1,2,0,0,0,0
                db 0,0,0,2,1,1,2,2,1,1,2,2,1,2,2,1,1,2,2,1,1,2,0,0,0
                db 0,0,2,1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,1,2,0,0
                db 0,0,2,1,2,0,0,2,1,2,0,2,1,2,0,2,1,2,0,0,2,1,2,0,0
                db 0,0,2,1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,1,2,0,0
                db 0,0,0,2,1,1,2,2,1,1,2,2,1,2,2,1,1,2,2,1,1,2,0,0,0
                db 0,0,0,0,2,1,1,2,2,1,1,2,1,2,1,1,2,2,1,1,2,0,0,0,0
                db 0,0,0,0,0,2,1,1,1,1,2,2,2,2,2,1,1,1,1,2,0,0,0,0,0
                db 0,0,0,0,2,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,0,0,0,0
                db 0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0
                db 0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0
                db 0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0
                db 0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

pawn_sprite     db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,2,2,1,1,1,2,2,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,2,2,2,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0
                db 0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0
                db 0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0
                db 0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                
rook_sprite     db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,2,2,2,0,0,0,2,2,2,2,2,0,0,0,2,2,2,0,0,0,0
                db 0,0,0,0,2,1,1,2,2,2,1,1,1,1,1,2,2,2,1,1,2,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,0,2,2,1,1,1,1,1,1,1,1,1,1,1,2,2,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,2,2,1,1,1,1,1,2,2,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,2,2,2,2,2,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,2,2,1,2,2,2,1,1,1,2,2,2,1,2,2,0,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,2,2,2,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0
                db 0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0
                db 0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

knight_sprite   db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,2,1,2,2,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,2,1,1,1,1,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,1,1,1,1,2,2,1,1,1,1,2,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,1,1,1,2,0,0,2,2,1,1,2,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,2,0,0,0,2,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,2,2,1,1,1,1,1,2,2,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,2,2,1,1,1,2,2,2,2,2,1,1,1,2,2,0,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                
bishop_sprite   db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,2,0,0,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,2,0,2,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,2,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,2,1,2,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,1,2,1,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,2,2,2,1,1,1,2,2,2,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,2,2,1,1,1,1,2,2,2,1,1,1,1,2,2,0,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

queen_sprite    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,0,0,0,0,2,1,2,0,0,0,0,2,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,2,0,2,0,0,2,0,0,2,0,2,2,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,2,1,2,0,2,0,2,1,2,1,2,0,0,0,0,0,0
                db 0,0,0,0,0,0,2,1,1,1,1,2,2,2,1,1,1,1,2,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,2,1,1,1,2,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,2,2,2,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,2,2,1,1,1,2,2,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,2,2,2,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,2,2,1,1,1,2,2,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,2,1,1,2,2,2,1,1,2,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,2,2,1,1,1,1,1,1,1,2,2,0,0,0,0,0,0,0
                db 0,0,0,0,0,2,2,1,1,2,2,1,1,1,2,2,1,1,2,2,0,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,2,2,2,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,0
                db 0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                

stack 100

END main