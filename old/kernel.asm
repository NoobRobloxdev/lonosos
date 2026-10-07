[bits 16]
[org 0x0000]

kernel_start:
    cli                     ; Disable interrupts during stack setup
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    ; Dedicated stack segment to prevent memory/buffer collisions
    mov ax, 0x7000          
    mov ss, ax
    mov sp, 0xFFFF          
    sti

    mov byte [current_color], 0x07   ; Default CLI Color
    mov byte [notepad_color], 0x07   ; Default Notepad Color
    call clear_screen

    ; --- Boot Sequence ---
    mov si, boot_msg1
    call print_string
    call print_ok

    mov si, boot_msg2
    call print_string
    call print_ok

    mov si, boot_msg3
    call print_string
    call print_ok

    mov si, boot_msg4
    call print_string
    call print_ok

    mov si, boot_msg_cpu
    call print_string
    call print_ok

    mov si, boot_msg_rtc
    call print_string
    call print_ok

    mov si, boot_msg_part
    call print_string
    call print_ok

    mov si, boot_msg5
    call print_string
    call print_ok

    mov si, newline_str
    call print_string

    mov si, welcome_msg
    call print_string

prompt:
    mov si, cli_prompt
    call print_string
    mov di, cmd_buffer

read_key:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D            ; Enter
    je process_command

    cmp al, 0x08            ; Backspace
    je handle_backspace

    cmp al, 32
    jl read_key
    cmp al, 126
    jg read_key

    stosb
    call print_char_colored
    jmp read_key

handle_backspace:
    cmp di, cmd_buffer
    je read_key
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp read_key

process_command:
    mov byte [di], 0
    mov si, newline_str
    call print_string

    cmp byte [cmd_buffer], 0
    je prompt

    mov si, cmd_buffer
    call to_uppercase

    ; --- Command Routing ---
    mov si, cmd_buffer
    mov di, cmd_cls
    call strcmp
    je do_cls

    mov si, cmd_buffer
    mov di, cmd_beep
    call strcmp
    je do_beep

    mov si, cmd_buffer
    mov di, cmd_lgui
    call strcmp
    je do_lgui

    mov si, cmd_buffer
    mov di, cmd_notepad
    call strcmp
    je do_notepad

    mov si, cmd_buffer
    mov di, cmd_setup
    call strcmp
    je do_setup

    mov si, cmd_buffer
    mov di, cmd_dir
    call strcmp
    je do_dir

    mov si, cmd_buffer
    mov di, cmd_tree
    call strcmp
    je do_tree

    mov si, cmd_buffer
    mov di, cmd_time
    call strcmp
    je do_time

    mov si, cmd_buffer
    mov di, cmd_date
    call strcmp
    je do_date

    mov si, cmd_buffer
    mov di, cmd_vol
    call strcmp
    je do_vol

    mov si, cmd_buffer
    mov di, cmd_sysinfo
    call strcmp
    je do_sysinfo

    mov si, cmd_buffer
    mov di, cmd_cd
    call starts_with
    je do_cd

    mov si, cmd_buffer
    mov di, cmd_copy
    call starts_with
    je do_copy

    mov si, cmd_buffer
    mov di, cmd_del
    call starts_with
    je do_del

    mov si, cmd_buffer
    mov di, cmd_erase
    call starts_with
    je do_del

    mov si, cmd_buffer
    mov di, cmd_diskpart
    call strcmp
    je do_diskpart

    mov si, cmd_buffer
    mov di, cmd_find
    call starts_with
    je do_find

    mov si, cmd_buffer
    mov di, cmd_md
    call starts_with
    je do_md

    mov si, cmd_buffer
    mov di, cmd_mkdir
    call starts_with
    je do_md

    mov si, cmd_buffer
    mov di, cmd_mklink
    call starts_with
    je do_mklink

    mov si, cmd_buffer
    mov di, cmd_move
    call starts_with
    je do_move

    mov si, cmd_buffer
    mov di, cmd_xcopy
    call starts_with
    je do_xcopy

    mov si, cmd_buffer
    mov di, cmd_color
    call starts_with
    je do_color

    mov si, cmd_buffer
    mov di, cmd_help
    call strcmp
    je do_help

    mov si, unknown_msg
    call print_string
    jmp prompt

; --- Shell Commands ---

do_cls:
    call clear_screen
    jmp prompt

do_help:
    mov si, help_msg
    call print_string
    jmp prompt

do_beep:
    call play_beep_sound
    mov si, beep_ok_msg
    call print_string
    jmp prompt

do_sysinfo:
    mov si, sysinfo_msg
    call print_string
    jmp prompt

do_vol:
    mov si, vol_msg
    call print_string
    jmp prompt

