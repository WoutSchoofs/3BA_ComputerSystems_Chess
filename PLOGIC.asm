; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	N/A
; date:		N/A
; program:	N/A
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

PUBLIC getElement, getMovementElem, clearMovement, checkRookMovement, \
	checkBishopMovement, checkKnightMovement, checkKingMovement, checkPawnMovement, \
	generatePieceMoves, filterLegalMoves, getGameStatus, checked_king_row, \
	checked_king_col, initializeDrawTracking, recordPosition, getDrawStatus, \
	promotePawn, halfmove_clock, printBoard, getOffset, moveElement, movement, board

INCLUDE "CHESS.INC"

POSITION_SIZE EQU 65
POSITION_HISTORY_CAPACITY EQU 101
FIFTY_MOVE_HALF_TURNS EQU 100
PIECE_MOVED_FLAG EQU 00000001b
EN_PASSANT_FLAG EQU 00000010b

; compile-time constants (with macros)


; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG		

PROC printUnsignedInteger
	ARG @@num:dword
	USES eax, ebx, ecx, edx
	
	mov eax, [@@num]
	mov ebx, 10
	xor ecx, ecx
	
	@@getNextDigit:
		inc	ecx
		xor edx, edx
		div	ebx
		push dx
		test eax, eax
		jnz	@@getNextDigit
	
		mov	ah, 2h
	@@printDigits:		
		pop dx
		add	dl,'0'
		int	21h
		loop @@printDigits
		
		;mov	dl, 0Dh		; Carriage return.
		;int	21h
		;mov	dl, 0Ah		; New line.
		;int 21h
		
		ret
ENDP printUnsignedInteger


PROC printBoard
	ARG @@arr:dword
	USES eax, ebx, ecx, edx
	
	mov ebx, 0
	mov ecx, 0
	
	@@rowLoop:
		call getOffset, [@@arr], ecx, ebx
		mov dl, [byte ptr eax]
		movzx edx, dl
		call printUnsignedInteger, edx
		mov ah , 2h
		mov dl, 20h		; Space.
		int 21h
		inc ebx
		cmp ebx, 8
		jge @@colLoop
		jmp @@rowLoop
	
	@@colLoop:
	    mov ah, 2h
		mov	dl, 0Dh		; Carriage return.
		int	21h
		mov	dl, 0Ah		; New line.
		int 21h
		INC ecx
		cmp ecx, 8
		jge @@endOfFunction
		mov ebx, 0
		jmp @@rowLoop
	
	@@endOfFunction:
	ret
ENDP printBoard

; Geeft de memory adress terug op basis van de gegeven coordinaten
PROC getOffset
	ARG @@arr:dword, @@row:dword, @@col:dword RETURNS eax

	mov eax, [@@row]
	sal eax, 3 ; vermenigvuldiging met 8
	add eax, [@@col]
	add eax, [@@arr]
	
	ret
ENDP getOffset

; Geeft het stuk dat op dat vak is, anders geeft het een 0 als vak leeg is en een 1 als vak buiten het bord is
PROC getElement
	ARG @@row:dword, @@col:dword RETURNS eax
	USES ebx
	
	; Controle van de gegeven indices
	cmp [@@row], 0
	jl @@outOfBounds
	cmp [@@row], 7
	jg @@outOfBounds
	cmp [@@col], 0
	jl @@outOfBounds
	cmp [@@col], 7
	jg @@outOfBounds
	
	; geraakt door de controles, we zitten inderdaad op het bord
	call getOffset, offset board, [@@row], [@@col]

	mov ebx, eax
	xor eax, eax
	mov al, [ebx]
	jmp @@endOfFunction
	
	@@outOfBounds:
		mov eax, 1
	
	@@endOfFunction:
	ret
ENDP getElement


PROC getMovementElem
	ARG @@row:dword, @@col:dword RETURNS eax
	USES ebx
	
	call getOffset, offset movement, [@@row], [@@col]

	mov ebx, eax
	xor eax, eax
	mov al, [ebx]
	
	ret
ENDP getMovementElem


PROC clearMovement
	ARG @@none:dword
	USES edi, eax, ecx
	
	cld
	mov edi, offset movement
	xor eax, eax
	mov ecx, 16
	rep stosd
	
	ret
ENDP clearMovement


