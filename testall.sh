# Both succ and fail test names need to be added to the Makefile
# for this list to be updated.
# 
tests=$(make print_succtests)
fail_tests=$(make print_failtests)

Usage() {
    echo "Usage: ./testall.sh [-a | -s <testname>] [-keept] [-keepc] \n
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
    ./toplevel.native < "tests/$1.bs" > $1.llvm
    check_success $?
    llc "-relocation-model=pic" $1.llvm 
    check_success $?
    cc -c exec.c # links with our c file
    cc $1.llvm.s exec.o -o $1.exe
    check_success $?
}


run_single_test() {
    testname=$1
    testpath="tests/$testname.bs"
    if [ ! -f $testpath ]
    then 
        echo "File $testpath doesn't exist" 
        return 
    fi 
    
    compile_one_test $testname
    output="$testname.exe"
        echo "RUNNING TEST ${testname}......"
    ./$output > $testname.out

    gst="tests/gsts/$testname.gst"
    touch $gst
    ls > $gst
    if [ ! -f $gst ] 
    then 
        echo "File $gst does not exist" 
        return
    else 
        diff $testname.out $gst > $testname.diff
        if [ -s $testname.diff ]; then
                echo "ERROR: OUTPUT FOR $testname DOES NOT MATCH EXPECTED OUTPUT \n "
                cat $testname.diff
            else
                echo "PASSED \n"
        fi

    fi 
}


run_all_tests() {
    # get all test names

    echo "ABOUT TO RUN ${#tests[@]} TESTS....."
    for test in $tests
    do
      name=${test%.*}
      run_single_test $name
    done
    for test in $fail_tests
    do
      name=${test::-3}
      run_single_test $name
    done
    # for each test name call run single test on it 
}

# Given a dummy string, a file name, and potentially two flags, 
# clean up the intermediate files and keep ones specified by the flags. 
# see Usage function to get flag specifications.
clean_up() {
    if [ $# -eq 2 ]
    then # just file name was passed in 
        echo "Removing all intermediate files created by $2 (.s, .llvm, .exe, .out, and .diff)..."
        rm $2.llvm
        rm $2.llvm.s
        rm $2.exe
        rm $2.out 
        rm $2.diff
    else
        keepc=false
        keept=false 

        if [[ $3 = "-keept" ]] || [[ $4 = "-keept" ]] 
        then
            keept=true 
        fi 

        if [[ $4 = "-keepc" ]] || [[ $3 = "-keepc" ]]
        then
            keepc=true 
        fi 

        if [ "$keepc" = true ] 
        then 
            echo "Keeping intermediate compiler files..." 
        else
            echo "Removing all .s, .llvm, and .exe files created by $2..."
            rm $2.llvm
            rm $2.llvm.s
            rm $2.exe
        fi
        
        if [ "$keept" = true ] 
        then 
            echo "Keeping intermediate testing files..." 
        else
            echo "Removing all .out and .diff files created by $2..."
            rm $2.out
            rm $2.diff
        fi 
    fi
    echo "Done. Bye!"
}


# wrong number of arguments 
if [ $# -lt 1 ] 
    then 
    Usage
fi

echo "Making...."
make


# -a runs all tests
if [ $1 = "-a" ]
    then 
    run_all_tests
    if [ $# -eq 1 ]
    then 
        echo "Removing all intermediate outputs (.s, .llvm, .exes, .out, and .diff) files..."
        make clean_intermediates
        make clean_tests
        make clean_exes
        echo "Done. Bye!"
    else 
        keepc=false
        keept=false 

        if [[ $2 = "-keept" ]] || [[ $3 = "-keept" ]] 
        then
            keept=true 
        fi 

        if [[ $2 = "-keepc" ]] || [[ $3 = "-keepc" ]]
        then
            keepc=true 
        fi 

        if [ "$keepc" = true ] 
        then 
            echo "Keeping intermediate compiler files..." 
        else
            echo "Removing all .s, .llvm, and .exe files..."
            make clean_intermediates
            make clean_exes
        fi
        
        if [ "$keept" = true ] 
        then 
            echo "Keeping intermediate testing files..." 
        else
            echo "Removing all .out and .diff files created..."
            make clean_tests
        fi 
        echo "Done. Bye!"
    fi 
        
    exit
fi 

# -s runs one single test 
if [ $1 = "-s" ]
    then
    # $2 is the file name 
    run_single_test $2
    clean_up "dummy" $2 $3 $4
    exit
fi 

Usage


# keep intermediatery tests



