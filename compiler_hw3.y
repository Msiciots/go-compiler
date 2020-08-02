/*	Definition section */
%{
    extern int yylineno;
    extern int yylex();

    extern int yylen;
    extern char* yytext;
    extern char id_name[100];
    extern char left_id_name[100];
    extern char var_id_name[100];
    extern char str[100];
    extern int len;
    extern int i_number;
    extern int lines;
    extern int error_line;
    extern double f_number;
    int scope_index=0;
    int stack[1000];
    int stack_index=0;
    int for_stack[1000];
    int for_index=0;
    int for_stack_index=0;
#include <stdio.h>
#include <string.h>
    int yyerror(char *s);
    /* Symbol table function - you can add new function if need. */
    struct symbol_table {
        char id[20];
        char type[20];
        int i_data;
        double f_data;
        int scope_depth;

    };
    struct symbol_table table[100];
    int table_index=0;
    int table_exist =0;

    int lookup_symbol(char var_name[20]);
    void create_symbol();
    void insert_symbol(char* var_name,char* type,int i_data,double f_data);
    void dump_symbol();
    FILE *f;
    int var_index=0;
    int label_index=0;
    int exit_index=0;

    int for_i_index=0;
    int for_stat_index=0;
    int error=0;
%}

%code requires {
    typedef struct number{
        float v;
        int t;
    } number;
}
/* Using union to define nonterminal and token type */
%union {
    int i_val;
    double f_val;
    char* string;
    number value;
}


/* Token with return, which need to sepcify type */

%token <f_val> T_REAL T_INTEGER
%token <string> T_STRING T_INT T_FLOAT T_IDENTIFIER
%type <string> type
%type <i_val> assign_op
%type <value> term mul_expr add_expr relational_expr equal_expr and_expr or_expr assign_expr
/* my code */
%token	T_MOD T_INC T_DEC
%token	T_LE T_GE T_EQ T_NE
%token	T_AND T_OR T_NOT
%token	T_ASSIGN T_AbMUL T_AbDIV T_AbMOD T_AbADD T_AbMIN
%token	T_VAR
%token	T_PRINT T_PRINTLN
%token	T_IF T_ELSE T_FOR
%token	T_EOF  0
%token	T_LB T_RB
%nonassoc then
%nonassoc T_ELSE

/* Yacc will start at this nonterminal */
%start program
/* Grammar section */
%%
left_block
:
T_LB {scope_index++;}
;
right_block
:
T_RB {scope_index--;}
;
type
:
T_INT {char* tmp=malloc(sizeof(char)*yylen); strcpy(tmp,yytext); $$=tmp; }
| T_FLOAT {char* tmp=malloc(sizeof(char)*yylen); strcpy(tmp,yytext); $$=tmp;}
;
term
:
T_IDENTIFIER {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0) {
                fprintf(f,"\tiload %d\n",i);
                $$.v=table[i].i_data;
                $$.t=0;
            } else if(strcmp(table[i].type,"float32")==0) {
                fprintf(f,"\tfload %d\n",i);
                $$.v=table[i].f_data;
                $$.t=1;
            }

        }

    }

}
| T_INTEGER {
    fprintf(f,"\tldc %d\n",i_number);
    $$.v=i_number;
    $$.t=0;
}
| T_REAL	{
    fprintf(f,"\tldc %f\n",f_number);
    $$.v=f_number;
    $$.t=1;
}
| '(' add_expr ')'  {$$.v=$2.v; $$.t=$2.t;}
;

