
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
SPTESTS = $(shell find sp-tests -type f -name 'test*.bs' -exec basename {} \;)

SPFAILS = $(shell find sp-tests -type f -name 'fail*.bs' -exec basename {} \;)

# sast tests
SAST_TESTS = $(shell find sast-tests -type f -name 'test*.bs' -exec basename {} \;)

SAST_FAILS = $(shell find sast-tests -type f -name 'fail*.bs' -exec basename {} \;)


SUCCSAST_NAMES = $(SAST_TESTS:%.bs=%)
FAILSAST_NAMES = $(SAST_FAILS:%.bs=%)

print_succsast:
	@echo $(SUCCSAST_NAMES)

print_failsast:
	@echo $(FAILSAST_NAMES)


# tests for codegen
TESTS = $(shell find tests -type f -name 'test*.bs' -exec basename {} \;)

FAILS = $(shell find tests -type f -name 'fail*.bs' -exec basename {} \;)

TESTFILES = $(TESTS) $(TESTS:%.bs=gsts/%.gst) \
		$(FAILS) $(FAILS:%.bs=gsts/%.gst)

# zips files and tests together
bostonbitpackers.zip : $(ZIPFILES)
	mkdir blueshell && cp $(ZIPFILES) blueshell \
	&& zip -r bostonbitpackers.zip blueshell && rm -r blueshell

# prints the list of tests which should pass

TESTNAMES = $(TESTS:%.bs=%)

FAILTESTNAMES = $(FAILS:%.bs=%)

print_succtests:
	@echo $(TESTNAMES)

# prints the list of tests which should fail
print_failtests:
	@echo $(FAILTESTNAMES)

print_files:
	@echo $(TESTFILES)

#removes .out and .diff files produced by the testing script
clean_tests:
	rm -rf tests/diff/*.diff tests/out/*.out

# removes .exes produced
clean_exes:
	rm -rf *.exes

clean_intermediates:
	rm -rf *.s *.llvm
