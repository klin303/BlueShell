#!/bin/bash

make
./toplevel.native < ./sast-tests/test-run1.bs > out.llvm
llc  "-relocation-model=pic" out.llvm
cc -c exec.c
cc out.llvm.s exec.o
./a.out