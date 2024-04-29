.text

    /* Load Q from memory */
    la         x1, q
    lw         x2, 0(x1)
    BN.BROADCAST    w1, x2       /* broadcast KYBER_Q across w1 */

    /* Load QINV from memory */
    la         x1, qinv
    lw         x2, 0(x1)
    BN.BROADCAST    w2, x2       /* broadcast QINV across w2. correct but only sign-extended to 16b, not 32 */

    /* Load mask with low 16 bits set */
    la         x1, mask_low16
    addi       x3, x0, 3
    BN.LID     x3, 0(x1)         /* w3 has mask with the low 16 bits of each 32-bit word set only. correct */

    /* Load v_vec into w30 */
    la         x1, v_vec
    addi       x3, x0, 30
    BN.LID     x3, 0(x1)

    /* Load barrett_add_vec into w31 */
    la         x1, barrett_add_vec
    addi       x3, x0, 31
    BN.LID     x3, 0(x1)
    
    la         x1, mask_16b
    lw         x26, 0(x1)

    addi       x4, x0, 252         /* x4 : k */
    addi       x20, x0, 1        /* x20: inner looplim */
    addi       x6, x0, 0         /* x6 : offset to next block */
    addi       x14, x0, 32      /* x14: len(*2) */
    addi       x29, x0, 16
    addi       x5, x0, 0         /* x5: loop ctr */

    addi       x17, x0, 256        /* x17: loop_len lim */
    addi       x25, x0, 512         /* lim start */
    addi       x21, x0, 4

/************************************************LEN={16,32,64}****************************************************/

looplen_mul16:

    addi       x19, x0, 0        /* x19 : start */

loopstart_mul16:

    add        x6, x0, x19       /* x6 : offset to next block */

    /* load zeta and broadcast */
    la         x1, zetas         /* Load base address of zetas from memory */
    add        x2, x1, x4        /* x1 : base address of zetas plus offset to element */
    lw         x28, 0(x2)         /* load word 32 bits */
    and        x8, x28, x26

    BN.BROADCAST    w4, x8       /* broadcast zeta across w4 */

    sub        x4, x4, x21         /* k-- */
    addi       x5, x0, 0         /* x5: loop_j ctr */

loopj_mul16:

    /* Load r[j] */
    la         x1, r
    add        x1, x1, x6
    addi       x3, x0, 12
    BN.LID     x3, 0(x1)         /* r[j] elements are in w12 */

    /* Load r[j + len] */
    la         x1, r
    add        x1, x1, x6
    add        x1, x1, x14
    addi       x3, x0, 5
    BN.LID     x3, 0(x1)         /* r[j + len] elements are in w5 */

    BN.ADDVEC       w6, w12, w5   /* w6: rjvec + rjlenvec (barrett arg) */

    BN.LSHIFTVEC    w7, w6, 16
    BN.RSHIFTVEC    w7, w7, 16   /* w7: rjlow16vec */
    BN.RSHIFTVEC    w8, w6, 16   /* w8: rjupp16vec */

    /* barrett reduction */

    /* barrett reduction for tl */
    BN.MULVEC       w21, w7, w30     /* rjlow16vec*v_vec */
    BN.ADDVEC       w21, w21, w31    /* (rjlow16vec*v_vec) + (1<<25) */
    BN.ARSHIFTVEC    w21, w21, 26
    BN.MULVEC       w21, w21, w1

    BN.AND          w21, w21, w3

    /* barrett reduction for tu */
    BN.MULVEC       w10, w8, w30
    BN.ADDVEC       w10, w10, w31    /* (rjlow16vec*v_vec) + (1<<25) */
    BN.ARSHIFTVEC    w10, w10, 26
    BN.MULVEC       w10, w10, w1

    BN.AND          w10, w10, w3
    BN.LSHIFTVEC    w11, w10, 16
    BN.XOR          w22, w11, w21
    BN.SUBVEC       w22, w6, w22

    /* full barrett reduction done */

    BN.SUBVEC       w5, w5, w12  /* w5: r[j+len] - t */

    BN.LSHIFTVEC    w7, w5, 16
    BN.RSHIFTVEC    w7, w7, 16   /* w7: rjlenlow16vec */
    BN.RSHIFTVEC    w8, w5, 16   /* w8: rjlenupp16vec */

    /* compute tl = fqmul_simd(zeta32vec, rjlenlow16vec); */
    BN.MULVEC       w9, w4, w7   /* fqmul arg: a = a*b */
    BN.MULVEC32     w19, w9, w2     /* t = a*QINV */
    BN.MULVEC       w29, w19, w1    /* t = t*KYBER_Q */
    BN.SUBVEC       w20, w9, w29
    BN.RSHIFTVEC    w21, w20, 16

    BN.AND          w21, w21, w3

    /* compute tu = fqmul_simd(zeta32vec, rjlenupp16vec); */
    BN.MULVEC       w10, w4, w8
    BN.MULVEC32     w14, w10, w2
    BN.MULVEC       w14, w14, w1
    BN.SUBVEC       w10, w10, w14
    BN.RSHIFTVEC    w10, w10, 16
    BN.AND          w10, w10, w3
    BN.LSHIFTVEC    w11, w10, 16
    BN.XOR          w12, w11, w21

    /* r[j] */
    la         x1, r
    add        x1, x1, x6
    addi       x3, x0, 22
    BN.SID     x3, 0(x1)

    /* r[j + len] */
    la         x1, r
    add        x1, x1, x6
    add        x1, x1, x14
    addi       x3, x0, 12
    BN.SID     x3, 0(x1)

    addi       x6, x6, 32
    addi       x5, x5, 1
    bne        x5, x20, loopj_mul16

    add        x19, x19, x14
    add        x19, x19, x14
    add        x6, x0, x19       /* x6 : offset to next block */

    /* load zeta and broadcast */
    srli       x8, x28, 16

    BN.BROADCAST    w4, x8       /* broadcast zeta across w4 */

    addi       x5, x0, 0         /* x5: loop_j ctr */

