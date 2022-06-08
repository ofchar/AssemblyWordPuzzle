.8086
.model small
.stack 2048h

dseg	segment para public 'data'
		error_opening_file_message		db		'Error trying to open the file$'
		error_reading_file_message		db		'Error trying to read from the file$'
		error_closing_file_message		db		'Error trying to close the file$'
		file							db		'data.TXT',0
		file_handle						dw		0
		read_character					db		?
		read_lines						db		0	; amount of already read lines from file

		Car								db		32	; save a screen character
		Cor								db		5	; store character color attribute 0101
		constCor						db		5	;
		POSy							db		1	; POSY [1 .. 25]
		POSx							db		2	; POSx [1..80]

		pointerX						db		0
		savedPointerX					db		0
		pointerY						db		0
		savedPointerY					db		0
		chuj							db		10h

		stringus 						db		' '
 		HELLO_LEN 						db		5

		wordsToFind 					dw		12*15 dup(0) ; so we asumme there must be at most 12 words to find, with at most 15 characters each
		currentOffset					dw		0
		currentLength					dw		0
		tempp							dw		0

		wordNumber						db		0
dseg	ends


cseg   	segment para public 'code'
		assume  cs:cseg, ds:dseg


;########################################################################
; Put cursor to X Y coordinates
goto_xy	macro	POSx,POSy
		push 	dx

		mov		ah,02h
		mov		bh,0		; page number
		mov		dl,POSx
		mov		dh,POSy
		int		10h

		pop		dx
endm

;########################################################################
; Clear screen
clear_screen	proc
		xor		bx,bx
		mov		cx,25*80

clear_screen_loop:
		mov		byte ptr es:[bx],' '
		mov		byte ptr es:[bx+1],7
		inc		bx
		inc 	bx
		loop	clear_screen_loop
		ret
clear_screen	endp


;########################################################################
; Read a key
read_key	PROC
		mov		ah,08h
		int		21h
		mov		ah,0
		cmp		al,0
		jne		read_key_return
		mov		ah, 08h
		int		21h
		mov		ah,1
	read_key_return:
		RET
read_key	endp
;########################################################################


;########################################################################
; Read character from screen at pointerX pointerY location
read_char_from_screen	PROC
		push dx

		goto_xy pointerX, pointerY
		mov		ah, 08h
		mov		bh, 0
		int		10h

		pop dx
		ret
read_char_from_screen	endp
;########################################################################


;########################################################################
; mark a word that has been just found
mark_found_word	PROC
		xor 	ax, ax
		mov 	al, wordNumber
		mov		pointerX, 1Dh
		mov 	pointerY, al
	mark_found_word_loop:
		call read_char_from_screen

		mov		bl, 2h
		mov 	ah, 09h
		mov		bh, 0
		mov		cx, 1
		int		10h

		inc pointerX
		cmp pointerX,27h
		jne mark_found_word_loop
		ret
mark_found_word	endp
;########################################################################


;########################################################################
; find next word in the wordsToFind array and find its length
; if there is no word to be found ax will be set to 69, otherwise to 420
find_next_word	PROC
		inc		wordNumber
		lea		si, wordsToFind
		add		si, currentOffset

		mov 	currentLength, 0

	find_length_loop:
		inc		currentLength
		mov 	bx, currentLength
		mov		al, [si + bx]
		cmp		al, 0Dh
		jne		find_length_loop

		mov 	ax,	currentOffset
		add 	ax, currentLength
		add 	ax, 1
		mov 	currentOffset, ax

		; inc 	currentLength
		dec 	currentLength

		xor		ax, ax

		cmp		currentOffset, 0B4h
		jle		next2
		mov		ax, 69h
		ret
	next2:
		mov		ax, 420h
		ret
find_next_word	endp
;########################################################################


