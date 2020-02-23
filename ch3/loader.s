%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
    mov ax,cs
    mov ds,ax
    mov ss,ax
    mov sp,LOADER_BASE_ADDR
    mov ax,0xb800
    mov es,ax

    mov si,message
    mov di,0

.print:
    mov al,[si]
    cmp byte al,0
    jz .clear
    mov [es:di],al

    inc si
    add di,2
    jmp .print

.clear:
    cmp di,4320
    jz .end
    mov byte [es:di],0
    add di,2
    loop .clear

.end:
    jmp $

    message db "Loader: Hello, world",0