mul_expr
:
term	{$$.v=$1.v; $$.t=$1.t;}
| mul_expr '*' term {

    if (($1.t==0)&&($3.t==0)) { // int * int
        fprintf(f,"\timul\n");
        $$.t=0;
    } else if(($1.t==1)&&($3.t==1)) { //float * float

        fprintf(f,"\tfmul\n");
        $$.t=1;
    } else if (($1.t==1)&&($3.t==0)) { //float * int

        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfmul\n");
        $$.t=1;
    } else if (($1.t==0)&&($3.t==1)) { //int * float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfmul\n");
        $$.t=1;
    }
    $$.v=$1.v*$3.v;
}
| mul_expr '/' term {
    if($3.v==0) {
        printf("<ERROR>Divide by 0 (line :%d)\n",error_line);
        error=1;
    } else {
        if (($1.t==0)&&($3.t==0)) { // int / int
            fprintf(f,"\tidiv\n");
            $$.t=0;
        } else if(($1.t==1)&&($3.t==1)) { //float / float
            fprintf(f,"\tfdiv\n");
            $$.t=1;
        } else if (($1.t==1)&&($3.t==0)) { //float / int
            fprintf(f,"\ti2f\n");
            fprintf(f,"\tfdiv\n");
            $$.t=1;
        } else if (($1.t==0)&&($3.t==1)) { //int / float
            fprintf(f,"\tfstore %d\n",var_index);
            fprintf(f,"\ti2f\n");
            fprintf(f,"\tfload %d\n",var_index);
            fprintf(f,"\tfdiv\n");
            $$.t=1;
        }
        $$.v=$1.v/$3.v;
    }
}
| mul_expr '%' term {

    if(($1.t==1)||($3.t==1)) {
        printf("<ERROR>float number should't involve into mod operation(line :%d)\n",error_line);
        error=1;
    } else {

        fprintf(f,"\tirem\n");
        int temp1,temp2;
        temp1=$1.v;
        temp2=$3.v;
        $$.v=temp1%temp2;
        $$.t=0;
    }
}
;
add_expr
:
mul_expr {$$.v=$1.v; $$.t=$1.t;}
| add_expr '+' mul_expr {

    if(($1.t==1)&&($3.t==1)) { // float + float
        fprintf(f,"\tfadd\n");
        $$.t=1;
    } else if(($1.t==1)&&($3.t==0)) { // float + int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfadd\n");
        $$.t=1;
    } else if(($1.t==0)&&($3.t==1)) { // int + float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfadd\n");
        $$.t=1;
    } else if(($1.t==0)&&($3.t==0)) { // int + int
        fprintf(f,"\tiadd\n");
        $$.t=0;
    }
    $$.v=$1.v+$3.v;
}
| add_expr '-' mul_expr {

    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
        $$.t=1;
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
        $$.t=1;
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
        $$.t=1;
    } else if(($1.t==0)&&($3.t==0)) { // int - int
        fprintf(f,"\tisub\n");
        $$.t=0;
    }
    $$.v=$1.v-$3.v;
}
;
relational_expr
:
add_expr	{$$.v=$1.v; $$.t=$1.t;}
| relational_expr '<' add_expr {
    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==0)) {
        fprintf(f,"\tisub\n");
    }
    fprintf(f,"\tifge Label_%d\n",label_index);
    stack[stack_index++]=label_index;
    label_index++;
    if($1.v<$3.v) {
        $$.v=1;

    } else {
        $$.v=-1;

    }
}
| relational_expr '>' add_expr {
    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==0)) {
        fprintf(f,"\tisub\n");
    }
    fprintf(f,"\tifle Label_%d\n",label_index);
    stack[stack_index++]=label_index;
    label_index++;
    if($1.v>$3.v) {
        $$.v=1;
    } else {
        $$.v=-1;
    }
}
| relational_expr T_LE add_expr {
    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==0)) {
        fprintf(f,"\tisub\n");
    }
    fprintf(f,"\tifgt Label_%d\n",label_index);
    stack[stack_index++]=label_index;
    label_index++;
    if($1.v<=$3.v) {
        $$.v=1;
    } else {
        $$.v=-1;
    }
}
| relational_expr T_GE add_expr {
    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==0)) {
        fprintf(f,"\tisub\n");
    }
    fprintf(f,"\tiflt Label_%d\n",label_index);
    stack[stack_index++]=label_index;
    label_index++;
    if($1.v>=$3.v) {
        $$.v=1;

    } else {
        $$.v=-1;
    }
}
;
equal_expr
:
relational_expr	{$$.v=$1.v; $$.t=$1.t;}
| equal_expr T_EQ relational_expr {
    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==0)) {
        fprintf(f,"\tisub\n");
    }
    fprintf(f,"\tifne Label_%d\n",label_index);
    stack[stack_index++]=label_index;
    label_index++;
    if($1.v==$3.v) {
        $$.v=1;
    } else {
        $$.v=-1;
    }
}
| equal_expr T_NE relational_expr {
    if(($1.t==1)&&($3.t==1)) { // float - float
        fprintf(f,"\tfsub\n");
    } else if(($1.t==1)&&($3.t==0)) { // float - int
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==1)) { // int - float
        fprintf(f,"\tfstore %d\n",var_index);
        fprintf(f,"\ti2f\n");
        fprintf(f,"\tfload %d\n",var_index);
        fprintf(f,"\tfsub\n");
    } else if(($1.t==0)&&($3.t==0)) {
        fprintf(f,"\tisub\n");
    }
    fprintf(f,"\tifeq Label_%d\n",label_index);
    stack[stack_index++]=label_index;
    label_index++;
    if($1.v!=$3.v) {
        $$.v=1;
    } else {
        $$.v=-1;
    }
}
;
and_expr
:
equal_expr	{$$.v=$1.v; $$.t=$1.t;}
| and_expr T_AND equal_expr {
    if($1.v&&$3.v)
        $$.v=1;
    else
        $$.v=-1;
}
;
or_expr
:
and_expr	{$$.v=$1.v; $$.t=$1.t;}
| or_expr T_OR and_expr {
    if($1.v||$3.v)
        $$.v=1;
    else
        $$.v=-1;

}
;
assign_op
:
T_ASSIGN {$$=0;}
| T_AbMUL {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(left_id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0)
                fprintf(f,"\tiload %d\n",i);
            else if(strcmp(table[i].type,"float32")==0)
                fprintf(f,"\tfload %d\n",i);
        }
    }
    $$=1;
}
| T_AbDIV  {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(left_id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0)
                fprintf(f,"\tiload %d\n",i);
            else if(strcmp(table[i].type,"float32")==0)
                fprintf(f,"\tfload %d\n",i);
        }
    }
    $$=2;
}
| T_AbMOD {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(left_id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0)
                fprintf(f,"\tiload %d\n",i);
            else if(strcmp(table[i].type,"float32")==0)
                fprintf(f,"\tfload %d\n",i);
        }
    }
    $$=3;
}
| T_AbADD {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(left_id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0)
                fprintf(f,"\tiload %d\n",i);
            else if(strcmp(table[i].type,"float32")==0)
                fprintf(f,"\tfload %d\n",i);
        }
    }
    $$=4;
}
| T_AbMIN {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(left_id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0)
                fprintf(f,"\tiload %d\n",i);
            else if(strcmp(table[i].type,"float32")==0)
                fprintf(f,"\tfload %d\n",i);
        }
    }
    $$=5;
}
;
assign_expr
:
or_expr	{$$.v=$1.v; $$.t=$1.t;}
| T_IDENTIFIER assign_op assign_expr {
    int i,flag=0;
    for(i=0; i<table_index; i++) {
        if(strcmp(left_id_name,table[i].id)==0) {
            flag=1;
            if($2==0) {
                if(strcmp(table[i].type,"int")==0) {
                    fprintf(f,"\tistore %d\n",i);
                    table[i].i_data=$3.v;

                } else if(strcmp(table[i].type,"float32")==0) {
                    fprintf(f,"\tfstore %d\n",i);
                    table[i].f_data=$3.v;
                }
            } else if($2==1) {
                if(strcmp(table[i].type,"int")==0) {
                    fprintf(f,"\timul\n");
                    fprintf(f,"\tistore %d\n",i);
                    table[i].i_data*=$3.v;

                } else if(strcmp(table[i].type,"float32")==0) {

                    if($3.t==1)
                        fprintf(f,"\tfmul\n");
                    else {
                        fprintf(f,"\ti2f\n");
                        fprintf(f,"\tfmul\n");
                    }
                    fprintf(f,"\tfstore %d\n",i);
                    table[i].f_data*=$3.v;
                }
            } else if($2==2) {
                int tmp=$3.v;
                if(tmp==0) {
                    printf("<ERROR>Divide by 0 (line :%d)\n",error_line);
                    error=1;
                }
                if(strcmp(table[i].type,"int")==0) {
                    fprintf(f,"\tidiv\n");
                    fprintf(f,"\tistore %d\n",i);

                    table[i].i_data/=$3.v;

                } else if(strcmp(table[i].type,"float32")==0) {

                    if($3.t==1)
                        fprintf(f,"\tfdiv\n");
                    else {
                        fprintf(f,"\ti2f\n");
                        fprintf(f,"\tfdiv\n");
                    }
                    fprintf(f,"\tfstore %d\n",i);
                    table[i].f_data/=$3.v;
                }
            } else if($2==3) {
                if(strcmp(table[i].type,"int")==0) {
                    if($3.t==1) {
                        printf("<ERROR>float number should't involve into mod operation(line :%d)\n",error_line);
                        error=1;
                    } else {

                        fprintf(f,"\tirem\n");
                        fprintf(f,"\tistore %d\n",i);
                        int temp=$3.v;
                        table[i].i_data%=temp;
                    }
                } else if(strcmp(table[i].type,"float32")==0) {
                    //table[i].f_data%=$3;
                    printf("<ERROR>float number should't involve into mod operation(line :%d)\n",error_line);
                    error=1;
                }
            } else if($2==4) {
                if(strcmp(table[i].type,"int")==0) {
                    fprintf(f,"\tiadd\n");
                    fprintf(f,"\tistore %d\n",i);
                    table[i].i_data+=$3.v;
                } else if(strcmp(table[i].type,"float32")==0) {
                    if($3.t==1)
                        fprintf(f,"\tfadd\n");
                    else {
                        fprintf(f,"\ti2f\n");
                        fprintf(f,"\tfadd\n");
                    }
                    fprintf(f,"\tfstore %d\n",i);
                    table[i].f_data+=$3.v;
                }
            } else if($2==5) {
                if(strcmp(table[i].type,"int")==0) {
                    fprintf(f,"\tisub\n");
                    fprintf(f,"\tistore %d\n",i);
                    table[i].i_data-=$3.v;
                } else if(strcmp(table[i].type,"float32")==0) {
                    if($3.t==1)
                        fprintf(f,"\tfsub\n");
                    else {
                        fprintf(f,"\ti2f\n");
                        fprintf(f,"\tfsub\n");
                    }
                    fprintf(f,"\tfstore %d\n",i);
                    table[i].f_data-=$3.v;
                }
            }
        }

    }
    if(flag==0) {
        printf("<ERROR>Undeclared variables (line : %d)\n",error_line);
        error=1;
    }
}
| T_IDENTIFIER T_INC {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0) {
                fprintf(f,"\tiload %d\n",i);
                fprintf(f,"\tldc 1\n");
                fprintf(f,"\tiadd\n");
                fprintf(f,"\tistore %d\n",i);
                table[i].i_data++;

            } else if(strcmp(table[i].type,"float32")==0) {
                fprintf(f,"\tfload %d\n",i);
                fprintf(f,"\tldc 1.000000\n");
                fprintf(f,"\tfadd\n");
                fprintf(f,"\tfstore %d\n",i);
                table[i].f_data=table[i].f_data+1;
            }

        }

    }
}
| T_IDENTIFIER T_DEC {
    int i;
    for(i=0; i<table_index; i++) {
        if(strcmp(id_name,table[i].id)==0) {
            if(strcmp(table[i].type,"int")==0) {
                fprintf(f,"\tiload %d\n",i);
                fprintf(f,"\tldc 1\n");
                fprintf(f,"\tisub\n");
                fprintf(f,"\tistore %d\n",i);
                table[i].i_data--;

            } else if(strcmp(table[i].type,"float32")==0) {
                fprintf(f,"\tfload %d\n",i);
                fprintf(f,"\tldc 1.000000\n");
                fprintf(f,"\tfsub\n");
                fprintf(f,"\tfstore %d\n",i);
                table[i].f_data=table[i].f_data-1;
            }

        }
    }
}
;
condition_stat
:
T_IF '(' assign_expr ')' stat {fprintf(f,"\tgoto EXIT_%d\n",exit_index); fprintf(f,"Label_%d:\n",stack[--stack_index]); } T_ELSE stat {fprintf(f,"EXIT_%d:\n",exit_index++);}
| T_IF '(' assign_expr ')' stat {fprintf(f,"Label_%d:\n",stack[--stack_index]);} %prec then
;


