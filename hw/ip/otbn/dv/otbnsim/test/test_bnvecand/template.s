/* The input placeholders will be overwritten by the actual input values */

.text

    /* Load Q from memory */
    la         x1, inp1
    addi       x3, x0, 1
    BN.LID     x3, 0(x1)          /*  w1 should now contain inp1 */

    /* Load inputs from memory */
    la         x1, inp2
    addi       x3, x0, 2
    BN.LID     x3, 0(x1)          /*  w2 should now contain inp2 */

    BN.ANDVEC  w3, w1, w2

    ecall

.data

    .balign 32
    inp1:
    [inp1]

    .balign 32
    inp2:
    [inp2]