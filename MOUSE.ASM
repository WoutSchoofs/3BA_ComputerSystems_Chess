;=============================================================================
; 32-bit Assembler Mouse library.
;
; For use under DMPI 0.9 protected mode.
;
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Copyright (c) 2015, Tim Bruylants <tim.bruylants@gmail.com>
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions
; are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
;    this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from this
;    software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;
;=============================================================================

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

;PUBLIC mouse_install, mouse_uninstall, mouse_present, calculateIndex, getMouseInput, drawMouse


INCLUDE "mouse.inc"
INCLUDE "chess.inc"

MOUSE_CURSOR_WIDTH EQU 10
MOUSE_CURSOR_HEIGHT EQU 12
MOUSE_BOARD_X_OFFSET EQU 60
MOUSE_TILE_SIZE EQU 25
MOUSE_BOARD_SIZE EQU MOUSE_TILE_SIZE * 8

;=============================================================================
; Uninitialized DATA
;=============================================================================
UDATASEG

;=============================================================================
; DATA
;=============================================================================
DATASEG

custom_mouse_handler    dd ?
mouse_background db MOUSE_CURSOR_WIDTH * MOUSE_CURSOR_HEIGHT dup (0)
mouse_previous_x dd 0
mouse_previous_y dd 0
mouse_visible db 0

mouse_arrow db 2,0,0,0,0,0,0,0,0,0
            db 2,2,0,0,0,0,0,0,0,0
            db 2,1,2,0,0,0,0,0,0,0
            db 2,1,1,2,0,0,0,0,0,0
            db 2,1,1,1,2,0,0,0,0,0
            db 2,1,1,1,1,2,0,0,0,0
            db 2,1,1,1,1,1,2,0,0,0
            db 2,1,1,1,1,1,1,2,0,0
            db 2,1,1,1,1,1,1,2,0,0
            db 2,1,1,1,1,2,2,0,0,0
            db 2,1,1,2,2,0,0,0,0,0
            db 2,2,2,0,0,0,0,0,0,0

;=============================================================================
; CODE
;=============================================================================
CODESEG

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Test if mouse is present or not.
;
; ARGUMENTS:
;   none
; RETURNS:
;   EAX     1 if mouse available
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PROC mouse_present
    USES    ebx

    mov     eax, 0
    int     33h

    and     eax, 1

    ret
ENDP mouse_present

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Internal mouse handler.
;
; Requires special attention, as this procedure gets called by the mouse
; driver, through the DOS Protected Mode extender.
;
; ARGUMENTS:
;   none
; RETURNS:
;   nothing
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PROC mouse_internal_handler NOLANGUAGE
    push    ds
    push    es
    push    ax

    mov     ax, [cs:theDS]
    mov     ds, ax
    mov     es, ax

    pop     ax

    call    [custom_mouse_handler]
    
    pop     es
    pop     ds
    
    retf

    ; Internal variable to keep track of DS
    theDS   dw  ?
ENDP mouse_internal_handler

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Install mouse handler.
;
; ARGUMENTS:
;   address of the custom mouse handler
; RETURNS:
;   nothing
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PROC mouse_install
    ARG     @@custom_handler
    USES    eax, ecx, edx, es

    call    mouse_present
    cmp     eax, 1
    jne     @@no_mouse

    mov     eax, [@@custom_handler]
    mov     [custom_mouse_handler], eax

    push    ds
    mov     ax, cs
    mov     ds, ax
    ASSUME  ds:_TEXT
    mov     [theDS], ax
    ASSUME  ds:FLAT
    pop     ds

    mov     eax, 0ch
    mov     ecx, 255
    push    cs
    pop     es
    mov     edx, offset mouse_internal_handler
    int     33h

@@no_mouse:
    ret
ENDP mouse_install

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Uninstall mouse handler.
;
; ARGUMENTS:
;   none
; RETURNS:
;   nothing
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PROC mouse_uninstall
    USES    eax, ecx, edx

    mov     eax, 0ch
    mov     ecx, 0
    mov     edx, 0
    int     33h

    ret
ENDP mouse_uninstall


PROC calculateIndex
	ARG @@horPos:dword, @@verPos:dword RETURNS ecx, edx
	USES eax, ebx

	; The board is drawn rotated: screen X maps to board row, screen Y to column.
	mov eax, [@@horPos]
	cmp eax, MOUSE_BOARD_X_OFFSET
	jb @@outside_board
	sub eax, MOUSE_BOARD_X_OFFSET
	cmp eax, MOUSE_BOARD_SIZE
	jae @@outside_board
	mov ebx, MOUSE_TILE_SIZE
	xor edx, edx
	div ebx
	mov ecx, eax

	mov eax, [@@verPos]
	cmp eax, SCRHEIGHT
	jae @@outside_board
	xor edx, edx
	div ebx
	mov edx, eax
	ret

	@@outside_board:
	mov ecx, -1
	mov edx, -1
	ret
