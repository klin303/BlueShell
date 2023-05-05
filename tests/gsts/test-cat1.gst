BlueShell

Kenneth Lin (kenneth.lin@tufts.edu)
Alan Luc (alan.luc@tufts.edu)
Tina Ma (tina.ma@tufts.edu)
Mary-Joy Sidhom (mary-joy.sidhom@tufts.edu)

*** Compiling a BlueShell program ***
You can compile a BlueShell program with the following command:

./compile.sh {input_file}.bs

This produces a file named {input_file}.exe, which can be run using
./{input_file}.exe

*** Compiling the BlueShell Compiler ***
To compile the BlueShell Compiler, run:
  make

*** Run and Validate Tests ***
To run and validate all tests:
./testall.sh -a

To run and validate a single test:
./testall.sh -s {test-name}

where test-name is a file in the tests directory without the .bs extension
(you don't need the path to the file, just the file name).

Example:
./testall.sh -s test-ls

To keep intermediate output files produced during compilation (.s and .llvm files):
./testall.sh -a -keepc

To keep intermediate output files produced during testing (.out and .diff files):
./testall.sh -a -keept


*** Interpreting Testing Results ***
The testall script validates that a BlueShell program succeeds at every step of
compilation.
If no errors occur, there will be no observable output.
If an error occurs during compilation, the testall script prints the error and
exits.

If a test's output matches the gold standard, testall will print 'PASSED'.
If a test's output does not match the gold standard, testall will print an error
and the differences between the gold standard and the output.


*** Demo Programs ***
Demonstration programs are located within the demo-programs subdirectory. The
program 

NOTE: misc-ops.bs relies on files located within the sample-files subdirectory. 

NOTE: All demonstration programs should be run from the parent BlueShell
directory, not any subdirectories. 


*** Testing Suite ***
End-to-end integration tests are located in the tests subdirectory. 

NOTE: There are separate semantic tests in the sast-tests subdirectory
      There are separate scanner and parser tests in the sp-tests subdirectory

Below is a listing of every test in the tests subdirectory:

test-allops1.bs
    Tests a variety of different combinations of executable operators. This test
    relies on "test_file.txt" and "test_file2.txt".

test-arith1.bs
    Creates two integer variables, does addition on them, and creates an 
    executable with path "echo" and one integer argument.

test-assign1.bs
    Creates an executable with a single string argument and stores it in an 
    executable variable. It then runs the executable using the variable.

test-assign2.bs
    Declares a string variable, then assigns a string value to
    the variable. Verifies assignment by printing the output of the string
    variable.

test-assign3.bs
    Declares and assigns a value to a string variable in a single line. Verifies
     assignment by printing out the string variable.

test-block1.bs
    Ensure that variables created within a block are in scope within the same 
    block. Variables declared outside the block should remain in scope as well.

test-boolops1.bs
    Tests the boolean operations &&, ||, and, or, and prints out the results of
    each.

test-cat1.bs
    Creates an executable with two string arguments. Executes it to demonstrate
    that multiple arguments work.

test-charfunc1.bs
    Tests the char type by printing out chars and
    also printing out variable of type char

test-compile.bs:
    Creates and runs a BlueShell executable which compiles a BlueShell program.
    It then creates and runs a BlueShell executable which runs the compiled
    program.

test-compop1.bs
    Tests integer comparison operators (<, >, <=, >=, ==, and !=) and prints out
     the resulting boolean

test-concat1.bs
    Test executable concatenation - the result of the two operands to an 
    executable should be concatenated.

test-concatseq1.bs
    Tests executable concatenation in tandem with executable sequencing. 
    Sequencing should have precedence over concatenation.

test-cons1.bs
    Tests cons to an empty list.

test-cons2.bs
    Tests setting a list variable equal to the result of a cons to an empty 
    list.

test-cons3.bs
    Tests cons to a non-empty list.

test-cons4.bs
    Tests cons with a value returned from a function.

test-echo1.bs
    Creates an executable with a single string argument and executes it without
    storing the executable in a variable.

test-echo2.bs
    Creates a string list with one element and stores it in a list variable.
    Creates an executable using the list variable and executes it.

test-execcopy1.bs
    Declares an executable with one argument and assigns it to a variable. 
    Creates a new executable variable by assigning it to the initial executable 
    made. Executes the second executable.

test-execcopy2.bs
    Declares a string variable. Declares an executable variable of one argument 
    of the string variable. Creates a new executable variable by assigning it to
     the initial executable made. Executes the second executable.

test-floatarith1.bs
    Tests our code can handle floats and all four arithmetic operations on 
    floats to ensure they work and print out the result of each operation.

test-for1.bs
    Tests a simple for loop, printing at each iteration to verify that it ran.

test-function1.bs
    Creates a function that runs the echo command and calls the function.
    This is a function with no arguments and no return type.

test-function2.bs
    Tests a function containing a for loop.

test-hofs1.bs
    Tests higher order functions by assigning a variable to an existing function
     and calling that function through the variable.

test-hofs2.bs
    Tests higher order functions by passing defining a function that takes in 
    another function as a parameter and calls the parameter function.

test-hof3.bs
    Tests higher order functions by by declaring two function variables of the 
    same type, assigning one two a function, assigning the second to the first 
    function variable, then calling the second.

test-if1.bs
    Tests if statements by printing a boolean depending on which branch it 
    entered.

test-index1.bs
    Tests indexing to access elements in a list and change them.

test-index2.bs
    Tests putting indexed elements into a list.

test-index3.bs
    Tests indexing into lists of all types.

test-intarith1.bs
    Tests simple integer arithmetic.

test-len1.bs
    Tests len on both empty and non-empty lists.

test-list1.bs
    Stores a list with two string arguments in a list variable. Creates an
    executable using the list variable and executes it.

test-map.bs
    Creates a function that takes a function as a parameter. Calls the 
    function in a loop.

tests-neg1.bs
    Tests integer and float negation.

tests-not1.bs
    Tests boolean negation.

test-path1.bs
    Tests getting and setting the path of an executable.

test-printbools1.bs
    Tests printing booleans with autocasting.

test-printfloat1.bs
    Tests printing floats with autocasting.

tests-printints.bs
    Tests printing ints with autocasting.

tests-returnfunc1.bs
    Tests using the return value of a function.

tests-run1.bs
    Tests run with a variable path.

test-runreturn1.bs
    Tests using the string returned from running an executable.

test-seq1.bs
    Tests basic executable sequencing with multiple arguments.

tests-string1.bs
    Tests string assignment and putting strings as the arg of an executable

test-stringfunc1.bs
    Creating a function of type string -> void that calls prints the parameter 
    string out to stdout. Calls the function on three different strings.

test-toplevel1.bs
    Tests multiple arguments in an executable using toplevel.native as the path.

test-while1.bs
    Tests a simple while loop, printing at each iteration.

FAILS

fail-arith1.bs
    Detects mismatched types in an arithmetic operation.

fail-block1.bs
    Detects scope mismatch going from within a block to outside it.

fail-exec1.bs
    Detects a non-executable type used with run.

fail-list1.bs
    Creates a list of strings but attempts to store an int element.




BlueShell

Kenneth Lin (kenneth.lin@tufts.edu)
Alan Luc (alan.luc@tufts.edu)
Tina Ma (tina.ma@tufts.edu)
Mary-Joy Sidhom (mary-joy.sidhom@tufts.edu)

*** Compiling a BlueShell program ***
You can compile a BlueShell program with the following command:

./compile.sh {input_file}.bs

This produces a file named {input_file}.exe, which can be run using
./{input_file}.exe

*** Compiling the BlueShell Compiler ***
To compile the BlueShell Compiler, run:
  make

*** Run and Validate Tests ***
To run and validate all tests:
./testall.sh -a

To run and validate a single test:
./testall.sh -s {test-name}

where test-name is a file in the tests directory without the .bs extension
(you don't need the path to the file, just the file name).

Example:
./testall.sh -s test-ls

To keep intermediate output files produced during compilation (.s and .llvm files):
./testall.sh -a -keepc

To keep intermediate output files produced during testing (.out and .diff files):
./testall.sh -a -keept


*** Interpreting Testing Results ***
The testall script validates that a BlueShell program succeeds at every step of
compilation.
If no errors occur, there will be no observable output.
If an error occurs during compilation, the testall script prints the error and
exits.

If a test's output matches the gold standard, testall will print 'PASSED'.
If a test's output does not match the gold standard, testall will print an error
and the differences between the gold standard and the output.


*** Demo Programs ***
Demonstration programs are located within the demo-programs subdirectory. The
program 

NOTE: misc-ops.bs relies on files located within the sample-files subdirectory. 

NOTE: All demonstration programs should be run from the parent BlueShell
directory, not any subdirectories. 


*** Testing Suite ***
End-to-end integration tests are located in the tests subdirectory. 

NOTE: There are separate semantic tests in the sast-tests subdirectory
      There are separate scanner and parser tests in the sp-tests subdirectory

Below is a listing of every test in the tests subdirectory:

test-allops1.bs
    Tests a variety of different combinations of executable operators. This test
    relies on "test_file.txt" and "test_file2.txt".

test-arith1.bs
    Creates two integer variables, does addition on them, and creates an 
    executable with path "echo" and one integer argument.

test-assign1.bs
    Creates an executable with a single string argument and stores it in an 
    executable variable. It then runs the executable using the variable.

test-assign2.bs
    Declares a string variable, then assigns a string value to
    the variable. Verifies assignment by printing the output of the string
    variable.

test-assign3.bs
    Declares and assigns a value to a string variable in a single line. Verifies
     assignment by printing out the string variable.

test-block1.bs
    Ensure that variables created within a block are in scope within the same 
    block. Variables declared outside the block should remain in scope as well.

test-boolops1.bs
    Tests the boolean operations &&, ||, and, or, and prints out the results of
    each.

test-cat1.bs
    Creates an executable with two string arguments. Executes it to demonstrate
    that multiple arguments work.

test-charfunc1.bs
    Tests the char type by printing out chars and
    also printing out variable of type char

test-compile.bs:
    Creates and runs a BlueShell executable which compiles a BlueShell program.
    It then creates and runs a BlueShell executable which runs the compiled
    program.

test-compop1.bs
    Tests integer comparison operators (<, >, <=, >=, ==, and !=) and prints out
     the resulting boolean

test-concat1.bs
    Test executable concatenation - the result of the two operands to an 
    executable should be concatenated.

test-concatseq1.bs
    Tests executable concatenation in tandem with executable sequencing. 
    Sequencing should have precedence over concatenation.

test-cons1.bs
    Tests cons to an empty list.

test-cons2.bs
    Tests setting a list variable equal to the result of a cons to an empty 
    list.

test-cons3.bs
    Tests cons to a non-empty list.

test-cons4.bs
    Tests cons with a value returned from a function.

test-echo1.bs
    Creates an executable with a single string argument and executes it without
    storing the executable in a variable.

test-echo2.bs
    Creates a string list with one element and stores it in a list variable.
    Creates an executable using the list variable and executes it.

test-execcopy1.bs
    Declares an executable with one argument and assigns it to a variable. 
    Creates a new executable variable by assigning it to the initial executable 
    made. Executes the second executable.

test-execcopy2.bs
    Declares a string variable. Declares an executable variable of one argument 
    of the string variable. Creates a new executable variable by assigning it to
     the initial executable made. Executes the second executable.

test-floatarith1.bs
    Tests our code can handle floats and all four arithmetic operations on 
    floats to ensure they work and print out the result of each operation.

test-for1.bs
    Tests a simple for loop, printing at each iteration to verify that it ran.

test-function1.bs
    Creates a function that runs the echo command and calls the function.
    This is a function with no arguments and no return type.

test-function2.bs
    Tests a function containing a for loop.

test-hofs1.bs
    Tests higher order functions by assigning a variable to an existing function
     and calling that function through the variable.

test-hofs2.bs
    Tests higher order functions by passing defining a function that takes in 
    another function as a parameter and calls the parameter function.

test-hof3.bs
    Tests higher order functions by by declaring two function variables of the 
    same type, assigning one two a function, assigning the second to the first 
    function variable, then calling the second.

test-if1.bs
    Tests if statements by printing a boolean depending on which branch it 
    entered.

test-index1.bs
    Tests indexing to access elements in a list and change them.

test-index2.bs
    Tests putting indexed elements into a list.

test-index3.bs
    Tests indexing into lists of all types.

test-intarith1.bs
    Tests simple integer arithmetic.

test-len1.bs
    Tests len on both empty and non-empty lists.

test-list1.bs
    Stores a list with two string arguments in a list variable. Creates an
    executable using the list variable and executes it.

test-map.bs
    Creates a function that takes a function as a parameter. Calls the 
    function in a loop.

tests-neg1.bs
    Tests integer and float negation.

tests-not1.bs
    Tests boolean negation.

test-path1.bs
    Tests getting and setting the path of an executable.

test-printbools1.bs
    Tests printing booleans with autocasting.

test-printfloat1.bs
    Tests printing floats with autocasting.

tests-printints.bs
    Tests printing ints with autocasting.

tests-returnfunc1.bs
    Tests using the return value of a function.

tests-run1.bs
    Tests run with a variable path.

test-runreturn1.bs
    Tests using the string returned from running an executable.

test-seq1.bs
    Tests basic executable sequencing with multiple arguments.

tests-string1.bs
    Tests string assignment and putting strings as the arg of an executable

test-stringfunc1.bs
    Creating a function of type string -> void that calls prints the parameter 
    string out to stdout. Calls the function on three different strings.

test-toplevel1.bs
    Tests multiple arguments in an executable using toplevel.native as the path.

test-while1.bs
    Tests a simple while loop, printing at each iteration.

FAILS

fail-arith1.bs
    Detects mismatched types in an arithmetic operation.

fail-block1.bs
    Detects scope mismatch going from within a block to outside it.

fail-exec1.bs
    Detects a non-executable type used with run.

fail-list1.bs
    Creates a list of strings but attempts to store an int element.




