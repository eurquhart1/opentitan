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
                tmpreplace = tmpcopy.replace("[inp" + str(j+1) + "]", hex(inputs[i][j]))
                tmpcopy = tmpreplace
            # Create a new file for this input
            new_asm_filepath = inputoutputpath + "/test" + str(i+1) + ".s"
            with open(new_asm_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

            QINV = 62209
            Q = 3329

            a_32bit = inputs[i][0] * inputs[i][1]
            out2 = a_32bit & 65535  # Take the lower 16 bits
            out3 = (a_32bit - (out2 * QINV * Q)) >> 16


            tmpcopy = exp_template
            # Write the output value into the template
            tmpreplace = tmpcopy.replace("[out1]", str(a_32bit))
            tmpreplace = tmpreplace.replace("[out2]", str(out2))
            tmpreplace = tmpreplace.replace("[out3]", str(out3))
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
            pairs = [(x, y) for x in range(1, 2147483647, 100000000) for y in range(1, 2147483647, 100000000)]

            # Create all of the input/output files in the /testadd directory
            tests += create_tests(pairs, "test/test_inner_loop0")
            
        test_ids = [os.path.basename(e[0]) for e in tests]
        metafunc.parametrize("asm_file,expected_file", tests, ids=test_ids)