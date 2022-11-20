; This code is a mess, good luck ;)

TITLE_LENGTH               equ 12
NEWLINE_LENGTH             equ 1
USER_HOST_SEPARATOR_LENGTH equ 1

section .data
	; Indiviual Characters
	NEWLINE db 10
	NEWLINE_END db 0

	USER_HOST_SEPARATOR db '@'
	USER_HOST_SEPARATOR_END db 0

	; Spaces for padding
	SPACES times TITLE_LENGTH db ' '
	SPACES_END db 0

	; Paths
	PASSWD_PATH db "/etc/passwd"
	PASSWD_PATH_END db 0

	HOSTNAME_PATH db "/etc/hostname"
	HOSTNAME_PATH_END db 0

	RELEASE_PATH db "/etc/os-release"
	RELEASE_PATH_END db 0

	RELEASE_FALLBACK_PATH db "/usr/lib/os-release"
	RELEASE_FALLBACK_PATH_END db 0

	VERSION_PATH db "/proc/version"
	VERSION_PATH_END db 0

	; Titles
	TITLE_RELEASE db "OS - "
	TITLE_RELEASE_END db 0

	TITLE_VERSION db "Kernel - "
	TITLE_VERSION_END db 0

	TITLE_SHELL db "Shell - "
	TITLE_SHELL_END db 0

	; Misc
	RELEASE_PRETTY_NAME_FIELD db "PRETTY_NAME"
	RELEASE_PRETTY_NAME_FIELD_END db 0

section .bss
	trash resb 255
	trash_END resb 1

	uid resq 1
	uid_END resb 1

	uid_string resb 8
	uid_string_END resb 1

	release_line_key resb 32
	release_line_key_END resb 1

	release_line_value resb 255
	release_line_value_END resb 1

	username resb 32
	username_END resb 1

	hostname resb 255
	hostname_END resb 1

	release resb 255
	release_END resb 1

	version resb 255
	version_END resb 1

	shell resb 255
	shell_END resb 1

section .text
	global _start

_start:
	call read_passwd
	call read_hostname
	call read_release
	call read_version

	call print_username_hostname

	mov rdi, TITLE_RELEASE
	mov rsi, release
	call print_info_line

	mov rdi, TITLE_VERSION
	mov rsi, version
	call print_info_line

	mov rdi, TITLE_SHELL
	mov rsi, shell
	call print_info_line

	call _exit

print_username_hostname:
	mov rdi, username
	call strlen

	mov rax, (TITLE_LENGTH - 2)
	sub rax, rdx
	test rax, rax
	jg .print

	mov rax, 1

	.print:
	mov rsi, SPACES
	mov rdx, rax
	call writestd

	mov rdi, username
	call printstr

	mov rsi, USER_HOST_SEPARATOR
	mov rdx, (USER_HOST_SEPARATOR_END - USER_HOST_SEPARATOR)
	call writestd

	mov rdi, hostname
	call printstr

	mov rsi, NEWLINE
	mov rdx, NEWLINE_LENGTH
	call writestd

	ret

print_info_line:
	push rsi
	push rdi

	call strlen
	mov rax, TITLE_LENGTH
	sub rax, rdx
	mov rsi, SPACES
	mov rdx, rax
	call writestd

	pop rdi
	call printstr
	
	pop rdi
	call printstr

	mov rsi, NEWLINE
	mov rdx, NEWLINE_LENGTH
	call writestd
	
	ret

read_passwd:
	; Get Userid
	mov rax, 0x66								; Set syscall number to 0x66 (getuid)
	syscall
	mov [uid], rax								; Store uid 

	; Open /etc/passwd
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, PASSWD_PATH						; Set filename to "/etc/passwd"
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set create mode to 0
	syscall

	mov r12, rax								; Save /etc/passwd fd to callee-saved register

	.loop:
		; Read username
		mov r13, username
		mov r14, username_END
		call read_passwd_field

		; Trash "password"
		mov r13, trash
		mov r14, trash_END
		call read_passwd_field

		; Read uid string
		mov r13, uid_string
		mov r14, uid_string_END
		call read_passwd_field

		; Trash group id string, display name, and home directory
		mov r13, trash
		mov r14, trash_END
		call read_passwd_field

		mov r13, trash
		mov r14, trash_END
		call read_passwd_field

		mov r13, trash
		mov r14, trash_END
		call read_passwd_field

		; Read shell
		mov r13, shell
		mov r14, shell_END
		call read_passwd_field


		mov rdi, uid_string						; Convert uid string to integer value
		call str_to_int							; ..
		cmp rax, [uid]							; Loop if uid isn't current uid
		jne .loop								; ..

	; Close /etc/passwd
	mov rax, 0x03								; Set syscall number to 0x03 (close)
	mov rdi, r12								; Set fd to /etc/passwd
	syscall

	ret

		read_passwd_field:
			sub r13, 1							; Move buffer pointer back one (Incremented at start of loop)
			
			.loop:
				inc r13							; Move buffer to next char

				mov rax, 0x00					; Set syscall number to 0x00 (read)
				mov rdi, r12					; Set fd to /etc/passwd
				mov rsi, r13					; Set buffer to current char buffer
				mov rdx, 1						; Set count to 1
				syscall

				mov bl, [r13]					; Load read char into bl
				cmp bl, ':'						; Break if read char is a colon
				je .end							; ..
				.notcolon:
				cmp bl, 10						; Break if read char is a newline
				je .end							; ..

				jmp .loop

			.end:
				xor bl, bl

				.clear_loop:
					mov [r13], bl				; Overwrite current buffer character
					inc r13						; Move to next character
					
					cmp r13, r14				; Loop if buffer is not at end
					jne .clear_loop				; ..

			ret