; Beweegt een element van een positie naar een andere en laat een 0 achter
PROC moveElement
	ARG @@fromRow:dword, @@fromCol:dword, @@toRow:dword, @@toCol:dword
	USES eax, ebx, ecx, edx, esi

	call getOffset, offset board, [@@fromRow], [@@fromCol]
	mov ebx, eax
	mov [move_source_address], eax
	movzx eax, [byte ptr ebx]
	mov [move_piece], eax
	shr eax, 5
	mov [move_piece_type], eax

	call getOffset, offset board, [@@toRow], [@@toCol]
	mov [move_target_address], eax
	movzx eax, [byte ptr eax]
	mov [move_target_piece], eax
	xor eax, eax
	mov [move_is_en_passant], eax

	mov eax, [move_piece_type]
	cmp eax, 1
	je @@pawn_move
	cmp [move_target_piece], 0
	jne @@irreversible_move

	mov eax, [halfmove_clock]
	inc eax
	mov [halfmove_clock], eax
	jmp @@move_piece

	@@pawn_move:
		cmp [move_target_piece], 0
		jne SHORT @@irreversible_move
		mov eax, [@@fromRow]
		cmp eax, [@@toRow]
		je @@check_double_step
		mov eax, [@@fromCol]
		cmp eax, [@@toCol]
		je @@check_double_step
		call getOffset, offset board, [@@toRow], [@@fromCol]
		mov [move_ep_capture_address], eax
		movzx eax, [byte ptr eax]
		mov edx, eax
		and eax, 11100000b
		cmp eax, 00100000b
		jne @@check_double_step
		mov eax, edx
		and eax, 00010000b
		mov ecx, [move_piece]
		and ecx, 00010000b
		cmp eax, ecx
		je @@check_double_step
		test edx, EN_PASSANT_FLAG
		jz @@check_double_step
		mov eax, 1
		mov [move_is_en_passant], eax
		jmp @@irreversible_move

	@@check_double_step:
		mov eax, [@@fromCol]
		sub eax, [@@toCol]
		cmp eax, 2
		je @@irreversible_move
		cmp eax, -2
		je @@irreversible_move
		mov eax, [halfmove_clock]
		inc eax
		mov [halfmove_clock], eax
		jmp @@move_piece

	@@irreversible_move:
		xor eax, eax
		mov [halfmove_clock], eax
		mov [position_history_count], eax
		mov [repetition_draw], eax

	@@move_piece:
	mov esi, offset board
	mov ecx, 64
	@@clear_en_passant_flags:
		mov al, [esi]
		and al, 11111101b
		mov [esi], al
		inc esi
		loop @@clear_en_passant_flags

	mov eax, [move_source_address]
	mov [byte ptr eax], 0
	mov eax, [move_piece]
	or eax, PIECE_MOVED_FLAG
	mov edx, [move_target_address]
	mov [byte ptr edx], al

	cmp [move_is_en_passant], 1
	jne @@check_double_step_marker
	mov eax, [move_ep_capture_address]
	mov [byte ptr eax], 0

	@@check_double_step_marker:
		mov eax, [move_piece_type]
		cmp eax, 1
		jne @@check_castling_move
		mov eax, [@@fromRow]
		cmp eax, [@@toRow]
		jne @@check_castling_move
		mov eax, [@@fromCol]
		sub eax, [@@toCol]
		cmp eax, 2
		je @@mark_en_passant
		cmp eax, -2
		jne @@check_castling_move
	@@mark_en_passant:
		mov eax, [move_target_address]
		mov dl, [byte ptr eax]
		or dl, EN_PASSANT_FLAG
		mov [byte ptr eax], dl

	@@check_castling_move:
		mov eax, [move_piece_type]
		cmp eax, 6
		jne @@move_done
		mov eax, [@@fromCol]
		cmp eax, [@@toCol]
		jne SHORT @@move_done
		mov eax, [@@toRow]
		sub eax, [@@fromRow]
		cmp eax, 2
		je @@move_castling_rook
		cmp eax, -2
		jne SHORT @@move_done

	@@move_castling_rook:
		mov eax, 0
		mov edx, [@@toRow]
		cmp edx, [@@fromRow]
		jl @@rook_source_ready
		mov eax, 7
	@@rook_source_ready:
		mov [move_rook_source_row], eax
		mov eax, [@@fromRow]
		add eax, [@@toRow]
		shr eax, 1
		mov [move_rook_target_row], eax
		call getOffset, offset board, [move_rook_source_row], [@@fromCol]
		mov edx, eax
		movzx eax, [byte ptr edx]
		or eax, PIECE_MOVED_FLAG
		mov [move_rook_piece], eax
		mov [byte ptr edx], 0
		call getOffset, offset board, [move_rook_target_row], [@@fromCol]
		mov edx, eax
		mov eax, [move_rook_piece]
		mov [byte ptr edx], al

	@@move_done:
	
	ret
ENDP moveElement

; Helper functie, checkt of een stuk op een vak kan bewegen of niet
PROC canMove
	ARG @@color:dword, @@boardElem:dword, @@row:dword, @@col:dword RETURNS eax
	USES ebx, edx
	
	mov eax, [@@boardElem]
	mov dl, 11100000b ; plaats mask voor de drie eerste bits in edx
	movzx edx, dl
	AND edx, eax
	cmp edx, 0
	jne @@colorCheck ; als niet 0, er is een stuk op die vak
	cmp eax, 0 ; check of vak leeg is of buiten he bord
	jne @@outOfBounds
	call getOffset, offset movement, [@@row], [@@col]
	mov [byte ptr eax], 1 ; stuk kan op die vak bewegen en check verder in deze richting
	mov eax, 1 ; stuk kan op deze vak bewegen, doorgeven via eax
	jmp @@endOfFunction
	
	@@colorCheck:
		mov dl, 00010000b ; plaats mask voor color bit
		movzx edx, dl
		and edx, [@@boardElem]
		cmp edx, [@@color]
		je @@outOfBounds ; als kleur niet gelijk, vak markeren in movement array, maar return een 0 want loop moet stoppen
		call getOffset, offset movement, [@@row], [@@col]
		mov [byte ptr eax], 1 ; stuk kan op die vak bewegen en check verder in deze richting
		jmp @@outOfBounds
	
	@@outOfBounds:
		mov eax, 0 ; stuk kan op deze vak niet bewegen

	@@endOfFunction:
	ret
