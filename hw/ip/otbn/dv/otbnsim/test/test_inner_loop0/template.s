/* The input placeholders will be overwritten by the actual input values */

.text
start:
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
    la         x1, mask_16b
    lw         x27, 0(x1)

    /* Load 16-bit mask from memory */
    la         x1, mask_32b
    addi       x3, x0, 21
    BN.LID     x3, 0(x1)          /*  w21 should now contain 32-bit mask */

    /* Set constants outside of loops */
    addi       x30, x0, 2         /* limit for len loop */
    addi       x31, x0, 255       /* limit for start loop */
    addi       x7, x0, 1          /* x7 : k = 1 */
    addi       x8, x0, 128        /* x8 : len = 128 */

loop_len:
    addi       x9, x0, 0          /* x9 : start = 0 */

loop_start:
    addi       x7, x7, 1          /* k++ */
    add        x11, x0, x9

    /* Load zeta into x20 */
    la         x1, zetas          /* Load base address of zetas from memory */
    srai       x13, x7, 1
    slli       x13, x13, 2        /* x13 : k*2 ... offset to element in zetas */
    add        x2, x1, x13        /* x1 : base address of zetas plus offset to element */
    lw         x20, 0(x2)         /* load word 32 bits */
    and        x18, x7, 1         /* k mod 2 */
    xor        x17, x18, 1        /* inverse */
    slli       x23, x18, 4        /* shift idx left by 4 */
    slli       x24, x17, 4
    srl        x20, x20, x24
    sll        x20, x20, x23
    srl        x20, x20, x23

loop_j:
    /* Load r[j + len] into x16 */
    la         x1, r              /* Load base address of r from memory */
    add        x12, x11, x8       /* x12 : j + len */
    srai       x13, x12, 1        /* floor divide (j + len)//2 */
    slli       x13, x13, 2        /* x13 : (j + len)*2 ... offset to element in r */
    add        x2, x1, x13        /* x1 : base address of r plus offset to element */
    lw         x26, 0(x2)
    and        x18, x12, 1        /* (j + len) mod 2 */
    xor        x17, x18, 1        /* inverse */
    slli       x23, x18, 4        /* shift idx left by 4 */
    slli       x24, x17, 4        /* shift idx inverse left by 4 */
    srl        x16, x26, x23
    sll        x16, x16, x24
    srl        x16, x16, x24

    sll        x28, x27, x24
    add        x29, x0, x26
    and        x26, x26, x28      /* isolate the opposite sub-block in position */

    /* Load r[j] into x19 */
    la         x1, r              /* Load base address of r from memory */
    srai       x13, x11, 1
    slli       x13, x13, 2        /* x13 : j*2 ... offset to element in r */
    add        x2, x1, x13        /* x1 : base address of r plus offset to element */
    lw         x5, 0(x2)         /* load word 32 bits */
    and        x18, x11, 1        /* j mod 2 */
    xor        x17, x18, 1        /* inverse */
    slli       x18, x18, 4        /* shift idx left by 4 */
    slli       x17, x17, 4        /* shift idx inverse left by 4 */
    srl        x19, x5, x6
    sll        x19, x19, x17
    srl        x19, x19, x17

    sll        x28, x27, x17
    add        x29, x0, x5
    and        x5, x5, x28      /* isolate the opposite sub-block in position */
    
    /* Store zeta and r[j+len] in memory as params */
    la         x1, zeta
    sw         x20, 0(x1)
    la         x1, r_j_len
    sw         x16, 0(x1)

    /* Read zeta and r[j+len] into WDRs for processing */
    la         x1, zeta
    addi       x3, x0, 1
    BN.LID     x3, 0(x1)          /*  w1 should now contain zeta */

    /* Load inputs from memory */
    la         x1, r_j_len
    addi       x3, x0, 2
    BN.LID     x3, 0(x1)          /*  w2 should now contain r_j_len */

    jal        x1, montmul

    /* Load t into x21 */
    la         x1, t
    lw         x21, 0(x1)         /* load word 32 bits */

    /* Subtract: r[j] - t into x22 */
    add        x22, x19, x21

    /* construct the block for overwriting r[j + len] in memory */
    sll        x28, x27, x23
    sll        x22, x22, x23
    and        x22, x22, x28
    xor        x18, x22, x26

    /* overwrite r[j + len] */
    la         x1, r
    add        x12, x11, x8       /* x12 : j + len */
    srai       x13, x12, 1        /* floor divide (j + len)//2 */
    slli       x13, x13, 2        /* x13 : (j + len)*2 ... offset to element in r */
    add        x2, x1, x13        /* x1 : base address of r plus offset to element */
    sw         x18, 0(x2)

    /* Add: r[j] + t into x22 */
    add        x22, x19, x21

    /* construct the block for overwriting r[j] in memory */
    sll        x28, x27, x6
    sll        x22, x22, x6
    and        x22, x22, x28
    xor        x18, x22, x5

    add        x29, x9, x8      /* lim: start + len - 1 */
    addi       x29, x29, -1    

    beq        x11, x29, loop_start_end
    addi       x11, x11, 1      /* j++ */
    jal        x1, loop_j

