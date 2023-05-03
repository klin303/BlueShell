BlueShell

Kenneth Lin (kenneth.lin@tufts.edu)
Alan Luc (alan.luc@tufts.edu)
Tina Ma (tina.ma@tufts.edu)
Mary-Joy Sidhom (mary-joy.sidhom@tufts.edu)

*** Testing Suite ***
NOTE: There are separate semantic tests in the directory sast-tests

test-arith1.bs
    Creates two integer variables, does addition on them, and creates an executable with path "echo" and one integer argument 

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

test-boolops1.bs 
    Tests the boolean operations &&, ||, and, or, and prints out the results of each. 

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
    Tests integer comparison operators (<, >, <=, >=, ==, and !=) and prints out the resulting boolean 

test-echo1.bs
    Creates an executable with a single string argument and executes it without
    storing the executable in a variable.

test-echo2.bs
    Creates a string list with one element and stores it in a list variable.
    Creates an executable using the list variable and executes it.

test-execcopy1.bs
    Declares an executable with one argument and assigns it to a variable. Creates a new executable variable by assigning it to the initial executable made. Executes the second executable. 

test-execcopy2 
    Declares a string variable. Declares an executable variable of one argument of the string variable. Creates a new executable variable by assigning it to the initial executable made. Executes the second executable. 

test-floatarith1 
    Tests our code can handle floats and all four arithmetic operations on floats to ensure they work and print out the result of each operation. 

test-function1.bs
    Creates a function that runs the echo command and calls the function.
    This is a function with no arguments and no return type.

test-hofs1.bs 
    Tests higher order functions by assigning a variable to an existing function and calling that function through the variable.  


test-hofs2.bs 
    Tests higher order functions by passing defining a function that takes in another function as a parameter and calls the parameter function. 

test-hof3.bs 
    Tests higher order functions by by declaring two function variables of the same type, assigning one two a function, assigning the second to the first function variable, then calling the second. 

test-if1.bs
    Tests if statements by 

test-list2.bs
    Stores a list with two string arguments in a list variable. Creates an
    executable using the list variable and executes it.

test-ls.bs:
    Creates and runs an executable with path 'ls' and no arguments

tests-neg1.bs 

tests-not1.bs 

test-printbools1.bs 

test-printfloat1.bs 

tests-printints.bs 

tests-returnfunc1.bs 

tests-string1.bs 

test-stringfunc1.bs 



FAILS 

fail-arith1.bs
    Detects mismatched types in an arithmetic operation.

fail-list1.bs
    Creates a list of strings but attempts to store an int element.

fail-exec1.bs
    Detects a non-executable type used with run.

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

*** Compiling a BlueShell program ***
You can compile a BlueShell program with the following command:

./compile.sh {input_file}.bs

This produces a file named {input_file}.exe, which can be run using ./{input_file}.exeBlueShell

Kenneth Lin (kenneth.lin@tufts.edu)
Alan Luc (alan.luc@tufts.edu)
Tina Ma (tina.ma@tufts.edu)
Mary-Joy Sidhom (mary-joy.sidhom@tufts.edu)

*** Testing Suite ***
NOTE: There are separate semantic tests in the directory sast-tests

test-arith1.bs
    Creates two integer variables, does addition on them, and creates an executable with path "echo" and one integer argument 

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

test-boolops1.bs 
    Tests the boolean operations &&, ||, and, or, and prints out the results of each. 

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
    Tests integer comparison operators (<, >, <=, >=, ==, and !=) and prints out the resulting boolean 

test-echo1.bs
    Creates an executable with a single string argument and executes it without
    storing the executable in a variable.

test-echo2.bs
    Creates a string list with one element and stores it in a list variable.
    Creates an executable using the list variable and executes it.

test-execcopy1.bs
    Declares an executable with one argument and assigns it to a variable. Creates a new executable variable by assigning it to the initial executable made. Executes the second executable. 

test-execcopy2 
    Declares a string variable. Declares an executable variable of one argument of the string variable. Creates a new executable variable by assigning it to the initial executable made. Executes the second executable. 

test-floatarith1 
    Tests our code can handle floats and all four arithmetic operations on floats to ensure they work and print out the result of each operation. 

test-function1.bs
    Creates a function that runs the echo command and calls the function.
    This is a function with no arguments and no return type.

test-hofs1.bs 
    Tests higher order functions by assigning a variable to an existing function and calling that function through the variable.  


test-hofs2.bs 
    Tests higher order functions by passing defining a function that takes in another function as a parameter and calls the parameter function. 

test-hof3.bs 
    Tests higher order functions by by declaring two function variables of the same type, assigning one two a function, assigning the second to the first function variable, then calling the second. 

test-if1.bs
    Tests if statements by 

test-list2.bs
    Stores a list with two string arguments in a list variable. Creates an
    executable using the list variable and executes it.

test-ls.bs:
    Creates and runs an executable with path 'ls' and no arguments

tests-neg1.bs 

tests-not1.bs 

test-printbools1.bs 

test-printfloat1.bs 

tests-printints.bs 

tests-returnfunc1.bs 

tests-string1.bs 

test-stringfunc1.bs 



FAILS 

fail-arith1.bs
    Detects mismatched types in an arithmetic operation.

fail-list1.bs
    Creates a list of strings but attempts to store an int element.

fail-exec1.bs
    Detects a non-executable type used with run.

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

*** Compiling a BlueShell program ***
You can compile a BlueShell program with the following command:

./compile.sh {input_file}.bs

This produces a file named {input_file}.exe, which can be run using ./{input_file}.exe