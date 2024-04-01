# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

'''Run tests to make sure the simulator works as expected

We expect tests below ./simple. Each test is defined by two files (in the same
directory as each other). The code for the test is in a single assembly file,
called <name>.s, and the expected results are in a file called <name>.exp.

'''

import os
import py
import subprocess
from typing import Any, List, Tuple

from testutil import asm_and_link_one_file, SIM_DIR

import argparse
import subprocess
import sys
from enum import IntEnum
from typing import List

from shared.check import CheckResult
from shared.reg_dump import parse_reg_dump

# Names of special registers
ERR_BITS = 'ERR_BITS'
INSN_CNT = 'INSN_CNT'
STOP_PC = 'STOP_PC'

from pathlib import Path

output_dir = Path('/tmp/pytest-of-eu233/pytest-7/test_count_test1_s_0')
output_dir.mkdir(parents=True, exist_ok=True)

def find_tests(dir) -> List[Tuple[str, str]]:
    '''Find all tests below ./{dirname} (relative to this file)

    Returns (asm, expected) pairs, with the paths to the assembly file and
    expected values.

    '''
    root = os.path.join(os.path.dirname(__file__), dir)
    ret = []
    for subdir, _, files in os.walk(root):
        # We're interested in pairs foo.s / foo.exp, which contain the assembly
        # and expected values, respectively.
        asm_files = {}
        exp_files = {}

        for filename in files:
            basename, ext = os.path.splitext(filename)
            if ext == '.s':
                assert basename not in asm_files
                asm_files[basename] = filename
            elif ext == '.exp':
                assert basename not in exp_files
                exp_files[basename] = filename
            else:
                # Ignore any files that aren't called .s or .exp (which allows
                # things like adding READMEs to the tree)
                pass

        dirname = os.path.join(root, subdir)

        # Pair up the files we found
        for basename, asm_file in asm_files.items():
            exp_file = exp_files.get(basename)
            if exp_file is None:
                raise RuntimeError('In the directory {!r}, there is {}, but '
                                   'no {}.exp, which should contain expected '
                                   'values.'
                                   .format(dirname, asm_file, basename))

            ret.append((os.path.join(dirname, asm_file),
                        os.path.join(dirname, exp_file)))

        # We've checked that every .s file has a matching .exp. Check the other
        # way around too.
        for basename, exp_file in exp_files.items():
            if basename not in asm_files:
                raise RuntimeError('In the directory {!r}, there is {}, but '
                                   'no {}.s, which should contain the program '
                                   'that generates the expected values.'
                                   .format(dirname, exp_file, basename))

        assert len(exp_files) == len(asm_files)
    return ret


def test_count(tmpdir: py.path.local,
               asm_file: str,
               expected_file: str) -> None:
        assert helper_test_count(tmpdir=tmpdir, asm_file=asm_file, expected_file=expected_file)


def helper_test_count(tmpdir: py.path.local,
               asm_file: str,
               expected_file: str) -> None:
    # Start by assembling and linking the input file
    elf_file = asm_and_link_one_file(asm_file, tmpdir)

    # Run the simulation. We can just pass a list of commands to stdin, and
    # don't need to do anything clever to track what's going on.
    sim_file = os.path.join(SIM_DIR, 'standalone.py')

    args_list = [sim_file, expected_file, elf_file, "--verbose"]
    return not otbn_sim_test(args_list)


def pytest_generate_tests(metafunc: Any) -> None:
    if metafunc.function is test_count:
        tests = find_tests("simple")
        test_ids = [os.path.basename(e[0]) for e in tests]
        metafunc.parametrize("asm_file,expected_file", tests, ids=test_ids)


###########################################################################################################################################
        
# copied from hw/ip/otbn/dv/otbnsim/sim/constants.py
class ErrBits(IntEnum):
    '''A copy of the list of bits in the ERR_BITS register.'''
    BAD_DATA_ADDR = 1 << 0
    BAD_INSN_ADDR = 1 << 1
    CALL_STACK = 1 << 2
    ILLEGAL_INSN = 1 << 3
    LOOP = 1 << 4
    KEY_INVALID = 1 << 5
    RND_REP_CHK_FAIL = 1 << 6
    RND_FIPS_CHK_FAIL = 1 << 7
    IMEM_INTG_VIOLATION = 1 << 16
    DMEM_INTG_VIOLATION = 1 << 17
    REG_INTG_VIOLATION = 1 << 18
    BUS_INTG_VIOLATION = 1 << 19
    BAD_INTERNAL_STATE = 1 << 20
    ILLEGAL_BUS_ACCESS = 1 << 21
    LIFECYCLE_ESCALATION = 1 << 22
    FATAL_SOFTWARE = 1 << 23


