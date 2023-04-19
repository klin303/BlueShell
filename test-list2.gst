BlueShell

Kenneth Lin (kenneth.lin@tufts.edu)
Alan Luc (alan.luc@tufts.edu)
Tina Ma (tina.ma@tufts.edu)
Mary-Joy Sidhom (mary-joy.sidhom@tufts.edu)

*** Testing Suite ***
NOTE: There are separate semantic tests in the directory sast-tests

test-ls.bs:
    Creates and runs an executable with path 'ls' and no arguments

test-compile.bs:
    Creates and runs a BlueShell executable which compiles a BlueShell program.
    It then creates and runs a BlueShell executable which runs the compiled
    program.

test-echo.bs
    Creates an executable with a single string argument and executes it without
    storing the executable in a variable.

test-assign2.bs
    Creates an executable with a single string argument and stores it in an
    executable variable. It then runs the executable using the variable.

test-assign3.bs
    Declares a string variable then in another line assigns a string value to
    the variable. Verifies assignment by printing the output of the string
    variable.

test-assign4.bs
    Declares and assigns a value to a string variable in a single line. Verifies
    assignment by printing out the string variable.

test-echo3.bs
    Creates a string list with one element and stores it in a list variable.
    Creates an executable using the list variable and executes it.

test-cat2.bs
    Creates an executable with two string arguments. Executes it to demonstrate
    that multiple arguments work.

test-function1.bs
    Creates a function that runs the echo command and calls the function.
    This is a function with no arguments and no return type.

test-list2.bs
    Stores a list with two string arguments in a list variable. Creates an
    executable using the list variable and executes it.

fail-list1.bs
    Creates a list of strings but attempts to store an int element.

fail-arith1.bs
    Detects mismatched types in an arithmetic operation.

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

test-ls.bs:
    Creates and runs an executable with path 'ls' and no arguments

test-compile.bs:
    Creates and runs a BlueShell executable which compiles a BlueShell program.
    It then creates and runs a BlueShell executable which runs the compiled
    program.

test-echo.bs
    Creates an executable with a single string argument and executes it without
    storing the executable in a variable.

test-assign2.bs
    Creates an executable with a single string argument and stores it in an
    executable variable. It then runs the executable using the variable.

test-assign3.bs
    Declares a string variable then in another line assigns a string value to
    the variable. Verifies assignment by printing the output of the string
    variable.

test-assign4.bs
    Declares and assigns a value to a string variable in a single line. Verifies
    assignment by printing out the string variable.

test-echo3.bs
    Creates a string list with one element and stores it in a list variable.
    Creates an executable using the list variable and executes it.

test-cat2.bs
    Creates an executable with two string arguments. Executes it to demonstrate
    that multiple arguments work.

test-function1.bs
    Creates a function that runs the echo command and calls the function.
    This is a function with no arguments and no return type.

test-list2.bs
    Stores a list with two string arguments in a list variable. Creates an
    executable using the list variable and executes it.

fail-list1.bs
    Creates a list of strings but attempts to store an int element.

fail-arith1.bs
    Detects mismatched types in an arithmetic operation.

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