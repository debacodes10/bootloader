LOAD_FAT:

; save starting cluster of boot image

  mov si, msgCRLF
  call Print
  mov dx, WORD [di + 0x001A]
  mov WORD [cluster], dx ; file's first cluster

  ; compute size of FAT and store in 'cx'

  xor ax, ax
  mov al, BYTE [bpbNumberOfFATs]
  mul WORD [bpbSectorsPerFAT]
  mov cx, ax

  ; compute location of FAT and store in 'ax'

  mov ax, WORD [bpbReservedSectors] ; adjust for boot sector 

  ; read FAT into memory

  mov bx, 0x0200 ; copy FAT above bootcode
  call ReadSectors

