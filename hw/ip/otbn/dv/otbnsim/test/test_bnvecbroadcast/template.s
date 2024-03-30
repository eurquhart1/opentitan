/* The input placeholders will be overwritten by the actual input values */

.text

    la         x1, inp
    lw         x2, 0(x1)
    BN.BROADCAST    w3, x2

    ecall

.data

.balign 4
    inp:
    [inp]