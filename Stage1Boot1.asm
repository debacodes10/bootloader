bits 16
org 0x7C00

start: jmp main

; BIOS Parameter Block (for 1.44MB floppy)
bpbOEM                  db "DebOS   "
bpbBytesPerSector       dw 512
bpbSectorsPerCluster    db 1
bpbReservedSectors      dw 1
bpbNumberOfFATs         db 2
bpbRootEntries          dw 224
bpbTotalSectors         dw 2880
bpbMedia                db 0xF0  ; F0 for 1.44MB floppy
bpbSectorsPerFAT        dw 9
bpbSectorsPerTrack      dw 18
bpbHeadsPerCylinder     dw 2
bpbHiddenSectors        dd 0
bpbTotalSectorsBig      dd 0
bsDriveNumber           db 0
bsUnused                db 0
bsExtBootSignature      db 0x29
bsSerialNumber          dd 0xa0a1a2a3
bsVolumeLabel           db "MOS FLOPPY "
bsFileSystem            db "FAT12   "

;==================================================================
;   ROUTINES
;==================================================================

; Print: Prints a null-terminated string.
; IN: SI = address of string
Print:
    lodsb           ; Load character from SI into AL, increment SI
    or al, al       ; Check if AL is zero
    jz .DONE
    mov ah, 0x0E    ; BIOS teletype function
    int 0x10
    jmp Print
.DONE:
    ret

; ReadSectors: Reads sectors from disk using LBA.
; IN: AX = LBA, CX = count, ES:BX = destination buffer, DL = drive
ReadSectors:
.LOOP:
    push cx
    call ReadSingleSector
    
    mov si, msgProgress ; Print a dot to show progress
    call Print
    
    add bx, word [bpbBytesPerSector] ; Move buffer pointer
    inc ax                          ; Next LBA sector
    pop cx
    loop .LOOP
    ret

ReadSingleSector:
    mov di, 5       ; 5 retries
.RETRY:
    push ax
    push bx
    call LBACHS     ; Convert LBA in AX to CHS
    pop bx
    pop ax

    mov ah, 0x02    ; BIOS Read Sector function
    mov al, 1       ; Read 1 sector
    mov ch, byte [absoluteTrack]
    mov cl, byte [absoluteSector]
    mov dh, byte [absoluteHead]
    ; DL should already be set
    int 0x13
    jnc .SUCCESS    ; If Carry Flag is clear, it worked!

    ; --- It failed, so reset disk and retry ---
    pusha
    mov ah, 0x00
    int 0x13
    popa
    dec di
    jnz .RETRY
    jmp FAILURE     ; All retries failed

.SUCCESS:
    ret

; LBACHS: Converts LBA address to CHS.
; IN: AX = LBA address | OUT: absoluteTrack, absoluteHead, absoluteSector
LBACHS:
    xor dx, dx
    div word [bpbSectorsPerTrack]
    inc dl
    mov byte [absoluteSector], dl
    xor dx, dx
    div word [bpbHeadsPerCylinder]
    mov byte [absoluteHead], dl
    mov byte [absoluteTrack], al
    ret

;==================================================================
;   MAIN PROGRAM
;==================================================================
main:
    ; --- Setup Segments and Stack ---
    cli
    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x7C00  ; Stack starts just below our code
    sti

    mov dl, byte [bsDriveNumber] ; Set boot drive number for reads

    mov si, msgLoading
    call Print

LOAD_ROOT:
    ; --- Calculate where the Root Directory starts ---
    mov ax, word [bpbNumberOfFATs]
    mul word [bpbSectorsPerFAT]
    add ax, word [bpbReservedSectors]
    mov word [RootDirectoryLBA], ax

    ; --- Calculate size of root directory in sectors ---
    mov ax, 32
    mul word [bpbRootEntries]
    div word [bpbBytesPerSector]
    mov cx, ax                      ; CX = sectors to read for root dir

    ; --- Load the root directory into memory ---
    mov ax, word [RootDirectoryLBA]
    mov bx, buffer                  ; Load to our buffer area
    call ReadSectors

    ; --- Calculate where the Data Section starts ---
    mov ax, word [RootDirectoryLBA]
    add ax, cx ; Root LBA + Root Size = Data LBA
    mov word [DataSectionLBA], ax

    ; --- Search for the kernel file in the root directory ---
    mov cx, word [bpbRootEntries]
    mov di, buffer
.LOOP:
    push cx
    mov si, ImageName
    mov cx, 11                      ; Compare 11 bytes
    repe cmpsb
    je FOUND_KERNEL
    pop cx
    add di, 32                      ; Next directory entry
    loop .LOOP
    jmp FAILURE

FOUND_KERNEL:
    pop cx ; Discard loop counter from stack

    ; --- Load the FAT into memory ---
    mov si, msgCRLF
    call Print

    mov ax, word [bpbReservedSectors]
    mov bx, buffer
    mov cx, word [bpbSectorsPerFAT]
    call ReadSectors

    ; --- Load the Kernel into memory at 0x10000 ---
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x0000

    mov dx, word [di + 0x001A]      ; Get first cluster of the file
    mov word [cluster], dx

LOAD_IMAGE:
    ; --- Convert cluster to LBA ---
    mov ax, word [cluster]
    sub ax, 2
    mul byte [bpbSectorsPerCluster]
    add ax, word [DataSectionLBA]

    ; --- Read one cluster (1 sector for our simple FS) ---
    push es
    push bx
    mov cx, 1
    mov bx, buffer2     ; Read cluster to a temporary buffer
    call ReadSectors    ; This will trash ES:BX, so we saved them
    
    ; --- Copy from temp buffer to final destination ---
    pop bx
    pop es
    mov si, buffer2
    mov cx, 512
    rep movsb

    ; --- Find next cluster in FAT ---
    mov ax, word [cluster]
    mov cx, ax
    mov dx, ax
    shr dx, 1
    add cx, dx
    mov si, buffer              ; FAT is in our buffer
    add si, cx
    mov dx, word [si]

    test ax, 1
    jnz .ODD_CLUSTER

.EVEN_CLUSTER:
    and dx, 0x0FFF
    jmp .GOT_CLUSTER
.ODD_CLUSTER:
    shr dx, 4
.GOT_CLUSTER:
    mov word [cluster], dx
    cmp dx, 0x0FF0              ; Check for end-of-chain marker
    jb LOAD_IMAGE

DONE:
    mov si, msgCRLF
    call Print
    jmp 0x1000:0x0000           ; Jump to our loaded kernel

FAILURE:
    mov si, msgFailure
    call Print
    hlt                         ; Halt the CPU

;==================================================================
;   DATA
;==================================================================
absoluteSector      db 0
absoluteHead        db 0
absoluteTrack       db 0
RootDirectoryLBA    dw 0
DataSectionLBA      dw 0
cluster             dw 0

ImageName           db "KRNLDR  SYS" ; 8.3 filename format
msgLoading          db 0x0D, 0x0A, "Loading Boot Image ", 0x00
msgCRLF             db 0x0D, 0x0A, 0x00
msgProgress         db ".", 0x00
msgFailure          db 0x0D, 0x0A, "ERROR: KRNLDR.SYS not found or disk error.", 0x0A, 0x00

times 510 - ($ - $$) db 0
dw 0xAA55

;==================================================================
;   BSS (Uninitialized Data) - must be after the boot signature filler
;==================================================================
section .bss
    buffer: resb 14336   ; Buffer for root directory (224 entries * 32 bytes = 7168) and FAT (9 sectors * 512 = 4608). 14336 is plenty.
    buffer2: resb 512    ; Temporary buffer for reading one sector/cluster
