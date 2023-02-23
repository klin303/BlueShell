
# "make all" builds the executable 
.PHONY : all
all : toplevel.native

# "make test" compiles everything and runs the regression tests
.PHONY : test
test : all testall.sh
	./testall.sh

# 'make gold' compiles everything and re-runs all the tests to produce new 
# gold standards. DO NOT RUN UNLESS YOU WANT ALL GOLD STANDARDS TO BE REMADE
.PHONY : gold
gold : all make-gsts.sh
	./make-gsts.sh

# "make toplevel.native" builds the scanner, parser, and toplevel for testing
toplevel.native :parser.mly scanner.mll toplevel.ml 
	opam exec -- \
	ocamlbuild -use-ocamlfind toplevel.native


# "make clean" removes all generated files
.PHONY : clean
clean :
	ocamlbuild -clean
	rm -rf testall.log ocamlllvm *.diff *.tsout

# Filling the ziploc
TESTS = \
	elseif1 exec1 if-elses1 int1 intliteral1 list2 lists1 types1 vdecl1 string1 string2 \
	program indexing1 hofs1 function2 function3 function1 float1 exec4 exec2 emptyfile \
	char1 bool1

FAILS = \
	cons1 function1 noend badif1 badeq1 char1 cons2 

TESTFILES = $(TESTS:%=test-%.bs) $(TESTS:%=test-%.out) \
	    $(FAILS:%=fail-%.bs) $(FAILS:%=fail-%.err)

ZIPFILES = ast.ml Makefile toplevel.ml parser.mly README scanner.mll \
		testall.sh $(TESTFILES:%=tests/%) 

# zips files and tests together
bostonbitpackers.zip : $(ZIPFILES)
	zip bostonbitpackers.zip $(ZIPFILES)

# prints the list of tests which should pass
print_succtests: 
	@echo $(TESTS)

# prints the list of tests which should fail
print_failtests:
	@echo $(FAILS)
