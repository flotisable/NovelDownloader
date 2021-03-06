libDir := Lib

PERL      := /c/Strawberry/perl/bin/perl
INCLUDE   := -I ${libDir}
PERLFLAGS := ${INCLUDE}
PROG      := ./novelDownloader.pl

testProgram := test.pl
testDir     := Test
testcaseDir := ${testDir}/Testcase

.PHONY: all test

all:

test:
	${PERL} ${testProgram} "${PERL} ${PERLFLAGS} ${PROG}" ${testcaseDir}
