type token =
  | SEMI
  | LPAREN
  | RPAREN
  | LBRACE
  | RBRACE
  | COMMA
  | LBRACKET
  | RBRACKET
  | AMP
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE
  | ASSIGN
  | AND
  | OR
  | NOT
  | GT
  | LT
  | EQ
  | GEQ
  | LEQ
  | NEQ
  | IF
  | ELSE
  | WHILE
  | FOR
  | RETURN
  | INT
  | BOOL
  | FLOAT
  | VOID
  | EXEC
  | CHR
  | STR
  | LIST
  | FUNCTION
  | LITERAL of (int)
  | BLIT of (bool)
  | ID of (string)
  | FLIT of (string)
  | CHAR of (string)
  | STRING of (string)
  | EOF
  | PIPE
  | RUN
  | EXITCODE
  | PATH
  | CONS
  | LEN

val program :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Ast.program
