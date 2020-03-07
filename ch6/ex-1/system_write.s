section .data
str_c_lib: db "c lib: hello, world!",0xa
str_c_lib_len equ $-str_c_lib

str_syscall: db "syscall: hello, world!",0xa
str_syscall_len equ $-str_syscall

section .text
global _start
_start:
    ; cdecl conventions
    push str_c_lib_len
    push str_c_lib
    push 1
    call simu_write
    add esp,12

    ; syscall directly without lib
    mov eax,4
    mov ebx,1
    mov ecx,str_syscall
    mov edx,str_syscall_len
    int 0x80

    ; exit normally by syscall
    mov eax,1
    int 0x80

    ; simulate C implement of syscall
simu_write:
    push ebp
    mov ebp,esp
    mov eax,4
    mov ebx,[ebp+8]
    mov ecx,[ebp+12]
    mov edx,[ebp+16]
    int 0x80
    pop ebp
    ret
