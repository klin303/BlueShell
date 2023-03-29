#!/bin/bash

Usage() {
    echo "Usage: ./compile.sh [file].bs \n"
}

if [ $# -lt 1 ] 
    then 
    Usage
fi

full_filename=$1
filename=$(basename -- "$full_filename")
filename=${filename%.*}

make
./toplevel.native < $full_filename > "$filename.llvm"
llc "-relocation-model=pic" $filename.llvm
cc -c exec.c
cc $filename.llvm.s exec.o -o $filename.exe