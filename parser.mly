/* parser.mly */
/* BlueShell */
/* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom */

%{ open Ast %}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA LBRACKET RBRACKET SNGLQUOTE DBLQUOTE /* strucutral tokens */
%token PLUS MINUS TIMES DIVIDE ASSIGN /* type operators */
%token AND OR NOT /* logical operator */
%token GT LT EQ GEQ LEQ NEQ /* comparisons */
%token IF ELSE WHILE FOR RETURN /* statements */
%token INT BOOL FLOAT VOID EXEC CHAR STRING LIST /* types */
%token <int> LITERAL
%token <bool> BLIT
%token <string> ID FLIT CHAR STRING
%token EOF
%token PIPE RUN EXITCODE PATH /* executable operators */
%token CONS INDEX LEN /* list operators */

%start program
%type <Ast.program> program

/* precedence */
%nonassoc NOELSE
%left EXITCODE
%right PATH RUN
%left PIPE
%nonassoc ELSE
%right ASSIGN
%left OR
%left AND
%left EQ NEQ
%left LT GT LEQ GEQ
%left PLUS MINUS
%left TIMES DIVIDE
%right NOT
%right LEN
%right INDEX
%left CONS

%%

program:
  decls EOF { $1 }

decls:
   /* nothing */ { ([], [])               }
 | decls vdecl { (($2 :: fst $1), snd $1) }
 | decls fdecl { (fst $1, ($2 :: snd $1)) }

typ:
    INT   { Int    }
  | BOOL  { Bool   }
  | FLOAT { Float  }
  | VOID  { Void   }
  | EXEC  { Exec   }
  | CHAR  { Char }
  | STRING   { String }
  | LIST  { List }
  | fdecl  { Function }

/* Executables */
exec:
  simple_exec       { $1 }
  | complex_exec      { $1 }

complex_exec: 
  exec PLUS exec    { Binop($1, Add, $3) }
  | exec TIMES exec { Binop($1, Mult, $3) }
  | exec PIPE exec  { Binop($1, Pipe, $3) }

simple_exec:
  path earg_opt         { Exec($1, $2) }

path:
  expr              { $1 }

earg_opt:
    /* nothing */ { [] }
  | eargs_list  { List.rev $1 }

eargs_list:
    expr                    { [$1] }
  | eargs_list expr { $2 :: $1 }

earg_index:
    eargs_list LBRACKET expr RBRACKET { Binop($1, Index, $3) }

/* Lists */
list:
    LBRACKET cont_list   { List($2) }
    | LBRACKET RBRACKET  { List(()) }

cont_list:
    expr COMMA cont_list    { ($1, $3) }
    | expr RBRACKET         { ($1, ()) }

list_index:
    list LBRACKET expr RBRACKET { Binop($1, Index, $3) }

list_cons:
    expr CONS list { Binop($1, Cons, $3) }

list_length:
    LEN list { PreUnop(Length, $2) }

/* Functions */
fdecl:
   typ ID LPAREN formals_opt RPAREN LBRACE body_list RBRACE
     { { typ = $1;
	 fname = $2;
	 formals = List.rev $4;
	 body = List.rev $7; } }

formals_opt:
    /* nothing */ { [] }
  | formal_list   { $1 }

formal_list:
    typ ID                   { [($1,$2)]     }
  | formal_list COMMA typ ID { ($3,$4) :: $1 }

vdecl_list:
    /* nothing */    { [] }
  | vdecl_list vdecl { $2 :: $1 }

vdecl:
   typ ID SEMI { ($1, $2) }

body_list:
  /* nothing */ { [] }
| body_list body { $2 :: $1 }

body:
  vdecl { $1 }
  | stmt { $1 }

stmt_list:
    /* nothing */  { [] }
  | stmt_list stmt { $2 :: $1 }

stmt:
    expr SEMI                               { Expr $1               }
  | RETURN expr_opt SEMI                    { Return $2             }
  | LBRACE stmt_list RBRACE                 { Block(List.rev $2)    }
  | IF LPAREN expr RPAREN stmt %prec NOELSE { If($3, $5, Block([])) }
  | IF LPAREN expr RPAREN stmt ELSE stmt    { If($3, $5, $7)        }
  | FOR LPAREN expr_opt SEMI expr SEMI expr_opt RPAREN stmt
                                            { For($3, $5, $7, $9)   }
  | WHILE LPAREN expr RPAREN stmt           { While($3, $5)         }

expr_opt:
    /* nothing */ { Noexpr }
  | expr          { $1 }

args_opt:
    /* nothing */ { [] }
  | args_list  { List.rev $1 }

args_list:
    expr                    { [$1] }
  | args_list COMMA expr { $3 :: $1 }

/* Expressions */
full_expr:
  expr EOF { $1 }

expr:
    LITERAL          { Literal($1)            }
  | FLIT	         { Fliteral($1)           }
  | BLIT             { BoolLit($1)            }
  | ID               { Id($1)                 }
  | expr PLUS   expr { Binop($1, Add,   $3)   }
  | expr MINUS  expr { Binop($1, Sub,   $3)   }
  | expr TIMES  expr { Binop($1, Mult,  $3)   }
  | expr DIVIDE expr { Binop($1, Div,   $3)   }
  | expr EQ     expr { Binop($1, Equal, $3)   }
  | expr NEQ    expr { Binop($1, Neq,   $3)   }
  | expr LT     expr          { Binop($1, Less,  $3)   }
  | expr LEQ    expr          { Binop($1, Leq,   $3)   }
  | expr GT     expr          { Binop($1, Greater, $3) }
  | expr GEQ    expr          { Binop($1, Geq,   $3)   }
  | expr AND    expr          { Binop($1, And,   $3)   }
  | expr OR     expr          { Binop($1, Or,    $3)   }
  | MINUS expr %prec NOT      { PreUnop(Neg, $2)          }
  | NOT expr                  { PreUnop(Not, $2)          }
  | ID ASSIGN expr            { Assign($1, $3)         }
  | ID LPAREN args_opt RPAREN { Call($1, $3)  }
  | LPAREN expr RPAREN        { $2                   }
  | exec EXITCODE             { PostUnop($1, Exitcode) }
  | earg_index                     { $1 }
  | PATH exec                 { PreUnop(Path, $2) }
  | RUN exec                  { PreUnop(Run, $2) }
  | exec                      { $1 }
  | list                      { List($1) }
  | list_index                     { $1 }
  | list_cons                      { $1 }
  | list_length                    { $1 }