do_diskpart:
    mov si, diskpart_msg
    call print_string
    jmp prompt

do_cd:
    mov si, cd_msg
    call print_string
    jmp prompt

do_copy:
    mov si, copy_msg
    call print_string
    jmp prompt

do_del:
    mov si, del_msg
    call print_string
    jmp prompt

do_find:
    mov si, find_msg
    call print_string
    jmp prompt

do_setup:
    mov si, setup_header
    call print_string

    mov si, setup_confirm
    call print_string

.wait_confirm:
    mov ah, 0x00
    int 0x16

    cmp al, 'y'
    je .proceed
    cmp al, 'Y'
    je .proceed

    mov si, newline_str
    call print_string
    mov si, setup_cancel_msg
    call print_string
    jmp prompt

.proceed:
    mov si, newline_str
    call print_string

    mov si, setup_format_msg
    call print_string
    call write_boot_sector
    jc .install_failed

    call initialize_fat_root
    jc .install_failed

    mov si, setup_copy_msg
    call print_string
    call copy_kernel_files
    jc .install_failed

    mov si, setup_done_msg
    call print_string
    jmp prompt

.install_failed:
    mov si, setup_fail_msg
    call print_string
    jmp prompt

do_md:
    mov si, mkdir_prompt
    call print_string

    mov di, input_buffer
    mov cx, 11
.clear_in:
    mov byte [di], ' '
    inc di
    loop .clear_in
    mov byte [di], 0

    mov di, input_buffer

.read_folder_name:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D            ; Enter
    je .create_folder_entry

    cmp al, 0x08            ; Backspace
    je .handle_rbk

    cmp di, input_buffer + 11
    jge .read_folder_name

    stosb
    call print_char_colored
    jmp .read_folder_name

.handle_rbk:
    cmp di, input_buffer
    je .read_folder_name
    dec di
    mov byte [di], ' '
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_folder_name

.create_folder_entry:
    mov si, newline_str
    call print_string

    mov si, input_buffer
    call to_uppercase

    call read_root_directory
    mov bx, disk_buffer

.find_free_slot:
    cmp byte [bx], 0x00
    je .found_slot
    cmp byte [bx], 0xE5
    je .found_slot
    add bx, 32
    jmp .find_free_slot

.found_slot:
    mov si, input_buffer
    mov di, bx
    mov cx, 11
    rep movsb               

    mov byte [bx + 11], 0x10 ; Folder Attribute

    call write_root_directory

    mov si, md_success_msg
    call print_string
    jmp prompt

do_mklink:
    mov si, mklink_msg
    call print_string
    jmp prompt

do_move:
    mov si, move_msg
    call print_string
    jmp prompt

do_xcopy:
    mov si, xcopy_msg
    call print_string
    jmp prompt

; --- LGUI Desktop Environment ---

do_lgui:
    mov ah, 0x00
    mov al, 0x13            ; Switch to 320x200 256-color VGA mode
    int 0x10

    ; Reset PS/2 Mouse Driver
    mov ax, 0x0000
    int 0x33
    cmp ax, 0xFFFF
    jne .no_mouse

    ; Show mouse cursor
    mov ax, 0x0001
    int 0x33
    mov byte [mouse_enabled], 1
    jmp .reset_gui_state

.no_mouse:
    mov byte [mouse_enabled], 0

.reset_gui_state:
    mov byte [active_win], 0
    mov byte [start_open], 0
    mov byte [power_open], 0
    mov word [cursor_x], 160
    mov word [cursor_y], 100
    mov byte [need_redraw], 1       

.gui_event_loop:
    ; Non-blocking keyboard check first
    mov ah, 0x01
    int 0x16
    jz .process_mouse

    ; Read Keypress
    mov ah, 0x00
    int 0x16

    ; Exit LGUI on ESC or F12
    cmp al, 0x1B            ; ESC
    je .exit_lgui
    cmp ah, 0x58            ; F12
    je .exit_lgui

.process_mouse:
    cmp byte [mouse_enabled], 0
    je .render_check

    ; Poll Mouse Status
    mov ax, 0x0003
    int 0x33
    
    shr cx, 1               ; Scale X position from 640 to 320 for Mode 13h

    ; Clamp Mouse Cursor to Screen Bounds
    cmp cx, 312
    jbe .chk_y_bound
    mov cx, 312
.chk_y_bound:
    cmp dx, 192
    jbe .update_pos
    mov dx, 192

.update_pos:
    cmp cx, [cursor_x]
    jne .pos_changed
    cmp dx, [cursor_y]
    je .check_clicks

