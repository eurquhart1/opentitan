from simple_test import find_tests, helper_test_count
import os, py
from typing import Any
from pathlib import Path
from ctypes import *
import random

QINV = 62209
KYBER_Q = 3329

zetas = [-1044,  -758,  -359, -1517,  1493,  1422,   287,   202,
        -171,   622,  1577,   182,   962, -1202, -1474,  1468,
                    573, -1325,   264,   383,  -829,  1458, -1602,  -130,
                    -681,  1017,   732,   608, -1542,   411,  -205, -1571,
                    1223,   652,  -552,  1015, -1293,  1491,  -282, -1544,
                    516,    -8,  -320,  -666, -1618, -1162,   126,  1469,
                    -853,   -90,  -271,   830,   107, -1421,  -247,  -951,
                    -398,   961, -1508,  -725,   448, -1065,   677, -1275,
                    -1103,   430,   555,   843, -1251,   871,  1550,   105,
                    422,   587,   177,  -235,  -291,  -460,  1574,  1653,
                    -246,   778,  1159,  -147,  -777,  1483,  -602,  1119,
                    -1590,   644,  -872,   349,   418,   329,  -156,   -75,
                    817,  1097,   603,   610,  1322, -1285, -1465,   384,
                    -1215,  -136,  1218, -1335,  -874,   220, -1187, -1659,
                    -1185, -1530, -1278,   794, -1510,  -854,  -870,   478,
                    -108,  -308,   996,   991,   958, -1460,  1522,  1628]

def test_fn(tmpdir: py.path.local,
               asm_file: str,
               expected_file: str) -> None:
    assert helper_test_count(tmpdir=tmpdir, asm_file=asm_file, expected_file=expected_file)

def set_values(values, file):
    # Open a file in read mode
    with open(file, 'r') as file:
        content = file.read()
        
        for i in range(len(values)):
            content.replace("[val" + (i+1) + "]", values[i])

def to_twos_complement(value, bit_width=16):
    """
    Converts a negative integer to its two's complement representation as a bit string.
    
    :param value: The negative integer to convert.
    :param bit_width: The bit width for the two's complement representation.
    :return: A string representing the two's complement bit representation of the input value.
    """
    if value >= 0:
        raise ValueError("Value must be negative.")
    
    # Compute two's complement
    twos_complement = (1 << bit_width) + value
    
    return twos_complement

def read_vectors(filename):
    with open(filename, 'r') as f:
        content = f.read().strip()
    vectors = [list(map(int, block.split('\n'))) for block in content.split('\n\n')]
    return vectors

def create_tests(dirpath, r_inp, r_out, idx):
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
        init_vals, init_asm_data = generate_otbn_data_section_16bit(r_inp)

        # Create the input files
        for i in range(1):
            tmpcopy = asm_template
            # Write the input value into the template
            tmpreplace = tmpcopy.replace("[idx]", str(i))
            tmpreplace = tmpreplace.replace("[r]", init_asm_data)
            # Create a new file for this input
            new_asm_filepath = inputoutputpath + "/test_" +str(idx) + ".s"
            with open(new_asm_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

        # Create the output files
        for i in range(1):
            tmpcopy = exp_template

            tmpreplace = tmpcopy.replace("[rj]", str(111 & 0xFFFF))        # remember j gets updated an extra time in python

            resvals = generate_256bit_hex_strings(r_out)

            for j in range(len(resvals)):
                tmpreplace = tmpreplace.replace("[out" + str(j+1) + "]", resvals[j])
                
            # Create a new file for this output
            new_exp_filepath = inputoutputpath + "/test_" + str(idx) + ".exp"
            with open(new_exp_filepath, 'w') as newfile:
                newfile.write(tmpreplace)


def pytest_generate_tests(metafunc: Any) -> None:
    if metafunc.function is test_fn:
        tests = list()

        r_inps = read_vectors('/home/eu233/opentitan/hw/ip/otbn/dv/otbnsim/test/test_vectors/ntt_input_1024.txt')
        r_outs = read_vectors('/home/eu233/opentitan/hw/ip/otbn/dv/otbnsim/test/test_vectors/ntt_output_1024.txt')
        
        for i in range(100):
            random_index = random.randint(0, len(r_inps) - 1)
            # Create all of the input/output files in the /testadd directory
            create_tests("test/ntt_vectors_test", r_inps[random_index], r_outs[random_index], random_index)
        
        tests += find_tests("ntt_vectors_test/inputoutput")
        test_ids = [os.path.basename(e[0]) for e in tests]
        metafunc.parametrize("asm_file,expected_file", tests, ids=test_ids)

def generate_otbn_data_section_16bit(values):
    """
    Generates the .data section for OTBN assembly where each 16-bit value
    is stored contiguously in memory, ensuring that the array's elements
    are in order of increasing significance in memory locations. Each pair
    of 16-bit values is combined into a 32-bit word, with padding added if necessary
    to accommodate an odd number of 16-bit values.
    """
    # Initialize the assembly code string
    assembly_code = ".data\n"
    vals = []

    # Ensure the number of values is even by padding with a zero if necessary
    if len(values) % 2 != 0:
        values.append(0)

    # Process each pair of 16-bit values
    for i in range(0, len(values), 2):
        # Convert to two's complement if negative, then ensure it's confined to 16 bits
        val1 = values[i] & 0xFFFF
        val2 = values[i+1] & 0xFFFF

        if values[i] < 0:
            val1 = ((~(-values[i]) + 1) & 0xFFFF)
        if values[i+1] < 0:
            val2 = ((~(-values[i+1]) + 1) & 0xFFFF)

        # Combine the two 16-bit values into a single 32-bit value
        combined_val = val1 | (val2 << 16)
        vals.append(hex(combined_val))
        
        # Append the assembly directive with the combined value
        assembly_code += f"    .word 0x{combined_val:08x}\n"
        
    return vals, assembly_code


def generate_256bit_hex_strings(values):
    """
    Takes a list of 16-bit values and groups them into 256-bit hex strings, 
    ensuring little endian format. Each 256-bit hex string represents 16 of the 16-bit values.
    """
    # Ensure the number of values is a multiple of 16, pad with zeros if necessary
    while len(values) % 16 != 0:
        values.append(0)
    
    res = []

    # Process each group of 16 16-bit values
    for i in range(0, len(values), 16):
        vals = []
        # Convert to two's complement if negative, then ensure it's confined to 16 bits
        for idx in range(16):
            vals.append(values[i+idx] & 0xFFFF)
            if values[i+idx] < 0:
                vals[idx] = ((~(-values[i+idx]) + 1) & 0xFFFF)

        # Combine the two 16-bit values into a single 32-bit value
        combined_val = 0
        
        for j in range(16):
            combined_val |= (vals[j] << 16*j)

        res.append(hex(combined_val))
        
    return res