;########################################################################
; Check for matching words horizontally, left to right and right to left <--->
; starting from pointerX and pointerY coordinates
check_horizontally	PROC
		; reset some variables
		mov 	currentOffset, 0
		mov 	wordNumber, 0

		; copy pointers for later
		mov		al, pointerX
		mov		savedPointerX, al
		mov		al, pointerY
		mov		savedPointerY, al

	check_horizontally_loop_main:
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		call 	find_next_word

		; if there is no next word return
		cmp		ax, 69h
		jne		check_horizontally_loop_pointer_left
		ret

		; firstly look left to right --->
		; loop as far left as we can
	check_horizontally_loop_pointer_left:
		sub		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_horizontally_loop_pointer_left

		; go back one, since we went one too far
		add 	pointerX, 2h

		xor		dx, dx

	check_horizontally_loop_left:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_horizontally_left_character_selected
		jmp		check_horizontally_next_direction

	check_horizontally_left_character_selected:
		mov		bx, dx
		inc		bx
		mov     cl, [si + bx]

		; al comes from call to read_char_from_screen, cl comes from predefined string with winning words
		; if both are the same we will continue to check, if not we will jump to checking in opposite direction
		cmp		al, cl
		jne		check_horizontally_next_direction

		add		pointerX, 2h
		inc 	dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_horizontally_left_found
		jmp 	check_horizontally_loop_left

	check_horizontally_left_found:
		call 	mark_found_word
		ret


	check_horizontally_next_direction:
		; now we look right to left <---
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		; loop as far right as we can
	check_horizontally_loop_pointer_right:
		add		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_horizontally_loop_pointer_right

		; go back one, since we went one too far
		sub		pointerX, 2h

		xor		dx, dx

	check_horizontally_loop_right:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_horizontally_right_character_selected
		jmp		check_horizontally_not_found

	check_horizontally_right_character_selected:
		mov		bx, dx
		inc 	bx
		mov		cl, [si + bx]

		cmp		al, cl
		jne		check_horizontally_not_found

		sub		pointerX, 2h
		inc		dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_horizontally_right_found
		jmp		check_horizontally_loop_right

	check_horizontally_right_found:
		call 	mark_found_word
		ret

	check_horizontally_not_found:
		jmp		check_horizontally_loop_main
check_horizontally	endp
;########################################################################


;########################################################################
; Check for matching words vertically, up to down, and down to up
; starting from pointerX and pointerY coordinates
check_vertically	PROC
		; reset some variables
		mov 	currentOffset, 0
		mov 	wordNumber, 0

		; copy pointers for later
		mov		al, pointerX
		mov		savedPointerX, al
		mov		al, pointerY
		mov		savedPointerY, al

	check_vertically_loop_main:
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		call 	find_next_word

		; if there is no next word return
		cmp		ax, 69h
		jne		check_vertically_loop_pointer_up
		ret

		; firstly look up to down
		; loop as far up as we can
	check_vertically_loop_pointer_up:
		dec		pointerY
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_vertically_loop_pointer_up

		; go back one, since we went one too far
		inc		pointerY

		xor		dx, dx

	check_vertically_loop_up:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_vertically_up_character_selected
		jmp		check_vertically_next_direction

	check_vertically_up_character_selected:
		mov		bx, dx
		inc		bx
		mov     cl, [si + bx]

		; al comes from call to read_char_from_screen, cl comes from predefined string with winning words
		; if both are the same we will continue to check, if not we will jump to checking in opposite direction
		cmp		al, cl
		jne		check_vertically_next_direction

		inc 	pointerY
		inc 	dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_vertically_up_found
		jmp		check_vertically_loop_up

	check_vertically_up_found:
		call	mark_found_word
		ret


	check_vertically_next_direction:
		; now we look down to up
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		; loop as far down as we can
	check_vertically_loop_pointer_down:
		inc		pointerY
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_vertically_loop_pointer_down

		; go back one, since we went one too far
		dec		pointerY

		xor		dx, dx

	check_vertically_loop_down:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_vertically_down_character_selected
		jmp		check_vertically_not_found

	check_vertically_down_character_selected:
		mov		bx, dx
		inc 	bx
		mov     cl, [si + bx]

		cmp		al, cl
		jne		check_vertically_not_found

		dec		pointerY
		inc		dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_vertically_down_found
		jmp		check_vertically_loop_down

	check_vertically_down_found:
		call	mark_found_word
		ret

	check_vertically_not_found:
		jmp check_vertically_loop_main
