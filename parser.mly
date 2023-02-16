(* Starter parser.mly code from the OCaml slides *)

%{ open Ast %}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA (* strucutral tokens *)
%token PLUS MINUS TIMES DIVIDE ASSIGN (* type operators *)
%token AND OR NOT (* logical operator *)
%token GT LT EQ GEQ LEQ NEQ (* comparisons *)
%token IF ELSEIF ELSE WHILE FOR RETURN (* statements *)
%token <int> LITERAL
%token <bool> BLIT
%token <string> ID FLIT
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

typ:
    INT   { Int    }
  | BOOL  { Bool   }
  | FLOAT { Float  }
  | VOID  { Void   }
  | EXEC  { Exec   }
  | STR   { String }
  | LIST  { List }

path:
  LITERAL           { Lit($1) }
  | VARIABLE        { Var($1)}

args:
  list              { List($1) }

list:
    LBRACKET cont_list   { List($2) }
    | LBRACKET RBRACKET  { List() }         

cont_list:
    VARIABLE COMMA cont_list    { }
    | LITERAL COMMA cont_list
    | VARIABLE RBRACKET
    | LITERAL RBRACKET

exec:
  simple_exec       { $1 }
  | exec PLUS exec  { Binop($1, Concat, $3) }
  | exec TIMES exec { Binop($1, Seq, $3) }
  | exec PIPE exec  { Binop($1, Pipe, $3) }

simple_exec:
  path args         { Exec($1, $2) }

output:
  LITERAL           { Lit($1) }

exit_code:
  LITERAL           { Lit($1) }

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
  | expr %prec NOT            { Unop(Neg, $2)      }
  | NOT expr                  { Unop(Not, $2)          }
  | ID ASSIGN expr            { Assign($1, $3)         }
  | ID LPAREN args_opt RPAREN { Call($1, $3)  }
  | LPAREN expr RPAREN        { $2                   }
  | VARIABLE ASSIGN expr      { Asn($1, $3) }
  | VARIABLE                  { Var($1) }
  | exec EXITCODE             { Uop($1, exit_code) }
  | RUN exec                  { Uop($1, run) }
  | exec                      { $1 }
