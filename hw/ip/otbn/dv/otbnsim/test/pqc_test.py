from simple_test import find_tests, helper_test_count
import os, py
from typing import Any
from pathlib import Path

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


def create_tests(inputs, dirpath):

    # Read in the input and output templates
    asm_template_path = dirpath +  "/template.s"
    exp_template_path = dirpath + "/template.exp"

    # Create an /inputoutput directory if it does not already exist
    inputoutputpath = dirpath + '/inputoutput'
    if not os.path.exists(inputoutputpath):
        os.makedirs(inputoutputpath)

    # Write the new input files based on the template
    with open(asm_template_path, 'r') as asm_template, open(exp_template_path, 'r') as exp_template:
        asm_template = asm_template.read()
        exp_template = exp_template.read()
        for i in range(len(inputs)):
            tmpcopy = asm_template
            # Write the input value into the template
            for j in range(2):
                tmpreplace = tmpcopy.replace("[inp" + str(j+1) + "]", hex(inputs[i]))
                tmpcopy = tmpreplace
            # Create a new file for this input
            new_asm_filepath = inputoutputpath + "/test" + str(i+1) + ".s"
            with open(new_asm_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

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
            
            tmpcopy = exp_template
            # Write the output value into the template
            out = zetas[inputs[i]]
            if out < 0 :
                out = to_twos_complement(out)
            tmpreplace = tmpcopy.replace("[out1]", str(out))
            # Create a new file for this input
            new_exp_filepath = inputoutputpath + "/test" + str(i+1) + ".exp"
            with open(new_exp_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

    return find_tests("test_inner_loop0/inputoutput")


def pytest_generate_tests(metafunc: Any) -> None:
    if metafunc.function is test_fn:
        tests = list()
        testaddbn_flag = os.environ.get('BN')
        testmontmul_flag = os.environ.get('MM')
        testfqmul_flag = os.environ.get('FQ')
        testloop0_flag = os.environ.get('L0')
        
        if testaddbn_flag is not None:
            # Define the input list
            pairs = [(x, y) for x in range(5) for y in range(5)]

            # Create all of the input/output files in the /testadd directory
            tests += create_tests(pairs, "test/testaddbn")

        if testmontmul_flag is not None:
            # Define the input list
            pairs = [x for x in range(1, 2147483647, 10000000)]

            # Create all of the input/output files in the /testadd directory
            tests += create_tests(pairs, "test/test_montmul")

        if testfqmul_flag is not None:
            # Define the input list
            pairs = [(x, y) for x in range(1, 2147483647, 100000000) for y in range(1, 2147483647, 100000000)]

            # Create all of the input/output files in the /testadd directory
            tests += create_tests(pairs, "test/test_fqmul")

        if testloop0_flag is not None:
            # Define the input list
            pairs = [x for x in range(128)]

            # Create all of the input/output files in the /testadd directory
            tests += create_tests(pairs, "test/test_inner_loop0")
            
        test_ids = [os.path.basename(e[0]) for e in tests]
        metafunc.parametrize("asm_file,expected_file", tests, ids=test_ids)