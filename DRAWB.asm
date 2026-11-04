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
PUBLIC setVideoMode, terminateProcess, draw_board, draw_move_highlight
PUBLIC empty_sprite, king_sprite, pawn_sprite, rook_sprite
PUBLIC knight_sprite, bishop_sprite, queen_sprite

include "CHESS.INC"
include "PLOGIC.INC"

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

;   takes a coded element of a square, decodes into usable data e.g. 00100000b, 001 means it is a pawn the next bit being zero means its a black piece. next four bits arent used here
PROC getPieceAndColor
    ARG @@element:dword RETURNS esi, edi
    mov esi, [@@element]
    shr esi, 4
    test esi, 1
    jz piece_is_black
    piece_is_white:
        mov edi, WHITE
        jmp end_getPieceAndColor
    piece_is_black:
        mov edi, BLACK
    end_getPieceAndColor:
    shr esi, 1
    ret
ENDP getPieceAndColor

; Draw one 25x25 square at the requested board coordinates.
; The sprite mask stored in @@25X25array is interpreted as follows:
; 0 => paint it in the background color for this square (brown or white)
; 1 => paint using @@color
; >1 => paint black (0)
PROC DRAW_SQUARE
    ARG @@column:dword, @@row:dword, @@25X25array:dword, @@color:dword
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
    mov bl, BROWN_SQUARE                                   ; Brown is the default for odd squares.
    mov esi, [@@row]
    add esi, [@@column]
    test esi, 1
    jnz @@startpixelloops                                               ; Odd squares keep the brown color.
    mov bl, WHITE_SQUARE                                  ; Even squares are white.

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

;   used to stop program fromfreezing at the end
PROC terminateProcess
    USES eax
    call setVideoMode, 03h
    mov ax, 04C00h
    int 21h
    ret
ENDP terminateProcess

;   draws the given board state
PROC draw_board
    ARG @@board_array:dword
    USES eax, ecx, ebx, edx, esi, edi
    xor ebx, ebx
    rowloop:
    xor ecx, ecx
    columnloop:
        call getOffset, [@@board_array], ebx, ecx                     ;puts the total offset of [ebx, ebc] square in eax                                        
        movzx eax, [byte ptr eax]                                     ;puts the byte stored in [ebx, ebc] square in lowest byte of eax, other bytes in eax are empty
        call getPieceAndColor, eax                                    ;puts the piece code in esi and the color in edi
        call DRAW_SQUARE, ebx, ecx, [sprite_array+4*esi], edi         ;we have stored the possible sprites in an array, where eacht piece is at the offset that matches its code to the start of the array, so +4*esi finds the correct sprite
        inc ecx
        cmp ecx, 8
        jl columnloop
    inc ebx
    cmp ebx, 8
    jl rowloop
    ret
ENDP draw_board

;   Here follows a loop that checks for each of the board squares whether its corresponding entry in the possible_move_array is set to 1. If so, draw a blue border around the square
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
        imul eax, eax, BOARD_ROW_BYTES
        add edi, eax
        add edi, BOARD_X_OFFSET
        imul edx, edx, TILESIDE
        add edi, edx
        mov al, BLUE_OUTLINE

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
    
; -------------------------------------------------------------------
DATASEG
    empty_sprite    db 625 dup (0)
    ; 0 is the background color for the square, 1 is the color of the piece, 2 is black (outline).

    sprite_array dd offset empty_sprite, offset pawn_sprite, offset rook_sprite, offset knight_sprite, offset bishop_sprite, offset queen_sprite, offset king_sprite

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
