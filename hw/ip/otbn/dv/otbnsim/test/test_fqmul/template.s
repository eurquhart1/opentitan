/* The input placeholders will be overwritten by the actual input values */

.text
    addi    x1, x0, 0
    loopi 123, 1
ret_here:
    jal x0, my_body

my_body:
    addi    x1, x1, 1
    jal x0, ret_here
