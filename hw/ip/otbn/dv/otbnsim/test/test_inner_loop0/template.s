/* The input placeholders will be overwritten by the actual input values */

.text

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
    addi       x11, x0, 0         /* w11 : j */

    /* Load r[j + len] into w13 */
    add        x12, x11, x8       /* w12 : j + len */
    slli       x12, x12, 1        /* w12 : (j + len)*16 ... offset to element in r */
    add        x2, x1, x12        /* x1 : base address of r plus offset to element */
    addi       x3, x0, 13         /* idx for w15 */
    BN.LID     x3, 0(x2)
    BN.AND     w13, w13, w5

    /* Load r[j] into w14 */
    add        x13, x0, x11       /* w12 : j + len */
    slli       x13, x13, 1        /* w12 : j*16 ... offset to element in r */
    la         x1, r
    add        x3, x1, x13        /* x1 : base address of r plus offset to element */
    addi       x3, x0, 14         /* idx for w15 */
    BN.LID     x3, 0(x2)
    BN.AND     w14, w14, w5
    
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
    r:
    .dword 0xfa13fe99fd0afbec
    .dword 0x00ca011f058e05d5
    .dword 0x00b60629026eff55
    .dword 0x05bcfa3efb4e03c2

    .dword 0x017f0108fad3023d
    .dword 0xff7ef9be05b2fcc3
    .dword 0x026002dc03f9fd57
    .dword 0xf9ddff33019bf9fa

    .dword 0x03f7fdd8028c04c7
    .dword 0xf9f8fee605d3faf3
    .dword 0xfd66fec0fff80204
    .dword 0x05bd007efb76f9ae

    .dword 0x033efef1ffa6fcab
    .dword 0xfc49ff09fa73006b
    .dword 0xfd2bfa1c03c1fe72
    .dword 0xfb0502a5fbd701c0

    .dword 0x034b022b01aefbb1
    .dword 0x0069060e0367fb1d
    .dword 0xff1500b1024b01a6
    .dword 0x06750626fe34fedd

    .dword 0xff6d0487030aff0a
    .dword 0x045ffda605cbfcf7
    .dword 0x015dfc980284f9ca
    .dword 0xffb5ff64014901a2

    .dword 0x0262025b04490331
    .dword 0x0180fa47fafb052a
    .dword 0xfac904c2ff78fb41
    .dword 0xf985fb5d00dcfc96
    
    .dword 0x031afb02fa06fb5f
    .dword 0x01defc9afcaafa1a
    .dword 0x03df03e4feccff94
    .dword 0x065c05f2fa4c03be

    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    