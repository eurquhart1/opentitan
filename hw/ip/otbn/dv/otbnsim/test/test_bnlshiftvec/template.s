.text

    /* Load Q from memory */
    la         x1, inp1
    addi       x3, x0, 1
    BN.LID     x3, 0(x1)          /*  w1 should now contain inp1 */

    BN.LSHIFTVEC  w3, w1, [inp2]
    ecall

.data

    .balign 32
    inp1:
    [inp1]