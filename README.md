# Go-compiler

A simple Go compiler. This program will generate Java assembly code from the given Go program. The generated code will be translated to the Java bytecode by the Java assembler, Jasmin. The generated Java bytecode should be run by the Java Virtual Machine (JVM) successfully.

## Prerequisite
In Linux environment, you could prepare the development tools with following commands:
- Lexical Analyzer (Flex) and Syntax Analyzer (Bison)
  
  ```
  $ sudo apt-get install flex bison
  ```
- Java Assembler (jasmin.jar) is attached.
- Java Virtual Machine (JVM)

  ```
  $ sudo apt-get update
  $ sudo apt-get install default-jre
  $ sudo apt-get install oracle-java8-installer
  ```
## Build & Run
To build and run Go-compiler, run 'make run' inside the directory where you have the source.

```
$ make run
```

You can specify the input file on line 19 of Makefile.
```Makefile
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
```

The execution flowchart for compiling the Go program into Java bytecode for JVM.

![Flow_chart](https://github.com/Msiciots/Go-compiler/raw/master/img/Flow_chart.png)

##  Features
The compiler offers basic syntax rules of Go language. 
- Handle variable declarations and scoping.
- Handle arithmetic operations for integers and floats. 
- Handle the print and println function.
- Handle the if, else if and else statement. 
- Handle the for statement.
