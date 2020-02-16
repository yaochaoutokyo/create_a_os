section mbr vstart=0x7c00
    mov ax,cs
    mov ds,ax
    mov ss,ax
    mov sp,0x7c00
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

    message db "Hello, world",0
    times 510-($-$$) db 0
    db 0x55,0xaa
