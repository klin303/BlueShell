#!/bin/sh

# Both succ and fail test names need to be added to the Makefile
# for this list to be updated.
#
tests=$(make print_succtests)
fail_tests=$(make print_failtests)
test_dir="tests/"

sast_tests=$(make print_succsast)
sast_fail=$(make print_failsast)
sast_dir="sast-tests"

sp_tests=$(make print_succsp)
sp_fail=$(make print_failsp)
sp_dir="sp-tests" 

Usage() {
    echo "Usage: ./testall.sh [-sast | -sp | [-a | -s <testname>] [-keept] [-keepc]]  \n
          Flags:
            -sast: Run sast tests 
            -sp: Run Scanner-parser tests
            -a : run all regular executable tests specified in /tests directories
                 and test against expected output
            -s <testname>:
                Run a single executable test located in test/<fail|tests>-<testname>.bs
                and tests against expected output
            -keept: Optional: Keep intermediate output files produced during testing
                    (.out and .diff files)
            -keepc: Keep intermediate output files produced during
                   compilation (.s and .llvm files)"
    exit
}


# runs all sast tests
run_sast_tests()
{
    echo "************************RUNNING SAST TESTS***********************\n"
    echo "**********************RUNNING SAST SUCCESS TESTS**********************\n"
    for test in $sast_tests
    do
        echo "Running test $test........"
        file_name="${sast_dir}/${test}.bs"
        gold_standard="${sast_dir}/${test}.gst"
        ./toplevel.native -s < $file_name > "${sast_dir}/out/$test.out"
        diff "${sast_dir}/out/$test.out" $gold_standard > "${sast_dir}/diff/$test.diff"
        if [ -s "${sast_dir}/diff/$test.diff" ]; then
            echo "\nERROR: SAST FOR ${test} DOES NOT MATCH GOLD STANDARD\n"
            echo "The difference: \n"
            cat ${sast_dir}/diff/$test.diff
        else
            echo "PASSED \n"
        fi

    done

    echo "\n"
    echo "\n"
    echo "\n"
    echo "**********************RUNNING SAST FAILURE TESTS**********************\n"

    # cringe fail test compilation
    for ftest in $sast_fail
    do
        echo "Running failure test $ftest............"
        file_name="${sast_dir}/${ftest}.bs"
        fail_standard="${sast_dir}/${ftest}.gst"
        ./toplevel.native -a < $file_name 2> "${sast_dir}/out/$ftest.out"
        diff "${sast_dir}/out/$ftest.out" $fail_standard > "${sast_dir}/diff/$ftest.diff"
        if [ -s "${sast_dir}/diff/$ftest.diff" ]; then
            echo "ERROR: OUTPUT FOR ${ftest} DOES NOT MATCH EXPECTED OUTPUT \n "
            echo "The difference: \n"
            cat "${sast_dir}/diff/$ftest.diff"
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
}



# runs all scanner parser tests
run_sp_tests()
{
    echo "************************RUNNING SP TESTS***********************\n"
    echo "**********************RUNNING SUCCESS TESTS**********************\n"
    for test in $sp_tests
    do
        echo "Running test $test........"
        file_name="${sp_dir}/${test}.bs"
        gold_standard="${sp_dir}/${test}.gst"
        ./toplevel.native -a < $file_name > "${sp_dir}/out/$test.out"
        diff "${sp_dir}/out/${test}.out" $gold_standard > "${sp_dir}/diff/$test.diff"
        if [ -s "${sp_dir}/diff/$test.diff" ]; then
            echo "\nERROR: AST FOR ${test} DOES NOT MATCH GSAST\n\n"
            cat "${sp_dir}/diff/$test.diff"
        else
            echo "PASSED \n"
        fi

    done

    echo "\n"
    echo "\n"
    echo "\n"
    echo "**********************RUNNING FAILURE TESTS**********************\n"

    # cringe fail test compilation
    for ftest in $sp_fail
    do
        echo "Running failure test $ftest............"
        file_name="${sp_dir}/${ftest}.bs"
        fail_standard="${sp_dir}/${ftest}.gst"
        ./toplevel.native < $file_name 2> "${sp_dir}/out/$ftest.out"
        diff "${sp_dir}/out/${ftest}.out" $fail_standard > "${sp_dir}/diff/$ftest.diff"
        if [ -s "${sp_dir}/diff/$ftest.diff" ]; then
            echo "ERROR: OUTPUT FOR ${ftest} DOES NOT MATCH EXPECTED OUTPUT \n "
            cat "${sp_dir}/diff/$ftest.diff"
        else
            echo "PASSED \n"
        fi

    done

    echo "removing .out and .diff files created:"

    make clean_tests
    echo "\n"

    echo "bye"
    exit
    # bye

}


# cecks if a file exists
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
    echo $1
    ./toplevel.native < "tests/$1.bs" > $1.llvm
    check_success $?
    llc "-relocation-model=pic" $1.llvm
    check_success $?
    cc -c exec.c # links with our c file
    cc $1.llvm.s exec.o -o $1.exe
    check_success $?
}

# runs one single executable tests and compares it to its gold standard 
run_single_test() {
    testname=$1
    testpath="tests/$testname.bs"
    if [ ! -f $testpath ]
    then
        echo "File $testpath doesn't exist"
        return
    fi
    # we're in top dir

    compile_one_test $testname
    # we're in tests/
    # copy exe into testing directory
    output="$testname.exe"
        echo "RUNNING TEST ${testname}......"
    ./$output > "tests/out/$testname.out"

    #compare with gst
    gst="tests/gsts/$testname.gst"
    if [ ! -f $gst ]
    then
        echo "File $gst does not exist"
        return
    else
        diff "tests/out/$testname.out" $gst > "tests/diff/$testname.diff"
        if [ -s "tests/diff/$testname.diff" ]; then
                echo "ERROR: OUTPUT FOR $testname DOES NOT MATCH EXPECTED OUTPUT \n "
                cat "tests/diff/$testname.diff"
            else
                echo "PASSED \n"
        fi

    fi
}

# runs one failure tests; should semantically fail 
run_fail_test() {
    ftest=$1
    echo "Running failure test $1..........."
    file_name="tests/${ftest}.bs"
    fail_standard="tests/gsts/${ftest}.gst"
    ./toplevel.native -s < $file_name 2> "tests/out/$ftest.out"
    diff "tests/out/$ftest.out" $fail_standard > "tests/diff/$ftest.diff"
    if [ -s $ftest.diff ]; then
        echo "ERROR: OUTPUT FOR ${ftest} DOES NOT MATCH EXPECTED OUTPUT \n "
        cat $ftest.diff
    else
        echo "PASSED \n"
    fi
}


# runs all tests
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
      #name=${test::-3}
      name=${test%.*}
      run_fail_test $name
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


# THE PROGRAM IS STARTING


# wrong number of arguments
if [ $# -lt 1 ]
    then
    Usage
fi

make clean
echo "Making...."
make

if [ $1 = "-sast" ]
    then 
    run_sast_tests
    exit 
fi 


if [ $1 = "-sp" ]
    then 
    run_sp_tests
    exit 
fi 


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
    cd ../
    clean_up "dummy" $2 $3 $4
    exit
fi

Usage




