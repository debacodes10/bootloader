bits 16

org 0x7c00

start: jmp loader ; jump over OEM block

bpbOEM db "My OS   "

bpbBytesPerSector: DW 512
bpbSectorsPerCluster: DB 1
bpbReservedSectors: DW 1
bpbNumberOfFATs: DB 2
bpbRootEntries: DW 224
bpbTotalSectors: DW 2880
bpbMedia: DB 0xF0
bpbSectorsPerFAT: DW 9
bpbSectorsPerTrack: DW 18
bpbHeadsPerCylinder: DW 2 
bpbHiddenSectors: DD 0 
bpbTotalSectorsBig: DD 0 
bsDriveNumber: DB 0 
bsUnused: DB 0 
bsExtBootSignature: DB 0x29
bsSerialNumber: DD 0xa0a1a2a3
bsVolumeLabel: DB "MOS FLOPPY"
bsFIleSystem: DB "FAT32   "

msg db "Welcome to my OS!", 0 

Print:
  lodsb ;load next byte from string from SI to AL
  or al, al ;al=0?
  jz PrintDone ;null terminator found. Bail out.
  mov ah, 0eh ;Print the character
  int 10h 
  jmp Print ;repeat untill null terminator found

PrintDone:
  ret ;return cause we finished

loader:
  xor ax, ax; setup segment to insure it is 0 
  mov ds, ax;
  mov es, ax; Since we are starting from 0x7c00, all addresses are based on 0x7c00:0, so null they segments.
  mov si,msg ;move our msg to print 
  call Print
  xor ax, ax; clear ax
  int 0x12; get amount of KB from BIOS 

  cli; clear interrupts
  hlt; halt the system 

times 510 - ($-$$) db 0 
dw 0xAA55 ;Boot signature.
