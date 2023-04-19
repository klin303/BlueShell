#!/bin/sh

# WOAH WOAH WOAH
# UNLESS WE, BLUESHELL, AS A GROUP, HAVE DECIDED ON SWITCHING OUR SYNTAX TO SOMETHING DIFFERENT,
# *****DO NOT RUN THIS SCRIPT***** unless you want to create new gold standard ASTs

# It creates new gold standards, both errors and ASTs for our compiler.

# if [[ -e $# 0 ]]; then
#     echo "no args"
# elif [[ -e $# 1 ]]; then
#     echo $1
# fi
tests=$(Make print_succtests)
fail_tests=$(Make print_failtests)
test_dir="tests/"
gsts_dir="tests/gsts/"

### for sast
sast_succ=$(Make print_succsast)
sast_fail=$(Make print_failsast)

sast_dir="sast-tests/"
sast_gsts="sast-tests/gsts/"

#         # -sast: makes gold standards for all sast tests
        # -ast: makes gold standards for all ast tests



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

compile_one_test() {
    ./toplevel.native < "tests/$1.bs" > $1.llvm
    check_success $?
    llc "-relocation-model=pic" $1.llvm
    check_success $?
    cc -c exec.c # links with our c file
    cc $1.llvm.s exec.o -o $1.exe
    check_success $?
}

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

# run_sast() {

# }

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
# run_ast_tests() {
#     if [ "$#" -eq 0 ]; then
#     for test in $tests
#     do
#         echo "Making gold standard for test $test........\n"
#         file_name="${test_dir}${test}"
#         cat $file_name
#         # echo $gold_standard
#         if [ ! -f $file_name ]; then
#             echo "****ALERT***** Test $test doesn't exist\n\n\n\n"
#             continue;
#         fi
#         gold_standard="sast-tests/gsts/${test}.gst"
#         ./toplevel.native -s < $file_name 2> "$test.gst"
#     done


#     # cringe fail test compilation
#     for ftest in $fail_tests
#     do
#         echo "Making goldstandard for fail test $ftest.............\n"
#         file_name="sast/gsts/${ftest}.bs"
#         if [ ! -f $file_name ]; then
#             echo "****ALERT***** Test $ftest doesn't exist\m\n\n\n"
#             continue;
#         fi
#         gold_standard="${gsts_dir}fail-${ftest}.gst"
#         ./toplevel.native -s < $file_name 2> "$ftest.gst"
#     done
#     exit


# elif [ "$#" -eq 1 ]; then
#         test_name=$1
#         echo "Making gst for $type-$test_name........\n"
#         file_name="${test_dir}${type}-${test_name}.bs"

#         # check if file exists
#         if [ ! -f $file_name ]; then
#             echo "****ALERT***** Test $test_name doesn't exist\m\n\n\n"
#             exit
#         fi


#         gold_standard="${test_dir}${type}-${test_name}.gst"

#         # if fail, get from stderr. Else if regular, get output from stdout
#         if [ "$2" = "fail" ]; then
#             ./toplevel.native -s < $file_name 2> "$file_name.gst"
#         else
#             ./toplevel.native -s < $file_name > "$file_name.gst"
#         fi
#     else
#         echo "Type must be test or fail"
#     fi
# else
#     echo "Usage: ./make-gsts.sh [test-name type] where type is either test or fail"
#     exit
# fi
# }




# echo "Making top level:"
# make clean
# make toplevel.native

