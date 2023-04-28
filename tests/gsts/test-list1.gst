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
    Creates an executable with two s