check_vertically	endp
;########################################################################

;########################################################################
; Check for matching words diagonally left to righ \
; starting from pointerX and pointerY coordinates
check_diagonally_left_right	PROC
		; reset some variables
		mov 	currentOffset, 0
		mov 	wordNumber, 0

		; copy pointers for later
		mov		al, pointerX
		mov		savedPointerX, al
		mov		al, pointerY
		mov		savedPointerY, al

	check_diagonally_left_right_loop_main:
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		call 	find_next_word

		; if there is no next word return
		cmp		ax, 69h
		jne		check_diagonally_left_right_loop_pointer_up
		ret

		; firstly look up to down
		; loop as far up and left as we can
	check_diagonally_left_right_loop_pointer_up:
		dec		pointerY
		sub		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_left_right_loop_pointer_up

		; go back one, since we went one too far
		inc		pointerY
		add		pointerX, 2h

		xor		dx, dx

	check_diagonally_left_right_loop_up:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_left_right_up_character_selected
		jmp		check_diagonally_left_right_next_direction

	check_diagonally_left_right_up_character_selected:
		mov		bx, dx
		inc		bx
		mov     cl, [si + bx]

		; al comes from call to read_char_from_screen, cl comes from predefined string with winning words
		; if both are the same we will continue to check, if not we will jump to checking in opposite direction
		cmp		al, cl
		jne		check_diagonally_left_right_next_direction

		inc 	pointerY
		add		pointerX, 2h
		inc 	dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_diagonally_left_right_up_found
		jmp		check_diagonally_left_right_loop_up

	check_diagonally_left_right_up_found:
		call	mark_found_word
		ret


	check_diagonally_left_right_next_direction:
		; now we look down to up
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		; loop as far down and right as we can
	check_diagonally_left_right_loop_pointer_down:
		inc		pointerY
		add		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_left_right_loop_pointer_down

		; go back one, since we went one too far
		dec		pointerY
		sub		pointerX, 2h

		xor		dx, dx

	check_diagonally_left_right_loop_down:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_left_right_down_character_selected
		jmp		check_diagonally_left_right_not_found

	check_diagonally_left_right_down_character_selected:
		mov		bx, dx
		inc 	bx
		mov     cl, [si + bx]

		cmp		al, cl
		jne		check_diagonally_left_right_not_found

		dec		pointerY
		sub		pointerX, 2h
		inc		dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_diagonally_left_right_down_found
		jmp		check_diagonally_left_right_loop_down

	check_diagonally_left_right_down_found:
		call	mark_found_word
		ret

	check_diagonally_left_right_not_found:
		jmp		check_diagonally_left_right_loop_main
check_diagonally_left_right	endp
;########################################################################