loopj_mul16b:

    /* Load r[j] */
    la         x1, r
    add        x1, x1, x6
    addi       x3, x0, 12
    BN.LID     x3, 0(x1)         /* r[j] elements are in w12 */

    /* Load r[j + len] */
    la         x1, r
    add        x1, x1, x6
    add        x1, x1, x14
    addi       x3, x0, 5
    BN.LID     x3, 0(x1)         /* r[j + len] elements are in w5 */

    BN.ADDVEC       w6, w12, w5   /* w6: rjvec + rjlenvec (barrett arg) */

    BN.LSHIFTVEC    w7, w6, 16
    BN.RSHIFTVEC    w7, w7, 16   /* w7: rjlow16vec */
    BN.RSHIFTVEC    w8, w6, 16   /* w8: rjupp16vec */

    /* barrett reduction */

    /* barrett reduction for tl */
    BN.MULVEC       w21, w7, w30     /* rjlow16vec*v_vec */
    BN.ADDVEC       w21, w21, w31    /* (rjlow16vec*v_vec) + (1<<25) */
    BN.ARSHIFTVEC    w21, w21, 26
    BN.MULVEC       w21, w21, w1

    BN.AND          w21, w21, w3

    /* barrett reduction for tu */
    BN.MULVEC       w10, w8, w30
    BN.ADDVEC       w10, w10, w31    /* (rjlow16vec*v_vec) + (1<<25) */
    BN.ARSHIFTVEC    w10, w10, 26
    BN.MULVEC       w10, w10, w1

    BN.AND          w10, w10, w3
    BN.LSHIFTVEC    w11, w10, 16
    BN.XOR          w22, w11, w21
    BN.SUBVEC       w22, w6, w22

    /* full barrett reduction done */

    BN.SUBVEC       w5, w5, w12  /* w5: r[j+len] - t */

    BN.LSHIFTVEC    w7, w5, 16
    BN.RSHIFTVEC    w7, w7, 16   /* w7: rjlenlow16vec */
    BN.RSHIFTVEC    w8, w5, 16   /* w8: rjlenupp16vec */

    /* compute tl = fqmul_simd(zeta32vec, rjlenlow16vec); */
    BN.MULVEC       w9, w4, w7   /* fqmul arg: a = a*b */
    BN.MULVEC32     w19, w9, w2     /* t = a*QINV */
    BN.MULVEC       w29, w19, w1    /* t = t*KYBER_Q */
    BN.SUBVEC       w20, w9, w29
    BN.RSHIFTVEC    w21, w20, 16

    BN.AND          w21, w21, w3

    /* compute tu = fqmul_simd(zeta32vec, rjlenupp16vec); */
    BN.MULVEC       w10, w4, w8
    BN.MULVEC32     w14, w10, w2
    BN.MULVEC       w14, w14, w1
    BN.SUBVEC       w10, w10, w14
    BN.RSHIFTVEC    w10, w10, 16
    BN.AND          w10, w10, w3
    BN.LSHIFTVEC    w11, w10, 16
    BN.XOR          w12, w11, w21

    /* r[j] */
    la         x1, r
    add        x1, x1, x6
    addi       x3, x0, 22
    BN.SID     x3, 0(x1)

    /* r[j + len] */
    la         x1, r
    add        x1, x1, x6
    add        x1, x1, x14
    addi       x3, x0, 12
    BN.SID     x3, 0(x1)

    addi       x6, x6, 32
    addi       x5, x5, 1
    bne        x5, x20, loopj_mul16b

    add        x19, x19, x14
    add        x19, x19, x14
    bne        x19, x25, loopstart_mul16

    slli       x20, x20, 1
    slli       x14, x14, 1            /* len >>= 1 */
    bne        x14, x17, looplen_mul16