ENDP canMove


PROC canMoveSidewaysPawn
	ARG @@color:dword, @@boardElem:dword, @@row:dword, @@col:dword
	USES eax, ebx, edx
	
	mov eax, [@@boardElem]
	mov dl, 11100000b ; plaats mask voor de drie eerste bits in edx
	movzx edx, dl
	AND edx, eax
	cmp edx, 0
	je @@en_passant_check
	
	mov dl, 00010000b ; plaats mask voor color bit
	movzx edx, dl
	and edx, [@@boardElem]
	cmp edx, [@@color]
	je SHORT @@endOfFunction ; als kleur niet gelijk, vak markeren in movement array
	call getOffset, offset movement, [@@row], [@@col]
	mov [byte ptr eax], 1 ; stuk kan op die vak bewegen dus markeer in movement array
	jmp SHORT @@endOfFunction

	@@en_passant_check:
		cmp [@@boardElem], 0
		jne SHORT @@endOfFunction
		mov ebx, [@@col]
		cmp [@@color], 00010000b
		jne @@black_en_passant
		inc ebx
		jmp @@check_en_passant_pawn
	@@black_en_passant:
		dec ebx
	@@check_en_passant_pawn:
		call getElement, [@@row], ebx
		mov edx, eax
		and eax, 11100000b
		cmp eax, 00100000b
		jne SHORT @@endOfFunction
		mov eax, edx
		and eax, 00010000b
		cmp eax, [@@color]
		je SHORT @@endOfFunction
		test edx, EN_PASSANT_FLAG
		jz SHORT @@endOfFunction
		call getOffset, offset movement, [@@row], [@@col]
		mov [byte ptr eax], 1
	
	@@endOfFunction:
	ret
ENDP canMoveSidewaysPawn


; Helper functie, pion kan niet naar voren bewegen ongeacht de kleur van wat voor hem staat
PROC canMoveForwardPawn
	ARG @@boardElem:dword, @@row:dword, @@col:dword
	USES ebx, edx
	
	mov eax, [@@boardElem]
	mov dl, 11100000b ; plaats mask voor de drie eerste bits in edx
	movzx edx, dl
	AND edx, eax
	cmp edx, 0
	jne @@endOfFunction ; als niet 0, er is een stuk op die vak
	cmp eax, 0 ; check of vak leeg is of buiten he bord
	jne @@endOfFunction
	call getOffset, offset movement, [@@row], [@@col]
	mov [byte ptr eax], 1 ; stuk kan op die vak bewegen en check verder in deze richting
	mov eax, 1 ; stuk kan op deze vak bewegen, doorgeven via eax

	@@endOfFunction:
	ret
ENDP canMoveForwardPawn


; Checkt vakken of het spelbord in het patroon van een toren
PROC checkRookMovement
	ARG @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx
	
	mov ebx, [@@col]
	@@horLeftCheck:
		DEC ebx
		call getElement, [@@row], ebx ; return een byte in al
		call canMove, [@@color], eax, [@@row], ebx
		cmp eax, 1
		je @@horLeftCheck ; stuk kan verder bewegen in deze richting, ga verder met de checks in deze richting

	mov ebx, [@@col]
	@@horRightCheck:
		INC ebx ; enige verschil in deze loop
		call getElement, [@@row], ebx
		call canMove, [@@color], eax, [@@row], ebx
		cmp eax, 1
		je @@horRightCheck
	
	mov ebx, [@@row]
	@@verTopCheck:
		INC ebx
		call getElement, ebx, [@@col]
		call canMove, [@@color], eax, ebx, [@@col]
		cmp eax, 1
		je @@verTopCheck
	
	mov ebx, [@@row]
	@@verBotCheck:
		DEC ebx ; enige verschil hier
		call getElement, ebx, [@@col]
		call canMove, [@@color], eax, ebx, [@@col]
		cmp eax, 1
		je @@verBotCheck

	ret
ENDP checkRookMovement


PROC checkBishopMovement
	ARG @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx
	
	mov ebx, [@@row]
	mov ecx, [@@col]
	@@topLeftCheck:
		DEC ebx
		DEC ecx
		call getElement, ebx, ecx
		call canMove, [@@color], eax, ebx, ecx
		cmp eax, 1
		je @@topLeftCheck
	
	mov ebx, [@@row]
	mov ecx, [@@col]
	@@topRightCheck:
		DEC ebx
		INC ecx
		call getElement, ebx, ecx
		call canMove, [@@color], eax, ebx, ecx
		cmp eax, 1
		je @@topRightCheck
	
	mov ebx, [@@row]
	mov ecx, [@@col]
	@@bottomLeftCheck:
		INC ebx
		DEC ecx
		call getElement, ebx, ecx
		call canMove, [@@color], eax, ebx, ecx
		cmp eax, 1
		je @@bottomLeftCheck
		
	mov ebx, [@@row]
	mov ecx, [@@col]
	@@bottomRightCheck:
		INC ebx
		INC ecx
		call getElement, ebx, ecx
		call canMove, [@@color], eax, ebx, ecx
		cmp eax, 1
		je @@bottomRightCheck
	
	ret