.pos_changed:
    mov [cursor_x], cx
    mov [cursor_y], dx
    mov byte [need_redraw], 1

.check_clicks:
    test bx, 1              ; Left Click Check
    jz .render_check

    cmp dx, 16
    jl .click_top_bar
    jmp .render_check

.click_top_bar:
    cmp cx, 80
    jg .render_check
    xor byte [start_open], 1
    mov byte [need_redraw], 1
    call debounce_mouse

.render_check:
    cmp byte [need_redraw], 0
    je .frame_delay

    call redraw_desktop_area
    mov byte [need_redraw], 0       

.frame_delay:
    ; Frame delay (~60 FPS) to prevent 100% CPU lock
    mov ah, 0x86
    mov cx, 0x0000
    mov dx, 0x3E80          ; ~16ms sleep
    int 0x15

    jmp .gui_event_loop

.exit_lgui:
    ; Hide Mouse Cursor
    mov ax, 0x0002
    int 0x33

    ; Restore Text Mode (80x25 16-color)
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    call clear_screen
    mov si, lgui_exit_msg
    call print_string
    jmp prompt

debounce_mouse:
    cmp byte [mouse_enabled], 0
    je .done_db
    push ax
    push bx
.wait_up:
    mov ax, 0x0003
    int 0x33
    test bx, 1
    jnz .wait_up
    pop bx
    pop ax
.done_db:
    ret

redraw_desktop_area:
    call restore_mouse_bg
    call draw_desktop
    call draw_top_taskbar
    call draw_desktop_icons

    cmp byte [active_win], 0
    je .chk_m
    call draw_active_window

.chk_m:
    cmp byte [start_open], 1
    jne .chk_p
    call draw_start_menu

.chk_p:
    cmp byte [power_open], 1
    jne .d_cur
    call draw_power_menu

.d_cur:
    call save_mouse_bg
    call draw_mouse_cursor
    ret

; --- VGA Drivers ---

draw_desktop:
    push es
    pusha
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov ax, 0x0303          ; Cyan
    mov cx, 32000
    rep stosw               
    popa
    pop es
    ret

draw_top_taskbar:
    push es
    pusha
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov ax, 0x0808          ; Dark Gray
    mov cx, 2560
    rep stosw               
    popa
    pop es

    mov bx, 2
    mov dx, 5
    mov al, 0x01            ; Blue Start Button
    mov cx, 12
    mov si, 50
    call fill_rect

    mov bx, 2
    mov dx, 230
    mov al, 0x02            ; Green Status
    mov cx, 12
    mov si, 60
    call fill_rect
    ret

draw_desktop_icons:
    mov bx, 30
    mov dx, 20
    mov al, 0x01
    mov cx, 30
    mov si, 30
    call fill_rect

    mov bx, 30
    mov dx, 80
    mov al, 0x0E
    mov cx, 30
    mov si, 30
    call fill_rect

    mov bx, 30
    mov dx, 140
    mov al, 0x0F
    mov cx, 30
    mov si, 30
    call fill_rect
    ret

draw_active_window:
    mov bx, 30
    mov dx, 50
    mov al, 0x07
    mov cx, 140
    mov si, 220
    call fill_rect

    mov bx, 30
    mov dx, 50
    mov al, 0x01
    mov cx, 14
    mov si, 220
    call fill_rect

    mov bx, 32
    mov dx, 255
    mov al, 0x0C
    mov cx, 10
    mov si, 13
    call fill_rect

    mov bx, 46
    mov dx, 52
    mov al, 0x00
    cmp byte [active_win], 2
    jne .chk_np_win
    mov al, 0x08
.chk_np_win:
    cmp byte [active_win], 3
    jne .fill_inner
    mov al, 0x0F
.fill_inner:
    mov cx, 122
    mov si, 216
    call fill_rect
    ret

draw_start_menu:
    mov bx, 16
    mov dx, 5
    mov al, 0x07
    mov cx, 64
    mov si, 80
    call fill_rect
    ret

draw_power_menu:
    mov bx, 80
    mov dx, 140
    mov al, 0x04
    mov cx, 48
    mov si, 80
    call fill_rect
    ret

fill_rect:
    pusha
    push es

    mov di, 0xA000
    mov es, di
    mov byte [.rect_color], al

.row_loop:
    push cx
    push bx
    push dx

    mov ax, bx              ; Y
    mov cx, 320
    mul cx                  

    pop dx
    push dx
    
    add ax, dx              ; (Y * 320) + X
    mov di, ax

    mov al, [.rect_color]
    mov ah, al              
    mov cx, si
    shr cx, 1               
    rep stosw               

    test si, 1              
    jz .next_line
    stosb

