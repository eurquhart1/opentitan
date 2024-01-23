/* The input placeholders will be overwritten by the actual input values */

  BN.ADDI    w10, w0, [inp1]
  BN.ADDI    w11, w0, [inp2]

  BN.CRASH     w2, w10, w11

  ecall