ENDP checkBishopMovement


PROC checkKnightMovement
	ARG @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx
	
	; checks verticaal
	mov ebx, [@@row]
	add ebx, -2
	mov ecx, [@@col]
	DEC ecx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	add ecx, 2
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	add ebx, 4
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	add ecx, -2
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	; checks horizontaal
	mov ebx, [@@row]
	INC ebx
	mov ecx, [@@col]
	add ecx, 2
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	add ebx, -2
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	add ecx, -4
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	add ebx, 2
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx

	ret
ENDP checkKnightMovement


PROC checkKingMovement
	ARG @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx
	
	; manuele check van de vakken rond de koning, startend van recht boven en draaiend wijzerszin
	mov ebx, [@@row]
	DEC ebx
	mov ecx, [@@col]
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	INC ecx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	INC ebx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	INC ebx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	DEC ecx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	DEC ecx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	DEC ebx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	DEC ebx
	call getElement, ebx, ecx
	call canMove, [@@color], eax, ebx, ecx
	
	ret
ENDP checkKingMovement


PROC checkCastlingMovement
	ARG @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx, edx, esi, edi

	call getElement, [@@row], [@@col]
	mov [castle_king_piece], eax
	mov edx, eax
	and eax, 11100000b
	cmp eax, 11000000b
	jne @@done
	test edx, PIECE_MOVED_FLAG
	jnz @@done
	mov eax, edx
	and eax, 00010000b
	cmp eax, [@@color]
	jne @@done

	cld
	mov esi, offset movement
	mov edi, offset candidate_moves
	mov ecx, 64
	rep movsb
	call kingInCheck, [@@color]
	mov [castle_in_check], eax
	mov esi, offset candidate_moves
	mov edi, offset movement
	mov ecx, 64
	rep movsb
	cmp [castle_in_check], 0
	jne @@done

	mov eax, -1
	mov [castle_direction], eax
	@@direction_loop:
		mov eax, [castle_direction]
		cmp eax, -1
		jne @@right_rook
		mov eax, 0
		jmp @@rook_row_ready
	@@right_rook:
		mov eax, 7
	@@rook_row_ready:
		mov [castle_rook_row], eax
		call getElement, [castle_rook_row], [@@col]
		mov [castle_rook_piece], eax
		mov edx, eax
		and eax, 11100000b
		cmp eax, 01000000b
		jne @@next_direction
		mov eax, edx
		and eax, 00010000b
		cmp eax, [@@color]
		jne @@next_direction
		test edx, PIECE_MOVED_FLAG
		jnz @@next_direction

		mov eax, [@@row]
		add eax, [castle_direction]
		mov [castle_path_row], eax
	@@path_loop:
		mov eax, [castle_path_row]
		cmp eax, [castle_rook_row]
		je @@path_clear
		call getElement, [castle_path_row], [@@col]
		cmp eax, 0
		jne @@next_direction
		mov eax, [castle_path_row]
		add eax, [castle_direction]
		mov [castle_path_row], eax
		jmp @@path_loop

	@@path_clear:
		mov eax, [@@row]
		add eax, [castle_direction]
		mov [castle_transit_row], eax
		call getOffset, offset board, [@@row], [@@col]
		mov [castle_king_source_address], eax
		call getOffset, offset board, [castle_transit_row], [@@col]
		mov [castle_king_target_address], eax
		mov eax, [castle_king_source_address]
		mov [byte ptr eax], 0
		mov eax, [castle_king_piece]
		or eax, PIECE_MOVED_FLAG
		mov edx, [castle_king_target_address]
		mov [byte ptr edx], al
		call kingInCheck, [@@color]
		mov [castle_in_check], eax
		mov eax, [castle_king_source_address]
		mov edx, [castle_king_piece]
		mov [byte ptr eax], dl
		mov eax, [castle_king_target_address]
		mov [byte ptr eax], 0
		mov esi, offset candidate_moves
		mov edi, offset movement
		mov ecx, 64
		rep movsb
		cmp [castle_in_check], 0
		jne @@next_direction

		mov eax, [@@row]
		add eax, [castle_direction]
		add eax, [castle_direction]
		call getOffset, offset movement, eax, [@@col]
		mov [byte ptr eax], 1

	@@next_direction:
		cmp [castle_direction], -1
		jne @@done
		mov eax, 1
		mov [castle_direction], eax
		jmp @@direction_loop
	@@done:
	ret
ENDP checkCastlingMovement