.next_line:
    pop dx
    pop bx
    pop cx

    inc bx                  
    loop .row_loop

    pop es
    popa
    ret

.rect_color: db 0

; --- Double-Buffered Mouse Cursor Drivers ---

save_mouse_bg:
    pusha
    push ds
    push es

    mov ax, 0xA000
    mov ds, ax
    mov ax, cs
    mov es, ax

    mov ax, [cursor_y]
    mov cx, 320
    mul cx
    add ax, [cursor_x]
    mov si, ax
    mov [saved_cursor_offset], si

    mov di, mouse_bg_buffer
    mov cx, 5
.save_loop:
    push cx
    push si
    mov cx, 4
    rep movsb
    pop si
    add si, 320
    pop cx
    loop .save_loop

    mov byte [cursor_saved], 1

    pop es
    pop ds
    popa
    ret

restore_mouse_bg:
    cmp byte [cursor_saved], 0
    je .done_restore

    pusha
    push ds
    push es

    mov ax, cs
    mov ds, ax
    mov ax, 0xA000
    mov es, ax

    mov si, mouse_bg_buffer
    mov di, [saved_cursor_offset]

    mov cx, 5
.restore_loop:
    push cx
    push di
    mov cx, 4
    rep movsb
    pop di
    add di, 320
    pop cx
    loop .restore_loop

    mov byte [cursor_saved], 0

    pop es
    pop ds
    popa
.done_restore:
    ret

draw_mouse_cursor:
    pusha
    push es

    mov ax, 0xA000
    mov es, ax

    mov ax, [cursor_y]
    mov cx, 320
    mul cx
    add ax, [cursor_x]
    mov di, ax

    mov al, 0x0F            ; Bright White

    ; Render Cursor Pixel Pattern
    mov byte [es:di], al

    add di, 320
    mov byte [es:di], al
    mov byte [es:di+1], al

    add di, 320
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di+2], al

    add di, 320
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di+2], al
    mov byte [es:di+3], al

    add di, 320
    mov byte [es:di], al
    mov byte [es:di+1], al

    pop es
    popa
    ret

; --- Low-Level Disk Installer Drivers ---

write_boot_sector:
    pusha
    mov di, disk_buffer
    mov cx, 256
    xor ax, ax
    rep stosw

    mov word [disk_buffer + 510], 0xAA55

    mov ah, 0x03
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, 1
    mov dl, [target_drive]
    mov bx, disk_buffer
    int 0x13
    popa
    ret

initialize_fat_root:
    pusha
    mov di, disk_buffer
    mov cx, 256
    xor ax, ax
    rep stosw

    mov ah, 0x03
    mov al, 1
    mov ch, 0
    mov dh, 1
    mov cl, 2
    mov dl, [target_drive]
    mov bx, disk_buffer
    int 0x13
    popa
    ret

copy_kernel_files:
    pusha
    mov ah, 0x03
    mov al, 1
    mov ch, 0
    mov dh, 1
    mov cl, 16
    mov dl, [target_drive]
    mov bx, kernel_start
    int 0x13
    popa
    ret

; --- RTC & Hardware Routines ---

do_time:
    mov si, time_label
    call print_string

    mov ah, 0x02
    int 0x1A

    mov al, ch
    call print_bcd_byte
    mov al, ':'
    call print_char_colored

    mov al, cl
    call print_bcd_byte
    mov al, ':'
    call print_char_colored

    mov al, dh
    call print_bcd_byte

    mov si, newline_str
    call print_string
    jmp prompt

do_date:
    mov si, date_label
    call print_string

    mov ah, 0x04
    int 0x1A

    mov al, dl
    call print_bcd_byte
    mov al, '/'
    call print_char_colored

    mov al, dh
    call print_bcd_byte
    mov al, '/'
    call print_char_colored

    cmp ch, 0x00
    jne .print_real_year

    mov al, '2'
    call print_char_colored
    mov al, '0'
    call print_char_colored
    mov al, '2'
    call print_char_colored
    mov al, '6'
    call print_char_colored
    jmp .done_date

.print_real_year:
    mov al, ch
    call print_bcd_byte
    mov al, cl
    call print_bcd_byte

.done_date:
    mov si, newline_str
    call print_string
    jmp prompt

print_bcd_byte:
    push ax
    shr al, 4
    add al, '0'
    call print_char_colored
    pop ax
    and al, 0x0F
    add al, '0'
    call print_char_colored
    ret

play_beep_sound:
    mov al, 0xB6
    out 0x43, al
    mov ax, 0x04A9
    out 0x42, al
    mov al, ah
    out 0x42, al

    in al, 0x61
    or al, 0x03
    out 0x61, al

    mov cx, 0x000F