def get_err_names(err: int) -> List[str]:
    '''Get the names of all error bits that are set.'''
    out = []
    for err_bit in ErrBits:
        if err & err_bit != 0:
            out.append(err_bit.name)
    return out


def otbn_sim_test(args_list):
    parser = argparse.ArgumentParser()
    parser.add_argument('simulator',
                        help='Path to the standalone OTBN simulator.')
    parser.add_argument('expected',
                        metavar='FILE',
                        type=argparse.FileType('r'),
                        help=(f'File containing expected register values. '
                              f'Registers that are not listed are allowed to '
                              f'have any value, except for {ERR_BITS}. If '
                              f'{ERR_BITS} is not listed, the test will assume '
                              f'there are no errors expected (i.e. {ERR_BITS}'
                              f'= 0).'))
    parser.add_argument('elf',
                        help='Path to the .elf file for the OTBN program.')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args(args_list)

    # Parse expected values.
    result = CheckResult()
    expected_regs = parse_reg_dump(args.expected.read())

    # Run the simulation and produce a register dump.
    cmd = [args.simulator, '--dump-regs', '-', '--dump-dmem', 'memdump.txt', args.elf]
    sim_proc = subprocess.run(cmd, check=True,
                              stdout=subprocess.PIPE, universal_newlines=True)
    actual_regs = parse_reg_dump(sim_proc.stdout)

    # Special handling for the ERR_BITS register.
    expected_err = expected_regs.get(ERR_BITS, 0)
    actual_err = actual_regs[ERR_BITS]
    insn_cnt = actual_regs[INSN_CNT]
    stop_pc = actual_regs[STOP_PC]
    if expected_err == 0 and actual_err != 0:
        # Test is expected to have no errors, but an error occurred. In this
        # case, give a special error message and exit rather than print all the
        # mismatched registers.
        if actual_err != 0:
            err_names = ', '.join(get_err_names(actual_err))
            result.err(f'OTBN encountered an unexpected error: {err_names}.\n'
                       f'  {ERR_BITS}\t= {actual_err:#010x}\n'
                       f'  {INSN_CNT}\t= {insn_cnt:#010x}\n'
                       f'  {STOP_PC}\t= {stop_pc:#010x}')
    else:
        for reg, expected_value in expected_regs.items():
            actual_value = actual_regs.get(reg, None)
            if actual_value != expected_value:
                # Handle signed expected_value by constructing its 2's complement if it's negative
                if expected_value < 0:
                    # Construct 2's complement for negative numbers
                    mask = (1 << 256) - 1
                    # Compute two's complement
                    expected_value_unsigned = ((abs(expected_value) ^ mask) + 1) & mask
                else:
                    expected_value_unsigned = expected_value

                if actual_value < 0:
                    # Construct 2's complement for negative numbers
                    mask = (1 << 256) - 1
                    # Compute two's complement
                    actual_value_unsigned = ((abs(actual_value) ^ mask) + 1) & mask
                else:
                    actual_value_unsigned = actual_value

                # Truncate both expected and actual values to the lowest 32 bits. this is just to eliminate all of the 1s introduced by 2s complement right shift in python
                expected_value_truncated = expected_value_unsigned
                actual_value_truncated = actual_value_unsigned
            
                if reg.startswith('w'):
                    # Now compare the truncated values
                    if actual_value_truncated != expected_value_truncated:
                        # Updated for 256 bits + '0x' prefix
                        # The '#066x' format specifier: 
                        # '#' for the '0x' prefix, '66' for the width (64 hex digits + 2 for the '0x' prefix), and 'x' for hexadecimal.
                        expected_str = f'{expected_value_truncated:#066x}'  
                        actual_str = f'{actual_value_truncated:#066x}'
                        result.err(f'Mismatch for register {reg}:\n'
                                    f'  Expected: {expected_str}\n'
                                    f'  Actual:   {actual_str}')

                else:
                    if actual_value_truncated != expected_value_truncated:
                        expected_str = f'{expected_value_truncated:#8x}'  # Updated for 16 bits + '0b' prefix
                        actual_str = f'{actual_value_truncated:#8x}'     # Updated for 16 bits + '0b' prefix
                        result.err(f'Mismatch for register {reg}:\n'
                                    f'  Expected: {expected_str}\n'
                                    f'  Actual:   {actual_str}')


    if result.has_errors() or result.has_warnings() or args.verbose:
        print(result.report())

    return 1 if result.has_errors() else 0