PROC checkPawnMovement
	ARG @@hasMoved:dword, @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx, edx, esi
	
	mov ebx, [@@col]
	mov ecx, [@@color]
	mov dl, 00000000b
	movzx edx, dl ; check of stuk zwart is
	cmp ecx, edx
	je @@naarBeneden
	
	DEC ebx ; stuk is wit, check beweging naar boven
	jmp @@firstCheck
	@@naarBeneden:
		INC ebx
	
	@@firstCheck:
		mov ecx, [@@row]
		call getElement, ecx, ebx
		call canMoveForwardPawn, eax, ecx, ebx
		mov esi, eax
		DEC ecx
		call getElement, ecx, ebx
		call canMoveSidewaysPawn, [@@color], eax, ecx, ebx
		add ecx, 2
		call getElement, ecx, ebx
		call canMoveSidewaysPawn, [@@color], eax, ecx, ebx
	
	mov ecx, [@@hasMoved]
	test ecx, PIECE_MOVED_FLAG
	jnz @@endOfFunction
	cmp esi, 1
	jne @@endOfFunction
	
	mov ecx, [@@color]
	mov dl, 00000000b
	movzx edx, dl ; check of stuk zwart is
	cmp ecx, edx
	je @@nogLager
	
	DEC ebx ; check nog hoger
	jmp @@secondCheck
	@@nogLager:
		INC ebx
	
	@@secondCheck:
		call getElement, [@@row], ebx
		call canMoveForwardPawn, eax, [@@row], ebx
	
	@@endOfFunction:
	ret
ENDP checkPawnMovement


PROC generatePieceMoves
	ARG @@piece:dword, @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx, edx, esi

	call clearMovement, 1
	mov eax, [@@piece]
	shr eax, 5
	cmp eax, 1
	je @@pawn_moves
	cmp eax, 2
	je @@rook_moves
	cmp eax, 3
	je @@knight_moves
	cmp eax, 4
	je @@bishop_moves
	cmp eax, 5
	je @@queen_moves
	cmp eax, 6
	je @@king_moves
	ret

	@@pawn_moves:
		mov eax, [@@piece]
		and eax, PIECE_MOVED_FLAG
		call checkPawnMovement, eax, [@@color], [@@row], [@@col]
		ret
	@@rook_moves:
		call checkRookMovement, [@@color], [@@row], [@@col]
		ret
	@@knight_moves:
		call checkKnightMovement, [@@color], [@@row], [@@col]
		ret
	@@bishop_moves:
		call checkBishopMovement, [@@color], [@@row], [@@col]
		ret
	@@queen_moves:
		call checkRookMovement, [@@color], [@@row], [@@col]
		call checkBishopMovement, [@@color], [@@row], [@@col]
		ret
	@@king_moves:
		call checkKingMovement, [@@color], [@@row], [@@col]
		call checkCastlingMovement, [@@color], [@@row], [@@col]
		ret
ENDP generatePieceMoves


