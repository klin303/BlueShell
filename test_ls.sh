#!/bin/bash

# Single integration test that runs a Blue Shell program executing 'ls'.
# Diffs against the true 'ls' run in the shell.

make
./toplevel.native < ./sast-tests/test-ls.bs > test-ls.llvm
llc  "-relocation-model=pic" test-ls.llvm
cc -c exec.c
cc test-ls.llvm.s exec.o
./a.out > output.test
ls | diff output.test -