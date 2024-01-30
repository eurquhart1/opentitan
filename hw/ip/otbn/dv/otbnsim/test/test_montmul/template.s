/* The input placeholders will be overwritten by the actual input values */

.text
  BN.ADDI    w10, w0, [inp1]    /* move input into r10 */
  addi       x1, x0, 0x8000
  addi       x3, x0, 11
  BN.LID     x3, 0(x1)          /* now w11 contains qinv */
  /* BN.MULQACC.Z  w2, w11.0, w10.0, 250   multiply the low word of w11 with the low word of w10, shift by 256-16 bits and store in w2 */  

  ecall

.data
    .balign 32  /* Align to 4 bytes (32 bits) */
    qinv:
    .word 0xfffff301  /* -3327 in 32-bit two's complement */