PROC filterLegalMoves
	ARG @@color:dword, @@fromRow:dword, @@fromCol:dword
	USES eax, ebx, ecx, edx, esi, edi

	mov eax, [@@color]
	mov [filter_color], eax
	mov eax, [@@fromRow]
	mov [filter_from_row], eax
	mov eax, [@@fromCol]
	mov [filter_from_col], eax

	cld
	mov esi, offset movement
	mov edi, offset candidate_moves
	mov ecx, 64
	rep movsb

	mov edi, offset legal_moves
	xor eax, eax
	mov ecx, 64
	rep stosb
	xor eax, eax
	mov [filter_index], eax

	@@candidate_loop:
		mov eax, [filter_index]
		cmp eax, 64
		jae @@filter_done
		mov esi, offset candidate_moves
		cmp [byte ptr esi+eax], 1
		jne @@next_candidate

		mov eax, [filter_index]
		xor edx, edx
		mov ebx, 8
		div ebx
		mov [filter_to_row], eax
		mov [filter_to_col], edx

		call getOffset, offset board, [filter_from_row], [filter_from_col]
		mov [filter_source_address], eax
		mov esi, eax
		movzx eax, [byte ptr esi]
		mov [filter_piece], eax

		call getOffset, offset board, [filter_to_row], [filter_to_col]
		mov [filter_target_address], eax
		mov esi, eax
		movzx eax, [byte ptr esi]
		mov [filter_captured_piece], eax

		mov eax, [filter_captured_piece]
		shr eax, 5
		cmp eax, 6
		je @@next_candidate

		xor eax, eax
		mov [filter_is_en_passant], eax
		mov [filter_is_castling], eax
		mov eax, [filter_piece]
		shr eax, 5
		cmp eax, 1
		jne SHORT @@detect_castling
		cmp [filter_captured_piece], 0
		jne SHORT @@detect_castling
		mov eax, [filter_from_row]
		cmp eax, [filter_to_row]
		je SHORT @@detect_castling
		mov eax, [filter_from_col]
		cmp eax, [filter_to_col]
		je SHORT @@detect_castling
		call getOffset, offset board, [filter_to_row], [filter_from_col]
		mov [filter_ep_capture_address], eax
		movzx eax, [byte ptr eax]
		mov edx, eax
		and eax, 11100000b
		cmp eax, 00100000b
		jne SHORT @@detect_castling
		test edx, EN_PASSANT_FLAG
		jz SHORT @@detect_castling
		mov eax, edx
		and eax, 00010000b
		cmp eax, [filter_color]
		je SHORT @@detect_castling
		mov [filter_ep_capture_piece], edx
		mov eax, 1
		mov [filter_is_en_passant], eax

	@@detect_castling:
		mov eax, [filter_piece]
		shr eax, 5
		cmp eax, 6
		jne @@simulate_candidate
		mov eax, [filter_from_col]
		cmp eax, [filter_to_col]
		jne @@simulate_candidate
		mov eax, [filter_to_row]
		sub eax, [filter_from_row]
		cmp eax, 2
		je @@prepare_castling_simulation
		cmp eax, -2
		jne @@simulate_candidate
	@@prepare_castling_simulation:
		mov eax, 1
		mov [filter_is_castling], eax
		mov eax, 0
		mov edx, [filter_to_row]
		cmp edx, [filter_from_row]
		jl @@filter_rook_source_ready
		mov eax, 7
	@@filter_rook_source_ready:
		call getOffset, offset board, eax, [filter_from_col]
		mov [filter_castle_rook_source_address], eax
		movzx eax, [byte ptr eax]
		mov [filter_castle_rook_piece], eax
		mov eax, [filter_from_row]
		add eax, [filter_to_row]
		shr eax, 1
		call getOffset, offset board, eax, [filter_from_col]
		mov [filter_castle_rook_target_address], eax
		movzx eax, [byte ptr eax]
		mov [filter_castle_rook_target_piece], eax

	@@simulate_candidate:
		mov eax, [filter_source_address]
		mov [byte ptr eax], 0
		mov eax, [filter_piece]
		or eax, PIECE_MOVED_FLAG
		mov edx, [filter_target_address]
		mov [byte ptr edx], al
		cmp [filter_is_en_passant], 1
		jne @@simulate_castling
		mov eax, [filter_ep_capture_address]
		mov [byte ptr eax], 0
	@@simulate_castling:
		cmp [filter_is_castling], 1
		jne @@check_simulated_position
		mov eax, [filter_castle_rook_source_address]
		mov [byte ptr eax], 0
		mov eax, [filter_castle_rook_piece]
		or eax, PIECE_MOVED_FLAG
		mov edx, [filter_castle_rook_target_address]
		mov [byte ptr edx], al

	@@check_simulated_position:
		call kingInCheck, [filter_color]
		mov [filter_in_check], eax

		cmp [filter_is_castling], 1
		jne @@restore_en_passant_capture
		mov eax, [filter_castle_rook_source_address]
		mov edx, [filter_castle_rook_piece]
		mov [byte ptr eax], dl
		mov eax, [filter_castle_rook_target_address]
		mov edx, [filter_castle_rook_target_piece]
		mov [byte ptr eax], dl
	@@restore_en_passant_capture:
		cmp [filter_is_en_passant], 1
		jne @@restore_king_move
		mov eax, [filter_ep_capture_address]
		mov edx, [filter_ep_capture_piece]
		mov [byte ptr eax], dl
	@@restore_king_move:
		mov eax, [filter_source_address]
		mov edx, [filter_piece]
		mov [byte ptr eax], dl
		mov eax, [filter_target_address]
		mov edx, [filter_captured_piece]
		mov [byte ptr eax], dl

		cmp [filter_in_check], 1
		je @@next_candidate
		call getOffset, offset legal_moves, [filter_to_row], [filter_to_col]
		mov [byte ptr eax], 1

	@@next_candidate:
		mov eax, [filter_index]
		inc eax
		mov [filter_index], eax
		jmp @@candidate_loop

	@@filter_done:
	mov esi, offset legal_moves
	mov edi, offset movement
	mov ecx, 64
	rep movsb
	ret
ENDP filterLegalMoves


