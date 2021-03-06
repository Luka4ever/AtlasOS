; AtlasOS
; A multiprocess capable DCPU OS by Plusmid and Chessmaster42
;AtlasOS version 0.5.3
;Atlas-Shell version 0.3.2

; clear screen (for emulator)
JSR clear

; low level routines
; runs best in DCPU-16 Studio (http://badsector.github.com/dcpustud/)

; Display the logo
SET A, text_logo1
JSR text_out

; Bootmessage
SET A, text_start
JSR text_out

; Reserve kernel-memory
SET X, 0
:kernel_mem
IFG X, kernel_end
    SET PC, kernel_mem_end
SET A, X
JSR page_reserve
ADD X, 1024
SET PC, kernel_mem
:kernel_mem_end

; Reserve video-memory
SET A, 0x8000
JSR page_reserve

; Reserve stack-memory
SET A, 0xFFFF
JSR page_reserve

; Copy the API
SET A, 0x1000
JSR page_reserve

;Reserve application memory
SET A, 0
:apps_mem
IFG A, apps_end
    SET PC, apps_mem_end
SET X, A
JSR page_reserve
SET A, X
ADD A, 1024
SET PC, apps_mem
:apps_mem_end

SET X, 0

; Copy the API.
SET A, 0x1000

SET B, A
SET A, api_start
SET C, api_end
SUB C, A
JSR mem_copy

; OS ready message
SET A, text_start_ok
JSR text_out

; Clear out a few things
SET [keyboard_buffers_exclusive], 0
SET [keyboard_oldvalue], 0
JSR keyboard_unregister_all

; The kernel constantly polls the keyboard.
:kernel_loop

	; Call the keyboard driver if the keyvalue has changed
	IFN [0x9000], [keyboard_oldvalue] ; Could be done IN the driver. But is faster this way.
        JSR driver_keyboard

	; Check if the kernel is the only running process, if so start the shell
	JSR kernel_watchdog_checkalone

    JSR proc_suspend
    SET PC, kernel_loop

:kernel_watchdog_checkalone
	SET PUSH, C
	SET PUSH, B
	SET PUSH, A

	SET C, kernel_watchdog_proc_list_buffer
	SET A, kernel_watchdog_helper
	JSR proc_callback_list
	SET C, kernel_watchdog_proc_list_buffer
	ADD C, 1
	IFE [C], 0
		JSR kernel_watchdog_loadshell

	; Clear the proc buffer
	SET C, kernel_watchdog_proc_list_buffer
	SET [C], 0
	ADD C, 1
	SET [C], 0

	SET A, POP
	SET B, POP
	SET C, POP
	SET PC, POP
:kernel_watchdog_helper
	IFE C, kernel_watchdog_proc_list_buffer_end
		SET PC, POP
	SET [C], A
	ADD C, 1
	SET PC, POP
:kernel_watchdog_loadshell
	; This is a workaround so the shell doesn't freak out
	; when there is no data in the keyboard buffer
	SET [keyboard_oldvalue], 0xFFFF
	; Now start the shell
	SET A, AtlasShell
	SET B, AtlasShell_end
	SUB B, AtlasShell
	JSR proc_load
	SET PC, POP

; START OF THE KEYBOARD DRIVER
:driver_keyboard
    SET PUSH, A
    SET PUSH, B

    SET A, keyboard_buffers

	IFN [keyboard_buffers_exclusive], 0
		SET PC, driver_keyboard_exclusive

:driver_keyboard_loop
	; Check to see if we have a buffer registered at this spot
    IFN [A], 0
        JSR driver_keyboard_save_to_buffer
	; Increment to the next buffer as long as we aren't at the end
    ADD A, 1
    IFN A, keyboard_buffers_end
        SET PC, driver_keyboard_loop
:driver_keyboard_end
	SET [keyboard_oldvalue], [0x9000]
	SET [0x9000], 0
	SET B, POP
    SET A, POP
    SET PC, POP

:driver_keyboard_exclusive
	SET B, [keyboard_buffers_exclusive]
	SET [B], [0x9000]
	SET PC, driver_keyboard_end

:driver_keyboard_save_to_buffer
	SET B, [A]
	SET [B], [0x9000]
	SET PC, POP

; END OF THE KEYBOARD DRIVER








SET PC, stop

; prints a text to stdout
; A: start address of the text
:text_out
      SET PUSH, A
      SET PUSH, B
      SET PUSH, C
      SET PUSH, I

      SET B, [video_col]
      SET I, [video_cur]

:text_out_loop
      SET C, [A]
      IFE C, 0x0000
          SET PC, text_out_end
      IFE C, 0x00A0
          SET PC, text_out_nl
      IFG C, 0x00FF
          AND C, 0x00FF
      BOR C, B
      SET [I], C
      ADD A, 1
      ADD I, 1
      IFE I, 0x8200
          SET PC, text_out_scroll
      SET PC, text_out_loop

:text_out_scroll
      SET [video_cur], I
      JSR scroll
      SET I, [video_cur]
      SET PC, text_out_loop

:text_out_nl
      SET [video_cur], I
      JSR newline
      SET I, [video_cur]
      ADD A, 1
      SET PC, text_out_loop

:text_out_end
      SET [video_cur], I
      SET I, POP
      SET C, POP
      SET B, POP
      SET A, POP
      SET PC, POP

; Linefeed (working)
:newline
      SET PUSH, A
      SET PUSH, B

      SET A, 0x0020
      SET B, [video_cur]
     ; SUB B, 0x8000
      MOD B, A
      SUB A, B
      ADD [video_cur], A
      IFE [video_cur], 0x8200
          JSR scroll

      SET B, POP
      SET A, POP
      SET PC, POP

; Scrolls the screen one line (working)
:scroll
      SET PUSH, X
      SET PUSH, Y

      SET X, 0x8000 ; Set X to the video memory
      SET Y, 0x8020 ; Set Y to the second line in the video memory

:scroll_loop1
      SET [X], [Y]
      ADD X, 1
      ADD Y, 1
      IFE Y, 0x8200
          SET PC, scroll_loop2
      SET PC, scroll_loop1

:scroll_loop2
      SET [X], [video_col]
      ADD X, 1
      IFE X, 0x8200
          SET PC, scroll_end
      SET PC, scroll_loop2

:scroll_end
      SUB [video_cur], 0x20
      SET Y, POP
      SET X, POP
      SET PC, POP

; Clears the screen and sets the cursor to the first line (working)
:clear
      SET PUSH, A
      SET PUSH, B

      SET A, [video_mem]
      SET B, [video_col]

:clear_loop
      SET [A], B
      ADD A, 1
      IFE A, 0x8200
          SET PC, clear_end
      SET PC, clear_loop

:clear_end
      SET [video_cur], [video_mem]
      SET B, POP
      SET A, POP
      SET PC, POP

:get_pos
      SET PUSH, B

      IFG A, 31
          SET PC, get_pos_clip
      IFG B, 15
          SET PC, get_pos_clip

      MUL B, 32
      ADD B, 0x8000
      ADD B, A

      SET A, B

:get_pos_skip
      SET B, POP
      SET PC, POP

:get_pos_clip
      SET A, 0x0000
      SET PC, get_pos_skip


:char_put
      SET PUSH, A

      JSR get_pos
      SET [A], C

      SET A, POP
      SET PC, POP


; Converts a Number into a Decimal String
; A: Number
; B: StrBuffer (length 5)
:int2dec
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C

	ADD B, 4

:int2dec_loop
	SET C, A
	MOD C, 10

	SET [B], C
	ADD [B], 0x0030

	DIV A, 10
	SUB B, 1
	IFE A, 0
		SET PC, int2dec_end
	SET PC, int2dec_loop

:int2dec_end
	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP

; Converts a Number into a Hexadecimal String
; A: Number
; B: StrBuffer (length 4)
:int2hex
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C

	ADD B, 3

:int2hex_loop
	SET C, A
	AND C, 0x000F ; does the same thing as MOD, but AND takes one cycle, MOD takes 3

	SET [B], C
	ADD [B], 0x0030 ; adding 30 gives us a value of 30 to 3F
	IFG [B], 0x0039 ; if it's 3A or more, add seven
		ADD [B], 0x0007 ; giving us 30 - 39, 41 - 46

	DIV A, 16
	SUB B, 1
	IFE A, 0
		SET PC, int2hex_end
	SET PC, int2hex_loop

:int2hex_end
	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP

; Takes a text buffer containing an integer and converts it to an integer
; A: Address of text buffer
:atoi
     SET PUSH, A
     SET PUSH, B
     SET C, 0

:atoi_loop
     IFE [A], 0
     SET PC, atoi_end

     ; Capture the first digit and subtract 48 so our ASCII code for the digit becomes the numeric value of the digit
     SET B, [A]
     SUB B, 48

     ; Add the value of the digit to the accumulator
     ADD C, B

     ; Increment our address and multiply the accumulator
     ADD A, 1
     IFE [A], 0
     SET PC, atoi_end
     MUL C, 10
     SET PC, atoi_loop

:atoi_end
     SET B, POP
     SET A, POP
     SET PC, POP

; mem_clear
; A: From Addr
; B: Length
:mem_clear
      SET PUSH, A
      SET PUSH, B

      ADD B, A

:mem_clear_loop
      SET [A], 0
      ADD A, 1
      IFN A, B
          SET PC, mem_clear_loop

      SET B, POP
      SET A, POP
      SET PC, POP

; A: source
; B: dest
; C: length
:mem_copy
      SET PUSH, A
      SET PUSH, B
      SET PUSH, C

      ; Calulate the last address
      ADD C, A

:mem_copy_loop
      SET [B], [A]
      ADD A, 1
      ADD B, 1
      IFN A, C
          SET PC, mem_copy_loop

      SET C, POP
      SET B, POP
      SET A, POP
      SET PC, POP

; A: Mem addr of the page
:page_reserve
      SET PUSH, B

      SET B, A
      MOD B, 1024
      SUB A, B
      DIV A, 1024        ; Set the pagenum

      JSR page_remove    ; Remove all occurences of this page
      SET B, 0x0001      ; By the OS
      JSR page_combine   ; Combine A (the page num) and B (the proc id) to the page entry
      BOR A, 0x8000      ; Set the "reserved" flag
      JSR page_add

      SET B, POP
      SET PC, POP

; A: Removes all entries with the given page num
:page_remove
      SET PUSH, A
      SET PUSH, B

      AND A, 0x003F
      SHL A, 8
      SET PUSH, A

      SET B, page_table

:page_remove_loop
      SET A, [B]
      AND A, 0x3F00
      IFE A, PEEK
          SET [B], 0x0000     ; Remove entry
      ADD B, 1
      IFN B, page_table_end
          SET PC, page_remove_loop

      SET A, POP              ; Remove a from stack
      SET B, POP              ; Restore registers
      SET A, POP
      SET PC, POP

; A -> page num
; B -> proc id
; A <- combined page entry
:page_combine
      SET PUSH, B

      AND A, 0x003F
      SHL A, 8
      AND B, 0x00FF
      BOR A, B

      SET B, POP
      SET PC, POP

; A -> combined page entry
; A <- page num
; B <- proc id
:page_decombine
      SET B, A

      SHR A, 8
      AND A, 0x003F
      AND B, 0x00FF

      SET PC, POP

; A -> page entry
; A <- 1 of succeeded, 0 if failed
:page_add
      SET PUSH, B
      SET B, page_table

:page_add_loop
      IFE [B], 0
          SET PC, page_add_set

      ADD B, 1
      IFN B, page_table_end
          SET PC, page_add_loop

      SET A, 0

:page_add_end
      SET B, POP
      SET PC, POP

:page_add_set
      SET [B], A

      JSR page_decombine
      JSR page_set_map

      SET A, 1
      SET PC, page_add_end

:page_find_free

      ;SET PC, page_find_free

      SET PUSH, B

      SET A, page_map
      SET B, 0
      IFN [A], 0xFFFF
          SET PC, page_find_free_found
      ADD A, 1
      ADD B, 1
      IFN [A], 0xFFFF
          SET PC, page_find_free_found
      ADD A, 1
      ADD B, 1
      IFN [A], 0xFFFF
          SET PC, page_find_free_found
      ADD A, 1
      ADD B, 1
      IFN [A], 0xFFFF
          SET PC, page_find_free_found

      ; Nothing found, exiting! (later: Swap)
      SET A, 0

:page_find_free_end
      SET B, POP
      SET PC, POP

:page_find_free_found
      SET PUSH, [A]
      MUL B, 16
      SET A, B

:page_find_free_found_loop
      SHR PEEK, 1
      IFN O, 0x0000
          SET PC, page_find_free_skip

      ADD SP, 1
      SET PC, page_find_free_end

:page_find_free_skip
      ADD A, 1
      SET PC, page_find_free_found_loop


; Allocates a page for the current application
:page_alloc
      SET PUSH, B

      JSR page_find_free
      IFE A, 0
          SET PC, page_alloc_error

      SET PUSH, A

      JSR proc_id
      SET B, A
      SET A, PEEK

      JSR page_combine
      JSR page_add
      IFE A, 0
          SET PC, page_alloc_error2

      SET A, POP
      MUL A, 1024

:page_alloc_end
      SET B, POP
      SET PC, POP

:page_alloc_error2
      SET A, POP

:page_alloc_error
      SET A, 0
      SET PC, page_alloc_end

; Frees the given page for the current application
; A: memory
:page_free

      SET PC, page_free

      SET PUSH, A
      SET PUSH, B
      SET PUSH, C

      SET B, A
      MOD B, 1024
      SUB A, B
      SET C, A

      JSR proc_id
      SET B, A
      SET A, C

      JSR page_combine
      SET PUSH, A
      SET A, page_table

:page_free_loop
      SET B, [A]
      AND B, 0x3FFF
      IFE B, PEEK
          SET PC, page_free_found
      ADD A, 1
      IFN A, page_table_end
          SET PC, page_free_loop

:page_free_end
      SET A, POP
      SET C, POP
      SET B, POP
      SET A, POP
      SET PC, POP

:page_free_found
      SET [A], 0x0000

      ADD SP, 3
      SET A, PEEK
      SUB SP, 3

      JSR page_unset_map

      SET PC, page_free_end


:page_free_of
      SET PUSH, A
      SET PUSH, B

      AND A, 0x00FF
      SET PUSH, A
      SET B, page_table

:page_free_of_loop
      SET A, [B]
      AND A, 0x00FF
      IFE A, PEEK
          SET [B], 0x0000
      ADD B, 1
      IFN B, page_table_end
          SET PC, page_free_of_loop

      ADD SP, 1

      SET B, POP
      SET A, POP

; A: page num
:page_set_map
      SET PUSH, A
      SET PUSH, B

      SET B, 0x0001

      IFG 16, A
          SET PC, page_set_map_0
      IFG 32, A
          SET PC, page_set_map_1
      IFG 48, A
          SET PC, page_set_map_2

      SUB A, 48
      SHL B, A
      BOR [page_map3], B

:page_set_map_end
      SET B, POP
      SET A, POP
      SET PC, POP

:page_set_map_0
      SHL B, A
      BOR [page_map0], B
      SET PC, page_set_map_end

:page_set_map_1
      SUB A, 16
      SHL B, A
      BOR [page_map1], B
      SET PC, page_set_map_end

:page_set_map_2
      SUB A, 32
      SHL B, A
      BOR [page_map2], B
      SET PC, page_set_map_end


; A: page num
:page_unset_map
      SET PUSH, A
      SET PUSH, B

      SET B, 0x0001

      IFG 16, A
          SET PC, page_unset_map_0
      IFG 32, A
          SET PC, page_unset_map_1
      IFG 48, A
          SET PC, page_unset_map_2

      SUB A, 48
      SHL B, A
      XOR B, 0xFFFF
      AND [page_map3], B

:page_unset_map_end
      SET B, POP
      SET A, POP
      SET PC, POP

:page_unset_map_0
      SHL B, A
      XOR B, 0xFFFF
      AND [page_map0], B
      SET PC, page_unset_map_end

:page_unset_map_1
      SUB A, 16
      SHL B, A
      XOR B, 0xFFFF
      AND [page_map1], B
      SET PC, page_unset_map_end

:page_unset_map_2
      SUB A, 32
      SHL B, A
      XOR B, 0xFFFF
      AND [page_map2], B
      SET PC, page_unset_map_end

; Returns the amount of reserved memory
:page_check
      SET PUSH, B

      SET B, page_table
      SET A, 0

:page_check_loop
      IFN [B], 0
          ADD A, 1024
      ADD B, 1
      IFN B, page_table_end
          SET PC, page_check_loop

      SET B, POP
      SET PC, POP


:page_check_of
      SET PUSH, B
      SET PUSH, C
      SET PUSH, A

      SET B, page_table
      SET A, 0

:page_check_of_loop
      SET C, [B]
      AND C, 0x00FF
      IFE C, PEEK
          ADD A, 1024
      ADD B, 1
      IFN B, page_table_end
          SET PC, page_check_of_loop

      ADD SP, 1
      SET C, POP
      SET B, POP
      SET PC, POP


; ##############################################################

; Returns the version of AtlasOS
; Takes: ---
; Returns:
; A: main version
; B: subversion
; C: fixversion
:os_version
      SET A, [os_version_main]
      SET B, [os_version_sub]
	  SET C, [os_version_fix]
	  SET PC, POP

; Returns the ID of the current process
; Takes: ---
; Returns:
; A: process ID
:proc_id
      SET A, [proc_current]
      SET PC, POP

; Returns the start address of the current process
; Takes: ---
; Returns:
; A: start address
:proc_get_addr
      JSR proc_id

:proc_get_addr_of
      JSR proc_get_info

      ADD A, 10
      SET A, [A]
      SET PC, POP

; Returns the flags of the current process
; Takes: ---
; Returns:
; A: flags
:proc_get_flags
      JSR proc_id

:proc_get_flags_of
      JSR proc_get_info_of

      ADD A, 11
      SET A, [A]
      SET PC, POP

; Returns the address of the process info structure
; Takes: ---
; Returns:
; A: address
:proc_get_info
      JSR proc_id

:proc_get_info_of
      MUL A, 12
      ADD A, proc_buffer
      SET PC, POP

; Sets the flags of the current process
; Takes:
; A: flags
; Returns: ---
:proc_set_flags
      SET PUSH, A
      JSR proc_get_info
      ADD A, 11
      IFN A, 11
          SET [A], PEEK
      SET A, POP
      SET PC, POP

; Sets the flags of a process
; Takes:
; A: process ID
; B: flags
; Returns: ---
:proc_set_flags_of
      SET PUSH, A
      JSR proc_get_info_of
      ADD A, 11
      IFN A, 11
          SET [A], B
      SET A, POP
      SET PC, POP

; Sets the active flag of the process
; Takes:
; A: process ID
; Returns: ---
:proc_set_flag_active_of
      SET PUSH, B
      SET PUSH, A

      JSR proc_get_flags_of
      BOR A, 0x0001
      SET B, A
      SET A, POP
      JSR proc_set_flags_of

      SET B, POP
      SET PC, POP

; Resets the active flag of the process
; Takes:
; A: process ID
; Returns: ---
:proc_reset_flag_active_of
      SET PUSH, B
      SET PUSH, A

      JSR proc_get_flags_of
      AND A, 0xFFFE
      SET B, A
      SET A, POP
      JSR proc_set_flags_of

      SET B, POP
      SET PC, POP

; Toggles the active flag of the process
; Takes:
; A: process ID
; Returns:
; A: 1 - active, 0 - inactive
:proc_flag_is_active_of
      JSR proc_get_flags_of
      AND A, 0x0001
      SET PC, POP

; Generates a list of all process IDs and hands it over to a callback-function
; Takes:
; A: address of the callback-function (Takes: A: process ID, Returns: ---)
; Returns: ---
:proc_callback_list
      SET PUSH, B
      SET PUSH, A

      SET B, proc_table

:proc_callback_list_loop
      SET A, [B]
      IFN A, 0
          JSR PEEK
      ADD B, 12
      IFN B, proc_table_end
          SET PC, proc_callback_list_loop

      SET A, POP
      SET B, POP
      SET PC, POP

; proc_suspend
:proc_suspend
      SET [proc_buffer], [proc_current] ; Buffer the registers of the current process
      SET [proc_buffer_a], A
      SET [proc_buffer_b], B
      SET [proc_buffer_c], C
      SET [proc_buffer_x], X
      SET [proc_buffer_y], Y
      SET [proc_buffer_z], Z
      SET [proc_buffer_i], I
      SET [proc_buffer_j], J
      SET [proc_buffer_sp], SP

      ; Restore the Stackpointer so we can call subroutines
      SET SP, [proc_table10]

      ; Copy the buffered state to the table
      JSR proc_get_info
      SET B, A
      SET A, proc_buffer

      SET C, 12

      JSR mem_copy

      ; Process saved, now restore the next proc
      SET A, B

:proc_kill_me_hook
      ADD A, 12
:proc_suspend_loop
      IFE A, proc_table_end
          SET A, proc_table
      SET X, [A]
      IFN X, 0x0000
          SET PC, proc_suspend_invoke
      ADD A, 12
      SET PC, proc_suspend_loop

:proc_suspend_invoke
      ; Copy the process information to the registers
      SET B, proc_buffer
      JSR mem_copy

      SET [proc_current], [proc_buffer]
      SET A, [proc_buffer_a]
      SET B, [proc_buffer_b]
      SET C, [proc_buffer_c]
      SET X, [proc_buffer_x]
      SET Y, [proc_buffer_y]
      SET Z, [proc_buffer_z]
      SET I, [proc_buffer_i]
      SET J, [proc_buffer_j]
      SET SP, [proc_buffer_sp]
      SET PC, POP ; Jump into the Programm

; Loads a new process into memory
; A: Begin of the BLOB
; B: Length of the BLOB
:proc_load

      IFE [A], 0x4714  ; Check for magic number
          SET PC, proc_exec     ; No flat binary, call advanced loader

      SET PUSH, B
      SET PUSH, C
      SET PUSH, X
      SET PUSH, Y
      SET PUSH, Z

      SET X, proc_table

:proc_load_loop
      IFE [X], 0x0000
          SET PC, proc_load_to

      ADD X, 12
      IFN X, proc_table_end
          SET PC, proc_load_loop

:proc_load_error
      SET A, 0

:proc_load_end
      SET Z, POP
      SET Y, POP
      SET X, POP
      SET C, POP
      SET B, POP
      SET PC, POP

:proc_load_to
      ; Calculate the ProcID
      SET [X], X
      SUB [X], proc_table
      DIV [X], 12
      ADD [X], 1

      ; X = ProcInfo Addr

      ; Finaly load the Process
      SET C, B
      SET Y, A

      SET Z, [proc_current]   ; Fake the process ID
      SET [proc_current], [X]

      JSR page_alloc

      SET [proc_current], z

      IFE A, 0
          SET PC, proc_load_error

      SET B, A
      SET A, Y
      JSR mem_copy

      SET A, [X] ; A return the ProcID

      ADD X, 1 ; A
      SET [X], 0
      ADD X, 1 ; B
      SET [X], 0
      ADD X, 1 ; C
      SET [X], 0
      ADD X, 1 ; X
      SET [X], 0
      ADD X, 1 ; Y
      SET [X], 0
      ADD X, 1 ; Z
      SET [X], 0
      ADD X, 1 ; I
      SET [X], 0
      ADD X, 1 ; J
      SET [X], 0
      ADD X, 1 ; SP
      SET [X], B
      ADD [X], 1023
      SET Y, [X] ; Save stack address
      ADD X, 1
      SET [X], B
      ADD X, 1 ; Flags
      SET [X], 0x0001

      SET [Y], B ; "Push" the "return" address on the stack

      SET PC, proc_load_end


















; Loads a new process into memory
; A: Begin of the BLOB
; B: Length of the BLOB
:proc_exec
      SET PUSH, B
      SET PUSH, C
      SET PUSH, X
      SET PUSH, Y
      SET PUSH, I
      SET PUSH, J

      IFN [A], 0x4714     ; seems to be a flat binary, call legacy loader
          SET PC, proc_load

      ADD A, 1
      SET I, [A]
      ADD A, 1
      SET J, [A]

      IFN I, B
          SET PC, proc_exec_error

      SET X, J
      AND X, 0x0001
      IFE X, 0x0000
          SET PC, proc_exec_skip_art

      ADD A, 1
      SUB B, [A]
      ADD A, [A]
      ADD A, 1
      SUB B, 2
:proc_exec_skip_art

      SET X, J
      AND X, 0x0010
      IFE X, 0x0000
          SET PC, proc_exec_skip_lib

      ADD A, 2
      SUB B, [A]
      ADD A, [A]
      SUB B, 2
:proc_exec_skip_lib

      SET X, proc_table

:proc_exec_loop
      IFE [X], 0x0000
          SET PC, proc_exec_to

      ADD X, 12
      IFN X, proc_table_end
          SET PC, proc_exec_loop

:proc_exec_error
      SET A, 0

:proc_exec_end
      SET J, POP
      SET I, POP
      SET Y, POP
      SET X, POP
      SET C, POP
      SET B, POP
      SET PC, POP

:proc_exec_to
      ; Calculate the ProcID
      SET [X], X
      SUB [X], proc_table
      DIV [X], 12
      ADD [X], 1

      ; X = ProcInfo Addr

      ; Finaly load the Process
      SET C, B
      SET Y, A
      JSR page_alloc

      IFE A, 0
          SET PC, proc_exec_error

      SET B, A
      SET A, Y
      JSR mem_copy

      SET A, [X] ; A return the ProcID

      ADD X, 1 ; A
      SET [X], 0
      ADD X, 1 ; B
      SET [X], 0
      ADD X, 1 ; C
      SET [X], 0
      ADD X, 1 ; X
      SET [X], 0
      ADD X, 1 ; Y
      SET [X], 0
      ADD X, 1 ; Z
      SET [X], 0
      ADD X, 1 ; I
      SET [X], 0
      ADD X, 1 ; J
      SET [X], 0
      ADD X, 1 ; SP
      SET [X], B
      ADD [X], 1023
      SET Y, [X] ; Save stack address
      ADD X, 1
      SET [X], B
      ADD X, 1 ; Flags
      SET [X], 0x0001

      SET [Y], B ; "Push" the "return" address on the stack

      SET PC, proc_exec_end

:proc_kill_me
      JSR proc_id ; Save process ID
      SET X, A
      JSR proc_get_info_of ; Save process info address
      SET Y, A
      ADD A, 10 ; Save memory page
      SET Z, [A]

      SET A, Y ; Delete the process info entry
      SET B, 12
      JSR mem_clear

      SET A, X
      JSR page_free_of

      SET A, Y ; Restore the pointer to the info entry
      SET C, 12
      SET PC, proc_kill_me_hook

:proc_kill
      SET PUSH, B
      SET PUSH, Y
      SET PUSH, Z
      SET PUSH, A

      JSR proc_get_info_of ; Save process info address
      SET Y, A
      ADD A, 10 ; Save memory page
      SET Z, [A]

      SET A, Y ; Delete the process info entry
      SET B, 12
      JSR mem_clear

      SET A, POP ; Free the process memory page
      JSR page_free_of ; ! It will not be cleared !

      SET Z, POP
      SET Y, POP
      SET B, POP
      SET PC, POP

; ##############################################################



; PUSHes all registers to the stack
:pusha
     SET [pushpop_buffer], POP ; Save jump-back-address

     SET PUSH, A
     SET PUSH, B
     SET PUSH, C
     SET PUSH, X
     SET PUSH, Y
     SET PUSH, Z
     SET PUSH, I
     SET PUSH, J

     SET PC, [pushpop_buffer] ; jump back

; POPs all registers from the stack
:popa
     SET [pushpop_buffer], POP ; Save jump-back-address

     SET J, POP
     SET I, POP
     SET Z, POP
     SET Y, POP
     SET X, POP
     SET C, POP
     SET B, POP
     SET A, POP

     SET PC, [pushpop_buffer] ; jump back

:pushpop_buffer dat 0x0000

; Driver functions

; Registers a new keyboard buffer
; Takes:
; A: Address of the buffer
; B: Keyboard buffer flags (right now set to 1 to make buffer exclusive)
:keyboard_register
	SET PUSH, C
	SET PUSH, B
    SET PUSH, A

    SET C, keyboard_buffers

:keyboard_register_loop
    IFE [C], 0
        SET PC, keyboard_register_set
    ADD C, 1
    IFN C, keyboard_buffers_end
        SET PC, keyboard_register_loop

:keyboard_register_set
    SET [C], A
	IFE B, 1
		SET [keyboard_buffers_exclusive], A

:keyboard_register_end
    SET A, POP
	SET B, POP
	SET C, POP
    SET PC, POP


; Unregisters a keyboard buffer
; Takes:
; A: Address of the buffer
:keyboard_unregister
	SET PUSH, B
    SET PUSH, A

    SET B, keyboard_buffers

:keyboard_unregister_loop
    IFE [B], A
        SET PC, keyboard_unregister_unset
    ADD B, 1
    IFN B, keyboard_buffers_end
        SET PC, keyboard_unregister_loop
	SET PC, keyboard_unregister_end
:keyboard_unregister_unset
    SET [B], 0x0000

	; If this is the exclusive buffer, reset the exclusive global flag
	IFE A, [keyboard_buffers_exclusive]
		JSR keyboard_unregister_exclusive

:keyboard_unregister_end
    SET A, POP
	SET B, POP
    SET PC, POP

:keyboard_unregister_exclusive
	; Trigger a keyboard buffer update on any other register buffers
	SET [keyboard_oldvalue], 0xFFFF
	; And clear the exclusive data
	SET [keyboard_buffers_exclusive], 0
	SET PC, POP



; Returns whether there is an exclusive keyboard buffer active
:keyboard_is_exclusive_active
	SET A, 0
	IFN [keyboard_buffers_exclusive], 0
		SET A, 1
	SET PC, POP

; Wipes out all of the registered keyboard buffers
; CAUTION! This make break other running applications
:keyboard_unregister_all
	SET PUSH, A
	SET A, keyboard_buffers
:keyboard_unregister_all_loop
	IFE A, keyboard_buffers_end
		SET PC, keyboard_unregister_all_end
	SET [A], 0
	ADD A, 1
	SET PC, keyboard_unregister_all_loop
:keyboard_unregister_all_end
	SET A, POP
	SET PC, POP


; Copies a string from a source to a destination
; Takes:
; A: source address
; B: destination address
:strcpy
    SET PUSH, A
    SET PUSH, B

:strcpy_loop
    IFE A, 0
        SET PC, strcpy_end
    SET [B], [A]
    ADD A, 1
    ADD B, 1
    SET PC, strcpy_loop

:strcpy_end
    SET B, POP
    SET A, POP
	SET PC, POP

; Copies a string from a source to a destination with length limitation
; Takes:
; A: source
; B: destination
; C: length
:strncpy
    SET PUSH, A
    SET PUSH, B
    SET PUSH, C

    ADD C, B
:strncpy_loop1
    IFE [A], 0
        SET PC, strncpy_loop2
    SET [B], [A]
    ADD A, 1
    ADD B, 1
    IFE B, C
        SET PC, strncpy_end
    SET PC, strncpy_loop1

:strncpy_loop2
    SET [B], 0
    ADD B, 1
    IFN B, C
        SET PC, strncpy_loop2

:strncpy_end
    SET C, POP
    SET B, POP
    SET A, POP
SET PC, POP

; Compares strings and stores the result in C
; Takes:
; A: source #1
; B: source #2
:strcmp
    SET PUSH, A
    SET PUSH, B

:strcmp_loop
    SET C, 0

    IFE [A], [B]
    JSR strcmp_checkend

    IFE C, 1
        SET PC, strcmp_end

    IFN [A], [B]
        SET PC, strcmp_end

    ADD A, 1
    ADD B, 1
    SET PC, strcmp_loop

:strcmp_checkend
    IFE [A], 0
        SET C, 1
    SET PC, POP

:strcmp_end
    SET B, POP
    SET A, POP
    SET PC, POP

; Stores the length of a given string in B
; A: Address of the string buffer
:strlen
	SET PUSH, A

	SET B, 0
:strlen_loop
	IFE [A], 0
		SET PC, strlen_end
	ADD A, 1
	SET PC, strlen_loop
:strlen_end
	SET B, A
	SUB B, PEEK

	SET A, POP
	SET PC, POP

; Reads a line of chars from the keyboard
; A: String buffer address
; B: Length
; C: Keybuffer
:read_line
     SET PUSH, C
     SET PUSH, B
     SET PUSH, A

     JSR mem_clear ; Clear the buffer

     ADD B, A

:read_line_loop
	 JSR proc_suspend
     IFE [C], 0
         SET PC, read_line_skip
     IFE [C], 0xA
         SET PC, read_line_end
     IFE [C], 0x8
         SET PC, read_line_backspace
     IFE A, B
         SET PC, read_line_skip

     SET [A], [C]

; Put the character on-screen so the user can see what is being typed
; Maybe have this toggleable?
     SET PUSH, A
     SET PUSH, B
     SET B, [A]
     BOR B, 0x7400
     SET A, B
     SET B, [video_cur]
     SET [B], A
     ADD [video_cur], 1
     SET B, POP
     SET A, POP

     ADD A, 1

:read_line_skip
     SET PC, read_line_loop

:read_line_backspace
; Ensure we don't backspace past the beginning
     IFE A, PEEK
     SET PC, read_line_skip

     SET PUSH, A
     SET PUSH, B
     SUB [video_cur], 1
     SET B, [video_cur]
     SET [B], 0
     SET B, POP
     SET A, POP
     SUB A, 1
     SET PC, read_line_skip

;
:read_line_end
; Add the null terminator
     SET [A], 0
; Pop everything back out
     SET A, POP
     SET B, POP
     SET C, POP
     SET PC, POP

; Sleeps for some cycles
; TODO: Change this (or add a new func.) to wait for a specific number of CPU cycles
; A: number of process cycles to wait
:sleep
    IFE A, 0
		SET PC, POP
    SUB A, 1
    JSR proc_suspend
    SET PC, sleep

; Returns a randomized number in A
:rand
    MUL [entropy], 52265
    ADD [entropy], 135
    SET A, [entropy]
    SET PC, POP

; Takes a seed in A
:srand
	MUL A, 49763
	SHL A, 2
	XOR A, 1273
	SET [entropy], A
	SET PC, POP

; Halts the CPU
:stop SET PC, stop

:data

; OS Variables
:os_version_main dat 0x0000
:os_version_sub dat 0x0005
:os_version_fix dat 0x0003

:video_mem dat 0x8000
:video_col dat 0x7000
:video_cur dat 0x8000

:text_start dat "AtlasOS v0.5.3 starting... ", 0x00
:text_start_ok dat "OK", 0xA0, 0x00
:text_logo1 DAT "      ___   __   __", 0xA0
:text_logo2 DAT "     /   | / /_ / /____ ______", 0xA0
:text_logo3 DAT "    / /| |/ __// // __ `/ ___/", 0xA0
:text_logo4 DAT "   / ___ / /  / // /_/ (__  )", 0xA0
:text_logo5 DAT "  /_/  |_\\_/ /_/ \\__,_/____/", 0xA0
:text_logo6 DAT "         / __ \\/ ___/", 0xA0
:text_logo7 DAT "        / / / /\\__ \\", 0xA0
:text_logo8 DAT "       / /_/ /___/ /", 0xA0
:text_logo9 DAT "       \\____//____/", 0xA0, 0x00

:mem_table
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000

:mem_table_end

:page_map
:page_map0 dat 0x0000
:page_map1 dat 0x0000
:page_map2 dat 0x0000
:page_map3 dat 0x0000

:page_table
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
:page_table_end

:proc_current dat 0x0001
:proc_buffer dat 0x0000
:proc_buffer_a dat 0x0000
:proc_buffer_b dat 0x0000
:proc_buffer_c dat 0x0000
:proc_buffer_x dat 0x0000
:proc_buffer_y dat 0x0000
:proc_buffer_z dat 0x0000
:proc_buffer_i dat 0x0000
:proc_buffer_j dat 0x0000
:proc_buffer_sp dat 0x0000
:proc_buffer_mem dat 0x0000
:proc_buffer_flags dat 0x0000
:proc_table
       dat 0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
:proc_table10
       dat 0xFFFF, 0x0000, 0xFFFD ; OS-Proc
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 ; 1st proc
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 ; 2nd proc
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 ; 3rd proc
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 ; 4th proc
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 ; 5th proc
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 ; [...]
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
       dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
:proc_table_end

:keyboard_buffers
dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
:keyboard_buffers_end
:keyboard_buffers_flags
dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
:keyboard_buffers_flags_end
:keyboard_buffers_exclusive dat 0x0000
:keyboard_oldvalue dat 0x0000

:kernel_watchdog_proc_list_buffer
	dat 0x0000, 0x0000
:kernel_watchdog_proc_list_buffer_end

:entropy dat 0x0000

:api_start ; API starts at 0x1000
    SET PC, os_version		; Returns the version of AtlasOS
    SET PC, proc_id 		; Returns the ID of the current process
    SET PC, proc_suspend 	; Suspends the process and starts the next
    SET PC, proc_get_addr 	; Returns the address of the current processes memory
    SET PC, proc_get_flags 	; Returns the flags of the current process
    SET PC, proc_kill_me 	; Kills the current process
    SET PC, proc_kill 		; Kills a process
    SET PC, page_alloc 		; Allocates another 1024 words
    SET PC, page_free 		; Frees allocated memory
    SET PC, mem_clear 		; Clears memory
    SET PC, pusha 			; Pushes all registers to the stack
    SET PC, popa 			; Pops all registers from the stack
    SET PC, strcpy 			; Copies a string
    SET PC, strncpy 		; Copies a string with length limitation
    SET PC, text_out 		; Displays a text on the screen
    SET PC, newline 		; Linefeed
    SET PC, scroll 			; Scrolls the screen one line
    SET PC, clear 			; Clears the screen
    SET PC, char_put 		; Puts a chat on the screen
    SET PC, read_line 		; Reads a line from the keyboard to a buffer
    SET PC, rand 			; Gets a random number
    SET PC, keyboard_register ; Registers a specific memory location as keyboard buffer
    SET PC, keyboard_unregister ; Unregisters a specific memory location
    SET PC, int2dec 		; Converts a value into the decimal representation
    SET PC, int2hex 		; Converts a value into the hexadecimal representation
	SET PC, atoi 			; Converts a textual, decimal number into the actual integer value
	SET PC, strlen 			; Returns the length of a null-terminated string
	SET PC, strcmp 			; Compares two null-terminated strings to see if they're equal
	SET PC, page_check		; Returns the amount of free memory
	SET PC, srand			; Initializes the random number generator
:api_end












; BASH-like Process
:AtlasShell
	SET A, text_versionoutput
	JSR text_out
:AtlasShell_start
	SET I, AtlasShell_loop_end ; Calculate the length of the back-jump
	SUB I, AtlasShell_loop

	; Register our buffer with the driver
	SET A, input_buffer
	JSR keyboard_register

:AtlasShell_loop
	; First check if anything is taking exclusive keyboard access
	JSR keyboard_is_exclusive_active
	IFN A, 0
		SET PC, AtlasShell_loop_wait

	; Display the prompt
	SET A, text_prompt
	JSR text_out

	; Reset the basics
	SET [ack_command], 0 ; reset command recognized

	; Read a line from the keyboard
	SET A, input_text_buffer
	SET B, 32
	SET C, input_buffer
	JSR read_line

	; Skip everything if we got an empty line
	SET A, input_text_buffer
	JSR strlen
	IFE B, 0
		SET PC, AtlasShell_loop_wait

	; Parse out the primary command
	SET A, input_text_buffer
	SET B, 0
	JSR shell_getparameter

	; Check for the 'clear' command
	SET a, command_clear
	SET b, command_parameter_buffer
	JSR strcmp
	IFE c, 1
	JSR command_clearf

	; Check for the 'version' command
	SET a, command_version
	SET b, command_parameter_buffer
	JSR strcmp
	IFE c, 1
	JSR command_versionf

	; Check for the 'load' command
	SET a, command_load
	SET b, command_parameter_buffer
	JSR strcmp
	IFE c, 1
	JSR command_loadf

	; Check for the 'kill' command
	SET a, command_kill
	SET b, command_parameter_buffer
	JSR strcmp
	IFE c, 1
	JSR command_killf

	; Check for the 'list' command
	SET a, command_list
	SET b, command_parameter_buffer
	JSR strcmp
	IFE c, 1
	JSR command_listf

	; If we don't have an acknowledged command, display the generic response
	ifn [ack_command], 1
	JSR command_unknownf
:AtlasShell_loop_wait
	; Pause then loop back to start of process
	JSR proc_suspend
	SUB PC, I
:AtlasShell_loop_end

; ==BEGIN COMMAND FUNCTIONS==
; Command function when we got an unknown command
:command_unknownf
	JSR newline
	SET a, text_unrecognized
	JSR text_out
	SET pc, pop

; Command function to display version info
:command_versionf
	SET [ack_command], 1 ; acknowledge recognized command
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C

	; Clear the param buffer
	SET A, command_parameter_buffer
	SET B, 16
	JSR mem_clear
	; Capture the param
	SET A, input_text_buffer
	SET B, 1
	JSR shell_getparameter

	; Check if our param was blank
	SET A, command_parameter_buffer
	JSR strlen
	IFE B, 0
		SET PC, command_versionf_shell

	; Check if our param was 'os' to give OS version
	SET A, command_version_os
	SET B, command_parameter_buffer
	JSR strcmp
	IFE C, 1
		SET PC, command_versionf_os
:command_versionf_shell
	JSR newline
	SET A, text_versionoutput
	JSR text_out
	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP
:command_versionf_os
	JSR newline
	JSR command_os_version_display
	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP

; Command function to clear the screen
:command_clearf
	SET [ack_command], 1 ; acknowledge recognized command
	JSR clear
	SET pc, pop

; Command function to load a new process
:command_loadf
	SET [ack_command], 1 ; acknowledge recognized command
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C

	JSR command_clear_parameter_buffer

	; Capture the param
	SET A, input_text_buffer
	SET B, 1
	JSR shell_getparameter

	; check if blank > load help
	SET A, command_parameter_buffer
	JSR strlen
	IFE B, 0
		SET PC, command_loadf_help

	;check if list > list applications in table
	SET A, command_parameter_buffer
	SET B, command_list
	JSR strcmp
	IfE C, 1
		SET PC, command_loadf_list

	SET A, application_table

:command_loadf_loop
	IFE A, application_table_end ; if index is at the end of the table, we have an unknown app
		SET PC, command_loadf_unknown
	IFG A, application_table_end ; if index is at the end of the table, we have an unknown app
		SET PC, command_loadf_unknown
	SET B, command_parameter_buffer
	JSR strcmp ; compare table string to parameter
	IFE C, 1
		SET PC, command_loadf_loop_end ; if equal move to end

	; Get the length of the app name and move our pointer forward past that
	JSR strlen
	ADD A, B
	; Skip past the null terminator, the start address, and the end address
	ADD A, 3
	SET PC, command_loadf_loop

:command_loadf_loop_end
	SET PUSH, A
	JSR newline
	SET A, command_parameter_buffer
	JSR strlen
	SET A, POP
	ADD A, B
	ADD A, 1

	; Load the start & end addresses and start the process
	SET B, A
	ADD B, 1
	SET A, [A]
	SET B, [B]
	SUB B, A

	JSR proc_load

        IFE A, 0
            SET PC, command_loadf_unknown

	SET [last_proc], A
	SET PC, command_loadf_end

:command_loadf_help
	JSR newline
	SET A, command_load_help
	JSR text_out
	SET PC, command_loadf_end

:command_loadf_list
	JSR command_clear_parameter_buffer ;clear parameter buffer so list command doesn't run afterwards
	JSR newline
	SET A, application_table
:command_loadf_list_loop
	IFE A, application_table_end ; if index is at the end of the table, finish listing apps
		SET PC, command_loadf_end
	IFG A, application_table_end ; if index is past end of the table, finish listing apps
		SET PC, command_loadf_end
	JSR text_out ;print out app name
	JSR newline
	; Get the length of the app name and move our pointer forward past that
	JSR strlen
	ADD A, B
	; Skip past the null terminator, the start address, and the end address
	ADD A, 3
	SET PC, command_loadf_list_loop ; loopback

:command_loadf_unknown
	JSR newline
	SET A, command_load_unknown
	JSR text_out

:command_loadf_end
	SET C, POP
	SET B, POP
	SET A, POP
	JSR proc_suspend
	SET PC, POP

; Command function to kill a running process
:command_killf
	SET [ack_command], 1 ; acknowledge recognized command
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C

	JSR command_clear_parameter_buffer

	; Capture the param
	SET A, input_text_buffer
	SET B, 1
	JSR shell_getparameter

	; Check if our param was blank
	SET A, command_parameter_buffer
	JSR strlen
	IFE B, 0
		SET PC, command_killf_help

	; Check if our param was 'last' to kill the last process
	SET A, command_kill_last
	SET B, command_parameter_buffer
	JSR strcmp
	IFE C, 1
		SET PC, command_killf_last

	; Convert the param to an integer
	SET A, command_parameter_buffer
	JSR atoi	; A is source, C is result

	; Selfkill?
	SET PUSH, A
	JSR proc_id
	IFE A, C      ; Wants to kill me?
		SET PC, AtlasShell_die
	SET A, POP

	; Trying to kill OS?
	IFE C, 1
		SET PC, command_killf_forbidden

	; Kill the corresponding process
	JSR newline
	SET A, C
	JSR proc_kill
	SET PC, command_killf_end
:command_killf_forbidden
	JSR newline
	SET A, command_kill_forbidden
	JSR text_out
	SET PC, command_killf_end
:command_killf_last
	JSR newline
	SET A, [last_proc]
	JSR proc_kill
	SET PC, command_killf_end
:command_killf_help
	JSR newline
	SET A, command_kill_help
	JSR text_out
:command_killf_end
	SET C, POP
	SET B, POP
	SET A, POP
	JSR proc_suspend
	SET PC, POP

; Command function to list process IDs
:command_listf
	SET [ack_command], 1
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C

	; Clear the process ID buffer first
	SET A, proc_list_buffer
:command_listf_clear_proc_list
	IFE A, proc_list_buffer_end
		SET PC, command_listf_end
	SET [A], 0
	ADD A, 1
	SET PC, command_listf_clear_proc_list

:command_listf_end
	; Get the process ID list
	SET C, proc_list_buffer
	SET A, command_listf_helper
	JSR proc_callback_list

	JSR newline
	SET A, command_list_info
	JSR text_out
	SET A, 0 ; OS process
	JSR command_listf_display_procID
	SET A, 1 ; Shell process
	JSR command_listf_display_procID
	SET A, 2
	JSR command_listf_display_procID
	SET A, 3
	JSR command_listf_display_procID
	SET A, 4
	JSR command_listf_display_procID
	SET A, 5
	JSR command_listf_display_procID

	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP
:command_listf_helper
	SET [C], A
	ADD C, 1
	SET PC, POP
:command_listf_display_procID
	JSR command_clear_number_buffer

	; Now display the list on-screen
	SET B, proc_list_buffer
	ADD B, A
	SET A, [B]
	; Don't display if it's 0
	IFE A, 0
		SET PC, POP
	; Convert to text and display
	SET B, command_number_buffer
	JSR int2dec
	SET A, command_number_buffer
	JSR text_out
	JSR newline

	SET PC, POP

:AtlasShell_die
	SET A, input_buffer
	JSR keyboard_unregister
	JSR newline
	JSR proc_kill_me

; ==BEGIN HELPER FUNCTIONS==
; Displays OS version using API call to get version numbers
; TODO: Make the output more user-friendly
:command_os_version_display
	JSR command_clear_number_buffer
	SET A, 0
	SET B, 0
	SET C, 0
	; A - main version, B - sub version, C - fix version
	JSR os_version
	SET PUSH, C
	SET PUSH, B
	MUL A, 10000
	SET B, command_number_buffer
	JSR int2dec
	IFE A, 0
		SET [B], 0x0030
	SET A, command_number_buffer
	SET B, POP
	SET A, B
	MUL A, 100
	SET B, command_number_buffer
	JSR int2dec
	SET A, command_number_buffer
	SET C, POP
	SET A, C
	SET B, command_number_buffer
	JSR int2dec
	SET A, command_number_buffer
	ADD A, 1
	SET [A], [command_version_separator]
	ADD A, 2
	SET [A], [command_version_separator]
	SET A, command_number_buffer
	JSR text_out
	JSR newline
	SET PC, POP
; Clears the parameter buffer
:command_clear_parameter_buffer
	SET PUSH, A
	SET PUSH, B
	SET A, command_parameter_buffer
	SET B, 32
	JSR mem_clear
	SET B, POP
	SET A, POP
	SET PC, POP
; Clears the number buffer
:command_clear_number_buffer
	; Empty the temp buffer
	SET PUSH, A
	SET A, command_number_buffer
	SET [A], 32
	ADD A, 1
	SET [A], 32
	ADD A, 1
	SET [A], 32
	ADD A, 1
	SET [A], 32
	ADD A, 1
	SET [A], 32
	SET A, POP
	SET PC, POP

; Takes a command input and parses out a parameter
; A: Address of source text buffer
; B: Which param we want to parse out (starts at 0)
:shell_getparameter
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C
	; C will keep track of which param we're looking at
	SET C, 0
:shell_getparameter_loop
	IFE C, B
	SET PC, shell_getparameter_save
	IFE [A], 32
	ADD C, 1
	ADD A, 1
	IFE [A], 0
	SET PC, shell_getparameter_end
	SET PC, shell_getparameter_loop
:shell_getparameter_save
	SET B, command_parameter_buffer
:shell_getparameter_save_loop
	SET [B], 0
	IFE [A], 32
	SET PC, shell_getparameter_end
	IFE [A], 0
	SET PC, shell_getparameter_end
	IFE [A], 10
	SET PC, shell_getparameter_end
	SET [B], [A]
	ADD A, 1
	ADD B, 1
	SET PC, shell_getparameter_save_loop
:shell_getparameter_end
	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP

; Data
:input_text_buffer dat "                                ", 0x00
:input_buffer dat 0x0000
:ack_command dat 0x00
:command_clear dat "clear", 0
:command_version dat "version", 0
:command_version_os dat "os", 0
:command_version_separator dat ".", 0
:command_load dat "load", 0
:command_load_help dat "Syntax: load [appID]", 0xA0, 0x00
:command_load_unknown dat "Failed to load application", 0xA0, 0x00
:command_kill dat "kill", 0
:command_kill_forbidden dat "Cannot kill process: Forbidden", 0xA0, 0x00
:command_kill_help dat "Syntax: kill [last|procID]", 0xA0, 0x00
:command_kill_last dat "last", 0
:command_list dat "list", 0
:command_list_info dat "Process list:", 0xA0, 0x00
:command_parameter_buffer dat "                                ", 0x00
:command_number_buffer dat "     ", 0x00

:proc_list_buffer
	dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	dat 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
:proc_list_buffer_end
:last_proc dat 0x0000

:text_unrecognized dat "Unrecognized command", 0xA0, 0x00
:text_versionoutput dat "Atlas-Shell v0.3.2", 0xA0, 0x00
:text_prompt dat "$> ", 0x00

; Note: This application table will be changed / go away once we have a filesystem
;application_table_format
;dat "name_of_app", 0, app_location, app_location_end
:application_table
:app1 dat "hello", 0, hello, hello_end
:app2 dat "ball", 0, app02, app02_end
:app3 dat "goodbye", 0, goodbye, goodbye_end
:app4 dat "free", 0, free, free_end
:app5 dat "AtlasText", 0, AtlasText, AtlasText_end
:app6 dat "AtlasShell", 0, AtlasShell, AtlasShell_end
:app7 dat "gfxline", 0, gfxline, gfxline_end
:application_table_end

:AtlasShell_end

;GUI Library Begins

;Draws a horizontal line with its left corner at position A and a width of B
:GUI_Draw_HLine
SET PUSH, A
SET PUSH, B
:GUI_Draw_HLine_loop
IFE B, 0
    SET PC, GUI_Draw_HLine_end
SET [A], 0x702d
SUB B, 1
ADD A, 1
SET PC, GUI_Draw_HLine_loop
:GUI_Draw_HLine_end
SET B, POP
SET A, POP
SET PC, POP

;Draws a vertical line with its left corner at position A and a height of B
:GUI_Draw_VLine
SET PUSH, A
SET PUSH, B
:GUI_Draw_VLine_loop
IFE B, 0
    SET PC, GUI_Draw_VLine_end
SET [A], 0x7021
SUB B, 1
ADD A, 32
SET PC, GUI_Draw_VLine_loop
:GUI_Draw_VLine_end
SET B, POP
SET A, POP
SET PC, POP

;Draw a character at a specific position
;Draws the character on B to the screen position on A
:gfx_set_pos
SET [A], B
SET PC, POP

;Gets a character from the screen at a specific position
;Gets the character on A and saves it on B
:gfx_get_pos
SET B, [A]
SET PC, POP

;Clears an area on the screen with its top position at A
;its width at B and its height at C
:gfx_clear_area
IFE C, 0
    SET PC, POP
SET PUSH, X
SET PUSH, A
SET PUSH, C
SET PUSH, B
SET X, [video_col]
:gfx_clear_area_l1
IFE B, 0
    SET PC, gfx_clear_area_s1
:gfx_clear_area_s2
SET [A], X
SUB B, 1
ADD A, 1
SET PC, gfx_clear_area_l1
:gfx_clear_area_s1
SUB C, 1
IFE C, 0
    SET PC, gfx_clear_area_end
SET B, PEEK
SUB A, B
ADD A, 32
SET PC, gfx_clear_area_s2
:gfx_clear_area_end
SET B, POP
SET C, POP
SET A, POP
SET X, POP
SET PC, POP

;Draws a line between two coordinates
;Coordinate 1 is A, coordinate 2 is B and the character is C
:gfx_line
SET [B], C
IFE A, B
    SET PC, POP
SET PUSH, [video_cur]
SET PUSH, J
SET PUSH, I
SET PUSH, Z
SET PUSH, X
SET PUSH, Y
SET PUSH, A
SET PUSH, B
SET [A], C
;push char to stack (must be returned after initial calculations)
SET PUSH, C
SET PUSH, A
SET PUSH, B
JSR gfx_coord_decons
SET J, B
SET I, C
SET A, PEEK
JSR gfx_coord_decons
SET X, B
SET Y, C
;find x distance between points
IFG J, X
    SET PC, gfx_line_it1
SET A, X
SUB A, J
SET [video_cur], 0
SET PC, gfx_line_it2
:gfx_line_it1
SET A, J
SUB A, X
SET [video_cur], 1
:gfx_line_it2
IFG I, Y
    SET PC, gfx_line_it3
SET B, Y
SUB B, I
SET PC, gfx_line_it4
:gfx_line_it3
SET B, I
SUB B, Y
ADD [video_cur], 2
:gfx_line_it4
;find the longest side
SET X, A
SET Y, B
SET I, POP
SET I, POP
SET C, POP
IFG X, Y
    SET PC, gfx_line_itx
:gfx_line_ity
SET Z, Y
;multiply the shortest side by 100 to get 2 decimal places
SET J, X
MUL J, 100
DIV J, Z
SET B, 50
:gfx_line_ityl
;auto increase cursor on the longest side
JSR gfx_line_la2
ADD B, J
IFG B, 100
    JSR gfx_line_la2c
SET [I], C
SUB Z, 1
IFE Z, 0
    SET PC, gfx_line_end
SET PC, gfx_line_ityl
:gfx_line_itx
SET Z, X
;multiply the shortest side by 100 to get 2 decimal places
SET J, Y
MUL J, 100
DIV J, Z
SET B, 50
:gfx_line_itxl
;auto increase cursor on the longest side
JSR gfx_line_la1
ADD B, J
IFG B, 100
    JSR gfx_line_la1c
SET [I], C
SUB Z, 1
IFE Z, 0
    SET PC, gfx_line_end
SET PC, gfx_line_itxl
:gfx_line_la1c
SUB B, 100
JSR gfx_line_la2
SET PC, POP
:gfx_line_la1
IFE [video_cur], 0
    ADD I, 1
IFE [video_cur], 1
    SUB I, 1
IFE [video_cur], 2
    ADD I, 1
IFE [video_cur], 3
    SUB I, 1
SET PC, POP
:gfx_line_la2c
SUB B, 100
JSR gfx_line_la1
SET PC, POP
:gfx_line_la2
IFE [video_cur], 0
    ADD I, 32
IFE [video_cur], 1
    ADD I, 32
IFE [video_cur], 2
    SUB I, 32
IFE [video_cur], 3
    SUB I, 32
SET PC, POP
;draw_end
:gfx_line_end
SET B, POP
SET A, POP
SET Y, POP
SET X, POP
SET Z, POP
SET I, POP
SET J, POP
SET [video_cur], POP
SET PC, POP

;Calculates the index of the character at a specific coordinate
;A is x and B is y, C is the output
:gfx_coord_cons
SET C, B
MUL C, 32
ADD C, A
ADD C, [video_mem]
SET PC, POP

;Calculates the x and y indexes of the character at a specific coordinate
;A is the coordinates, B is x and C is y
:gfx_coord_decons
SET PUSH, A
SUB A, [video_mem]
SET PUSH, A
MOD A, 32
SET B, A
SET A, POP
DIV A, 32
SET C, A
SET A, POP
SET PC, POP

;GUI Library Ends

:kernel_end
; ################################
; ################################
:apps

; AtlasText - A simple, dummy text editor
:AtlasText
	JSR clear

	SET I, AtlasText_loop_end ; Calculate the length of the back-jump
	SUB I, AtlasText_loop

	; Register our buffer with the driver
	SET A, AtlasText_input_buffer
	; And ask for exclusive keyboard access
	SET B, 1
	JSR keyboard_register
:AtlasText_loop
	; If we hit ESC kill the editor
	IFE [AtlasText_input_buffer], 0x001B
		SET PC, AtlasText_die

	; Just print the text to the screen
	SET A, AtlasText_input_buffer
	JSR text_out

	JSR proc_suspend
	SUB PC, I
:AtlasText_loop_end
:AtlasText_die
	SET A, AtlasText_input_buffer
	JSR keyboard_unregister
	JSR clear
	JSR proc_kill_me
:AtlasText_data
	:AtlasText_input_buffer dat 0x0000, 0x0000
:AtlasText_end

:app02
	SET X, 1
	SET Y, 1

	SET I, app02_loop_end
	SUB I, app02_loop

	SET J, 200

	; Register our buffer with the driver
	SET A, app02_input_buffer
	;SET B, 1
	JSR keyboard_register

	SET A, 0
	SET B, 0
	SET C, 0

:app02_loop
	; Restore the old character
	SET C, Z
        IFE C, 0
            ADD PC, 4
        IFN C, 0x744F
	    JSR char_put

	; If we reached the end of the iterations, quit
	SUB J, 1
	IFE J, 0
		JSR app02_die

	; Update the coordinates of the ball
	ADD A, X
	ADD B, Y

	IFE A, 31
	SET X, 0xFFFF

	IFE B, 15
	SET Y, 0xFFFF

	IFE A, 0
	SET X, 1

	IFE B, 0
	SET Y, 1

	; Save the character before we write so we can restore later
	SET PUSH, B
	MUL B, 32
	ADD B, A
	ADD B, [video_mem]
	SET Z, [B]
	SET B, POP

	SET [app02_wait_counter], 8
:app02_wait_loop
	SET PUSH, [app02_wait_counter]
	JSR app02_update_ball
	SET [app02_wait_counter], POP
	SUB [app02_wait_counter], 1
	IFN [app02_wait_counter], 0
		SET PC, app02_wait_loop

	JSR proc_suspend
	SUB PC, I
:app02_loop_end
:app02_update_ball
	SET C, 0x7400
	IFN [app02_input_buffer], [app02_old_input_buffer]
		IFN [app02_input_buffer], 0
			SET [app02_ball_char], [app02_input_buffer]
	BOR C, [app02_ball_char]
	JSR char_put

	IFN [app02_input_buffer], 0
		SET [app02_old_input_buffer], [app02_input_buffer]
	JSR proc_suspend
	SET PC, POP
:app02_die
	SET A, app02_input_buffer
	JSR keyboard_unregister
;	JSR newline
	JSR proc_kill_me
	SET PC, POP
:app02_data
	:app02_input_buffer dat 0x0000
	:app02_old_input_buffer dat 0x0000
	:app02_ball_char dat 0x0000
	:app02_wait_counter dat 0x0000
:app02_end

:hello ; beginning of application
	SET I, hello_loop_end
	SUB I, hello_loop

	SET J, 2
:hello_loop ; beginning of application loop
	SUB J, 1    ; check if application loop should end
	IFE J, 0
		JSR proc_kill_me

	SET A, hello_world
	JSR text_out

	JSR proc_suspend
	SUB PC, I
:hello_loop_end
	:hello_world dat "Hello World", 0xA0, 0
:hello_end

:goodbye ; beginning of application
	SET I, goodbye_loop_end
	SUB I, goodbye_loop

	SET J, 3
:goodbye_loop ; beginning of application loop
	SUB J, 1    ; check if application loop should end
	IFE J, 0
		JSR proc_kill_me

	SET A, goodbye_world
	JSR text_out

	JSR proc_suspend
	SUB PC, I
:goodbye_loop_end
	:goodbye_world dat "Goodbye World", 0xA0, 0
:goodbye_end

:free
     JSR page_check
     SET X, 0xFFFF
     SUB X, A
     SET A, X
     SET B, free_buffer
     JSR int2dec
     SET B, free_buffer2
     DIV A, 1024
     SHL A, 1
     JSR int2dec
     SET A, free_buffer
     JSR text_out
     SET A, free_buffer
     JSR proc_kill_me

:free_buffer  dat "      words free ("
:free_buffer2 dat "      KB)", 0xA0, 0x00
:free_end

;shows how exact gfx_line is
:gfxline
SET A, [video_mem]
SET B, [video_mem]
SET C, 0x702b
SET X, A
ADD X, 0x0200
:gfxline_loop
JSR clear
JSR gfx_line
ADD B, 1
IFG B, X
    JSR gfxline_inc
JSR gfxline_wait
SET PC, gfxline_loop
:gfxline_inc
SET B, [video_mem]
ADD A, 68
IFG A, X
    SET PC, gfxline_close
SET PC, POP
:gfxline_wait
SET PUSH, A
SET A, 2000
:gfxline_waitloop
SUB A, 1
IFE A, 0
SET PC, gfxline_waitend
SET PC, gfxline_waitloop
:gfxline_waitend
SET A, POP
SET PC, POP
:gfxline_close
JSR clear
JSR proc_kill_me
:gfxline_end

:apps_end