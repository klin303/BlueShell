# Both succ and fail test names need to be added to the Makefile
# for this list to be updated.
# The name is in the filename as "test-<filename>.bs"

Usage() {
    echo "Usage: ./test-all.sh [-a | -s <testname>] [-kio] \n
          Flags:
            -a : run all tests specified in /tests directories 
                 and test against expected output
            -s <testname>: 
                Run a single test located in test/<fail|tests>-<testname>.bs
                and tests against expected output
            -kio : Keep intermediate output files produced"
}

run_gsts_tests()
{
    # Both succ and fail test names need to be added to the Makefile
    # for this list to be updated.
    # The name is in the filename as "test-<filename>.bs"
    #
    tests=$(make print_succtests)
    fail_tests=$(make print_failtests)



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
        file_name="tests/test-${test}.bs"
        gold_standard="tests/test-${test}.gst"
        ./toplevel.native < $file_name > "$test.tsout"
        diff "$test.tsout" $gold_standard > $test.diff
        if [ -s $test.diff ]; then
            echo "\nERROR: AST FOR ${test} DOES NOT MATCH GSAST\n\n"
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
        file_name="tests/fail-${ftest}.bs"
        fail_standard="tests/fail-${ftest}.gst"
        ./toplevel.native < $file_name 2> "$ftest.tsout"
        diff "$ftest.tsout" $fail_standard > $ftest.diff
        if [ -s $ftest.diff ]; then
            echo "ERROR: OUTPUT FOR ${ftest} DOES NOT MATCH EXPECTED OUTPUT \n "
            cat $ftest.diff
        else
            echo "PASSED \n"
        fi

    done

    echo "removing .tsout and .diff files created:"

    make clean_tests
    echo "\n"

    echo "bye"
    exit
    # bye

}

run_single_test() {
    testpath="tests/{$1}.bs"
    ./compile.sh 
    output="{$1}.exe"
    ./output > "{$1}.out"
    
}


# wrong number of arguments 
if [ $# -lt 1 ] 
    then 
    Usage
fi

if [ $1 = "-a" ]
    then 
    run_all_tests
fi 

if [ $1 = "-s" ]
    then
    # $2 is the file name 
    echo $2
fi 

# # no flag = run all

# if [-z "$1" ]
#     then
#     run_all_tests
# fi 

# # if we're running a 




# run_single_test()
# {

# }


