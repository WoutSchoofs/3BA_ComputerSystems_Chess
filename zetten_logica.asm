IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

CODESEG

PROC check_zet
    ARG @@moveArrayPtr:dword, @@numberOfVectors:dword, @@columns:dword, @@rows:dword  RETURNS eax
    USES ebx, ecx
    mov eax, [@@moveArrayPtr]       ; EAX wijst naar de eerste pointer in de tabel
    mov ecx, [@@numberOfVectors]    ; ECX telt hoeveel vectoren gecontroleerd worden
    cmp ecx, 0
    jz end_loop                     ; geen vectoren: sla de lus over en retourneer 0
    checkloop:
        mov ebx, [eax]              ; EBX wijst naar de huidige (kolom, rij)-vector
        add eax, 4                  ; volgende tabelentry; iedere pointer is 4 bytes
        push eax                    ; bewaar de tabelpointer terwijl EAX vergelijkingswaarden bevat
        
        mov eax, [@@columns]
        cmp eax, [ebx]              ; vergelijk de kolomverplaatsing
        jne next_move

        mov eax, [@@rows]
        cmp eax, [ebx + 4]          ; het rij-element staat 4 bytes na het kolom-element
        jne next_move

        pop eax                     ; herstel de tabelpointer zodat de stack in balans blijft
        mov eax, 1                  ; vector gevonden: retourneer 1 in EAX
        jmp end_proc

        next_move:
        pop eax                     ; herstel de tabelpointer voor de volgende iteratie
    loop checkloop
    end_loop:
    mov eax, 0
    end_proc:
    RET
ENDP check_zet


start:
    sti
    cld

    mov esi, 2
    mov edi, -1
    call check_zet, offset loper_zetten, loper_zetten_aantal, esi, edi
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
loper_zetten_aantal equ 4


stack 100

END start