#!/bin/bash
# compiles the BlueShell compiler and compiles a BlueShell file with the
# BlueShell compiler

Usage() {
    echo "Usage: ./compile.sh [file].bs \n"
    exit
}

if [ $# -lt 1 ] 
    then 
    Usage
fi


full_filename=$1
# strips extension from full filename
extension="${full_filename##*.}"
# enforces the .bs extension
if [ "$extension" != "bs" ];
    then 
    Usage 
fi

# strips filename from path and extension
filename=$(basename -- "$full_filename")
filename=${filename%.*}

make # compiles compiler
./toplevel.native < $full_filename > "$filename.llvm"
llc "-relocation-model=pic" $filename.llvm 
cc -c exec.c # links with our c file
cc $filename.llvm.s exec.o -o $filename.exe