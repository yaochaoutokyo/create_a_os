%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR

    jmp loader_start

gdt_base:
    dq DESC_ZERO
    dq DESC_CODE_FLAT
    dq DESC_DATA_FLAT
    dq DESC_VEDIO_SEG
gdt_ptr:
    dw $ - gdt_base - 1
    dd gdt_base
gdt_remain:
    times 60 dq 0
message_pg:
    db "Protection model open!",0
message_pr:
    db "Page model open!",0
message_ld_kr:
    db "Loading Kernel...",0
message_kr:
    db "Kernel running...",0
mem_size:
    dd 0
ards_buf:
    times 200 db 0
ards_count:
    dw 0

; function: read memroy size, save it to [mem_size]
; must run in real model
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

    ; clear screen by BIOS 0x10
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0
    mov dx, 0x184f
    int 0x10

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
    jmp dword SEL_CODE_FLAT:pr_model_start 

    [bits 32]
; function: print message to screen
; must run in protection model
; input: esi -> message source address; edi -> vedio memory address
print_out:
    push esi
    push edi
    push eax
    ; gs = video seg, avoid previlege transmit 
    mov eax,SEL_VEDIO_SEG
    mov gs,eax
.print_loop:
    mov al,[esi]
    cmp byte al,0
    jz .print_over
    mov [gs:edi],al
    inc esi
    add edi,2
    jmp .print_loop
.print_over:
    pop eax
    pop edi
    pop esi
    ret

; function: read disk in protection model
; input: eax -> LBA address; es:ebx -> destination addr; ecx -> sector num
rd_disk_m_32:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; store state
    mov esi,eax
    mov edi,ecx

    ; sector count, 8 bits
    mov al,cl
    mov dx,0x1f2
    out dx,al

    ; restore eax
    mov eax,esi

    ; LBA low, 8 bits
    mov dx,0x1f3
    out dx,al

    ; LBA mid, 8 bits
    mov cl,8
    shr eax,cl
    mov dx,0x1f4
    out dx,al

    ; LBA high, 8 bits
    shr eax,cl
    mov dx,0x1f5
    out dx,al

    ; device, 8 bits
    shr eax,cl
    and al,0x0f
    or al,0xe0
    mov dx,0x1f6
    out dx,al

    ; command, 8 bits
    mov al,0x20
    mov dx,0x1f7
    out dx,al

    ; status, 8 bits, port is the same as command
.not_ready:
    nop
    in al,dx
    and al,0x88
    cmp al,0x08
    jnz .not_ready

    ; read data, 16 bits, 1 sector=512 bits
    mov edx,edi
    mov eax,256
    mul edx
    ; loop counter=512/2*sectorNum, only take low 32 bits
    mov ecx,eax

    mov dx,0x1f0
.read_data:
    in ax,dx
    mov [es:ebx],ax
    add ebx,2
    loop .read_data

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

kernel_init:
    xor eax,eax
    xor ebx,ebx
    xor ecx,ecx
    xor edx,edx

    ; dx(edx) = program header size
    mov dx,[KERNEL_BIN_BASE_ADDR + 42]
    ; ebx = program header offset
    mov ebx,[KERNEL_BIN_BASE_ADDR + 28]
    add ebx,KERNEL_BIN_BASE_ADDR
    ; cx(ecx) = program header number
    mov cx,[KERNEL_BIN_BASE_ADDR + 44]

.each_segment
    cmp byte [ebx], 0x0
    je .pt_null
    ; prepare params for func memcpy
    ; ebx = p_filesz: file size
    push dword [ebx + 16]
    ; p_offset: file offset, eax = source address
    mov eax,[ebx + 4]
    add eax,KERNEL_BIN_BASE_ADDR
    push eax
    ; p_vaddr: destination address
    push dword [ebx + 8]
    call mem_cpy
    ; clear params
    add esp,12
.pt_null:
    add ebx,edx
    loop .each_segment

    ret

; function: memory copy
; input: dst,src,size (in stack)
mem_cpy:
    push ebp
    mov ebp,esp
    push ecx

    mov edi,[ebp + 8]
    mov esi,[ebp + 12]
    mov ecx,[ebp + 16]
    cld
    rep movsb

    pop ecx
    pop ebp
    ret


; function: set up page table
setup_page_table:
; prepare page directory table
    ; 1.clear 4kb space
    mov ecx,1024
    mov ebx,PAGE_DIR_TABLE_ADDR
.clear_4k_dir_table_loop
    mov dword [ebx],0
    add ebx,4
    loop .clear_4k_dir_table_loop

    ; 2.set 0 and 768 term to the high 4M space
    mov eax,PAGE_DIR_TABLE_ADDR
    add eax,0x1000
    ; 0x7 means US=1,RW=1,P=1
    add eax,0x7
    mov [PAGE_DIR_TABLE_ADDR + 0x0],eax
    mov [PAGE_DIR_TABLE_ADDR + 0xc00],eax
    ; set the last PDE to be page directory table itself
    sub eax,0x1000
    mov [PAGE_DIR_TABLE_ADDR + 0xffc],eax

    ; prepare page table
    ; map high 1M space
    mov ebx,PAGE_DIR_TABLE_ADDR + 0x1000
    mov esi,0
    mov ecx,256
    mov eax,0x7
.map_high_1M_loop:
    mov [ebx + 4*esi],eax
    inc esi
    add eax,0x1000
    loop .map_high_1M_loop

    ; create other PDE for kernel space
    mov eax,PAGE_DIR_TABLE_ADDR
    add eax,0x2000
    add eax,0x7
    mov ebx,PAGE_DIR_TABLE_ADDR
    mov ecx,254
    mov esi,769
.create_kernel_space_loop:
    mov [ebx+4*esi],eax
    inc esi
    add eax,0x1000
    loop .create_kernel_space_loop
    ret

pr_model_start:
    mov eax,SEL_DATA_FLAT
    mov ds,eax
    mov es,eax
    mov ss,eax

    ; for 32bits model, esp is the stack pointer
    mov esp,LOADER_BASE_ADDR

    ; print message in protection model
    mov esi,message_pr
    mov edi,0
    call print_out

    ; load kernel
    mov eax,KERNEL_START_SECTOR
    mov ecx,200
    mov ebx,KERNEL_BIN_BASE_ADDR
    call rd_disk_m_32

    ; setup page
    call setup_page_table
    ; change gdt base address, map it to high 1G space
    sgdt [gdt_ptr]
    add dword [gdt_ptr + 2],0xc0000000
    ; set cr3
    mov eax,PAGE_DIR_TABLE_ADDR
    mov cr3,eax
    ; open PG in cr0
    mov eax,cr0
    or eax,0x80000000
    mov cr0,eax
    ; reload gdt
    lgdt [gdt_ptr]

     ; print message in protection model
    mov esi,message_pg
    mov edi,160
    call print_out

.end:
    ; print message in protection model
    mov esi,message_ld_kr
    mov edi,320
    call print_out

    call kernel_init

    ; print message in protection model
    mov esi,message_kr
    mov edi,480
    call print_out

    mov esp,0xc009f000
    jmp KERNEL_ENTRY_POINT
