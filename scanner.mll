(* Starter code for scanner.mll from OCaml slides *)

{ open Parser } (* Header which opens Parser file *)

rule tokenize = parse
  [' ' '\t' '\r' '\n'] { token lexbuf }
| "/*" { multiline_comment lexbuf } (* comments *)
| "//" { singleline_comment lexbuf }
| '('      { LPAREN }         (* structural tokens *)
| ')'      { RPAREN }
| '{'      { LBRACE }
| '}'      { RBRACE }
| ';'      { SEMI }
| ','      { COMMA }
| '+'      { PLUS }
| '-'      { MINUS }
| '*'      { TIMES }
| '/'      { DIVIDE }
| "and"    { AND }
| "&&"     { AND }
| "or"     { OR }
| "||"     { OR }
| "not"    { NOT }
| "!"      { NOT }
| "=="     { EQ }
| "!="     { NEQ }
| ">"      { GT }
| "<"      { LT }
| ">="      { GEQ }
| "<="      { LEQ }
| "if"      { IF }
| '=' { ASSIGN }
| ['0'-'9']+ as lit { LITERAL(int_of_string lit) }
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9' '_']* + as lit { VARIABLE(lit) }
| eof { EOF }

and multiline_comment = parse
  "*/" { token lexbuf }
  | _ { comment lexbuf }

and singleline_comment = parse
  "\n"{ token lexbuf }
  | _ { singleline_comment }