/******************************************************LEN=128********************************************************/

    add        x6, x0, x0       /* x6 : offset to next block */

    /* load zeta and broadcast */
    la         x1, zetas         /* Load base address of zetas from memory */
    add        x2, x1, x4        /* x1 : base address of zetas plus offset to element */
    lw         x28, 0(x2)         /* load word 32 bits */
    and        x8, x28, x26

    BN.BROADCAST    w4, x8       /* broadcast zeta across w4 */

    sub        x4, x4, x21         /* k-- */
    addi       x5, x0, 0         /* x5: loop_j ctr */

loopj_len128:

    /* Load r[j] */
    la         x1, r
    add        x1, x1, x6
    addi       x3, x0, 12
    BN.LID     x3, 0(x1)         /* r[j] elements are in w12 */

    /* Load r[j + len] */
    la         x1, r
    add        x1, x1, x6
    add        x1, x1, x14
    addi       x3, x0, 5
    BN.LID     x3, 0(x1)         /* r[j + len] elements are in w5 */

    BN.ADDVEC       w6, w12, w5   /* w6: rjvec + rjlenvec (barrett arg) */

    BN.LSHIFTVEC    w7, w6, 16
    BN.RSHIFTVEC    w7, w7, 16   /* w7: rjlow16vec */
    BN.RSHIFTVEC    w8, w6, 16   /* w8: rjupp16vec */

    /* barrett reduction */

    /* barrett reduction for tl */
    BN.MULVEC       w21, w7, w30     /* rjlow16vec*v_vec */
    BN.ADDVEC       w21, w21, w31    /* (rjlow16vec*v_vec) + (1<<25) */
    BN.ARSHIFTVEC    w21, w21, 26
    BN.MULVEC       w21, w21, w1

    BN.AND          w21, w21, w3

    /* barrett reduction for tu */
    BN.MULVEC       w10, w8, w30
    BN.ADDVEC       w10, w10, w31    /* (rjlow16vec*v_vec) + (1<<25) */
    BN.ARSHIFTVEC    w10, w10, 26
    BN.MULVEC       w10, w10, w1

    BN.AND          w10, w10, w3
    BN.LSHIFTVEC    w11, w10, 16
    BN.XOR          w22, w11, w21
    BN.SUBVEC       w22, w6, w22

    /* full barrett reduction done */

    BN.SUBVEC       w5, w5, w12  /* w5: r[j+len] - t */

    BN.LSHIFTVEC    w7, w5, 16
    BN.RSHIFTVEC    w7, w7, 16   /* w7: rjlenlow16vec */
    BN.RSHIFTVEC    w8, w5, 16   /* w8: rjlenupp16vec */

    /* compute tl = fqmul_simd(zeta32vec, rjlenlow16vec); */
    BN.MULVEC       w9, w4, w7   /* fqmul arg: a = a*b */
    BN.MULVEC32     w19, w9, w2     /* t = a*QINV */
    BN.MULVEC       w29, w19, w1    /* t = t*KYBER_Q */
    BN.SUBVEC       w20, w9, w29
    BN.RSHIFTVEC    w21, w20, 16

    BN.AND          w21, w21, w3

    /* compute tu = fqmul_simd(zeta32vec, rjlenupp16vec); */
    BN.MULVEC       w10, w4, w8
    BN.MULVEC32     w14, w10, w2
    BN.MULVEC       w14, w14, w1
    BN.SUBVEC       w10, w10, w14
    BN.RSHIFTVEC    w10, w10, 16
    BN.AND          w10, w10, w3
    BN.LSHIFTVEC    w11, w10, 16
    BN.XOR          w12, w11, w21

    /* r[j] */
    la         x1, r
    add        x1, x1, x6
    addi       x3, x0, 22
    BN.SID     x3, 0(x1)

    /* r[j + len] */
    la         x1, r
    add        x1, x1, x6
    add        x1, x1, x14
    addi       x3, x0, 12
    BN.SID     x3, 0(x1)

    addi       x6, x6, 32
    addi       x5, x5, 1
    bne        x5, x20, loopj_len128

    /* Load r[j] into x19 */
    la         x1, r              /* Load base address of r from memory */
    addi       x11, x0, [idx]
    srai       x13, x11, 1
    slli       x13, x13, 2        /* x13 : j*2 ... offset to element in r */
    add        x2, x1, x13        /* x1 : base address of r plus offset to element */
    lw         x15, 0(x2)         /* load word 32 bits */
    and        x18, x11, 1        /* j mod 2 */
    xor        x17, x18, 1        /* inverse */
    slli       x18, x18, 4        /* shift idx left by 4 */
    slli       x17, x17, 4        /* shift idx inverse left by 4 */
    srl        x19, x15, x18
    sll        x19, x19, x17
    srl        x19, x19, x17

