/* The input placeholders will be overwritten by the actual input values */

.text
    /* Load input from memory */
    la         x1, input
    addi       x3, x0, 1
    BN.LID     x3, 0(x1)          /*  w1 should now contain input */

    /* Load QINV from memory */
    la         x1, qinv
    addi       x3, x0, 4
    BN.LID     x3, 0(x1)          /*  w4 should now contain QINV */

    /* Load 16-bit mask from memory */
    la         x1, mask_16b
    addi       x3, x0, 5
    BN.LID     x3, 0(x1)          /*  w5 should now contain 16-bit mask */

    BN.AND     w2, w5, w1         /*  w2 should contain low 16 bits of input */

    BN.MULQACC.WO  w3, w2.0, w4.0, 0     /* w3 = (16_t)input * QINV */ 
    ecall

.data
    .balign 32
    qinv:
    .word  0xf301  /* -3327 in 32-bit two's complement */
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    mask_16b:
    .word  0xffff  /* 16 set bits */
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    input:
    .dword  [inp1]
    .dword 0x0
    .dword 0x0
    .dword 0x0