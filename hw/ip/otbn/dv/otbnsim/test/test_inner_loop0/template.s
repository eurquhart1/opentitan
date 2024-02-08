/* The input placeholders will be overwritten by the actual input values */

.text
    /* Load zeta (fixed) from memory */
    la         x1, zeta
    addi       x3, x0, 1
    BN.LID     x3, 0(x1)          /*  w1 should now contain zeta */

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

    /* Load base address of r from memory */
    la         x1, r

    /* Set looping variables to constants while iteratively building */
    addi       x7, x0, 1          /* w7 : k */
    addi       x8, x0, 0        /* w8 : len */
    addi       x9, x0, 0          /* w9 : start */
    BN.ADD     w10, w0, w1     /* w10 : zeta (-1044 in 2s complement) */
    addi       x11, x0, 0         /* w11 : j */

    /* Load r[j + 1] into w13 */
    add        x12, x11, x8       /* w12 : j + len */
    slli       x12, x12, 4        /* w12 : (j + len)*16 ... offset to element in r */
    add        x1, x1, x12        /* x1 : base address of r plus offset to element */
    addi       x3, x0, 13         /* idx for w15 */
    BN.LID     x3, 0(x1)


    /* Use BN.LID and AND with a rotating mask to load the correct zeta values. Offset can be read from a register. Get r[j + len] */
    /* Do the same to get r[j] */
    /* Use BN.SUB to calculate r[j] - t */
    /* Use BN.SID to write data to memory. Set r[j + len] = r[j] - t */
    /* Use BN.ADD to calculate r[j] + t */
    /* Use BN.SID to write r[j] = r[j] + t */


    BN.MULQACC.WO.Z  w1, w10.0, w13.0, 0     /* w1 = zeta * r[j + 1] */

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
    zeta:
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

    .balign 32
    r:
    .dword [inp2]
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    