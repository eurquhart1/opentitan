from simple_test import find_tests, helper_test_count
import os, py
from typing import Any
from pathlib import Path
from ctypes import *

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

r = [15377, -26226, -16503, 13125, 23887, -6490, -18999, 2168, 12817, -22940, 1276, 14694, 19688, 4012, 7521, 4266] + [0]*240
  
t_r = [15377, -26226, -16503, 13125, 23887, -6490, -18999, 
  2168, 12817, -22940, 1276, 14694, 19688, 4012, 7521, 4266, 
  30630, 11040, 10560, 7704, -3242, 73, -5305, -8095, 8633, 
  1384, 4132, -24258, -31679, 24477, -11072, -19693, -8324, 
  -31609, 29374, 30557, -1436, -21070, 13852, -26387, 2733, 
  7309, 4681, -20584, -27225, 5811, 17105, 13027, -9928, 
  31365, 24648, -2623, 18010, 11213, 32076, -8937, -7932, 
  20880, -26499, -17228, 15775, 13812, 23306, 21058, -22670, 
  32052, 10871, -30422, -26493, 5587, 11662, 32104, 2003, 
  25120, -13304, 13309, 25118, -10437, -3552, -17433, 6838, 
  19087, 14291, 21469, -32262, -13309, 11870, 20895, 720, 
  -17257, -4043, 22970, -29478, 4524, -26204, -21761, 3857,
  18851, 24564, 23511, 31160, -25887, 17992, -5069, 13060,
  -14045, 31159, 23165, -14570, -5456, -22044, -31573, -19415, 
  -23550, -8017, -912, -30099, -27615, -4533, -431, -11844, 
  16014, -15049, -1302, -7653, 25491, 3311, 18895, -25213, 
  23456, -5885, 31744, -5234, -13343, -23352, -23964, 31838, 
  23421, 13013, -31877, 6065, 27678, 5322, 20588, 15551, 
  5842, 8788, -24470, 1076, 3150, 29553, -21033, -17741, 
  -24210, 28891, -15402, 4990, 24416, 10432, -11318, -13365, 
  -5475, -29955, -12272, 7127, 21637, 1416, 25318, -18794, 
  -24649, -26219, 12055, -13903, 25694, -31521, 32150, 1096, 
  -6162, -13764, 19475, 21663, 21698, -24451, 3760, 5362, 
  12591, 26239, -11469, 13399, -13311, -6949, -25300, 7148, 
  23757, -24605, 15731, -31496, -26610, -26166, 30849, -31151, 
  4286, -14229, 28658, 4261, -5998, -6219, 18179, -17604, 
  -11154, -16498, -18377, -3328, 5995, 6817, -17966, 13305, 
  -31630, 237, 16593, 30200, 24600, 28008, 21273, 8170, 14187, 
  -22795, 20829, 3064, -7311, 13590, 15528, 7499, 15032, 8353, 
  -2095, -4398, -20327, 12361, 6855, 6586, 2126, 20492, -19098, 
  -22998, -12084, 26475, -1948, -5511, -4698, 1523,   -15727, -16336, 29446, 12214, 14160]

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

def create_tests(dirpath):
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
        init_vals, init_asm_data = generate_otbn_data_section_16bit(r)

        # Create the input files
        for i in range(256):
            tmpcopy = asm_template
            # Write the input value into the template
            tmpreplace = tmpcopy.replace("[idx]", str(i))
            tmpreplace = tmpreplace.replace("[r]", init_asm_data)
            # Create a new file for this input
            new_asm_filepath = inputoutputpath + "/test_" +str(i) + ".s"
            with open(new_asm_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

        # Calculate the new values of t
        # Run the C code using ctypes
        # Load the shared library
        lib = CDLL('/home/eu233/opentitan/hw/ip/otbn/dv/otbnsim/test/kyber_ntt_simd_prototype.so')

        # Define the return type of the function
        lib.ntt_simd.restype = POINTER(c_short)
        lib.ntt_simd.argtypes = [POINTER(c_short)]
        
        r_arr = (c_short * len(r))(*r)
    

        res = lib.ntt_simd(r_arr)

        r_res = [res[i] for i in range(256)]

        # Create the output files
        for i in range(256):
            tmpcopy = exp_template

            tmpreplace = tmpcopy.replace("[rj]", str(r_res[i] & 0xFFFF))        # remember j gets updated an extra time in python
                
            # Create a new file for this output
            new_exp_filepath = inputoutputpath + "/test_" + str(i) + ".exp"
            with open(new_exp_filepath, 'w') as newfile:
                newfile.write(tmpreplace)

    return find_tests("ntt_simd_cref_test/inputoutput")


def pytest_generate_tests(metafunc: Any) -> None:
    if metafunc.function is test_fn:
        tests = list()
        
        # Create all of the input/output files in the /testadd directory
        tests += create_tests("test/ntt_simd_cref_test")
            
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