# Both succ and fail test names need to be added to the Makefile
# for this list to be updated.
# 

kiot=false
kioc=false


Usage() {
    echo "Usage: ./test-all.sh [-a | -s <testname>] [-keept] [-keepc] \n
          Flags:
            -a : run all tests specified in /tests directories 
                 and test against expected output
            -s <testname>: 
                Run a single test located in test/<fail|tests>-<testname>.bs
                and tests against expected output
            -keept: Keep intermediate output files produced during testing 
                    (.out and .diff files)
            -keepc: Keep intermediate output files produced during 
                   compilation (.s and .llvm files)"
    exit
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

check_success() {
    if [ $1 -ne 0 ]
        # last command failed 
        then 
            echo "Previous command failed with exit code {$1}\n"
            echo  "Exiting script now...." 
            exit
    fi
}


# compiles one .bs file into an executable 
compile_one_test() {
    make
    echo $1
    ./toplevel.native < "tests/$1.bs" > $1.llvm
    check_success $?
    llc "-relocation-model=pic" $1.llvm 
    check_success $?
    cc -c exec.c # links with our c file
    cc $1.llvm.s exec.o -o $1.exe
    check_success $?
}



clean_up() {
    if [ $# -eq 3 ] 
    then
        if [ -z $2 ] 
        then 
            if [ $2 = "-keepc" ] 
            then 
                echo "Keeping intermediate compiler files..." 
            else 
                echo "Invalid flag $2"
                Usage 
            fi 
        else
            echo "Removing .s, .llvm, and .exe files made from $1\n"
                rm $1.llvm 
                rm $1.llvm.s
                rm $1.exe
        fi 


        if [ -z $3 ] 
        then 
            if [ $3 = "-keept" ] 
            then 
                echo "Keeping intermediate testing files..." 
            else 
                echo "Invalid flag $3"
                Usage 
            fi 
        else 
            echo "Removing .out and .diff files from $1\n"
            rm $1.out 
            rm $1.diff
        fi 
    else 
        # clean all files 
        if [ -z $1 ] 
        then 
            if [ $1 = "-keepc" ] 
            then 
                echo "Keeping intermediate compiler files..." 
            else 
                echo "Invalid flag $1"
                Usage 
            fi 
        else
            echo "Removing all .s, .llvm, and .exe files\n"
            make clean_exes
            make clean_intermediates
        fi 


        if [ -z $2 ] 
        then 
            if [ $2 = "-keept" ] 
            then 
                echo "Keeping intermediate testing files..." 
            else 
                echo "Invalid flag $2"
                Usage 
            fi 
        else 
            echo "Removing .out and .diff files\n"
            make clean_tests
        fi 
    fi 
}


run_single_test() {
    testname=$1
    echo "RUNNING TEST ${testname}......"
    testpath="tests/$testname.bs"
    make # compiles compiler
    compile_one_test $testname
    output="$testname.exe"
    echo $output
    ./$output > $testname.out

    # might be wrong 
    gst="tests/gsts/$testname.gst"
    if [ -f $gst ] 
    then 
        diff $testname.out $gst > $testname.diff
            if [ -s $testname.diff ]; then
                echo "ERROR: OUTPUT FOR $testname DOES NOT MATCH EXPECTED OUTPUT \n "
                cat $testname.diff
            else
                echo "PASSED \n"
        fi
    else 
        echo "File $gst does not exist" 
    fi 
}


run_all_tests() {
    # get all test names 
    for test in $tests
    do
      run_single_test test
    done
    for test in $fail_tests
    do
      run_single_test test
    done
    # for each test name call run single test on it 
}


# wrong number of arguments 
if [ $# -lt 1 ] 
    then 
    Usage
fi

# -a runs all tests
if [ $1 = "-a" ]
    then 
    run_all_tests
    exit
fi 

# -s runs one single test 
if [ $1 = "-s" ]
    then
    # $2 is the file name 
    run_single_test $2
    clean_up $2 $3 $4
    exit
fi 

# keep intermediatery tests



