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
    addi       x8, x0, 0          /* w8 : len */
    addi       x9, x0, 0          /* w9 : start */
    addi       x11, x0, [inp1]         /* w11 : j */

    /* Load r[j + len] into x16 */
    add        x12, x11, x8       /* x12 : j + len */
    srai       x13, x12, 1
    slli       x13, x13, 2        /* x13 : (j + len)*2 ... offset to element in r */
    add        x2, x1, x13        /* x1 : base address of r plus offset to element */
    lw         x16, 0(x2)         /* load word 32 bits */
    and        x18, x12, 1        /* (j + len) mod 2 */
    xor        x17, x18, 1        /* inverse */
    slli       x18, x18, 4        /* shift idx left by 5 */
    slli       x17, x17, 4
    srl        x16, x16, x17
    sll        x16, x16, x18
    srl        x16, x16, x18

    /* Load r[j] into x19 */
    srai       x13, x11, 1
    slli       x13, x13, 2        /* x13 : j*2 ... offset to element in r */
    la         x1, r
    add        x2, x1, x13        /* x1 : base address of r plus offset to element */
    lw         x19, 0(x2)         /* load word 32 bits */
    and        x18, x11, 1        /* j mod 2 */
    xor        x17, x18, 1        /* inverse */
    slli       x18, x18, 4        /* shift idx left by 5 */
    slli       x17, x17, 4
    srl        x19, x19, x17
    sll        x19, x19, x18
    srl        x19, x19, x18

    ecall

.data

    .balign 4
    r:
    .word 0x3c11998e
    .word 0xbf893345
    .word 0x5d4fe6a6
    .word 0xb5c90878
    .word 0x3211a664
    .word 0x04fc3966
    .word 0x4ce80fac
    .word 0x1d6110aa
    .word 0x77a62b20
    .word 0x29401e18
    .word 0xf3560049
    .word 0xeb47e061
    .word 0x21b90568
    .word 0x1024a13e
    .word 0x84415f9d
    .word 0xd4c0b313
    .word 0xdf7c8487
    .word 0x72be775d
    .word 0xfa64adb2
    .word 0x361c98ed
    .word 0x0aad1c8d
    .word 0x1249af98
    .word 0x95a716b3
    .word 0x42d132e3
    .word 0xd9387a85
    .word 0x6048f5c1
    .word 0x465a2bcd
    .word 0x7d4cdd17
    .word 0xe1045190
    .word 0x987dbcb4
    .word 0x3d9f35f4
    .word 0x5b0a5242
    .word 0xa7727d34
    .word 0x2a77892a
    .word 0x988315d3
    .word 0x2d8e7d68
    .word 0x07d36220
    .word 0xcc0833fd
    .word 0x621ed73b
    .word 0xf220bbe7
    .word 0x1ab64a8f
    .word 0x37d353dd
    .word 0x81facc03
    .word 0x2e5e519f
    .word 0x02d0bc97
    .word 0xf03559ba
    .word 0x8cda11ac
    .word 0x99a4aaff
    .word 0x0f1149a3
    .word 0x5ff45bd7
    .word 0x79b89ae1
    .word 0x4648ec33
    .word 0x3304c923
    .word 0x79b75a7d
    .word 0xc716eab0
    .word 0xa9e484ab
    .word 0xb429a402
    .word 0xe0affc70
    .word 0x8a6d9421
    .word 0xee4bfe51
    .word 0xd1bc3e8e
    .word 0xc537faea
    .word 0xe21b6393
    .word 0x0cef49cf
    .word 0x9d835ba0
    .word 0xe9037c00
    .word 0xeb8ecbe1
    .word 0xa4c8a264
    .word 0x7c5e5b7d
    .word 0x32d5837b
    .word 0x17b16c1e
    .word 0x14ca506c
    .word 0x3cbf16d2
    .word 0x2254a06a
    .word 0x04340c4e
    .word 0x7371add7
    .word 0xbab3a16e
    .word 0x70dbc3d6
    .word 0x137e5f60
    .word 0x28c0d3ca
    .word 0xcbcbea9d
    .word 0x8afdd010
    .word 0x1bd75485
    .word 0x058862e6
    .word 0xb6969fb7
    .word 0x99952f17
    .word 0xc9b1645e
    .word 0x84df7d96
    .word 0x0448e7ee
    .word 0xca3c4c13
    .word 0x549f54c2
    .word 0xa07d0eb0
    .word 0x14f2312f
    .word 0x667fd333
    .word 0x3457cc01
    .word 0xe4db9d2c
    .word 0x1bec5ccd
    .word 0x9fe33d73
    .word 0x84f8980e
    .word 0x99ca7881
    .word 0x865110be
    .word 0xc86b6ff2
    .word 0x10a5e892
    .word 0xe7b54703
    .word 0xbb3cd46e
    .word 0xbf8eb837
    .word 0xf300176b
    .word 0x1aa1b9d2
    .word 0x33f98472
    .word 0x00ed40d1
    .word 0x75f86018
    .word 0x6d685319
    .word 0x1fea376b
    .word 0xa6f5515d
    .word 0x0bf8e371
    .word 0x35163ca8
    .word 0x1d4b3ab8
    .word 0x20a1f7d1
    .word 0xeed2b099
    .word 0x30491ac7
    .word 0x19ba084e
    .word 0x500cb566
    .word 0xa62ad0cc
    .word 0x676bf864
    .word 0xea79eda6
    .word 0x05f3c291
    .word 0xc0307306
    .word 0x2fb63750

    .balign 4
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