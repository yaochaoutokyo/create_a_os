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
message:
    db "Protection: Hello, world",0
gdt_remain:
    times 60 dq 0

loader_start:
    mov ax,cs
    mov ds,ax
    mov ss,ax
    mov sp,LOADER_BASE_ADDR

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