read_hostname:
	; Open /etc/hostname
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, HOSTNAME_PATH						; Set filename to "/etc/hostname"
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set create mode to 0
	syscall

	mov r12, rax								; Save to preserved register

	; Read /etc/hostname
	mov rdi, r12								; Set fd to /etc/hostname
	mov rax, 0x00								; Set syscall number to 0x00 (read)
	mov rsi, hostname							; Set buffer to hostname buffer
	mov rdx, (hostname_END - hostname)			; Set count to length of hostname buffer
	syscall

	; Strip newline
	mov rdi, hostname							; Get length of hostname
	call strlen									; ..

	add rdx, hostname							; Get address of last character (always newline)
	dec rdx										; ..

	xor cl, cl									; Overwrite with null
	mov [rdx], cl								; ..

	; Close /etc/hostname
	mov rax, 0x03								; Set syscall number to 0x03 (close)
	mov rdi, r12								; Set fd to /etc/hostname
	syscall

	ret

read_release:
	; Attempt to open /etc/os-release
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, RELEASE_PATH						; Set filename to "/etc/os-release"
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set create mode to 0
	syscall

	test rax, rax								; Jump if no error, otherwise open fallback
	jg .opened

	; Open /usr/lib/os-release
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, RELEASE_FALLBACK_PATH				; Set filename to "/usr/lib/os-release"
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set create mode to 0
	syscall

	.opened:
	mov rbx, rax								; Store fd in preserved register

	call read_release_line
	call read_release_value

	; Close /etc/os-release or /usr/lib/os-release
	mov rax, 0x03								; Set syscall number to 0x03 (close)
	mov rdi, rbx								; Set fd to /etc/hostname or /usr/lib/os-release
	syscall

	ret

	read_release_line:
		mov r12, (release_line_key - 1)

		.loop:
			inc r12

			; Read 1 char
			mov rdi, rbx								; Set fd
			mov rax, 0x00								; Set syscall number to 0x00 (read)
			mov rsi, r12								; Set buffer to release line buffer
			mov rdx, 1									; Set count 1
			syscall

			mov al, [r12]

			cmp al, 10
			je .end
			cmp al, 0
			je .end

			cmp al, '='
			jne .loop
			
			mov al, 0
			mov [r12], al
			mov r12, (release_line_value - 1)

			jmp .loop

		.end:
			mov al, 0
			mov [r12], al
			mov rdi, release_line_key
			mov rsi, RELEASE_PRETTY_NAME_FIELD
			call strcmp

			mov r12, (release_line_key - 1)

			cmp rax, 0
			je .loop

		ret

	read_release_value:
		mov rcx, (release_line_value - 1)
		mov rdx, release

		.loop:
			inc rcx

			mov al, [rcx]

			cmp al, '"'
			je .loop

			cmp al, 0
			je .end

			mov [rdx], al
			inc rdx

			jmp .loop
		
		.end:

		ret

read_version:
	; Open /proc/version
	mov rax, 0x02								; Set syscall number to 0x02 (open)
	mov rdi, VERSION_PATH						; Set filename to "/proc/version"
	mov rsi, 0									; Set flags to O_RDONLY (0)
	mov rdx, 0									; Set create mode to 0
	syscall

	; Read /proc/version
	mov rdi, rax								; Set fd to /proc/version
	mov rax, 0x00								; Set syscall number to 0x00 (read)
	mov rsi, version							; Set buffer to version buffer
	mov rdx, (version_END - version)			; Set count to length of version buffer
	syscall

	; Strip compilation info
	mov rdx, (version - 1)						; Set buffer to version buffer and subtract one (Incremented at start of loop)
	xor cl, cl									; Clear character

	.loop:
		inc rdx

		mov cl, [rdx]

		cmp cl, '('
		jne .loop

	dec rdx
	xor cl, cl

	.clear_loop:
		mov [rdx], cl

		inc rdx

		cmp [rdx], cl
		jne .clear_loop

	; Close /proc/version
	mov rax, 0x03								; Set syscall number to 0x03 (close)
	mov rdi, rbx								; Set fd to /proc/version
	syscall

	ret

str_to_int:
	mov rax, 0									; Clear output
	dec rdi										; Move buffer pointer back one (Incremented at start of loop)
	
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
	mov rdx, -1									; Clear result and subtract one (Incremented at start of loop)
	sub rdi, 1									; Move buffer pointer back one (Incremented at start of loop)

	.loop:
		inc rdx									; Increment counter
		inc rdi									; Move buffer to next char

		mov cl, [rdi]							; Read char from buffer

		cmp cl, 0								; Break if char is null
		jne .loop								; ..

	ret

strcmp:
	dec rdi
	dec rsi

	.loop:
		inc rdi
		inc rsi

		mov al, [rdi]
		mov ah, [rsi]

		cmp al, ah
		jne .false

		cmp al, 0
		je .true

		jmp .loop

	.true:
		mov rax, 1
		jmp .end

	.false:
		mov rax, 0
		jmp .end

	.end:

	ret

printstr:
	mov rsi, rdi								; Set write buffer to string buffer
	call strlen									; Get length of string (returns in length register)
	call writestd								; Write to stdout

	ret

writestd:
	mov rax, 1									; Set syscall number to 0x01 (write)
	mov rdi, 1									; Set fd to stdout (1)
	syscall										; Write

	ret

_exit:
	mov rax, 60
	mov rdi, 0
	syscall