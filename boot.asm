[bits 16]
[org 0x7C00]

jmp short boot_start
nop

; --- FAT16 BIOS Parameter Block (BPB) ---
oem_name:           db "LONOS2.0"       ; 8 bytes OEM identifier
bytes_per_sector:   dw 512              ; Standard sector size
sectors_per_cluster:db 4                ; 2 KB per cluster
reserved_sectors:   dw 1                ; Boot sector count
fat_count:          db 2                ; Number of FAT copies
root_dir_entries:   dw 512              ; Max root directory files
total_sectors_16:   dw 0                ; 0 if total sectors > 65535
media_descriptor:   db 0xF8             ; Fixed hard disk
fat_size_sectors:   dw 256              ; Sectors per FAT
sectors_per_track:  dw 63               ; Geometry info
head_count:         dw 255
hidden_sectors:     dd 0
total_sectors_32:   dd 409600           ; Disk size (~200 MB)

; --- Extended BIOS Parameter Block (EBPB) ---
drive_number:       db 0x80             ; First hard drive (C:)
reserved1:          db 0
boot_signature:     db 0x29             ; Extended boot signature
volume_id:          dd 0x12345678       ; Serial number
volume_label:       db "LONOS2 DISK"   ; 11 bytes label
file_system_type:   db "FAT16   "       ; 8 bytes FS label

boot_start:
    ; Standardize Segment Registers
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl    ; Save BIOS drive number passed in DL

    ; Read Kernel Sectors
    mov ah, 0x02
    mov al, 16              ; Load 16 sectors
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    int 0x13
    jc disk_error

    jmp 0x1000:0x0000

disk_error:
    cli
    hlt

boot_drive: db 0

times 510-($-$$) db 0
dw 0xAA55