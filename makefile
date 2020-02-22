PERL := /c/Strawberry/perl/bin/perl
PROG := ./wenku8Download.pl

testProgram := test.pl
testDir     := Test
testcaseDir := ${testDir}/Testcase

.PHONY: all test

all:

test:
	${PERL} ${testProgram} "${PERL} ${PROG}" ${testcaseDir}
