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

;=============================================================================
; Uninitialized DATA
;=============================================================================
UDATASEG

;=============================================================================
; DATA
;=============================================================================
DATASEG

custom_mouse_handler    dd ?

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
	
	movzx edx,dx ;draw click
	sar cx,1; X-coordinate for 2D display grid (divide by 2)
	movzx ecx,cx
	sub ecx, 60
	
	xor edx, edx
	mov eax, [@@horPos]
	mov ebx, 25
	div ebx
	mov ecx, eax
	
	xor edx, edx
	mov eax, [@@verPos]
	div ebx
	mov edx, eax
	
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


PROC drawMouse
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col: dword
	USES 	eax, ecx, edx, edi ; note: MUL uses edx!

	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx
	add	eax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	eax,[@@col]
	rep stosb
	sub edi, edx		; reset edi to left-top corner
	
	; plot both vertical edges
	mov ecx,[@@h]
	@@vertLoop:
		mov	[edi],al		; left edge
		mov	[edi+edx-1],al	; right edge
		add	edi, SCRWIDTH
		loop @@vertLoop
	; edi should point at the bottom-left corner now
	sub edi, SCRWIDTH

	; Plot the bottom horizontal edge.
	mov	ecx, edx
	rep stosb
	ret
ENDP drawMouse


END