end:
    ecall

.data

    .balign 32
    r:
    [r]

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
    mask_low16:
    .dword 0x0000ffff0000ffff
    .dword 0x0000ffff0000ffff
    .dword 0x0000ffff0000ffff
    .dword 0x0000ffff0000ffff

    .balign 32
    q:
    .word  0xd01  /* Q = 3329 */
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    one:
    .word  0x1  /* Q = 3329 */
    .word  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    z:
    .dword 0xfffffffffffffd0a  /* Q = 3329 */
    .dword 0xffffffffffffffff
    .dword 0xffffffffffffffff
    .dword 0xffffffffffffffff

    .balign 32
    ropp:
    .dword 0xffffffffffff9d83  /* Q = 3329 */
    .dword 0xffffffffffffffff
    .dword 0xffffffffffffffff
    .dword 0xffffffffffffffff

    .balign 32
    qinv:
    .dword  0xfffff301  /* -3327 in 32-bit two's complement */
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
    mask_64b:
    .dword  0xffffffffffffffff  /* 64 set bits */
    .dword  0x0
    .dword 0x0
    .dword 0x0
    .dword 0x0

    .balign 32
    mask_128b:
    .dword  0xffffffffffffffff  /* 32 set bits */
    .dword  0xffffffffffffffff
    .dword 0x0
    .dword 0x0

    .balign 32
    len2mask:
    .dword 0x00000000ffffffff
    .dword 0x00000000ffffffff
    .dword 0x00000000ffffffff
    .dword 0x00000000ffffffff

    .balign 32
    len4mask:
    .dword 0xffffffffffffffff
    .dword 0x0
    .dword 0xffffffffffffffff
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

    .balign 32
    v_vec:
    .dword 0x00004ebf00004ebf
    .dword 0x00004ebf00004ebf
    .dword 0x00004ebf00004ebf
    .dword 0x00004ebf00004ebf

    .balign 32
    barrett_add_vec:
    .dword 0x0200000002000000
    .dword 0x0200000002000000
    .dword 0x0200000002000000
    .dword 0x0200000002000000