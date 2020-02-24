%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR

    jmp loader_start

gdt_base:
    dq DESC_ZERO
    dq DESC_CODE_FLAT
    dq DESC_DATA_FLAT
gdt_ptr:
    dw $ - gdt_base - 1
    dd gdt_base
gdt_remain:
    times 60 dq 0
message:
    db "Protection: "
mem_size:
    dd 0
ards_buf:
    times 200 db 0
ards_count:
    dw 0

read_mem_size:
    ; firstly, try 0xe820 subroutine
    ; input eax,ebx(next ards),es:di(destination),ecx(length of ards),edx(signature, 'SMAP')
.read_mem_by_0xe820:
    xor ebx,ebx
    mov edx,0x534d4150
    mov di,ards_buf
.get_ards:
    ; after int 0x15, eax=0x534d4150, need refresh
    mov eax,0xe820
    mov ecx,20
    int 0x15
    ; if cf=1, means error, try 0xe801
    jc .read_mem_by_0xe801
    inc word [ards_count]
    add di,cx
    cmp ebx,0
    jnz .get_ards

    ; after get all ards, find max mem length among them
    mov cx,[ards_count]
    xor edx,edx
    mov ebx,ards_buf
.find_max_mem_loop:
    mov eax,[ebx]
    add eax,[ebx+8]
    cmp edx,eax
    jge .next_ards
    mov edx,eax

.next_ards:
    add ebx,20
    loop .find_max_mem_loop
    jmp .mem_get_ok


; input eax, only support 4G
.read_mem_by_0xe801:
    mov eax,0xe801
    int 0x15
    ; if failed, try 0x88
    jc .read_mem_by_0x88
    ; ax and cx store <= 15MB part, unit 1KB
    mov cx,0x400
    mul cx
    shr edx,16
    and eax,0x0000ffff
    or edx,eax
    add edx,0x100000
    mov esi,edx

    ; bx and dx store > 15MB(not clude first 1MB) part, unit 64kb
    xor eax,eax
    mov ax,bx
    mov ecx,0x10000
    mul ecx

    add esi,eax
    mov edx,esi
    jmp .mem_get_ok

    ; input eax, only support 64MB(not include first 1MB)
.read_mem_by_0x88:
    mov ah, 0x88
    int 0x15
    jc .error_hlt
    and eax,0x0000ffff
    
    mov cx,0x400
    mul cx
    shl edx,16
    or edx,eax
    add edx,0x100000

.mem_get_ok:
    mov [mem_size],edx
    ret

.error_hlt:
    hlt

loader_start:
    mov ax,cs
    mov ds,ax
    mov ss,ax
    mov es,ax
    mov sp,LOADER_BASE_ADDR

    ; read memory through BIOS 0x15 interrupt
    call read_mem_size

    ; enter protection model
    ; open A20
    in al,0x92
    or al,0000_0010b
    out 0x92,al

    ; load gdt
    lgdt [gdt_ptr]

    ; enable PE in cr0
    mov eax,cr0
    or eax,0x00000001
    mov cr0,eax

    ; flush pipeline
    ; 0x0008 is 0x0000_0000_0000_1000, means index=1, TI=1, RPL=0
    ; notice: dword requires complier to take effactive address as 32 bits instead of 16 bits
    jmp dword 0x0008:p_model_start 

    [bits 32]
p_model_start:
    mov eax,0x0010
    mov ds,eax
    mov es,eax
    mov ss,eax
    ; for 32bits model, esp is the stack pointer
    mov esp,LOADER_BASE_ADDR
    mov esi,message
    ; edi store address for vedio memory
    mov edi,0xb8000

.print:
    mov al,[esi]
    cmp byte al,0
    jz .clear
    mov [es:edi],al

    inc esi
    add edi,2
    jmp .print

.clear:
    cmp edi,4320
    jz .end
    mov byte [es:edi],0
    add edi,2
    loop .clear

.end:
    jmp $
