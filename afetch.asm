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

; ; ; ; ; ; ; ; ; ; ; ;
; Starts the program  ;
; Arguments: none     ;
; Returns:   none     ;
; ; ; ; ; ; ; ; ; ; ; ;
_start:
	; Get all the things!
	call read_passwd
	call read_hostname
	call read_release
	call read_version

	; Print username and hostname (incredible observation!)
	call print_username_hostname

	; Print distro release
	mov rdi, TITLE_RELEASE
	mov rsi, release
	call print_info_line

	; Print kernel version
	mov rdi, TITLE_VERSION
	mov rsi, version
	call print_info_line

	; Print shell path
	mov rdi, TITLE_SHELL
	mov rsi, shell
	call print_info_line

	call _exit

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Prints the username and hostname.   ;
; Arguments: none                     ;
; Returns:   none                     ;
; Username and hostname are separated ;
; by USER_HOST_SEPARATOR ("@")        ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
print_username_hostname:
	; Get username length
	mov rdi, username
	call strlen

	; Get username padding amount, and
	; force it to 1 if <= 0
	mov rax, (TITLE_LENGTH - 2)
	sub rax, rdx
	test rax, rax
	jg .cont

	mov rax, 1

	.cont:
	; Print padding
	mov rsi, SPACES
	mov rdx, rax
	call writestd

	; Print username
	mov rdi, username
	call printstr

	; Print separator
	mov rsi, USER_HOST_SEPARATOR
	mov rdx, (USER_HOST_SEPARATOR_END - USER_HOST_SEPARATOR)
	call writestd

	; Print hostname
	mov rdi, hostname
	call printstr

	; Print newline
	mov rsi, NEWLINE
	mov rdx, NEWLINE_LENGTH
	call writestd

	ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Prints a line of system info.       ;
; Arguments: rdi = title, rsi = value ;
; Returns:   none                     ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
print_info_line:
	push rsi
	push rdi

	; Left pad title with spaces
	call strlen
	mov rax, TITLE_LENGTH
	sub rax, rdx
	mov rsi, SPACES
	mov rdx, rax
	call writestd

	; Print title
	pop rdi
	call printstr
	
	; Print value
	pop rdi
	call printstr

	; Print newline
	mov rsi, NEWLINE
	mov rdx, NEWLINE_LENGTH
	call writestd
	
	ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Reads and parses /etc/password. ;
; Arguments: none                 ;
; Returns:   none                 ;
; Sets username and shell buffers ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
read_passwd:
	; Get Userid
	mov rax, 0x66			; syscall = 0x66 (getuid)
	syscall
	mov rbx, rax

	; Open /etc/passwd
	mov rax, 0x02			; syscall = 0x02 (open)
	mov rdi, PASSWD_PATH	; filename = "/etc/passwd"
	mov rsi, 0				; flags = 0 (O_RDONLY)
	mov rdx, 0				; create mode = 0
	syscall

	mov r12, rax

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

		; Loop if uid != current uid
		mov rdi, uid_string
		call str_to_int
		cmp rax, rbx		; rbx = current uid
		jne .loop

	; Close /etc/passwd
	mov rax, 0x03			; syscall = 0x03 (close)
	mov rdi, r12			; fd = /etc/passwd
	syscall

	ret

	read_passwd_field:
		sub r13, 1
		
		.loop:
			inc r13

			; Read 1 char
			mov rax, 0x00			; syscall = 0x00 (read)
			mov rdi, r12			; fd = /etc/passwd
			mov rsi, r13			; buffer = current char buffer
			mov rdx, 1				; count = 1
			syscall

			; Load char
			mov cl, [r13]

			; Break if char is colon or newline
			cmp cl, ':'
			je .end
			cmp cl, 10
			je .end

			jmp .loop

		.end:
			xor cl, cl

			.clear_loop:
				; Overwrite current char
				mov [r13], cl

				inc r13
				
				; Loop if buffer is not at end
				cmp r13, r14
				jne .clear_loop

		ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Reads and parses /etc/hostname. ;
; Arguments: none                 ;
; Returns:   none                 ;
; Sets hostname buffer            ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
read_hostname:
	; Open /etc/hostname
	mov rax, 0x02			; syscall = 0x02 (open)
	mov rdi, HOSTNAME_PATH	; filename = "/etc/hostname"
	mov rsi, 0				; flags = 0 (O_RDONLY)
	mov rdx, 0				; create mode = 0
	syscall

	mov r12, rax

	; Read /etc/hostname
	mov rdi, r12						; fd = /etc/hostname
	mov rax, 0x00						; Set syscall number to 0x00 (read)
	mov rsi, hostname					; buffer = hostname buffer
	mov rdx, (hostname_END - hostname)	; count = size of hostname buffer
	syscall

	; Strip newline
	mov rdi, hostname
	call strlen
	add rdx, hostname
	dec rdx
	xor cl, cl
	mov [rdx], cl

	; Close /etc/hostname
	mov rax, 0x03			; syscall = 0x03 (close)
	mov rdi, r12			; fd = /etc/hostname
	syscall

	ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Reads and parses /etc/os-release (/usr/lib/os-release). ;
