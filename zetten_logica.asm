IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

CODESEG

PROC check_zet
    ARG @@moveArrayPtr:dword, @@numberOfVectors:dword, @@columns:dword, @@rows:dword  RETURNS eax
    USES ebx, ecx, edx, esi, edi
    mov edx, [@@moveArrayPtr] ;
    mov eax, 0
    mov esi, [@@columns]
    mov edi, [@@rows]
    mov ecx, [@@numberOfVectors]
    cmp ecx, 0
    jz end_loop
    checkloop:
        mov ebx, [edx] ;dit bekijkt de i-de pointer in de array, dus de i-de mogelijke vector
        add edx, 4
        cmp esi, [ebx]; het eerste element van de array achter die pointer is de kolomverplaatsing
        jne next_move
        cmp edi, [ebx + 4]; het tweede element is de rijverplaatsing
        jne next_move
        mov eax, 1; als deze zet kan geven we als output 1 en moet de rest niet meer gecheckt worden
        jmp end_loop
        next_move:
        inc eax
    loop checkloop
    mov eax, 0
    end_loop:
    RET
ENDP check_zet


start:
    sti
    cld

    mov eax, 4
    mov esi, -1
    mov edi, 3
    call check_zet, offset loper_zetten, eax, esi, edi
    mov ah, 9
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

end_program:
    mov ah,0
    int 16h
    mov ax,4C00h
    int 21h

DATASEG

loper_linksboven dd 1,-1
loper_linksonder dd -1,-1
loper_rechtsonder dd -1,1
loper_rechtsboven dd 1,1

loper_zetten dd offset loper_linksboven
             dd offset loper_linksonder
             dd offset loper_rechtsonder
             dd offset loper_rechtsboven
loper_zetten_aantal equ ($-loper_zetten)/4


stack 100

END start
