#!/bin/sh

# WOAH WOAH WOAH
# UNLESS WE, BLUESHELL, AS A GROUP, HAVE DECIDED ON SWITCHING OUR SYNTAX TO SOMETHING DIFFERENT,
# *****DO NOT RUN THIS SCRIPT***** unless you want to create new gold standard ASTs

# It creates new gold standards, both errors and ASTs for our compiler. 
# 

tests=$(Make print_succtests)
fail_tests=$(Make print_failtests)

echo "Making top level:"
make clean
make toplevel.native 

for test in $tests 
do 
    echo "making goldstandard for test $test........"
    file_name="tests/test-${test}.bs"
    gold_standard="tests/test-${test}.gst"
    # echo $gold_standard
    ./toplevel.native < $file_name > $gold_standard
done 


# cringe fail test compilation
for ftest in $fail_tests
do 
    echo "Running fail test $ftest........"
    file_name="tests/fail-${ftest}.bs"
    gold_standard="tests/fail-${ftest}.gst"
    ./toplevel.native < $file_name 2> $gold_standard
done 

# bye