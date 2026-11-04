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

PUBLIC getElement, checkRookMovement, checkBishopMovement, checkKnightMovement, checkKingMovement, checkPawnMovement, printBoard, getOffset, moveElement, movement, board

INCLUDE "CHESS.INC"


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
		call getOffset, [@@arr], ebx, ecx
		mov dl, [byte ptr eax]
		movzx edx, dl
		call printUnsignedInteger, edx
		mov ah , 2h
		mov dl, 20h		; Space.
		int 21h
		INC ebx
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

; Beweegt een element van een positie naar een andere en laat een 0 achter
PROC moveElement
	ARG @@fromRow:dword, @@fromCol:dword, @@toRow:dword, @@toCol:dword
	USES eax, ebx, ecx
	
	call getOffset, offset board, [@@fromRow], [@@fromCol]
	mov ebx, eax
	mov cl, [ebx]
	call getOffset, offset board, [@@toRow], [@@toCol]
	mov [eax], cl
	mov [byte ptr ebx], 0
	
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
	je @@endOfFunction ; als  0, is er geen stuk op die vak en kan pion daar niet bewegen
	
	mov dl, 00010000b ; plaats mask voor color bit
	movzx edx, dl
	and edx, [@@boardElem]
	cmp edx, [@@color]
	je @@endOfFunction ; als kleur niet gelijk, vak markeren in movement array
	call getOffset, offset movement, [@@row], [@@col]
	mov [byte ptr eax], 1 ; stuk kan op die vak bewegen dus markeer in movement array
	
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


PROC checkPawnMovement
	ARG @@firstMove:dword, @@color:dword, @@row:dword, @@col:dword
	USES eax, ebx, ecx, edx
	
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
		DEC ecx
		call getElement, ecx, ebx
		call canMoveSidewaysPawn, [@@color], eax, ecx, ebx
		add ecx, 2
		call getElement, ebx, ecx
		call canMoveSidewaysPawn, [@@color], eax, ecx, ebx
	
	mov ecx, [@@firstMove]
	mov dl, 00001000b
	movzx edx, dl
	cmp ecx, edx
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


; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	board 	db 01000000b, 00100000b, 0, 0, 0, 0, 00110000b, 01010000b
			db 01100000b, 00100000b, 0, 0, 0, 0, 00110000b, 01110000b
			db 10000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10010000b
			db 10100000b, 00100000b, 0, 0, 0, 0, 00110000b, 11010000b
			db 11000000b, 00100000b, 0, 0, 0, 0, 00110000b, 10110000b
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

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END
