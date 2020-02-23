%include "boot.inc"
section mbr vstart=0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,0x7c00
    
    mov eax,LOADER_START_SECTOR
    mov bx,LOADER_BASE_ADDR
    mov cx,1
    call rd_disk_m_16

    jmp LOADER_BASE_ADDR

; eax: LBA address
; bx: load to [es:bx]
; cx: sector number    

rd_disk_m_16:
    ; store state
    mov esi,eax
    mov di,cx

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
    mov dx,di
    mov ax,256
    mul dx
    ; loop counter=512/2*sectorNum, only take low 16 bits
    mov cx,ax

    mov dx,0x1f0
.read_data
    in ax,dx
    mov [es:bx],ax
    add bx,2
    loop .read_data

    ret

    times 510-($-$$) db 0
    db 0x55,0xaa


