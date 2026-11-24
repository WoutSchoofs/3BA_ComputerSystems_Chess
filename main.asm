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
INCLUDE "MOUSE.INC"

CODESEG

PROC wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
ENDP wait_VBLANK


PROC main
    ; Initialize the graphics environment and ensure string operations move in
    ; the expected direction.
    sti
    cld

    push ds
    pop es

	call    mouse_present
    cmp     eax, 1
    je      @@mouse_present

    mov     ah, 9
    mov     edx, offset msg_no_mouse
    int     21h

@@mouse_present:
    call setVideoMode, 13h
	call initializeDrawTracking, [current_color]

	gameLoop:
    cmp [game_status_dirty], 1
    jne @@status_ready
    call getGameStatus, [current_color]
    mov [game_status], eax
    mov [game_status_dirty], 0
    cmp eax, 2
    je @@checkmate
    cmp eax, 3
    je @@stalemate
    call getDrawStatus
    cmp eax, 1
    je @@fifty_move_draw
    cmp eax, 2
    je @@repetition_draw
    cmp [game_status], 1
    jne @@status_ready
    mov [board_dirty], 1
    @@status_ready:

	;Check program exit
	mov ah,01h		; check for keystroke
    int 16h
	jnz checkQuit
	
	cmp [board_dirty], 1
	jne @@board_ready
	call wait_VBLANK, 1
	call eraseMouse
	call draw_board, offset board
	cmp [game_status], 1
	jne @@no_check_highlight
	call draw_check_highlight, [checked_king_row], [checked_king_col]
	@@no_check_highlight:
	cmp [selected_flag], 1
	jne @@board_drawn
	call draw_move_highlight, offset movement
	@@board_drawn:
	cmp [promotion_pending], 1
	jne @@board_rendered
	call draw_promotion_menu, [promotion_color]
	@@board_rendered:
	mov [board_dirty], 0

	@@board_ready:
	; Temporary game loop, doesn't work properly, more a proof of concept than anything
	
	checkClick:
		;When input is needed, get the input and draw mouse
		call getMouseInput, 1
		call wait_VBLANK, 1
		call drawMouse, ecx, edx, 11
		test ebx, 1
		jz @@left_button_up
		cmp [left_button_down], 1
		je gameLoop
		mov [left_button_down], 1
		jmp @@process_click

		@@left_button_up:
		mov [left_button_down], 0
		jmp gameLoop

		@@process_click:
		cmp [promotion_pending], 1
		je @@promotion_click
		
		call calculateIndex, ecx, edx
		call getElement, ecx, edx
		
		cmp eax, 1
		je gameLoop
		
		cmp [selected_flag], 1
		je select_square
		
		mov esi, eax
		mov ebx, eax
		and ebx, 00010000b
		mov eax, ebx
		cmp eax, [current_color]
		jne gameLoop

		mov eax, esi
		call generatePieceMoves, eax, ebx, ecx, edx

		@@moves_ready:
		call filterLegalMoves, ebx, ecx, edx
		mov [selected_flag], 1
		mov [selected_row], ecx
		mov [selected_col], edx
		mov [board_dirty], 1
		jmp gameLoop
		
		select_square:
			call getMovementElem, ecx, edx
			cmp eax, 1
			jne stop_selection
			call moveElement, [selected_row], [selected_col], ecx, edx
			call getElement, ecx, edx
			mov esi, eax
			shr eax, 5
			cmp eax, 1
			jne @@commit_turn
			cmp [current_color], 00010000b
			jne @@black_promotion_rank
			cmp edx, 0
			jne @@commit_turn
			jmp @@start_promotion
		@@black_promotion_rank:
			cmp edx, 7
			jne @@commit_turn
		@@start_promotion:
			mov [promotion_pending], 1
			mov eax, ecx
			mov [promotion_row], eax
			mov eax, edx
			mov [promotion_col], eax
			mov eax, [current_color]
			mov [promotion_color], eax
			xor eax, eax
			mov [game_status], eax
			mov [board_dirty], 1
			jmp stop_selection
		@@commit_turn:
			mov ebx, 00010000b
			xor [current_color], ebx
			call recordPosition, [current_color]
			mov [game_status_dirty], 1
			
			stop_selection:
				call clearMovement, 1
				mov [selected_flag], 0
				mov [board_dirty], 1
		
	; End of temporary game loop
	
	
		
	jmp gameLoop ;Logic is over, next frame can go

	@@promotion_click:
		mov [promotion_mouse_y], edx
		cmp ecx, PROMOTION_MENU_X
		jb gameLoop
		mov eax, PROMOTION_MENU_X + PROMOTION_TILE_SIZE
		cmp ecx, eax
		jae gameLoop
		cmp edx, PROMOTION_MENU_Y
		jb gameLoop
		mov eax, [promotion_mouse_y]
		sub eax, PROMOTION_MENU_Y
		xor edx, edx
		mov ebx, PROMOTION_MENU_SPACING
		div ebx
		cmp eax, 4
		jae gameLoop
		cmp edx, PROMOTION_TILE_SIZE
		jae gameLoop
		mov [promotion_menu_row], eax
		cmp eax, 0
		je @@choose_queen
		cmp eax, 1
		je @@choose_rook
		cmp eax, 2
		je @@choose_bishop
		jmp @@choose_knight
	@@choose_queen:
		mov eax, 5
		jmp @@promotion_selected
	@@choose_rook:
		mov eax, 2
		jmp @@promotion_selected
	@@choose_bishop:
		mov eax, 4
		jmp @@promotion_selected
	@@choose_knight:
		mov eax, 3
	@@promotion_selected:
		mov [promotion_piece_type], eax
		call promotePawn, [promotion_row], [promotion_col], [promotion_piece_type]
		mov [promotion_pending], 0
		mov ebx, 00010000b
		xor [current_color], ebx
		call recordPosition, [current_color]
		mov [game_status_dirty], 1
		mov [board_dirty], 1
		jmp gameLoop

	@@checkmate:
		call eraseMouse
		call mouse_uninstall
		call setVideoMode, 03h
		cmp [current_color], 0
		je @@white_wins
		mov edx, offset msg_black_wins
		jmp @@print_game_result
	@@white_wins:
		mov edx, offset msg_white_wins
		jmp @@print_game_result
	@@stalemate:
		call eraseMouse
		call mouse_uninstall
		call setVideoMode, 03h
		mov edx, offset msg_stalemate
		jmp @@print_game_result
	@@fifty_move_draw:
		call eraseMouse
		call mouse_uninstall
		call setVideoMode, 03h
		mov edx, offset msg_fifty_move_draw
		jmp @@print_game_result
	@@repetition_draw:
		call eraseMouse
		call mouse_uninstall
		call setVideoMode, 03h
		mov edx, offset msg_repetition_draw
	@@print_game_result:
		mov ah, 09h
		int 21h
		mov ah, 00h
		int 16h
		call terminateProcess
	
	checkQuit:
	mov ah, 00h
	int 16h
	cmp al, 27 ;Check if ESC is pressed
	jne gameLoop
	
	call mouse_uninstall
	call terminateProcess
	

    call draw_board, offset board
    mov ah, 00h
    int 16h
    call draw_move_highlight, offset movement
    mov ah, 00h
    int 16h
    mov [byte ptr board+4], 00100000b
    call draw_board, offset board

    mov ah, 00h
    int 16h
    call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG
msg_no_mouse    db 'No mouse found!', 0dh, 0ah, '$'
msg_white_wins  db 'Checkmate! White wins.', 0dh, 0ah, 'Press any key to exit.$'
msg_black_wins  db 'Checkmate! Black wins.', 0dh, 0ah, 'Press any key to exit.$'
msg_stalemate   db 'Stalemate. The game is a draw.', 0dh, 0ah, 'Press any key to exit.$'
msg_fifty_move_draw db 'Draw by the 50-move rule.', 0dh, 0ah, 'Press any key to exit.$'
msg_repetition_draw db 'Draw by threefold repetition.', 0dh, 0ah, 'Press any key to exit.$'

msg_test    db 'Test $'

current_color dd 00010000b

selected_flag db 0
selected_row dd -1
selected_col dd -1
board_dirty db 1
left_button_down db 0
game_status dd 0
game_status_dirty db 1
promotion_pending db 0
promotion_row dd 0
promotion_col dd 0
promotion_color dd 0
promotion_mouse_y dd 0
promotion_menu_row dd 0
promotion_piece_type dd 0

; -------------------------------------------------------------------
stack 100

END main
