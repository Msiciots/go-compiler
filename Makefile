CC = gcc
YFLAG = -d
FNAME = compiler_hw3
PARSER = myparser
JAVABYTE = Output
OBJECT = lex.yy.c y.tab.c y.tab.h ${JAVABYTE}.j ${EXE}.class
EXE = main

all: lex.yy.c y.tab.c
	${CC} lex.yy.c y.tab.c -o ${PARSER}

lex.yy.c:
	@lex ${FNAME}.l

y.tab.c:
	@yacc ${YFLAG} ${FNAME}.y

run: all
	@./${PARSER} < ./input_example/test.go 
	@java -jar jasmin.jar ${JAVABYTE}.j
	@echo "\nOutput from JVM:"
	@java ${EXE} 

clean:
	rm -f *.o ${PARSER} ${OBJECT} 

