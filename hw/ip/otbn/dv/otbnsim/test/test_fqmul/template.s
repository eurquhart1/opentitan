/* The input placeholders will be overwritten by the actual input values */

.text
    /* Load inputs from memory */
    la         x1, input_a
    addi       x3, x0, 1
    BN.LID     x3, 0(x1)          /*  w1 should now contain input_a */

    /* Load inputs from memory */
    la         x1, input_b
    addi       x3, x0, 2
    BN.LID     x3, 0(x1)          /*  w2 should now contain input_b */

    /* Load Q from memory */
    la         x1, q
    addi       x3, x0, 6
    BN.LID     x3, 0(x1)          /*  w6 should now contain Q */
    
    /* Load QINV from memory */
    la         x1, qinv
    addi       x3, x0, 4
    BN.LID     x3, 0(x1)          /*  w4 should now contain QINV */

    /* Load 16-bit mask from memory */
    la         x1, mask_16b
    addi       x3, x0, 5
    BN.LID     x3, 0(x1)          /*  w5 should now contain 16-bit mask */

    BN.MULQACC.WO.Z  w1, w1.0, w2.0, 0     /* w1 = input_a * input_b */

    BN.AND     w2, w5, w1         /*  w2 should contain low 16 bits of input to MONTMUL (a*b) */

    BN.MULQACC.WO.Z  w3, w2.0, w4.0, 0     /* w3 = t = (16_t)input * QINV */
    BN.MULQACC.WO.Z  w3, w3.0, w6.0, 0     /* w7 = t * Q */ 
    BN.SUB           w3, w1, w3            /* w3 = a - (t*Q) */
    BN.RSHI          w7, w0, w3 >> 16
    BN.AND           w7, w7, w5            /* w7 = (int16t)((a - t*Q)>>16) */
    ecall

.data
    .balign 32
    q:
    .word  0xd01  /* Q = 3329 */
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

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
    input_a:
    .dword  [inp1]
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    input_b:
    .dword  [inp2]
    .dword 0x0
    .dword 0x0
    .dword 0x0

    