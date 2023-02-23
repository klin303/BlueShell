
# "make all" builds the executable 

.PHONY : all
all : toplevel.native

# "make test" Compiles everything and runs the regression tests

.PHONY : test
test : all testall.sh
	./testall.sh

# "make blueshell.native" compiles the compiler
#
# The _tags file controls the operation of ocamlbuild, e.g., by including
# packages, enabling warnings -- LLVM STUFF TO REMOVE?
#
# See https://github.com/ocaml/ocamlbuild/blob/master/manual/manual.adoc

toplevel.native :parser.mly scanner.mll toplevel.ml 
	opam exec -- \
	ocamlbuild -use-ocamlfind toplevel.native

# "make clean" removes all generated files

.PHONY : clean
clean :
	ocamlbuild -clean
	rm -rf testall.log ocamlllvm *.diff printbig.o *.tsout

# can add a test for one file here

# printbig : printbig.c
# 	cc -o printbig -DBUILD_TEST printbig.c

# Building the ziploc really funn.y 

TESTS = \
	elseif1 exec1 function1 if-elses1 int1 list2 lists1

FAILS = \
	cons1 function1 noend badif1 badeq1

TESTFILES = $(TESTS:%=test-%.bs) $(TESTS:%=test-%.out) \
	    $(FAILS:%=fail-%.bs) $(FAILS:%=fail-%.err)

ZIPFILES = ast.ml Makefile toplevel.ml parser.mly README scanner.mll \
		testall.sh $(TESTFILES:%=tests/%) 

bostonbitpackers.zip : $(ZIPFILES)
	zip bostonbitpackers.zip $(ZIPFILES)

print_succtests: 
	@echo $(TESTS)

print_failtests:
	@echo $(FAILS)