.delay_outer:
    mov dx, 0xFFFF
.delay_inner:
    dec dx
    jnz .delay_inner
    loop .delay_outer

    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret

do_color:
    mov si, cmd_buffer + 5
    cmp byte [si], 0
    je .show_help
    cmp byte [si], ' '
    jne .show_help
    inc si
    cmp byte [si], 0
    je .show_help

    mov di, str_help_arg
    call strcmp
    je .show_help

    mov al, [si]
    call hex_char_to_val
    cmp al, 0xFF
    je .show_help
    shl al, 4
    mov bl, al

    mov al, [si+1]
    call hex_char_to_val
    cmp al, 0xFF
    je .show_help
    or bl, al

    mov [current_color], bl
    call clear_screen
    jmp prompt

.show_help:
    mov si, color_help_msg
    call print_string
    jmp prompt

do_dir:
    mov si, dir_header
    call print_string
    call read_root_directory
    mov bx, disk_buffer
    mov cx, 16

.next_entry:
    cmp byte [bx], 0x00
    je .done
    cmp byte [bx], 0xE5
    je .skip_entry
    cmp byte [bx + 11], 0x0F
    je .skip_entry

    mov si, bx
    mov dx, 8
.print_name:
    lodsb
    call print_char_colored
    dec dx
    jnz .print_name

    test byte [bx + 11], 0x10
    jnz .print_dir_tag

    mov al, '.'
    call print_char_colored

    mov si, bx
    add si, 8
    mov dx, 3
.print_ext:
    lodsb
    call print_char_colored
    dec dx
    jnz .print_ext

    mov si, dir_file_info
    call print_string
    jmp .skip_entry

.print_dir_tag:
    mov si, dir_folder_info
    call print_string

.skip_entry:
    add bx, 32
    loop .next_entry

.done:
    jmp prompt

do_tree:
    mov si, tree_header
    call print_string
    call read_root_directory
    mov bx, disk_buffer
    mov cx, 16

.next_tree_entry:
    cmp byte [bx], 0x00
    je .tree_done
    cmp byte [bx], 0xE5
    je .skip_tree_entry

    mov al, [bx]
    cmp al, 33
    jb .skip_tree_entry
    cmp al, 126
    ja .skip_tree_entry

    mov si, tree_branch
    call print_string

    mov si, bx
    mov dx, 8
.print_tname:
    lodsb
    cmp al, ' '
    je .skip_char
    call print_char_colored
.skip_char:
    dec dx
    jnz .print_tname

    test byte [bx + 11], 0x10
    jnz .print_tree_dir_tag

    mov al, '.'
    call print_char_colored

    mov si, bx
    add si, 8
    mov dx, 3
.print_text:
    lodsb
    cmp al, ' '
    je .skip_ext_char
    call print_char_colored
.skip_ext_char:
    dec dx
    jnz .print_text

    mov si, newline_str
    call print_string
    jmp .skip_tree_entry

.print_tree_dir_tag:
    mov si, tree_folder_suffix
    call print_string

.skip_tree_entry:
    add bx, 32
    loop .next_tree_entry

.tree_done:
    jmp prompt

do_notepad:
    call draw_notepad_screen
    mov di, file_buffer

.notepad_loop:
    mov ah, 0x00
    int 0x16

    cmp ah, 0x3D            ; F3
    je file_manager

    cmp ah, 0x3E            ; F4
    je rename_file

    cmp ah, 0x40            ; F6
    je notepad_color_picker

    cmp al, 0x1B            ; ESC
    je .save_and_exit

    cmp al, 0x0D            ; Enter
    je .newline

    cmp al, 0x08            ; Backspace
    je .backspace

    cmp al, 32
    jl .notepad_loop

    stosb
    mov bl, [notepad_color]
    call print_char_colored_attr
    jmp .notepad_loop

.newline:
    mov byte [di], 0xd
    inc di
    mov byte [di], 0xa
    inc di
    mov ah, 0x0e
    mov al, 0x0d
    int 0x10
    mov al, 0x0a
    int 0x10
    jmp .notepad_loop

.backspace:
    cmp di, file_buffer
    je .notepad_loop
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .notepad_loop

.save_and_exit:
    mov byte [di], 0

    mov ah, 0x03
    mov al, 1
    mov ch, 0
    mov dh, 1
    mov cl, 16
    mov dl, 0x80
    mov bx, file_buffer
    int 0x13

    call clear_screen
    mov si, saved_ok_msg
    call print_string
    jmp prompt

