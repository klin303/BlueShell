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






if [ "$#" -eq 0 ]; then
    for test in $tests
    do
        echo "Making gold standard for test $test........\n"
        file_name="${test_dir}${test}"
        cat $file_name
        # echo $gold_standard
        if [ ! -f $file_name ]; then
            echo "****ALERT***** Test $test doesn't exist\n\n\n\n"
            continue;
        fi
        gold_standard="sast-tests/gsts/${test}.gst"
        ./toplevel.native -s < $file_name 2> "$test.gst"
    done


    # cringe fail test compilation
    for ftest in $fail_tests
    do
        echo "Making goldstandard for fail test $ftest.............\n"
        file_name="sast/gsts/${ftest}.bs"
        if [ ! -f $file_name ]; then
            echo "****ALERT***** Test $ftest doesn't exist\m\n\n\n"
            continue;
        fi
        gold_standard="${gsts_dir}fail-${ftest}.gst"
        ./toplevel.native -s < $file_name 2> "$ftest.gst"
    done
    exit


elif [ "$#" -eq 1 ]; then
        test_name=$1
        echo "Making gst for $type-$test_name........\n"
        file_name="${test_dir}${type}-${test_name}.bs"

        # check if file exists
        if [ ! -f $file_name ]; then
            echo "****ALERT***** Test $test_name doesn't exist\m\n\n\n"
            exit
        fi


        gold_standard="${test_dir}${type}-${test_name}.gst"

        # if fail, get from stderr. Else if regular, get output from stdout
        if [ "$2" = "fail" ]; then
            ./toplevel.native -s < $file_name 2> "$file_name.gst"
        else
            ./toplevel.native -s < $file_name > "$file_name.gst"
        fi
    else
        echo "Type must be test or fail"
    fi
else
    echo "Usage: ./make-gsts.sh [test-name type] where type is either test or fail"
    exit
fi


# echo "Making top level:"
# make clean
# make toplevel.native

