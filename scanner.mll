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
| '='       { ASSIGN }
| "if"     { IF }
| "else"   { ELSE }
| "for"    { FOR }
| "while"  { WHILE }
| "return" { RETURN }
| "int"    { INT }
| "bool"   { BOOL }
| "float"  { FLOAT }
| "list"   { LIST }
| ['0'-'9']+ as lit { LITERAL(int_of_string lit) }
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9' '_']* + as lit { VARIABLE(lit) }
| '['       { LBRACKET }
| ']'       { RBRACKET }
| "::"      { CONS }
| "@"       { APPEND }
| eof { EOF }

and multiline_comment = parse
  "*/" { token lexbuf }
  | _ { comment lexbuf }

and singleline_comment = parse
  "\n"{ token lexbuf }
  | _ { singleline_comment }