#!/bin/sh

# A single script to execute your toplevel program against your tests, validating them against the
# expected output from your toplevel program. This script should be written in Python or Bash.
# Your script must validate a positive test by comparing a printed AST against a gold standard AST; it
# must validate a negative test by checking the compiler’s output error against a gold standard of the
# expected error. For examples of both, see the MicroC testsuite and testing
# script.


# 
# Both succ and fail test names need to be added to the Makefile 
# for this list to be updated.
# The name is in the filename as "test-<filename>.bs"
#
tests=$(make print_succtests)
fail_tests=$(make print_failtests)



echo "Making top level:"
make clean
make toplevel.native 


for test in $tests 
do 
    echo "Running test $test........\n"
    file_name="tests/test-${test}.bs"
    gold_standard="tests/test-${test}.gst"
    ./toplevel.native < $file_name > "$test.tsout"
    diff "$test.tsout" $gold_standard > $test.diff 
    if [ -s $test.diff ]; then
        echo "ERROR: AST FOR ${test} DOES NOT MATCH GSAST\n\n"
    fi 

done 

echo "\n"
echo "\n"
echo "\n"


# cringe fail test compilation
for ftest in $fail_tests 
do 
    echo "Running failure test $ftest............\n"
    file_name="tests/fail-${ftest}.bs"
    fail_standard="tests/fail-${ftest}.gst"
    ./toplevel.native < $file_name 2> "$ftest.tsout"
    diff "$ftest.tsout" $fail_standard > $ftest.diff 
    if [ -s $ftest.diff ]; then
        echo "ERROR: OUTPUT FOR ${ftest} DOES NOT MATCH EXPECTED OUTPUT \n\n "
    fi 

done 

# bye