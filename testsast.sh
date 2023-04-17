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
tests=$(make print_succsast)
fail_tests=$(make print_failsast)



echo "Making top level:"
make clean
make toplevel.native

echo "\n"
echo "\n"
echo "\n"
echo "**********************RUNNING SUCCESS TESTS**********************\n"
for test in $tests
do
    echo "Running test $test........"
    file_name="sast-tests/${test}.bs"
    gold_standard="sast-tests/gsts/${test}.gst"
    ./toplevel.native -s < $file_name > "sast-tests/out/$test.out"
    diff "sast-tests/out/$test.out" $gold_standard > "sast-tests/diff/$test.diff"
    if [ -s "sast-tests/diff/$test.diff" ]; then
        echo "\nERROR: SAST FOR ${test} DOES NOT MATCH GOLD STANDARD\n"
        echo "The difference: \n"
        cat $test.diff
    else
        echo "PASSED \n"
    fi

done

echo "\n"
echo "\n"
echo "\n"
echo "**********************RUNNING FAILURE TESTS**********************\n"

# cringe fail test compilation
for ftest in $fail_tests
do
    echo "Running failure test $ftest............"
    file_name="sast-tests/${ftest}.bs"
    fail_standard="sast-tests/gsts/${ftest}.gst"
    ./toplevel.native -s < $file_name 2> "sast-tests/out/$ftest.out"
    diff "sast-tests/out/$ftest.out" $fail_standard > "sast-tests/diff/$ftest.diff"
    if [ -s "sast-tests/diff/$ftest.diff" ]; then
        echo "ERROR: OUTPUT FOR ${ftest} DOES NOT MATCH EXPECTED OUTPUT \n "
        echo "The difference: \n"
        cat $ftest.diff
    else
        echo "PASSED \n"
    fi

done

echo "removing .out and .diff files created:"

diffpath="sast-tests/diff/*"
rm -f $path

outpath="sast-tests/gsts/*"

rm -f $path

echo "\n"

echo "bye"
# bye