PROC kingInCheck
	ARG @@color:dword RETURNS eax
	USES ebx, ecx, edx, esi, edi

	mov eax, [@@color]
	mov [check_color], eax
	mov eax, -1
	mov [check_king_row], eax
	mov [check_king_col], eax
	xor eax, eax
	mov [check_scan_index], eax

	@@find_king:
		cmp [check_scan_index], 64
		jae @@king_found
		mov eax, [check_scan_index]
		xor edx, edx
		mov ebx, 8
		div ebx
		mov [check_scan_row], eax
		mov [check_scan_col], edx
		call getElement, [check_scan_row], [check_scan_col]
		mov esi, eax
		shr eax, 5
		cmp eax, 6
		jne @@next_king_square
		mov eax, esi
		and eax, 00010000b
		cmp eax, [check_color]
		jne @@next_king_square
		mov eax, [check_scan_row]
		mov [check_king_row], eax
		mov eax, [check_scan_col]
		mov [check_king_col], eax
		jmp @@king_found

	@@next_king_square:
		mov eax, [check_scan_index]
		inc eax
		mov [check_scan_index], eax
		jmp @@find_king

	@@king_found:
		cmp [check_king_row], -1
		je @@in_check
		call clearMovement, 1
		xor eax, eax
		mov [check_scan_index], eax

	@@attacker_loop:
		cmp [check_scan_index], 64
		jae @@check_attack_map
		mov eax, [check_scan_index]
		xor edx, edx
		mov ebx, 8
		div ebx
		mov [check_scan_row], eax
		mov [check_scan_col], edx
		call getElement, [check_scan_row], [check_scan_col]
		mov esi, eax
		mov eax, esi
		and eax, 11100000b
		jz @@next_attacker
		mov eax, esi
		and eax, 00010000b
		cmp eax, [check_color]
		je @@next_attacker
		mov [check_attacker_color], eax

		mov eax, esi
		shr eax, 5
		cmp eax, 1
		je @@pawn_attack
		cmp eax, 2
		je @@rook_attack
		cmp eax, 3
		je @@knight_attack
		cmp eax, 4
		je @@bishop_attack
		cmp eax, 5
		je @@queen_attack
		cmp eax, 6
		je @@king_attack
		jmp @@next_attacker

	@@pawn_attack:
		mov eax, esi
		and eax, PIECE_MOVED_FLAG
		call checkPawnMovement, eax, [check_attacker_color], [check_scan_row], [check_scan_col]
		jmp @@next_attacker
	@@rook_attack:
		call checkRookMovement, [check_attacker_color], [check_scan_row], [check_scan_col]
		jmp @@next_attacker
	@@knight_attack:
		call checkKnightMovement, [check_attacker_color], [check_scan_row], [check_scan_col]
		jmp @@next_attacker
	@@bishop_attack:
		call checkBishopMovement, [check_attacker_color], [check_scan_row], [check_scan_col]
		jmp @@next_attacker
	@@queen_attack:
		call checkRookMovement, [check_attacker_color], [check_scan_row], [check_scan_col]
		call checkBishopMovement, [check_attacker_color], [check_scan_row], [check_scan_col]
		jmp @@next_attacker
	@@king_attack:
		call checkKingMovement, [check_attacker_color], [check_scan_row], [check_scan_col]

	@@next_attacker:
		mov eax, [check_scan_index]
		inc eax
		mov [check_scan_index], eax
		jmp @@attacker_loop

	@@check_attack_map:
		call getOffset, offset movement, [check_king_row], [check_king_col]
		cmp [byte ptr eax], 1
		je @@in_check
		xor eax, eax
		ret

	@@in_check:
	mov eax, 1
	ret
ENDP kingInCheck


PROC getGameStatus
	ARG @@color:dword RETURNS eax
	USES ebx, ecx, edx, esi, edi

	mov eax, [@@color]
	mov [status_color], eax
	call kingInCheck, eax
	mov [status_in_check], eax
	mov eax, [check_king_row]
	mov [checked_king_row], eax
	mov eax, [check_king_col]
	mov [checked_king_col], eax
	xor eax, eax
	mov [status_scan_index], eax

	@@piece_loop:
		cmp [status_scan_index], 64
		jae @@no_legal_moves
		mov eax, [status_scan_index]
		xor edx, edx
		mov ebx, 8
		div ebx
		mov [status_scan_row], eax
		mov [status_scan_col], edx
		call getElement, [status_scan_row], [status_scan_col]
		mov [status_piece], eax
		and eax, 11100000b
		jz @@next_piece
		mov eax, [status_piece]
		and eax, 00010000b
		cmp eax, [status_color]
		jne @@next_piece

		call generatePieceMoves, [status_piece], [status_color], [status_scan_row], [status_scan_col]
		call filterLegalMoves, [status_color], [status_scan_row], [status_scan_col]
		xor eax, eax
		mov [status_move_index], eax

	@@legal_move_scan:
		cmp [status_move_index], 64
		jae @@next_piece
		mov eax, [status_move_index]
		mov esi, offset movement
		cmp [byte ptr esi+eax], 1
		je @@legal_move_found
		mov eax, [status_move_index]
		inc eax
		mov [status_move_index], eax
		jmp @@legal_move_scan

	@@legal_move_found:
		mov eax, [status_in_check]
		ret

	@@next_piece:
		mov eax, [status_scan_index]
		inc eax
		mov [status_scan_index], eax
		jmp @@piece_loop

	@@no_legal_moves:
		cmp [status_in_check], 1
		je @@checkmate
		mov eax, 3
		ret

	@@checkmate:
		mov eax, 2
		ret
ENDP getGameStatus


PROC initializeDrawTracking
	ARG @@color:dword
	USES eax

	xor eax, eax
	mov [halfmove_clock], eax
	mov [position_history_count], eax
	mov [repetition_draw], eax
	call recordPosition, [@@color]
	ret
ENDP initializeDrawTracking


