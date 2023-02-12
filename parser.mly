/* Starter parser.mly code from the OCaml slides */

%{ open Ast %}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA (* strucutral tokens *)
%token PLUS MINUS TIMES DIVIDE ASSIGN (* type operators *)
%token AND OR NOT (* logical operator *)
%token GT LT EQ GEQ LEQ NEQ (* comparisons *)
%token <int> LITERAL
%token <string> VARIABLE
%token EOF

(* precedence *)
%left SEQUENCE
%right ASSIGN
%left PLUS MINUS /* left means go left to right */
%left TIMES DIVIDE /* lower the line, higher the precedence */

%start full_expr
%type <Ast.expr> full_expr

%%

full_expr:
  expr EOF { $1 }

expr:
  expr PLUS   expr     { Binop($1, Add, $3) }
| expr MINUS  expr     { Binop($1, Sub, $3) }
| expr TIMES  expr     { Binop($1, Mul, $3) }
| expr DIVIDE expr     { Binop($1, Div, $3) }
| expr SEQUENCE expr   { Seq($1, $3) }
| VARIABLE ASSIGN expr { Asn($1, $3) }
| VARIABLE             { Var($1) }
| LITERAL              { Lit($1) }