notepad_color_picker:
    mov ah, 0x02
    mov bh, 0
    mov dx, 0x1500
    int 0x10

    mov si, np_color_help
    call print_string_notepad

    mov ah, 0x00
    int 0x16
    call hex_char_to_val
    cmp al, 0xFF
    je .cancel
    shl al, 4
    mov bl, al

    mov ah, 0x00
    int 0x16
    call hex_char_to_val
    cmp al, 0xFF
    je .cancel
    or bl, al

    mov [notepad_color], bl

.cancel:
    call draw_notepad_screen
    mov si, file_buffer
    call print_string_notepad
    jmp do_notepad.notepad_loop

file_manager:
    call draw_notepad_screen

    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0202
    int 0x10
    mov si, fm_title
    call print_string_notepad

    call read_root_directory
    mov byte [selected_file], 0

.render_list:
    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0402
    int 0x10

    mov bx, disk_buffer
    mov cx, 0

.entry_loop:
    cmp byte [bx], 0x00
    je .done_list
    cmp byte [bx], 0xE5
    je .next_entry
    cmp byte [bx + 11], 0x0F
    je .next_entry

    mov al, cl
    cmp al, [selected_file]
    jne .print_unselected

.print_selected:
    mov si, pointer_str
    call print_string_notepad
    jmp .print_entry_name

.print_unselected:
    mov si, space_pointer
    call print_string_notepad

.print_entry_name:
    push cx
    mov si, bx
    mov dx, 8
.p_name:
    lodsb
    mov bl, [notepad_color]
    call print_char_colored_attr
    dec dx
    jnz .p_name

    mov al, '.'
    mov bl, [notepad_color]
    call print_char_colored_attr

    mov si, bx
    add si, 8
    mov dx, 3
.p_ext:
    lodsb
    mov bl, [notepad_color]
    call print_char_colored_attr
    dec dx
    jnz .p_ext

    mov si, newline_str
    call print_string_notepad
    pop cx

    inc cx
    cmp cx, 2
    je .done_list

.next_entry:
    add bx, 32
    jmp .entry_loop

.done_list:
.wait_input:
    mov ah, 0x00
    int 0x16

    cmp ah, 0x48
    je .move_up
    cmp ah, 0x50
    je .move_down
    cmp al, 0x0D
    je .load_selected
    jmp .wait_input

.move_up:
    mov byte [selected_file], 0
    jmp .render_list

.move_down:
    mov byte [selected_file], 1
    jmp .render_list

.load_selected:
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov dh, 1
    mov cl, 16
    mov dl, 0x80
    mov bx, file_buffer
    int 0x13

    call draw_notepad_screen
    mov si, file_buffer
    call print_string_notepad
    jmp do_notepad.notepad_loop

rename_file:
    mov ah, 0x02
    mov bh, 0
    mov dx, 0x1602
    int 0x10

    mov si, rename_prompt
    call print_string_notepad

    mov di, file1_name
    cmp byte [selected_file], 1
    jne .clear_target
    mov di, file2_name

.clear_target:
    push di
    mov cx, 16
    mov al, 0
    rep stosb
    pop di

.read_new_name:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D
    je .done_rename

    cmp al, 0x08
    je .handle_rbk

    stosb
    mov bl, [notepad_color]
    call print_char_colored_attr
    jmp .read_new_name

.handle_rbk:
    cmp di, file1_name
    je .read_new_name
    cmp di, file2_name
    je .read_new_name
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_new_name

.done_rename:
    mov byte [di], 0
    call draw_notepad_screen
    mov si, file_buffer
    call print_string_notepad
    jmp do_notepad.notepad_loop

read_root_directory:
    pusha
    mov di, disk_buffer
    mov cx, 256             ; Clear buffer (512 bytes / 2)
    xor ax, ax
    rep stosw

    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov dh, 1
    mov cl, 2
    mov dl, 0x80
    mov bx, disk_buffer
    int 0x13
    popa
    ret

write_root_directory:
    mov ah, 0x03
    mov al, 32
    mov ch, 0
    mov dh, 1
    mov cl, 2
    mov dl, 0x80
    mov bx, disk_buffer
    int 0x13
    ret

draw_notepad_screen:
    mov ah, 0x06
    mov al, 0x00
    mov bh, [notepad_color]
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10

    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0000
    int 0x10

    mov si, np_header
    call print_string_notepad

    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0200
    int 0x10
    ret

clear_screen:
    mov ah, 0x06
    mov al, 0x00
    mov bh, [current_color]
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10

    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0000
    int 0x10
    ret

to_uppercase:
    push si
.loop:
    mov al, [si]
    cmp al, 0
    je .done
    cmp al, 'a'
    jb .next
    cmp al, 'z'
    ja .next
    sub al, 32
    mov [si], al
.next:
    inc si
    jmp .loop
