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
                tmpreplace = tmpcopy.replace("[inp" + str(j+1) + "]", str(inputs[i][j]))
                tmpcopy = tmpreplace
            # Create a new file for this input
            new_asm_filepath = inputoutputpath + "/test" + str(i+1) + ".s"
            with open(new_asm_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

            #exp = 0
            #for inp in inputs[i]:
            #    exp += inp

            arg1 = inputs[i][0] + 5
            arg2 = inputs[i][1] - 1
            exp = arg1 * arg2

            tmpcopy = exp_template
            # Write the output value into the template
            tmpreplace = tmpcopy.replace("[out1]", str(exp))
            # Create a new file for this input
            new_exp_filepath = inputoutputpath + "/test" + str(i+1) + ".exp"
            with open(new_exp_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

    return find_tests("testaddbn/inputoutput")


def pytest_generate_tests(metafunc: Any) -> None:
    if metafunc.function is test_fn:
        tests = list()
        testadd_flag = None #os.environ.get('TESTADD')
        testaddbn_flag = os.environ.get('BN')
        
        if testaddbn_flag is not None:
            # Define the input list
            pairs = [(x, y) for x in range(5) for y in range(5)]

            # Create all of the input/output files in the /testadd directory
            tests += create_tests(pairs, "test/testaddbn")
            
        test_ids = [os.path.basename(e[0]) for e in tests]
        metafunc.parametrize("asm_file,expected_file", tests, ids=test_ids)