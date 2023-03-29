
# "make all" builds the executable
.PHONY : all
all : toplevel.native exec.o

# "make test" compiles everything and runs the regression tests
.PHONY : test
test : all testall.sh
	./testall.sh

# "make test-sast" compiles everything and runs the regression tests for
# semantic checking
.PHONY : test-sast
test-sast : all testsast.sh
	./testsast.sh

# 'make gold' compiles everything and re-runs all the tests to produce new
# gold standards. DO NOT RUN UNLESS YOU WANT ALL GOLD STANDARDS TO BE REMADE
.PHONY : gold
gold : all make-gsts.sh
	./make-gsts.sh

# "make toplevel.native" builds the scanner, parser, and toplevel for testing
toplevel.native :parser.mly scanner.mll codegen.ml semant.ml toplevel.ml
	opam exec -- \
	ocamlbuild -use-ocamlfind toplevel.native


# "make clean" removes all generated files
.PHONY : clean
clean :
	ocamlbuild -clean
	rm -rf testall.log ocamlllvm *.diff *.tsout *.llvm *.o *.llvm.s *.out *.exe

# compiles the helper C file which executes shell commands
exec : exec.c
	cc -o exec

# Filling the ziploc

# SP passing and failing tests for the scanner and parser
SPTESTS = \
	arith1 bool1 char1 elseif1 emptyfile exec1 exec2 exec3 exec4 exec5 float1 \
	function1 function2 function3 function4 function5 hofs1 if-elses1 indexing1 \
	int1 int2 lists1 program string1 string2 types1 vdecl1

SPFAILS = \
	assign1 cons1 function2 noend badif1 badeq1 char1 int1 int2 program types1 \
	string1 list1

# tests for codegen
TESTS = $(shell find tests -type f -name '*.bs')

FAILS = $(shell find tests/fail -type f -name '*.bs')

TESTFILES = $(TESTS:%=test-%.bs) $(TESTS:%=test-%.gst) \
						$(FAILS:%=fail-%.bs) $(FAILS:%=fail-%.gst)

ZIPFILES = ast.ml scanner.mll toplevel.ml parser.mly sast.ml semant.ml \
		   codegen.ml testall.sh make-gsts.sh README Makefile \
		   testall.sh make-gsts.sh test_ls.sh $(TESTFILES:%=tests/%)

# zips files and tests together
bostonbitpackers.zip : $(ZIPFILES)
	cd .. && zip bostonbitpackers.zip $(ZIPFILES)

# prints the list of tests which should pass
print_succtests:
	@echo $(TESTS)

# prints the list of tests which should fail
print_failtests:
	@echo $(FAILS)

#removes .out and .diff files produced by the testing script
clean_tests:
	rm -rf *.diff *.tsout