declaration
:
T_VAR T_IDENTIFIER type {
    int i,flag=0;
    for(i=0; i<table_index; i++)
        if((strcmp(var_id_name,table[i].id)==0)&&(table[i].scope_depth==scope_index)) {
            printf("<ERROR>Redefined variables (line : %d)\n",error_line);
            error=1;
            flag=1;
        }
    if(flag==0)
        insert_symbol(var_id_name,$3,9999,9999);

    if(strcmp($3,"int")==0) {
        fprintf(f,"\tldc 0\n");
        fprintf(f,"\tistore %d\n",var_index++);
    }
    if(strcmp($3,"float32")==0) {
        fprintf(f,"\tldc 0.000000\n");
        fprintf(f,"\tfstore %d\n",var_index++);
    }
}

| T_VAR T_IDENTIFIER type T_ASSIGN assign_expr {
    if(table_exist==0)
        create_symbol();
    table_exist++;

    int i,flag=0;
    for(i=0; i<table_index; i++)
        if((strcmp(var_id_name,table[i].id)==0)&&(table[i].scope_depth==scope_index)) {
            printf("<ERROR>Redefined variables (line : %d)\n",error_line);
            error=1;
            flag=1;
        }
    if(flag==0) {
        int temp=$5.v;
        if(strcmp($3,"int")==0) {
            insert_symbol(var_id_name,$3,temp,9999);
            fprintf(f,"\tistore %d\n",var_index++);
        } else if(strcmp($3,"float32")==0) {
            insert_symbol(var_id_name,$3,9999,$5.v);
            fprintf(f,"\tfstore %d\n",var_index++);
        }
    }
}
;

