; This code is a mess, good luck ;)

section .data
	; yes
	newline db 10
	newline_END db 0

	spaces times 12 db ' '
	spaces_END db 0

	; Paths
	passwd_path db "/etc/passwd"
	passwd_path_END db 0

	hostname_path db "/etc/hostname"
	hostname_path_END db 0

	; Titles
	title_user db "User - "
	title_user_END db 0

	title_os db "OS - "
	title_os_END db 0

	title_shell db "Shell - "
	title_shell_END db 0

section .bss
	trash resb 255
	trash_END resb 1

	uid resq 1
	uid_END resb 1

	uid_string resb 8
	uid_string_END resb 1

	username resb 32
	username_END resb 1

	hostname resb 32
	hostname_END resb 1

	shell resb 255
	shell_END resb 1

section .text
	global _start

_start:
	call get_user

	mov rdi, shell
	call strlen
	mov rcx, rax

	mov rdi, title_user
	mov rsi, (title_user_END - title_user)
	mov rdx, username
	; mov rcx, strlen(username)
	call print_info_line

	call get_hostname

	mov rdi, title_os
	mov rsi, (title_os_END - title_os)
	mov rdx, hostname
	mov rcx, 32
	call print_info_line

	call _exit
	
print_info_line:
	mov rax, 12
	sub rax, rsi
	
	push rcx
	push rdx
	push rsi
	push rdi

	push rax

	mov rax, 1
	mov rdi, 1
	mov rsi, newline
	mov rdx, 1
	syscall

	mov rax, 1
	mov rdi, 1
	mov rsi, spaces
	pop rdx
	syscall
	
	mov rax, 1
	mov rdi, 1
	pop rsi
	pop rdx
	syscall
	
	mov rax, 1
	mov rdi, 1
	pop rsi
	pop rdx
	syscall
	
	ret

get_user:
	; Get Userid
	mov rax, 0x66								; Set syscall number to 0x66 (getuid)
	syscall
	mov [uid], rax								; Store uid 

	; Open /etc/passwd
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, passwd_path						; Set filename to "/etc/passwd"
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set mode to 0 (ignored since we don't create on open)
	syscall

	mov r12, rax								; Save /etc/passwd fd to callee-saved register

	.loop:
		; Read username
		mov r13, username
		call .read_field

		; Trash "password"
		mov r13, trash
		call .read_field

		; Read uid string
		mov r13, uid_string
		call .read_field

		; Trash group id string, display name, and home directory
		mov r13, trash
		call .read_field
		mov r13, trash
		call .read_field
		mov r13, trash
		call .read_field

		; Read shell
		mov r13, shell
		call .read_field


		mov rdi, uid_string						; Convert uid string to integer value
		call str_to_int							; ..
		cmp rax, [uid]							; Loop if uid isn't current uid
		jne .loop								; ..

		ret

		.read_field:
			sub r13, 1							; Move buffer pointer back one (Incremented at start of loop)
			
			.read_field_loop:
				inc r13							; Move buffer to next char
				inc r14

				mov rax, 0x00					; Set syscall number to 0x00 (read)
				mov rdi, r12					; Set fd to /etc/passwd
				mov rsi, r13					; Set buffer to current char buffer
				mov rdx, 1						; Set count to 1
				syscall

				mov bl, [r13]					; Load read char into bl
				cmp bl, ':'						; Break if read char is a colon
				je .read_field_loop_end			; ..
				.notcolon:
				cmp bl, 10						; Break if read char is a newline
				je .read_field_loop_end			; ..

				jmp .read_field_loop

			.read_field_loop_end:
				mov bl, 0						; Remove colon
				mov [r13], bl					; ..

			ret
	
	ret


get_hostname:
	; Open /etc/hostname
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, hostname_path						; Set filename to "/etc/hostname
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set mode to 0 (ignored since we don't create on open)
	syscall

	; Read /etc/hostname
	mov rdi, rax								; Set fd to /etc/hostname
	mov rax, 0x00								; Set syscall number to 0x00 (read)
	mov rsi, hostname							; Set buffer to hostname buffer
	mov rdx, (hostname_END - hostname)			; Set count to length of hostname buffer
	syscall

	ret


str_to_int:
	mov rax, 0									; Clear output
	sub rdi, 1									; Move buffer pointer back one (Incremented at start of loop)
	
	.loop:
		inc rdi									; Move buffer to next char

		mov rcx, 0								; Clear rcx/cl
		mov cl, [rdi]							; Read char from buffer

		cmp cl, 0								; Break if char is null
		je .end									; ..

		sub cl, 48								; Offset char ascii value to integer value

		mov r8, 10								; Shift current value by 1 place
		mul r8									; ..
		add rax, rcx							; Add newest digit to rax

		jmp .loop

	.end:
		ret


strlen:
	mov rax, -1									; Clear result and subtract one (Incremented at start of loop)
	sub rdi, 1									; Move buffer pointer back one (Incremented at start of loop)

	.loop:
		inc rax									; Increment counter
		inc rdi									; Move buffer to next char

		mov cl, [rdi]							; Read char from buffer

		cmp cl, 0								; Break if char is null
		jne .loop								; ..

	ret


_exit:
	mov rax, 60
	mov rdi, 0
	syscall