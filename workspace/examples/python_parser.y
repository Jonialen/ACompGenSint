%{

#include <stdio.h>
#include <stdlib.h>

extern int line;       /* current line, tracked in the lexer */
extern int yylex();
void yyerror(const char* msg);
%}

%token DEF RETURN IF ELSE
%token ID NUMBER
%token PLUS MINUS TIMES DIVIDE MOD POWER ASSIGN
%token LPAREN RPAREN LBRACKET RBRACKET COMMA COLON
%token NEWLINE

%left PLUS MINUS
%left TIMES DIVIDE MOD
%right POWER

%%

program
    : statement_list
    ;

statement_list
    : statement
    | statement_list statement
    ;

statement
    : ID ASSIGN expr NEWLINE   { printf("  [PARSE] Assignment\n"); }
    | expr NEWLINE             { printf("  [PARSE] Expression statement\n"); }
    | func_def
    | NEWLINE                  { /* blank line - ignore */ }
    ;

func_def
    : DEF ID LPAREN params RPAREN COLON NEWLINE
        { printf("  [PARSE] Function definition\n"); }
    ;

params
    : /* empty */
    | param_list
    ;

param_list
    : ID
    | param_list COMMA ID
    ;

expr
    : expr PLUS  term          { printf("  [PARSE] Addition\n"); }
    | expr MINUS term          { printf("  [PARSE] Subtraction\n"); }
    | term
    ;

term
    : term TIMES  power        { printf("  [PARSE] Multiplication\n"); }
    | term DIVIDE power        { printf("  [PARSE] Division\n"); }
    | term MOD    power        { printf("  [PARSE] Modulo\n"); }
    | power
    ;

power
    : atom POWER power         { printf("  [PARSE] Exponentiation\n"); }
    | atom
    ;

atom
    : ID
    | NUMBER
    | LPAREN expr RPAREN
    | list
    ;

list
    : LBRACKET RBRACKET              { printf("  [PARSE] Empty list\n"); }
    | LBRACKET expr_list RBRACKET    { printf("  [PARSE] List\n"); }
    ;

expr_list
    : expr
    | expr_list COMMA expr
    ;

%%

/* -- Support functions --------------------------------------------------- */

void yyerror(const char* msg) {
    fprintf(stderr, "\n  [SYNTAX ERROR] %s at line %d\n", msg, line);
}

int main() {
    printf("=== Python Parser (Flex + YACC) ===\n\n");
    int result = yyparse();
    if (result == 0) {
        printf("\n[OK] Input parsed successfully - no syntax errors.\n");
    } else {
        printf("\n[FAIL] Parsing stopped due to syntax error(s).\n");
    }
    return result;
}
