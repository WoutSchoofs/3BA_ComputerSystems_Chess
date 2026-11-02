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
PUBLIC setVideoMode, terminateProcess, set_up_board, draw_move, draw_move_highlight
PUBLIC empty_sprite, king_sprite, pawn_sprite, rook_sprite
PUBLIC knight_sprite, bishop_sprite, queen_sprite



include "CHESS.INC"

; Video mode 13h framebuffer dimensions and base address.
    TILESIDE EQU 25
    BOARD_ROW_BYTES EQU TILESIDE * SCRWIDTH                             ; 25 pixels * 320 bytes per scanline.
    BOARD_X_OFFSET EQU 60                                               ; Board origin inside the VGA framebuffer.
    NEXT_ROW_OFFSET EQU SCRWIDTH - TILESIDE                             ; 320 - 25, to advance from one tile row to the next.

; Color constants used by the board and sprite drawing code.
; These are the piece colors used in the sprite mask logic.
    BLACK_OUTLINE EQU 0

; Board colors
    BROWN_SQUARE EQU 6
    WHITE_SQUARE EQU 90
    BLUE_OUTLINE EQU 9

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
    ARG @@column:dword, @@row:dword, @@25X25array: dword, @@color:dword, @@background_color_dark:dword, @@background_color_light:dword
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
    mov bl, [byte ptr @@background_color_dark]                                   ; Brown is the default for odd squares.
    mov esi, [@@row]
    add esi, [@@column]
    test esi, 1
    jnz @@startpixelloops                                               ; Odd squares keep the brown color.
    mov bl, [byte ptr @@background_color_light]                                  ; Even squares are white.

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
    call DRAW_SQUARE, esi, ebx, offset empty_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    inc ebx
    cmp ebx, 6
    jl @@setup_row
    inc esi
    cmp esi, 8
    jl @@setup_column

    ; Black pawns occupy row 1.
    mov ebx, 0
@@black_pawns:
    call DRAW_SQUARE, ebx, 1, offset pawn_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    inc ebx
    cmp ebx, 8
    jl @@black_pawns

    ; White pawns occupy row 6.
    mov ebx, 0
@@white_pawns:
    call DRAW_SQUARE, ebx, 6, offset pawn_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE
    inc ebx
    cmp ebx, 8
    jl @@white_pawns

@@black_rooks:
    call DRAW_SQUARE, 0, 0, offset rook_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 7, 0, offset rook_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE

@@white_rooks:
    call DRAW_SQUARE, 0, 7, offset rook_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 7, 7, offset rook_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE

@@black_knights:
    call DRAW_SQUARE, 1, 0, offset knight_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 6, 0, offset knight_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE

@@white_knights:
    call DRAW_SQUARE, 1, 7, offset knight_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 6, 7, offset knight_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE

@@black_bishops:
    call DRAW_SQUARE, 2, 0, offset bishop_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 5, 0, offset bishop_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE

@@white_bishops:
    call DRAW_SQUARE, 2, 7, offset bishop_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 5, 7, offset bishop_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE

    ; Kings start on the e-file: column 4, with one king for each side.
@@kings_and_queens:
    call DRAW_SQUARE, 4, 0, offset king_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 4, 7, offset king_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 3, 0, offset queen_sprite, BLACK, BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, 3, 7, offset queen_sprite, WHITE, BROWN_SQUARE, WHITE_SQUARE

    ret
ENDP set_up_board

;   Here follows a loop that checks for each of the board squares whether its corresponding entry in the possible_move_array is set to 1. If so, redraw that square with different background colors.
PROC draw_move_highlight
   ARG possible_move_array:dword
   USES eax, ebx, esi, ecx, edx, edi
    mov esi, [possible_move_array]
    xor ebx, ebx

    @@check_square:
        cmp ebx, 64
        jae @@done
        cmp [byte ptr esi+ebx], 1
        jne @@next_square

        ; Convert this row-major board index to its board row and column.
        mov eax, ebx
        xor edx, edx
        mov ecx, 8
        div ecx

        mov edi, VMEMADR
        imul edx, edx, BOARD_ROW_BYTES
        add edi, edx
        add edi, BOARD_X_OFFSET
        imul eax, eax, TILESIDE
        add edi, eax
        mov al, CYAN_OUTLINE

        ; Draw the top edge, the two sides, and the bottom edge.
        mov ecx, TILESIDE
        rep stosb
        add edi, NEXT_ROW_OFFSET
        mov ecx, TILESIDE-2
    @@side_rows:
        mov [edi], al
        mov [byte ptr edi+TILESIDE-1], al
        add edi, SCRWIDTH
        loop @@side_rows

        mov ecx, TILESIDE
        rep stosb

    @@next_square:
        inc ebx
        jmp @@check_square

    @@done:
    ret
ENDP draw_move_highlight
    
;draw_move erases the piece from its starting square and draws it in its destination square.
;does not update board state, only the graphics (might change).
PROC draw_move
    ARG @@startcolumn:dword, @@startrow:dword, @@endcolumn:dword, @@endrow:dword, @@piece:dword, @@color:dword
    call DRAW_SQUARE, [@@startcolumn], [@@startrow], offset empty_sprite, [@@color], BROWN_SQUARE, WHITE_SQUARE
    call DRAW_SQUARE, [@@endcolumn], [@@endrow], [@@piece], [@@color], BROWN_SQUARE, WHITE_SQUARE
    ret
ENDP draw_move

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

END