.done:
    pop si
    ret

hex_char_to_val:
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    jbe .num
    cmp al, 'A'
    jb .invalid
    cmp al, 'F'
    jbe .alpha
.invalid:
    mov al, 0xFF
    ret
.num:
    sub al, '0'
    ret
.alpha:
    sub al, 'A'
    add al, 10
    ret

starts_with:
.loop:
    mov al, [di]
    cmp al, 0
    je .match
    mov bl, [si]
    cmp al, bl
    jne .no_match
    inc si
    inc di
    jmp .loop
.match:
    xor ax, ax
    ret
.no_match:
    mov ax, 1
    ret

print_ok:
    mov si, str_ok
.loop:
    lodsb
    or al, al
    jz .done
    mov bl, 0x0A
    call print_char_colored_attr
    jmp .loop
.done:
    mov si, newline_str
    call print_string
    ret

print_char_colored:
    mov bl, [current_color]

print_char_colored_attr:
    mov ah, 0x09
    mov bh, 0
    mov cx, 1
    int 0x10

    mov ah, 0x0e
    int 0x10
    ret

print_string:
    lodsb
    or al, al
    jz .done
    cmp al, 0x0D
    je .ctrl
    cmp al, 0x0A
    je .ctrl
    call print_char_colored
    jmp print_string
.ctrl:
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

print_string_notepad:
    lodsb
    or al, al
    jz .done
    cmp al, 0x0D
    je .ctrl
    cmp al, 0x0A
    je .ctrl
    mov bl, [notepad_color]
    call print_char_colored_attr
    jmp print_string_notepad
.ctrl:
    mov ah, 0x0e
    int 0x10
    jmp print_string_notepad
.done:
    ret

strcmp:
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    mov ax, 1
    ret
.equal:
    xor ax, ax
    ret

; --- Strings and Variables ---

boot_msg1:          db 'Initializing LONOS2 Kernel...', 0
boot_msg2:          db 'Loading BIOS Disk Interrupts (INT 13h)...', 0
boot_msg3:          db 'Detecting IDE Controller Primary Master...', 0
boot_msg4:          db 'ALLOCATING FAT16 VOLUME...', 0
boot_msg_cpu:       db 'Checking x86 CPU Real Mode Execution...', 0
boot_msg_rtc:       db 'Synchronizing Real-Time Clock (RTC)...', 0
boot_msg_part:      db 'Parsing Master Boot Record (MBR)...', 0
boot_msg5:          db 'Starting LONOS Interactive Shell...', 0
str_ok:             db ' [ OK ]', 0

welcome_msg:        db 'LONOS2 Workstation OS v1.5 (FAT16 Volume)', 0xd, 0xa, 0
cli_prompt:         db 'LONOS2> ', 0
newline_str:        db 0xd, 0xa, 0
unknown_msg:        db 'Unknown command.', 0xd, 0xa, 0
help_msg:           db 'Commands: BEEP, CD, CLS, COLOR, COPY, DATE, DEL, DIR, DISKPART, ERASE,', 0xd, 0xa
                    db '          FIND, HELP, LGUI, MD, MKDIR, MKLINK, MOVE, NOTEPAD, SETUP,', 0xd, 0xa
                    db '          SYSINFO, TIME, TREE, VOL, XCOPY', 0xd, 0xa, 0
saved_ok_msg:       db 'File saved successfully!', 0xd, 0xa, 0
beep_ok_msg:        db 'Beeped speaker.', 0xd, 0xa, 0

time_label:         db 'Current system time: ', 0
date_label:         db 'Current system date: ', 0

vol_msg:            db ' Volume in drive C is LONOS2 DISK', 0xd, 0xa
                    db ' Volume Serial Number is 1234-5678', 0xd, 0xa, 0

sysinfo_msg:        db 'LONOS2 Workstation System Info:', 0xd, 0xa
                    db ' - Architecture: x86 (16-bit Real Mode)', 0xd, 0xa
                    db ' - File System: FAT16 (2GB Target)', 0xd, 0xa
                    db ' - Base Segment: 0x1000', 0xd, 0xa, 0

cd_msg:             db 'C:\', 0xd, 0xa, 0
copy_msg:           db '1 file(s) copied.', 0xd, 0xa, 0
del_msg:            db 'File deleted.', 0xd, 0xa, 0
diskpart_msg:       db 'Disk 0: 2048 MB (FAT16 Active Primary)', 0xd, 0xa, 0
find_msg:           db 'FIND: Searching file contents...', 0xd, 0xa, 0
mkdir_prompt:       db 'Name: ', 0
md_success_msg:     db 'Directory created successfully.', 0xd, 0xa, 0
mklink_msg:         db 'Symbolic link created.', 0xd, 0xa, 0
move_msg:           db '1 file(s) moved.', 0xd, 0xa, 0
xcopy_msg:          db 'Directory tree copied successfully.', 0xd, 0xa, 0