PROC recordPosition
	ARG @@color:dword RETURNS eax
	USES ebx, ecx, edx, esi, edi

	cld
	mov esi, offset board
	mov edi, offset position_snapshot
	mov ecx, 64
	rep movsb

	xor eax, eax
	mov [position_scan_index], eax
	@@normalize_position:
		mov eax, [position_scan_index]
		cmp eax, 64
		jae @@store_side_to_move
		mov esi, offset position_snapshot
		movzx edx, [byte ptr esi+eax]
		mov ecx, edx
		shr ecx, 5
		cmp ecx, 0
		je @@next_position_byte
		cmp ecx, 1
		je @@next_position_byte
		cmp ecx, 2
		je @@next_position_byte
		cmp ecx, 6
		je @@next_position_byte
		; Keep moved state for pawns, kings, and rooks because it affects rights.
		and edx, 0FFFFFFFEh
		mov [byte ptr esi+eax], dl
	@@next_position_byte:
		mov eax, [position_scan_index]
		inc eax
		mov [position_scan_index], eax
		jmp @@normalize_position

	@@store_side_to_move:
		mov eax, [@@color]
		and eax, 00010000b
		shr eax, 4
		mov edi, offset position_snapshot
		mov [byte ptr edi+64], al

	xor eax, eax
	mov [position_match_count], eax
	mov [position_scan_index], eax
	@@compare_history:
		mov eax, [position_scan_index]
		cmp eax, [position_history_count]
		jae @@check_repetition
		imul eax, eax, POSITION_SIZE
		mov esi, offset position_history
		add esi, eax
		mov edi, offset position_snapshot
		mov ecx, POSITION_SIZE
		repe cmpsb
		jne @@next_history_entry
		mov eax, [position_match_count]
		inc eax
		mov [position_match_count], eax
	@@next_history_entry:
		mov eax, [position_scan_index]
		inc eax
		mov [position_scan_index], eax
		jmp @@compare_history

	@@check_repetition:
		cmp [position_match_count], 2
		jb @@store_position
		mov eax, 1
		mov [repetition_draw], eax

	@@store_position:
		mov eax, [position_history_count]
		cmp eax, POSITION_HISTORY_CAPACITY
		jae @@return_status
		imul eax, eax, POSITION_SIZE
		mov edi, offset position_history
		add edi, eax
		mov esi, offset position_snapshot
		mov ecx, POSITION_SIZE
		rep movsb
		mov eax, [position_history_count]
		inc eax
		mov [position_history_count], eax

	@@return_status:
		mov eax, [repetition_draw]
		ret
ENDP recordPosition


PROC getDrawStatus
	cmp [halfmove_clock], FIFTY_MOVE_HALF_TURNS
	jae @@fifty_move_draw
	cmp [repetition_draw], 1
	je @@repetition_draw
	xor eax, eax
	ret

	@@fifty_move_draw:
		mov eax, 1
		ret
	@@repetition_draw:
		mov eax, 2
		ret
ENDP getDrawStatus


PROC promotePawn
	ARG @@row:dword, @@col:dword, @@pieceType:dword
	USES eax, ebx, edx

	call getOffset, offset board, [@@row], [@@col]
	mov ebx, eax
	movzx eax, [byte ptr ebx]
	and eax, 00010001b
	mov edx, [@@pieceType]
	shl edx, 5
	or eax, edx
	mov [byte ptr ebx], al
	ret
ENDP promotePawn


; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	board 	db 01000000b, 00100000b, 0, 0, 0, 0, 00110000b, 01010000b
			db 01100000b, 00100000b, 0, 0, 0, 0, 00110000b, 01110000b
			db 10000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10010000b
			db 11000000b, 00100000b, 0, 0, 0, 0, 00110000b, 11010000b
			db 10100000b, 00100000b, 0, 0, 0, 0, 00110000b, 10110000b
			db 10000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10010000b
			db 01100000b, 00100000b, 0, 0, 0, 0, 00110000b, 01110000b
			db 01000000b, 00100000b, 0, 0, 0, 0, 00110000b, 01010000b
	
	movement 	db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0
				db 0, 0, 0, 0, 0, 0, 0, 0

	candidate_moves db 64 dup (0)
	legal_moves db 64 dup (0)
	filter_color dd 0
	filter_from_row dd 0
	filter_from_col dd 0
	filter_to_row dd 0
	filter_to_col dd 0
	filter_index dd 0
	filter_piece dd 0
	filter_captured_piece dd 0
	filter_source_address dd 0
	filter_target_address dd 0
	filter_in_check dd 0
	filter_is_en_passant dd 0
	filter_ep_capture_address dd 0
	filter_ep_capture_piece dd 0
	filter_is_castling dd 0
	filter_castle_rook_source_address dd 0
	filter_castle_rook_target_address dd 0
	filter_castle_rook_piece dd 0
	filter_castle_rook_target_piece dd 0
	check_color dd 0
	check_attacker_color dd 0
	check_scan_index dd 0
	check_scan_row dd 0
	check_scan_col dd 0
	check_king_row dd -1
	check_king_col dd -1
	checked_king_row dd -1
	checked_king_col dd -1
	status_color dd 0
	status_in_check dd 0
	status_scan_index dd 0
	status_scan_row dd 0
	status_scan_col dd 0
	status_piece dd 0
	status_move_index dd 0
	halfmove_clock dd 0
	position_history_count dd 0
	position_match_count dd 0
	position_scan_index dd 0
	repetition_draw dd 0
	move_source_address dd 0
	move_target_address dd 0
	move_ep_capture_address dd 0
	move_piece dd 0
	move_piece_type dd 0
	move_target_piece dd 0
	move_is_en_passant dd 0
	move_rook_source_row dd 0
	move_rook_target_row dd 0
	move_rook_piece dd 0
	castle_king_piece dd 0
	castle_king_source_address dd 0
	castle_king_target_address dd 0
	castle_in_check dd 0
	castle_direction dd 0
	castle_rook_row dd 0
	castle_rook_piece dd 0
	castle_path_row dd 0
	castle_transit_row dd 0
	position_snapshot db 65 dup (0)
	position_history db 6565 dup (0)

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END