loop_start_end:
    beq        x9, x31, loop_len_end
    add        x9, x11, x8      /* start = j + len */
    jal        x1, loop_start

loop_len_end:
    beq        x8, x30, end
    srli       x8, x8, 1
    jal        x1, loop_len

end:
    ecall

montmul:
    BN.MULQACC.WO.Z  w1, w1.0, w2.0, 0     /* w1 = a */

    BN.AND     w2, w5, w1         /*  (int16_t)a */

    BN.MULQACC.WO.Z  w3, w2.0, w4.0, 0     /* t = (int16_t)a * QINV */
    BN.AND           w3, w3, w21           /* (int32_t)t */
    BN.MULQACC.WO.Z  w4, w3.0, w6.0, 0     /* (int32_t)t * KYBER_Q */ 
    BN.SUB           w7, w1, w4            /* a - (int32_t)t*KYBER_Q */
    BN.RSHI          w7, w0, w7 >> 16
    BN.AND           w7, w7, w5            /* w7 = (int16t)((a - t*Q)>>16) */

    /* Store result t to memory */
    la         x1, t
    addi       x3, x0, 7                   /* reference to w7, which holds the result */
    BN.SID     x3, 0(x1)

    ret

.data

    .balign 32
    r:
    .word 0x998e3c11
    .word 0x3345bf89
    .word 0xe6a65d4f
    .word 0x0878b5c9
    .word 0xa6643211
    .word 0x396604fc
    .word 0x0fac4ce8
    .word 0x10aa1d61
    .word 0x2b2077a6
    .word 0x1e182940
    .word 0x0049f356
    .word 0xe061eb47
    .word 0x056821b9
    .word 0xa13e1024
    .word 0x5f9d8441
    .word 0xb313d4c0
    .word 0x8487df7c
    .word 0x775d72be
    .word 0xadb2fa64
    .word 0x98ed361c
    .word 0x1c8d0aad
    .word 0xaf981249
    .word 0x16b395a7
    .word 0x32e342d1
    .word 0x7a85d938
    .word 0xf5c16048
    .word 0x2bcd465a
    .word 0xdd177d4c
    .word 0x5190e104
    .word 0xbcb4987d
    .word 0x35f43d9f
    .word 0x52425b0a
    .word 0x7d34a772
    .word 0x892a2a77
    .word 0x15d39883
    .word 0x7d682d8e
    .word 0x622007d3
    .word 0x33fdcc08
    .word 0xd73b621e
    .word 0xbbe7f220
    .word 0x4a8f1ab6
    .word 0x53dd37d3
    .word 0xcc0381fa
    .word 0x519f2e5e
    .word 0xbc9702d0
    .word 0x59baf035
    .word 0x11ac8cda
    .word 0xaaff99a4
    .word 0x49a30f11
    .word 0x5bd75ff4
    .word 0x9ae179b8
    .word 0xec334648
    .word 0xc9233304
    .word 0x5a7d79b7
    .word 0xeab0c716
    .word 0x84aba9e4
    .word 0xa402b429
    .word 0xfc70e0af
    .word 0x94218a6d
    .word 0xfe51ee4b
    .word 0x3e8ed1bc
    .word 0xfaeac537
    .word 0x6393e21b
    .word 0x49cf0cef
    .word 0x5ba09d83
    .word 0x7c00e903
    .word 0xcbe1eb8e
    .word 0xa264a4c8
    .word 0x5b7d7c5e
    .word 0x837b32d5
    .word 0x6c1e17b1
    .word 0x506c14ca
    .word 0x16d23cbf
    .word 0xa06a2254
    .word 0x0c4e0434
    .word 0xadd77371
    .word 0xa16ebab3
    .word 0xc3d670db
    .word 0x5f60137e
    .word 0xd3ca28c0
    .word 0xea9dcbcb
    .word 0xd0108afd
    .word 0x54851bd7
    .word 0x62e60588
    .word 0x9fb7b696
    .word 0x2f179995
    .word 0x645ec9b1
    .word 0x7d9684df
    .word 0xe7ee0448
    .word 0x4c13ca3c
    .word 0x54c2549f
    .word 0x0eb0a07d
    .word 0x312f14f2
    .word 0xd333667f
    .word 0xcc013457
    .word 0x9d2ce4db
    .word 0x5ccd1bec
    .word 0x3d739fe3
    .word 0x980e84f8
    .word 0x788199ca
    .word 0x10be8651
    .word 0x6ff2c86b
    .word 0xe89210a5
    .word 0x4703e7b5
    .word 0xd46ebb3c
    .word 0xb837bf8e
    .word 0x176bf300
    .word 0xb9d21aa1
    .word 0x847233f9
    .word 0x40d100ed
    .word 0x601875f8
    .word 0x53196d68
    .word 0x376b1fea
    .word 0x515da6f5
    .word 0xe3710bf8
    .word 0x3ca83516
    .word 0x3ab81d4b
    .word 0xf7d120a1
    .word 0xb099eed2
    .word 0x1ac73049
    .word 0x084e19ba
    .word 0xb566500c
    .word 0xd0cca62a
    .word 0xf864676b
    .word 0xeda6ea79
    .word 0xc29105f3
    .word 0x7306c030
    .word 0x37502fb6

    .balign 32
    zetas:
    .word 0xfbecfd0a
    .word 0xfe99fa13
    .word 0x05d5058e
    .word 0x011f00ca
    .word 0xff55026e
    .word 0x062900b6
    .word 0x03c2fb4e
    .word 0xfa3e05bc
    .word 0x023dfad3
    .word 0x0108017f
    .word 0xfcc305b2
    .word 0xf9beff7e
    .word 0xfd5703f9
    .word 0x02dc0260
    .word 0xf9fa019b
    .word 0xff33f9dd
    .word 0x04c7028c
    .word 0xfdd803f7
    .word 0xfaf305d3
    .word 0xfee6f9f8
    .word 0x0204fff8
    .word 0xfec0fd66
    .word 0xf9aefb76
    .word 0x007e05bd
    .word 0xfcabffa6
    .word 0xfef1033e
    .word 0x006bfa73
    .word 0xff09fc49
    .word 0xfe7203c1
    .word 0xfa1cfd2b
    .word 0x01c0fbd7
    .word 0x02a5fb05
    .word 0xfbb101ae
    .word 0x022b034b
    .word 0xfb1d0367
    .word 0x060e0069
    .word 0x01a6024b
    .word 0x00b1ff15
    .word 0xfeddfe34
    .word 0x06260675
    .word 0xff0a030a
    .word 0x0487ff6d
    .word 0xfcf705cb
    .word 0xfda6045f
    .word 0xf9ca0284
    .word 0xfc98015d
    .word 0x01a20149
    .word 0xff64ffb5
    .word 0x03310449
    .word 0x025b0262
    .word 0x052afafb
    .word 0xfa470180
    .word 0xfb41ff78
    .word 0x04c2fac9
    .word 0xfc9600dc
    .word 0xfb5df985
    .word 0xfb5ffa06
    .word 0xfb02031a
    .word 0xfa1afcaa
    .word 0xfc9a01de
    .word 0xff94fecc
    .word 0x03e403df
    .word 0x03befa4c
    .word 0x05f2065c

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
    mask_32b:
    .dword  0xffffffff  /* 32 set bits */
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    zeta:
    .word  0x0
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    r_j_len:
    .word  0x0
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    t:
    .dword 0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0