iteration_stat
:
T_FOR {fprintf(f,"While_Label_%d:\n",for_index); for_stack[for_stack_index++]=for_index; for_index++;} '(' or_expr ')' stat {fprintf(f,"\tgoto While_Label_%d\n",for_stack[--for_stack_index]); fprintf(f,"Label_%d:\n",stack[--stack_index]);}
//| T_FOR assign_expr {fprintf(f,"For_Label_%d:\n",for_index);} or_expr {fprintf(f,"\tgoto stat_Label_%d\n",for_stat_index);fprintf(f,"i_Label_%d:\n",for_i_index);} assign_expr {fprintf(f,"\tgoto For_Label_%d\n",for_index++);fprintf(f,"stat_Label_%d:\n",for_stat_index++);} stat {fprintf(f,"\tgoto i_Label_%d\n",for_i_index++);fprintf(f,"Label_%d:\n",label_index++);}
;

print_stat
:
T_PRINT term {
    fprintf(f,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
    fprintf(f,"\tswap\n");
    if($2.t==0)
        fprintf(f,"\tinvokevirtual java/io/PrintStream/print(I)V\n");
    else if($2.t==1)
        fprintf(f,"\tinvokevirtual java/io/PrintStream/print(F)V\n");
}
| T_PRINTLN term {
    fprintf(f,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
    fprintf(f,"\tswap\n");
    if($2.t==0)
        fprintf(f,"\tinvokevirtual java/io/PrintStream/println(I)V\n");
    else if($2.t==1)
        fprintf(f,"\tinvokevirtual java/io/PrintStream/println(F)V\n");

    /*int temp=$2;
    if(($2-temp)>0)
    printf("println : %lf\n",$2);
    else
    { printf("println : %d\n",temp);}*/

}
| T_PRINT '(' T_STRING ')' {
    int i;
    fprintf(f,"\tldc %c",'"');
    for(i=1; i<=len-2; i++)
        fprintf(f,"%c",str[i]);
    fprintf(f,"%c\n",'"');
    fprintf(f,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
    fprintf(f,"\tswap\n");
    fprintf(f,"\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");

    /*printf("print : ");
    for(i=1;i<=len-2;i++)
    printf("%c",str[i]);
    printf("\n");*/
}
| T_PRINTLN '(' T_STRING ')' {
    int i;
    fprintf(f,"\tldc %c",'"');
    for(i=1; i<=len-2; i++)
        fprintf(f,"%c",str[i]);
    fprintf(f,"%c\n",'"');
    fprintf(f,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
    fprintf(f,"\tswap\n");
    fprintf(f,"\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
    /*printf("println : ");
    for(i=1;i<=len-2;i++)
    printf("%c",str[i]);
    printf("\n");*/
}
;

stat
:
assign_expr
| condition_stat
| iteration_stat
| compound_stat
| print_stat
;

block_item
:
stat
| declaration
;
block_item_list
:
block_item
| block_item_list block_item
;
compound_stat
:
left_block right_block
| left_block block_item_list right_block
;
program
:
block_item_list '\n'
| '\n'
;

%%

/* C code section */
int yyerror(char *s) {

    fprintf(stderr, "<ERROR>%s (line : %d)\n",s, lines+1);
    error=1;
    return 0;
}


int main(int argc, char** argv) {
    yylineno = 0;
    f=fopen("Output.j","w");
    fprintf(f,".class public main\n");
    fprintf(f,".super java/lang/Object\n");
    fprintf(f,".method public static main([Ljava/lang/String;)V\n");
    fprintf(f,".limit stack 10\n");
    fprintf(f,".limit locals 10\n");
    yyparse();
    fprintf(f,"\treturn\n");
    fprintf(f,".end method\n");
    fclose(f);
    if(error==1)
        remove("Output.j");
    //printf("\n\nTotal lines : %d\n",lines);

    // dump_symbol();
    return 0;
}

void create_symbol() {
}
void insert_symbol(char* var_name,char* type,int i_data,double f_data) {
    strcpy(table[table_index].id,var_name);
    strcpy(table[table_index].type,type);

    if(strcmp(table[table_index].type,"int")==0)
        table[table_index].i_data=i_data;
    else if(strcmp(table[table_index].type,"float32")==0)
        table[table_index].f_data=f_data;
    table[table_index].scope_depth=scope_index;
    table_index++;
}
int lookup_symbol(char var_name[20]) { //enter the variable'name and return it's index.
    int i=0;
    for(i=0; i<table_index; i++) {
        if(strcmp(var_name,table[i].id)==0) {
            return i;  // var index
        }

    }
    return -1;  // var not found
}
void dump_symbol() {
    if(table_index==0) {
        printf("\nNo symbol in the table!\n\n");
        return;
    }
    printf("\nThe symbol table dump:\nIndex\tId\tType\tData\tScope_depth\n");
    int i;
    for(i=0; i<table_index; i++) {
        //printf("i:%d\ttype:%s||\n",i,table[i].type);
        if(strcmp(table[i].type,"int")==0) {
            printf("%d\t%s\t%s\t",i,table[i].id,table[i].type);
            if(table[i].i_data!=9999)
                printf("%d\t%d\n",table[i].i_data,table[i].scope_depth);
            else
                printf("\t%d\n",table[i].scope_depth);
        } else if(strcmp(table[i].type,"float32")==0) {
            printf("%d\t%s\t%s\t",i,table[i].id,table[i].type);
            if(table[i].f_data!=9999)
                printf("%f\t%d\n",table[i].f_data,table[i].scope_depth);
            else
                printf("\t%d\n",table[i].scope_depth);
        }
    }
}


