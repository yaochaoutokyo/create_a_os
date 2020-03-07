%include "boot.inc"
[bits 32]
section .data
put_int_buffer dq 0

section .text
global put_char
put_char:
    pushad
    mov ax,SEL_VEDIO_SEG
    mov gs,ax

    ; get cursor location (high 8 bits)
    mov dx,0x03d4
    mov al,0x0e
    out dx,al
    mov dx,0x03d5
    in al,dx
    mov ah,al

    ; get cursor location (low 8 bits)
    mov dx,0x03d4
    mov al,0x0f
    out dx,al
    mov dx,0x03d5
    in al,dx

    mov bx,ax
    ; get character to print from stack
    mov ecx,[esp + 36]

    ;process according to the character
    cmp cl,0xd
    jz .is_carriage_return
    cmp cl,0xa
    jz .is_line_feed
    cmp cl,0x8
    jz .is_backspace
    jmp .put_other

.is_backspace:
    dec bx
    shl bx,1
    mov byte [gs:bx],0x20
    inc bx
    mov byte [gs:bx],0x07
    shr bx,1
    jmp .set_cursor

.put_other:
    shl bx,1
    mov [gs:bx],cl
    inc bx
    mov byte [gs:bx],0x07
    shr bx,1
    inc bx
    ; if need roll-screen
    cmp bx,2000
    jl .set_cursor

.is_line_feed:
.is_carriage_return:
    xor dx,dx
    mov ax,bx
    mov si,80
    div si
    ; CR back to the start of current line
    sub bx,dx

.is_carriage_return_end:
    ; LF to next line
    add bx,80
    ; if need roll-screen
    cmp bx,2000
.is_line_feed_end:
    jl .set_cursor

.roll_screen:
    ; copy the contects from second line to first line, except for the last line
    cld
    mov ecx,960
    ; move from ds:esi to es:edi, es and ds are 4G flat segment
    mov esi,0xc00b80a0
    mov edi,0xc00b8000
    rep movsd

    ; clear last line
    mov ebx,3840
    mov ecx,80

.cls:
    mov word [gs:ebx],0x0720
    add ebx,2
    loop .cls
    ; set cursor to the start of last line
    mov bx,1920

.set_cursor:
    ; set high 8 bits
    mov dx,0x03d4
    mov al,0x0e
    out dx,al
    mov dx,0x03d5
    mov al,bh
    out dx,al

    ; set low 8 bits
    mov dx,0x03d4
    mov al,0x0f
    out dx,al
    mov dx,0x03d5
    mov al,bl
    out dx,al

.put_char_done:
    popad
    ret



global put_str
put_str:
    push ebx
    push ecx
    xor ecx,ecx
    mov ebx,[esp + 12]
.goon:
    mov cl,[ebx]
    cmp cl,0
    jz .str_over

    ; pass param to put_char using cdecl conventions
    push ecx
    call put_char
    add esp,4

    inc ebx
    jmp .goon

.str_over:
    pop ecx
    pop ebx
    ret



global put_int
put_int:
    pushad
    mov ebp,esp
    ; get the 32 bits hex from stack
    mov eax,[ebp + 36]
    mov edx,eax
    ; initial offset 
    mov edi,7
    mov ecx,8
    mov ebx,put_int_buffer

    ; every 4 bits process once
.16based_4bits:
    and edx,0x0000000f
    cmp edx,9
    jg .is_A2F

    add edx,'0'
    jmp .store

.is_A2F:
    sub edx,10
    add edx,'A'

.store:
    mov [ebx + edi],dl
    dec edi
    ; next 4 bits
    shr eax,4
    mov edx,eax
    loop .16based_4bits

.ready_to_print:
    inc edi
.skip_prefix_0:
    cmp edi,8
    je .full0

.go_on_skip:
    mov cl, [put_int_buffer]
    inc edi
    cmp cl, '0'
    je .skip_prefix_0
    dec edi
    jmp .put_each_num

.full0:
    mov cl,'0'
.put_each_num:
    ; pass param to put_char using cdecl conventions
    push ecx
    call put_char
    add esp,4

    inc edi
    mov cl,[put_int_buffer + edi]
    cmp edi,8
    jl .put_each_num
    
    popad
    ret