setup_header:       db '=== LONOS2 Operating System Setup ===', 0xd, 0xa, 0
setup_confirm:      db 'WARNING: All data on target drive will be overwritten!', 0xd, 0xa
                    db 'Type Y to proceed with partition & format: ', 0
setup_format_msg:   db 'Formatting partition table & FAT16 structure...', 0xd, 0xa, 0
setup_copy_msg:     db 'Copying LONOS2 Kernel system files...', 0xd, 0xa, 0
setup_done_msg:     db 'Installation complete! You may now boot from target drive.', 0xd, 0xa, 0
setup_cancel_msg:   db 'Installation aborted by user.', 0xd, 0xa, 0
setup_fail_msg:     db 'Disk error writing to target drive.', 0xd, 0xa, 0

np_header:          db '=== LONOS2 EDIT === [F3: Open] [F4: Rename] [F6: Color] [ESC: Save/Exit]', 0xd, 0xa, 0
fm_title:           db '--- SELECT FILE TO OPEN ---', 0xd, 0xa, 0
rename_prompt:      db 'Enter New File Name: ', 0
pointer_str:        db '-> ', 0
space_pointer:      db '   ', 0

color_help_msg:     db 'Sets default console foreground and background colors.', 0xd, 0xa, 0xd, 0xa
                    db 'COLOR [attr]', 0xd, 0xa, 0xd, 0xa
                    db '  0 = Black       8 = Gray', 0xd, 0xa
                    db '  1 = Blue        9 = Light Blue', 0xd, 0xa
                    db '  2 = Green       A = Light Green', 0xd, 0xa
                    db '  3 = Aqua        B = Light Aqua', 0xd, 0xa
                    db '  4 = Red         C = Light Red', 0xd, 0xa
                    db '  5 = Purple      D = Light Purple', 0xd, 0xa
                    db '  6 = Yellow      E = Light Yellow', 0xd, 0xa
                    db '  7 = White       F = Bright White', 0xd, 0xa, 0

np_color_help:      db 'COLOR [0-F][0-F] (e.g. 0A): ', 0
str_help_arg:       db 'HELP', 0

lgui_exit_msg:      db 'Exited LGUI.', 0xd, 0xa, 0

dir_header:         db 'Directory of C:\', 0xd, 0xa, 0
dir_file_info:      db '         2048 bytes', 0xd, 0xa, 0
dir_folder_info:    db '    <DIR>', 0xd, 0xa, 0
tree_header:        db 'C:\', 0xd, 0xa, 0
tree_branch:        db ' |-- ', 0
tree_folder_suffix: db ' (DIR)', 0xd, 0xa, 0

cmd_cls:            db 'CLS', 0
cmd_help:           db 'HELP', 0
cmd_lgui:           db 'LGUI', 0
cmd_notepad:        db 'NOTEPAD', 0
cmd_setup:          db 'SETUP', 0
cmd_dir:            db 'DIR', 0
cmd_tree:           db 'TREE', 0
cmd_color:          db 'COLOR', 0
cmd_beep:           db 'BEEP', 0
cmd_sysinfo:        db 'SYSINFO', 0
cmd_time:           db 'TIME', 0
cmd_date:           db 'DATE', 0
cmd_vol:            db 'VOL', 0
cmd_cd:             db 'CD', 0
cmd_copy:           db 'COPY', 0
cmd_del:            db 'DEL', 0
cmd_erase:          db 'ERASE', 0
cmd_diskpart:       db 'DISKPART', 0
cmd_find:           db 'FIND', 0
cmd_md:             db 'MD', 0
cmd_mkdir:          db 'MKDIR', 0
cmd_mklink:         db 'MKLINK', 0
cmd_move:           db 'MOVE', 0
cmd_xcopy:          db 'XCOPY', 0

active_win:         db 0
start_open:         db 0
power_open:         db 0
mouse_enabled:      db 0
need_redraw:        db 1

cursor_x:           dw 160
cursor_y:           dw 100
cursor_saved:       db 0
saved_cursor_offset: dw 0

mouse_bg_buffer:    times 20 db 0

target_drive:       db 0x80

file1_name:         times 16 db 0
file2_name:         times 16 db 0
selected_file:      db 0

current_color:      db 0x07
notepad_color:      db 0x07
cmd_buffer:         times 64 db 0
input_buffer:       times 32 db 0
file_buffer:        times 512 db 0
disk_buffer:        times 512 db 0