;########################################################################
; Check for matching words diagonally right to left /
; starting from pointerX and pointerY coordinates
check_diagonally_right_left	PROC
		; reset some variables
		mov 	currentOffset, 0
		mov 	wordNumber, 0

		; copy pointers for later
		mov		al, pointerX
		mov		savedPointerX, al
		mov		al, pointerY
		mov		savedPointerY, al

	check_diagonally_right_left_loop_main:
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		call 	find_next_word

		; if there is no next word return
		cmp		ax, 69h
		jne		check_diagonally_right_left_loop_pointer_up
		ret

		; firstly look up to down
		; loop as far up and right as we can
	check_diagonally_right_left_loop_pointer_up:
		dec		pointerY
		add		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_right_left_loop_pointer_up

		; go back one, since we went one too far
		inc		pointerY
		sub		pointerX, 2h

		xor		dx, dx

	check_diagonally_right_left_loop_up:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_right_left_up_character_selected
		jmp		check_diagonally_right_left_next_direction

	check_diagonally_right_left_up_character_selected:
		mov		bx, dx
		inc		bx
		mov		cl, [si + bx]

		; al comes from call to read_char_from_screen, cl comes from predefined string with winning words
		; if both are the same we will continue to check, if not we will jump to checking in opposite direction
		cmp		al, cl
		jne		check_diagonally_right_left_next_direction

		inc 	pointerY
		sub		pointerX, 2h
		inc 	dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_diagonally_right_left_up_found
		jmp		check_diagonally_right_left_loop_up

	check_diagonally_right_left_up_found:
		call	mark_found_word
		ret


	check_diagonally_right_left_next_direction:
		; now we look down to up
		; start by reseting the pointers
		mov		al, savedPointerX
		mov		pointerX, al
		mov		al, savedPointerY
		mov		pointerY, al

		; loop as far down and left as we can
	check_diagonally_right_left_loop_pointer_down:
		inc		pointerY
		sub		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_right_left_loop_pointer_down

		; go back one, since we went one too far
		dec		pointerY
		add		pointerX, 2h

		xor		dx, dx

	check_diagonally_right_left_loop_down:
		; make sure that char at pointerX pointerY is selected
		call	read_char_from_screen
		cmp		ah, constCor
		je		check_diagonally_right_left_down_character_selected
		jmp		check_diagonally_right_left_not_found

	check_diagonally_right_left_down_character_selected:
		mov		bx, dx
		inc 	bx
		mov     cl, [si + bx]

		cmp		al, cl
		jne		check_diagonally_right_left_not_found

		dec		pointerY
		add		pointerX, 2h
		inc		dx

		; compare 'counter' (dx) with word length
		; if they are equal we (user) have found a match
		cmp		dx, currentLength
		je		check_diagonally_right_left_down_found
		jmp		check_diagonally_right_left_loop_down

	check_diagonally_right_left_down_found:
		call	mark_found_word
		ret

	check_diagonally_right_left_not_found:
		jmp		check_diagonally_right_left_loop_main
check_diagonally_right_left	endp
;########################################################################



;########################################################################
; Mark character on the screen
process_input	PROC
	process_input_loop:
		goto_xy	POSx,POSy	; Go to new position
		mov 	ah, 08h
		mov		bh,0		; page number
		int		10h
		mov		Car, al		; save character at cursor position
		mov		Cor, ah		; save color at cursor position

		goto_xy	78,0		; Shows the character that was in the position of the AVATAR (wtf)
		mov		ah, 02h		; print character in the corner
		mov		dl, Car
		int		21H

		goto_xy	POSx,POSy	; Go to the cursor position

	process_input_read_character:
		call 	read_key
		cmp		ah, 1
		je		process_input_up

		CMP 	AL, 27		; escape key
		JE		process_input_end
		CMP		AL, 13		; enter key
		je		process_input_select_character
		jmp		process_input_read_character

	process_input_up:
		cmp 	al, 48h 	; arrow up key
		jne		process_input_down
		dec		POSy
		jmp		process_input_loop

	process_input_down:
		cmp		al,50h		; arrow down key
		jne		process_input_left
		inc 	POSy
		jmp		process_input_loop

	process_input_left:
		cmp		al,4Bh		; arrow left key
		jne		process_input_right
		sub		POSx, 2h
		jmp		process_input_loop

	process_input_right:
		cmp		al,4Dh		; arrow right key
		jne		process_input_read_character
		add		POSx, 2h
		jmp		process_input_loop

	process_input_end:
		RET

	process_input_select_character:
		; mark character
		mov		bl, Cor
		not		bl
		mov		Cor, bl
		mov 	ah, 09h
		mov		al, car
		mov		bh, 0
		mov		cx, 1
		int		10h

		; check if user may have found some word.
		; copy our posx and posy pointer because we dont want cursor to fly around
		mov		al, POSx
		mov		pointerX, al
		mov		al, POSy
		mov		pointerY, al

		; start by checking if anything is marked in the square around currently selected letter
		; A B C
		; D   E
		; F G H
		; lets go from A clockwise

		sub		pointerX, 2h			; move cursor to the A position
		sub		pointerY, 1h
		call	read_char_from_screen	; read whats on the screen and check its attribute
		cmp		ah, constCor
		jne		process_input_check_b 	; if character at A is not selected we jump to check B
		call	check_diagonally_left_right

	process_input_check_b:
		add		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		jne		process_input_check_c
		call	check_vertically

	process_input_check_c:
		add		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		jne		process_input_check_d
		call 	check_diagonally_right_left

	process_input_check_d:
		sub		pointerX, 4h
		add		pointerY, 1h
		call	read_char_from_screen
		cmp		ah, constCor
		jne		process_input_check_e
		call	check_horizontally

	process_input_check_e:
		add		pointerX, 4h
		call	read_char_from_screen
		cmp		ah, constCor
		jne		process_input_check_f
		call 	check_horizontally

	process_input_check_f:
		sub		pointerX, 4h
		add		pointerY, 1h
		call	read_char_from_screen
		cmp		ah, constCor
		jne		process_input_check_g
		call	check_diagonally_right_left

	process_input_check_g:
		add		pointerX, 2h
		call	read_char_from_screen
		cmp		ah, constCor
		jne		process_input_check_h
		call	check_vertically

	process_input_check_h:
		add		pointerX, 2h
		call 	read_char_from_screen
		cmp		ah, constCor
		jne		jmp_process_input_loop
		call	check_diagonally_left_right

	jmp_process_input_loop:
		jmp		process_input_loop
