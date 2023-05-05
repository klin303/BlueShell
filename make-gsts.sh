#!/bin/sh


# It creates new gold standards, both errors and ASTs for our compiler.


# info for e2e tests

e2e_tests=$(make print_succtests)
e2e_fail=$(make print_failtests)
test_dir="tests/"

sast_tests=$(make print_succsast)
sast_fail=$(make print_failsast)
sast_dir="sast-tests"

sp_tests=$(make print_succsp)
sp_fail=$(make print_failsp)
sp_dir="sp-tests" 

## sp test info 


Usage() {
    echo "./make-gsts.sh [-sp | -sast | -e2e] [test-name]
        -sp :create gsts for scanner-parser tests
        -sast: create gsts for SAST tests
        -e2e: create gsts for e2e tests
        test-name: optional string that makes gold standard for test test-name"
}


check_success() {
    if [ $1 -ne 0 ];
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
            # actually compile and run
            compile_one_test $test
            output="$test.exe"
            ./$output > $gold_standard
        else
            echo "*****Alert**** test type is not of fail or tests :( - test name should start with fail- or test-\n"
        fi
    fi
}

# create one sast gst 
run_sast_gst()
{
    test=$1
    file_name="sast-tests/${test}.bs"
    echo "making gst file $file_name...\n"
    if [ ! -f $file_name ]; then
        echo "****ALERT***** Test ${test} doesn't exist. we're not gonna try :/ \n\n\n\n"
        continue;
    fi
    gold_standard="sast-tests/${test}.gst"
    touch $gold_standard
    type=${test::4}
    if [ $type == "fail" ]; then
        # get from stderr
        ./toplevel.native -s < $file_name 2> $gold_standard
    else
        ./toplevel.native -s < $file_name > $gold_standard
    fi 

}

#create a single gst of a scanner-parser test
run_sp_gst() 
{
    test=$1
    file_name="sp-tests/${test}.bs"
    echo "making gst file $file_name...\n"
    if [ ! -f $file_name ]; then
        echo "****ALERT***** Test ${test} doesn't exist. we're not gonna try :/ \n\n\n\n"
        continue;
    fi
    gold_standard="sp-tests/${test}.gst"
    touch $gold_standard
    type=${test::4}
    if [ $type == "fail" ]; then
        # get from stderr
        ./toplevel.native -a < $file_name 2> $gold_standard
    else
        # get standard output 
        ./toplevel.native -a < $file_name > $gold_standard
    fi 
    
}


if [ $# -lt 1 ];
    then
    Usage
fi

make 

# scanner parser gsts
if [ $1 = "-sp" ]; then 
    if [ "$#" -eq 1 ]; then
    echo "Making gold standard for all scanner-parser tests:"
        for test in $sp_tests; do
            run_sp_gst $test
        done

        for test in $sp_fail; do
            run_sp_gst $test
        done
    fi 
    exit
else
    if [ "$#" -eq 2 ]; then
        echo "Making gold standard for one scanner-parser test $2:"
        run_sp_gst $2
    fi 
    exit 
fi 

# sast gsts
if [ $1 = "-sast"]; then 
    if [ "$#" -eq 1 ]; then
    echo "Making gold standard for all sast tests:"
        for test in $sast_tests; do
            run_sast_gst $test
        done
        for test in $sast_fail; do
            run_sast_gst $test
        done
    fi 
    exit
else
    if [ "$#" -eq 2 ]; then
        echo "Making gold standard for one sast test $2:"
        run_sast_gst $2
    fi 
    exit
fi 


# create e2e gsts
if [ $1 = "-e2e"]; then 
    if [ "$#" -eq 1 ]; then
    echo "Making gold standard for all e2e tests:"
        for test in $tests; do
            run_one_gst $test
        done
        for test in $fail_tests; do
            run_one_gst $test
        done
    fi 
    exit 
else
    if [ "$#" -eq 2 ]; then
        echo "Making gold standard for one e2e test $2:"
        run_one_gst $2
    fi
    exit
fi 


make clean
echo "bye"