ENDP calculateIndex


PROC getMouseInput
	ARG @@waitTime:dword RETURNS ebx, ecx, edx
	USES eax

	; get mouse position and buttonstatus in bx,cx,dx
	;BX - The last and second last bit of BX is mapped to left click and right click respectively (set to 1/0 if there is click/no-click).
	;CX - X-coordinate (640 pixel width for 2D mouse grid)
    ;DX - Y-coordinate (200 pixel height for 2D mouse grid)
	mov  ax, 3  
	int  33h

	movzx ebx, bx

	movzx edx,dx ;draw click
	sar cx,1; X-coordinate for 2D display grid (divide by 2)
	movzx ecx,cx
	
	ret
ENDP getMouseInput


PROC eraseMouse
    USES eax, ebx, ecx, edx, edi, esi

    cmp [mouse_visible], 1
    jne @@done

    ; Restore the saved pixels beneath the previous arrow.
    mov esi, offset mouse_arrow
    xor ebx, ebx
    @@rowloop:
        cmp ebx, MOUSE_CURSOR_HEIGHT
        jae @@done
        xor ecx, ecx
    @@columnloop:
        cmp ecx, MOUSE_CURSOR_WIDTH
        jae @@nextrow

        mov al, [esi]
        inc esi
        test al, al
        jz @@nextpixel

        mov edx, [mouse_previous_y]
        add edx, ebx
        cmp edx, SCRHEIGHT
        jae @@nextpixel

        mov eax, [mouse_previous_x]
        add eax, ecx
        cmp eax, SCRWIDTH
        jae @@nextpixel

        imul edx, edx, SCRWIDTH
        add edx, eax
        mov edi, VMEMADR
        add edi, edx
        mov eax, ebx
        imul eax, eax, MOUSE_CURSOR_WIDTH
        add eax, ecx
        mov al, [mouse_background+eax]
        mov [edi], al

    @@nextpixel:
        inc ecx
        jmp @@columnloop
    @@nextrow:
        inc ebx
        jmp @@rowloop
    @@done:
    mov [mouse_visible], 0
    ret
ENDP eraseMouse


PROC drawMouse
    ARG @@x0:dword, @@y0:dword, @@col:dword
    USES eax, ebx, ecx, edx, edi, esi

    cmp [mouse_visible], 1
    jne @@draw_new
    mov eax, [mouse_previous_x]
    cmp eax, [@@x0]
    jne @@erase_previous
    mov eax, [mouse_previous_y]
    cmp eax, [@@y0]
    je @@done
    @@erase_previous:
        call eraseMouse

    @@draw_new:
    mov esi, offset mouse_arrow
    xor ebx, ebx
    @@draw_rowloop:
        cmp ebx, MOUSE_CURSOR_HEIGHT
        jae @@save_position
        xor ecx, ecx
    @@draw_columnloop:
        cmp ecx, MOUSE_CURSOR_WIDTH
        jae @@draw_nextrow

        mov al, [esi]
        inc esi
        test al, al
        jz @@draw_nextpixel

        mov edx, [@@y0]
        add edx, ebx
        cmp edx, SCRHEIGHT
        jae @@draw_nextpixel

        mov eax, [@@x0]
        add eax, ecx
        cmp eax, SCRWIDTH
        jae @@draw_nextpixel

        imul edx, edx, SCRWIDTH
        add edx, eax
        mov edi, VMEMADR
        add edi, edx

        mov eax, ebx
        imul eax, eax, MOUSE_CURSOR_WIDTH
        add eax, ecx
        mov dl, [edi]
        ; Save the current pixel so the arrow can be erased on the next move.
        mov [mouse_background+eax], dl
        mov al, [esi-1]
        cmp al, 1
        jne @@draw_outline
        mov al, [byte ptr @@col]
        jmp @@draw_plot
    @@draw_outline:
        xor al, al
    @@draw_plot:
        mov [edi], al

    @@draw_nextpixel:
        inc ecx
        jmp @@draw_columnloop
    @@draw_nextrow:
        inc ebx
        jmp @@draw_rowloop
    @@save_position:
    mov eax, [@@x0]
    mov [mouse_previous_x], eax
    mov eax, [@@y0]
    mov [mouse_previous_y], eax
    mov [mouse_visible], 1
    @@done:
    ret
ENDP drawMouse


END

