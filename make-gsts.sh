#!/bin/sh


# It creates new gold standards, both errors and ASTs for our compiler.


tests=$(Make print_succtests)
fail_tests=$(Make print_failtests)
test_dir="tests/"
gsts_dir="tests/gsts/"

### for sast
sast_succ=$(Make print_succsast)
sast_fail=$(Make print_failsast)

sast_dir="sast-tests/"
sast_gsts="sast-tests/gsts/"


Usage() {
    echo "./make-gsts.sh [test-name]
        where test-name: makes gold standard for test test-name"
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

# compile one .bs test into an executable 
compile_one_test() {
    ./toplevel.native < "tests/$1.bs" > $1.llvm
    check_success $?
    llc "-relocation-model=pic" $1.llvm
    check_success $?
    cc -c exec.c # links with our c file
    cc $1.llvm.s exec.o -o $1.exe
    check_success $?
}

# create one GST 
run_one_gst() {
    test=$1
    file_name="${test_dir}${test}.bs"
    echo "making gst file $file_name...\n"
    if [ ! -f $file_name ]; then
        echo "****ALERT***** Test ${test} doesn't exist. we're not gonna try :/ \n\n\n\n"
        continue;
    fi
    gold_standard="${gsts_dir}${test}.gst"
    touch $gold_standard
    # echo $gold_standard

    type=${test::4}
    if [ $type == "fail" ]; then
        # get from stderr
        ./toplevel.native -s < $file_name 2> $gold_standard
    else
        if [ $type == "test" ]; then
            compile_one_test $test
            output="$test.exe"
            ./$output > $gold_standard
        else
            echo "*****Alert**** test type is not of fail or tests :( - test name should start with fail- or test-\n"
        fi
    fi
}


## start execution
make

if [ "$#" -eq 0 ]; then
    echo "Making gold standard for all tests:"
    for test in $tests; do
        run_one_gst $test
    done
    for test in $fail_tests; do
        run_one_gst $test
    done
else
    if [ "$#" -eq 1 ]; then
    echo "Making gold standard for one test $1:"
    run_one_gst $1
    fi
fi

make clean
echo "bye"
