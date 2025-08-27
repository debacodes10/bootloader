org 0x7c00 ;Loading BIOS at 0x7c00

bits 16 ;set to 16 bit real mode

Start:

  cli ;clear all interrupts
  hlt ;halt the system

times 510 - ($-$$) db 0 ;clear till byte 510

dw 0xAA55 ;Boot signature at 511 and 512B
