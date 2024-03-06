from simple_test import find_tests, helper_test_count
import os, py
from typing import Any
from pathlib import Path
import numpy as np
import random
import copy

def test_fn(tmpdir: py.path.local,
               asm_file: str,
               expected_file: str) -> None:
    assert helper_test_count(tmpdir=tmpdir, asm_file=asm_file, expected_file=expected_file)


def array_to_hex_le(arr):
    # Ensure the array has 8 elements for a 256-bit register
    if len(arr) != 8:
        raise ValueError("Array must contain exactly 8 elements.")

    hex_str = ''
    for num in arr:
        # Handle 2's complement for negative numbers
        if num < 0:
            num = (1 << 32) + num  # Add 2^32 to the negative number
        # Convert the number to hexadecimal, remove the '0x' prefix, and ensure it's zero-padded to 8 characters
        hex_part = hex(num)[2:].rjust(8, '0')
        # Prepend to create little endian format
        hex_str = hex_part + hex_str

    return hex_str


def multiply_arrays_elementwise(arr1, arr2):
    """Multiply the low 16 bits of elements of two arrays element-wise, and store the result as 32-bit integers."""
    if len(arr1) != 8 or len(arr2) != 8:
        raise ValueError("Both arrays must contain exactly 8 elements.")
    
    # Mask to extract the low 16 bits: 0xFFFF
    # Multiply the extracted 16-bit values, result fits within 32 bits
    result = [((a & 0xFFFF) * (b & 0xFFFF)) for a, b in zip(arr1, arr2)]
    return result


def generate_random_int16_arrays():
    # Define the range for 16-bit integers
    min_val, max_val = -32768, 32767
    
    # Generate two lists of 8 random 16-bit integers each
    array1 = [random.randint(min_val, max_val) for _ in range(8)]
    array2 = [random.randint(min_val, max_val) for _ in range(8)]
    
    # Return the two arrays as a tuple
    return (array1, array2)


def create_tests(dirpath, inputs):
    # Read in the input and output templates
    asm_template_path = dirpath +  "/template.s"
    exp_template_path = dirpath + "/template.exp"

    # Create an /inputoutput directory if it does not already exist
    inputoutputpath = dirpath + '/inputoutput'
    if not os.path.exists(inputoutputpath):
        os.makedirs(inputoutputpath)

    with open(asm_template_path, 'r') as asm_template, open(exp_template_path, 'r') as exp_template:
        asm_template = asm_template.read()
        exp_template = exp_template.read()

        # Create the input files
        for i in range(len(inputs)):
            
            input = inputs[i]
            result = multiply_arrays_elementwise(input[0], input[1])
            out = array_to_hex_le(result)
            tmpcopy = asm_template
            # Write the input value into the template
            tmpreplace = tmpcopy.replace("[inp1]", generate_otbn_data_section_32bit(input[0]))
            tmpreplace = tmpreplace.replace("[inp2]", generate_otbn_data_section_32bit(input[1]))
            # Create a new file for this input
            new_asm_filepath = inputoutputpath + "/test" + str(i) + ".s"
            with open(new_asm_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

            tmpcopy = exp_template

            tmpreplace = tmpcopy.replace("[out]", "0x" + str(out))
            tmpreplace = tmpreplace.replace("[inp1]", "0x" + array_to_hex_le(input[0]))
            tmpreplace = tmpreplace.replace("[inp2]", "0x" + array_to_hex_le(input[1]))
            
            # Create a new file for this output
            new_exp_filepath = inputoutputpath + "/test" + str(i) + ".exp"
            with open(new_exp_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

    return find_tests("test_bnvecmul/inputoutput")


def pytest_generate_tests(metafunc: Any) -> None:
    if metafunc.function is test_fn:
        tests = list()

        input_pairs = []
        
        for i in range(100):
            el1, el2 = generate_random_int16_arrays()
            input_pairs.append([el1, el2])
        
        # Create all of the input/output files in the /testadd directory
        tests += create_tests("test/test_bnvecmul", input_pairs)
            
        test_ids = [os.path.basename(e[0]) for e in tests]
        metafunc.parametrize("asm_file,expected_file", tests, ids=test_ids)

def generate_otbn_data_section_32bit(values):
    """
    Generates the .data section for OTBN assembly where each 16-bit value
    is stored in a 32-bit word in memory, ensuring that the array's elements
    are in order of increasing significance in memory locations. Each 16-bit value
    is placed in the lower 16 bits of a 32-bit word, with the upper 16 bits padded with zeroes.
    The total length is padded to 256 bits if necessary.
    """
    vals = copy.deepcopy(values)
    # Initialize the assembly code string
    assembly_code = ".data\n"

    # Calculate the necessary padding to reach 256 bits (8 words, since now each value occupies a full word)
    required_words = 8  # 8 words needed for 256 bits
    padding_required = required_words - len(vals)
    
    # Pad with zeroes if necessary to reach 256 bits
    vals.extend([0] * padding_required)

    # Process each 16-bit value
    for val in vals:
        # Convert to two's complement if negative, then ensure it's confined to 16 bits
        if val < 0:
            val = ((~(-val) + 1) & 0xFFFF)
        else:
            val = val & 0xFFFF

        # Since each value is stored in a 32-bit word, no need to combine. The upper 16 bits will be zeros.
        # Append the assembly directive with the value
        assembly_code += f"    .word 0x{val:08x}\n"
        
    return assembly_code
