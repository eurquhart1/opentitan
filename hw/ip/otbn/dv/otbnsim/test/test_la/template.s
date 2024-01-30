.text
    la         x1, qinv
    addi       x3, x0, 11
    BN.LID     x3, 0(x1)        /* w11 should now contain qinv */
    ecall

.data
    .balign 32
    qinv:
    .word 0xf301  /* -3327 in 32-bit two's complement */
    .word 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0