process_input	endp
;########################################################################



;########################################################################
; print file on screen and read words to array
process_file	proc
		; open file
		mov		ah, 3dh
		mov		al, 0
		lea		dx, file
		int		21h
		jc		process_file_error_opening
		mov		file_handle,ax
		jmp		process_file_read_loop

	process_file_error_opening:
		mov		ah,	09h
		lea		dx,	error_opening_file_message
		int		21h
		ret

	process_file_read_loop:
		mov		ah, 3fh
		mov		bx, file_handle		; bx -> handle
		mov		cx, 1				; cx -> number of bytes to read
		lea		dx, read_character	; DS:DX -> buffer for data
		int		21h 				; 21,3f -> read from file
		jc		process_file_error_reading 			; jump if carry flag
		cmp		ax, 0				; EOF?
		jne		process_file_not_finished
		jmp		process_file_close_file
	process_file_not_finished:
		mov		ah, 02h
		mov		dl, read_character
		int		21h 				;21,02 -> write character to standard output

		; in the file first 25 lines are out 'gui', the rest are words to find, we need to separate those.
		; count lines and after 25 jump to read_words, where those words to find will be read from file.
		cmp		read_character, 0Dh
		jne		process_file_omit_line_increment ; if not a new line we jump
		inc		read_lines 			; if new line increment
	process_file_omit_line_increment:
		cmp		read_lines, 19h 	; if we read 25 lines from file we move to reading words to be found
		je		process_file_read_words
		jmp		process_file_read_loop

	process_file_error_reading:
		mov		ah, 09h
		lea		dx, error_reading_file_message
		int		21h


	process_file_read_words:
		mov 	di, offset wordsToFind
	process_file_read_words_loop:
		mov		ah, 3fh
		mov		bx, file_handle
		mov		cx, 1
		lea		dx, read_character
		int		21h 				; read character from file
		jc		process_file_error_reading
		cmp		ax, 0				; EOF?
		je		process_file_close_file
		mov		ah, 02h
		mov		dl, [read_character] ; move freshly read character to wordsToFind array
		mov		[di], dl
		inc		di
		jmp		process_file_read_words_loop

process_file_close_file:
		mov		ah, 3eh
		mov		bx, file_handle
		int		21h
		ret

		mov		ah, 09h
		lea		dx, error_closing_file_message
		int		21h
process_file	endp


;########################################################################
Main    Proc

		mov		ax,dseg
		mov		ds,ax
		mov		ax,0B800h
		mov		es,ax

		call 	clear_screen
		goto_xy	0,0
		call	process_file
		call	process_input
		goto_xy	0,22
		mov		ah,4ch
		int		21h
Main	endp
cseg	ends
end		Main