; Arguments: none                                         ;
; Returns:   none                                         ;
; Sets release buffer                                     ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
read_release:
	; Attempt to open /etc/os-release
	mov rax, 0x02			; syscall = 0x02 (open)
	mov rdi, RELEASE_PATH	; filename = "/etc/os-release"
	mov rsi, 0				; flags = 0 (O_RDONLY)
	mov rdx, 0				; create mode = 0
	syscall
	
	; Continue if no error, otherwise open fallback
	test rax, rax			
	jg .cont

	; Open /usr/lib/os-release
	mov rax, 0x02					; syscall = 0x02 (open)
	mov rdi, RELEASE_FALLBACK_PATH	; filename = "/usr/lib/os-release"
	mov rsi, 0						; flags = 0 (O_RDONLY)
	mov rdx, 0						; create mode = 0
	syscall

	.cont:
	mov rbx, rax

	call read_release_line
	call read_release_value

	; Close /etc/os-release or /usr/lib/os-release
	mov rax, 0x03			; syscall = 0x03 (close)
	mov rdi, rbx			; fd = /etc/hostname or /usr/lib/os-release
	syscall

	ret

	read_release_line:
		; Set current buffer to key buffer
		mov r12, (release_line_key - 1)

		.loop:
			inc r12

			; Read 1 char
			mov rdi, rbx			; fd
			mov rax, 0x00			; syscall = 0x00 (read)
			mov rsi, r12			; buffer = current buffer
			mov rdx, 1				; count = 1
			syscall

			; Load char
			mov al, [r12]

			; Break if newline or null
			cmp al, 10
			je .end
			cmp al, 0
			je .end

			; Loop if not '='
			cmp al, '='
			jne .loop
			
			; If char = '=', clear current char and
			; set current buffer to value buffer
			mov al, 0
			mov [r12], al
			mov r12, (release_line_value - 1)

			jmp .loop

		.end:
			; Overwrite current char with null. 
			; (already either null or newline)
			mov al, 0
			mov [r12], al

			; Check if key = "PRETTY_NAME"
			mov rdi, release_line_key
			mov rsi, RELEASE_PRETTY_NAME_FIELD
			call strcmp

			; Set current buffer to key buffer
			mov r12, (release_line_key - 1)

			; Loop key is incorrect
			cmp rax, 0
			je .loop

		ret

	read_release_value:
		; Set read buffer to release line value buffer
		; and set write buffer to release buffer
		mov rcx, (release_line_value - 1)
		mov rdx, release

		.loop:
			inc rcx

			; Load char
			mov al, [rcx]

			; Skip if char = '"'
			cmp al, '"'
			je .loop

			; Break if null
			cmp al, 0
			je .end

			; Copy char to release buffer
			mov [rdx], al
			inc rdx

			jmp .loop
		
		.end:

		ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Reads and parses /proc/version. ;
; Arguments: none                 ;
; Returns:   none                 ;
; Sets version buffer             ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
read_version:
	; Open /proc/version
	mov rax, 0x02			; syscall = 0x02 (open)
	mov rdi, VERSION_PATH	; filename = "/proc/version"
	mov rsi, 0				; flags = 0 (O_RDONLY)
	mov rdx, 0				; create mode = 0
	syscall

	; Read /proc/version
	mov rdi, rax			; fd = /proc/version
	mov rax, 0x00			; syscall = 0x00 (read)
	mov rsi, version		; buffer = version buffer
	mov rdx, (version_END - version)	; count = size of buffer
	syscall

	; Strip compilation info
	mov rdx, (version - 1)
	xor cl, cl

	.loop:
		inc rdx

		; Load char
		mov cl, [rdx]

		; Loop until parenthesis
		cmp cl, '('
		jne .loop

	dec rdx
	xor cl, cl

	.clear_loop:
		; Overwrite char
		mov [rdx], cl
		
		inc rdx

		; Loop if next char is not null
		cmp [rdx], cl
		jne .clear_loop

	; Close /proc/version
	mov rax, 0x03			; syscall = 0x03 (close)
	mov rdi, rbx			; fd = /proc/version
	syscall

	ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Parses a string into an int.  ;
; Arguments: rdi = string       ;
; Returns:   rax = int          ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
str_to_int:
	xor rax, rax
	dec rdi
	
	.loop:
		inc rdi

		mov rcx, 0
		mov cl, [rdi]

		; Break if end of string
		cmp cl, 0
		je .end

		; Offset ASCII value to numerical value
		sub cl, 48

		; Append to return value

		mov rdx, 10
		mul rdx			; Shifts current value by one place
		add rax, rcx

		jmp .loop

	.end:
		ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Gets length of a string.  ;
; Arguments: rdi = string   ;
; Returns:   rdx = length   ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
strlen:
	mov rdx, -1
	sub rdi, 1

	.loop:
		inc rdx
		inc rdi

		; Load char
		mov cl, [rdi]

		; Loop if not null
		cmp cl, 0
		jne .loop

	ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Compares two strings.         ;
; Arguments: rdi = a, rsi = b   ;
; Returns:   rax = equal        ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
strcmp:
	dec rdi
	dec rsi

	.loop:
		inc rdi
		inc rsi

		; Load chars
		mov al, [rdi]
		mov ah, [rsi]

		; Check for equality
		cmp al, ah
		jne .false

		; Check for end of string
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

	ret			; Unreachable

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Prints a string to stdout.      ;
; Arguments: rdi = string         ;
; Returns:   rax = bytes written  ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
printstr:
	mov rsi, rdi			; buffer = string buffer
	call strlen				; count = length of string
	call writestd

	ret

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Writes a buffer to stdout.            ;
; Arguments: rsi = buffer, rdx = count  ;
; Returns:   rax = bytes written        ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
writestd:
	mov rax, 1			; syscall = 0x01 (write)
	mov rdi, 1			; fd = 1 (stdout)
	syscall

	ret

; ; ; ; ; ; ; ; ; ; ; ; ;
; Exits the program.    ;
; Arguments: none       ;
; Returns:   error code ;
; ; ; ; ; ; ; ; ; ; ; ; ;
_exit:
	mov rax, 0x3C			; syscall = 0x3C (exit)
	mov rdi, 0				; error code = 0
	syscall