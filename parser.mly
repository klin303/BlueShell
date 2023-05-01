/* parser.mly */
/* BlueShell */
/* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom */

%{ open Ast %}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA LBRACKET RBRACKET AMPERSAND LANGLE
RANGLE OF ARROW/* structural tokens */
%token PLUS MINUS TIMES DIVIDE ASSIGN /* type operators */
%token AND OR NOT /* logical operators */
%token EQ GEQ LEQ NEQ /* comparisons */
%token IF ELSE WHILE FOR RETURN /* statements */
%token INT BOOL FLOAT VOID EXEC CHR STR LIST FUNCTION /* types */
%token <int> LITERAL
%token <bool> BLIT
%token <string> ID FLIT CHAR STRING
%token EOF
%token PIPE RUN EXITCODE PATH WITHARGS /* executable operators */
%token CONS LEN /* list operators */

%start program
%type <Ast.program> program

/* precedence */
%nonassoc ID
%nonassoc NOELSE
%nonassoc ELSE
%left EXITCODE
%left RUN
%left PIPE
%right ASSIGN
%left OR
%left AND
%left EQ NEQ
%left LANGLE RANGLE
%left LEQ GEQ
%left PLUS MINUS
%left TIMES DIVIDE
%right NOT
%right LEN
%left CONS
%right LBRACKET LPAREN
%right PATH

%%

program:
  decls EOF         { $1 }

decls:
   /* nothing */    { ([], []) }
 | decls stmt       { let (sdecls, fdecls) = $1 in (($2 :: sdecls), fdecls) }
 | decls fdecl      { let (sdecls, fdecls) = $1 in (sdecls, ($2 :: fdecls)) }

typ:
    INT             { Int      }
  | BOOL            { Bool     }
  | FLOAT           { Float    }
  | VOID            { Void     }
  | EXEC            { Exec     }
  | CHR             { Char     }
  | STR             { String   }
  | LIST OF typ     { List_type($3) }
  | FUNCTION formals_type      { Function($2) }

formals_type:
  LPAREN cont_formal_list { $2 }

cont_formal_list:
  typ RPAREN {([], $1)}
| typ ARROW cont_formal_list {( $1 :: (fst $3), snd $3)}
/* Executables */
exec:
  LANGLE expr WITHARGS expr RANGLE  { Exec($2, $4) }
| LANGLE expr RANGLE  { Exec($2, List([])) }

/* Lists */
list:
  LBRACKET cont_list      { List($2) }
  | LBRACKET RBRACKET     { List([]) }

cont_list:
  expr COMMA cont_list    { $1 :: $3 }
  | expr RBRACKET         { [$1] }

index:
  expr LBRACKET expr RBRACKET { Index($1, $3) }

list_cons:
  expr CONS expr          { Binop($1, Cons, $3) }

list_length:
  LEN expr                { PreUnop(Length, $2) }

/* Functions */
fdecl:
  typ ID LPAREN formals_opt RPAREN LBRACE stmt_list RBRACE
     { {  typ = $1;
	        fname = $2;
	        formals = List.rev $4;
	        body = List.rev $7; } }

formals_opt:
    /* nothing */             { [] }
  | formal_list               { $1 }

formal_list:
    typ ID                    { [($1,$2)]     }
  | formal_list COMMA typ ID  { ($3,$4) :: $1 }

vdecl:
  typ ID                      { ($1, $2) }

stmt_list:
     /* nothing */            { [] }
  | stmt_list stmt            { $2 :: $1 }

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

/* Expressions */
expr:
    LITERAL                   { Literal($1)            }
  | FLIT	                    { Fliteral($1)           }
  | BLIT                      { BoolLit($1)            }
  | ID                        { Id($1)                 }
  | CHAR                      { Char($1)               }
  | STRING                    { String($1)             }
  | expr PLUS   expr          { Binop($1, Add,   $3)   }
  | expr MINUS  expr          { Binop($1, Sub,   $3)   }
  | expr TIMES  expr          { Binop($1, Mult,  $3)   }
  | expr DIVIDE expr          { Binop($1, Div,   $3)   }
  | expr EQ     expr          { Binop($1, Equal, $3)   }
  | expr NEQ    expr          { Binop($1, Neq,   $3)   }
  | expr LANGLE     expr          { Binop($1, Less,  $3)   }
  | expr LEQ    expr          { Binop($1, Leq,   $3)   }
  | expr RANGLE     expr          { Binop($1, Greater, $3) }
  | expr GEQ    expr          { Binop($1, Geq,   $3)   }
  | expr AND    expr          { Binop($1, And,   $3)   }
  | expr OR     expr          { Binop($1, Or,    $3)   }
  | expr PIPE   expr          { Binop($1, Pipe, $3)    }
  | MINUS expr %prec NOT      { PreUnop(Neg, $2)       }
  | NOT expr                  { PreUnop(Not, $2)       }
  | expr ASSIGN expr          { Binop($1, ExprAssign, $3) }
  | ID ASSIGN expr            { Assign($1, $3)         }
  | vdecl                     { Bind($1)               }
  | ID LPAREN args_opt RPAREN { Call($1, $3)           }
  | LPAREN expr RPAREN        { $2                     }
  | expr EXITCODE             { PostUnop($1, ExitCode) }
  | index                     { $1                     }
  | expr PATH                 { PreUnop(Path, $1)      }
  | RUN expr                  { PreUnop(Run, $2)       }
  | exec                      { $1                     }
  | list                      { $1                     }
  | list_cons                 { $1                     }
  | list_length               { $1                     }

args_opt:
    /* nothing */             { []                     }
  | args_list                 { List.rev $1            }

args_list:
    expr                      { [$1]                   }
  | args_list COMMA expr      { $3 :: $1               }