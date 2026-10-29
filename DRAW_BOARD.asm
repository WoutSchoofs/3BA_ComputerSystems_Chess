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
    BOARD_ROW_BYTES EQU TILESIDE * SCRWIDTH                             ; 25 pixels * 320 bytes per scanline.
    BOARD_X_OFFSET EQU 60                                               ; Board origin inside the VGA framebuffer.
    NEXT_ROW_OFFSET EQU SCRWIDTH - TILESIDE                             ; 320 - 25, to advance from one tile row to the next.

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
; 0 => paint it in the background color for this square (brown or white)
; 1 => paint using @@color
; >1 => paint black (0)
PROC DRAW_SQUARE
    ARG @@column:dword, @@row:dword, @@25X25array: dword, @@color:dword
    USES eax, ebx, ecx, edx, edi, esi

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
    mov bl, BROWN_SQUARE                                                ; Brown is the default for odd squares.
    mov esi, [@@row]
    add esi, [@@column]
    test esi, 1
    jnz @@startpixelloops                                               ; Odd squares keep the brown color.
    mov bl, WHITE_SQUARE                                                ; Even squares are white.

@@startpixelloops:
    mov edx, [@@25X25array]                                             ; Load the address of the sprite mask for this square, outside of the loop so we can increment it as we go.
    mov ecx, TILESIDE                                                   ; Number of rows still to paint in this tile.

@@rowloop:
    push ecx                                                            ; Save outerloop counter for the 25 rows of the square.
    mov ecx, TILESIDE                                                   ; Number of pixels in the current 25-pixel row.
@@columnloop:                                                           ; Fill the scanline using the sprite mask in the array.
    mov al, bl                                                          ; bl contains the background color for this square.
    cmp [byte ptr edx], 1                                               ; Check if the current pixel should be painted.
    jb @@printpixel                                                     ; if its below 1, ie 0, paint it blackin the background color of the square.
    mov al, [byte ptr @@color]
    je @@printpixel                                                     ; if it is equal to one, paint it with the color of the piece.
    mov al, BLACK_OUTLINE                                               ; if its neither lower nor equal to one, ie 2, paint outline black.
@@printpixel:
    mov [edi], al
    inc edi
    inc edx                                                             ; Advance to the next pixel in the sprite mask.
    loop @@columnloop
    pop ecx                                                             ; Restore the outer row count.
    add edi, NEXT_ROW_OFFSET                                            ; Advance to the next screen row: 320 - 25 pixels.
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
; draw square takes the column, row, sprite mask, and color as arguments (in that order).
PROC set_up_board
    USES ebx, esi

    ; Paint empty squares before drawing the pieces.
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

;draw_move erases the piece from its starting square and draws it in its destination square.
;does not update board state, only the graphics (might change).
PROC draw_move
    ARG @@startcolumn:dword, @@startrow:dword, @@endcolumn:dword, @@endrow:dword, @@piece:dword, @@color:dword
    call DRAW_SQUARE, [@@startcolumn], [@@startrow], offset empty_sprite, [@@color]
    call DRAW_SQUARE, [@@endcolumn], [@@endrow], [@@piece], [@@color]
    ret
ENDP draw_move

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
    empty_sprite    db 625 dup (0)
    ; 0 is the background color for the square, 1 is the color of the piece, 2 is black (outline).
    king_sprite     db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
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
