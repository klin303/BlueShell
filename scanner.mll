(* Starter code for scanner.mll from OCaml slides *)

{ open Parser } (* Header which opens Parser file *)

rule tokenize = parse
  [' ' '\t' '\r' '\n'] { tokenize lexbuf }
| "/*" { multiline_comment lexbuf } (* comments *)
| "//" { singleline_comment lexbuf }
| '('      { LPAREN }         (* structural tokens *)
| ')'      { RPAREN }
| '{'      { LBRACE }
| '}'      { RBRACE }
| ';'      { SEMI }
| ','      { COMMA }
| '='       { ASSIGN }
| '+'      { PLUS }       (* arithmetic symbols *)
| '-'      { MINUS }
| '*'      { TIMES }
| '/'      { DIVIDE }
| "and"    { AND }        (* boolean operators *)
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
| "if"      { IF }            (* stmts *)
| "else if" {ELSEIF}
| "else"   { ELSE }
| "for"    { FOR }
| "while"  { WHILE }
| "return" { RETURN }
| "int"    { INT }      (* types *)
| "bool"   { BOOL }
| "float"  { FLOAT }
| "exec"    { EXEC }
| "|"       { PIPE }
| "./"      { RUN }
| "?"       { EXITCODE }
| '['       { LBRACKET }  (* list operators *)
| ']'       { RBRACKET }
| "::"      { CONS }
| "@"       { APPEND }
| ['0'-'9']+ as lit { LITERAL(int_of_string lit) }
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9' '_']* + as lit { VARIABLE(lit) }
| eof { EOF }
| _ as char { raise (Failure("illegal character " ^ Char.escaped char)) }

and multiline_comment = parse
  "*/" { tokenize lexbuf }
  | _ { comment lexbuf }

and singleline_comment = parse
  "\n"{ tokenize lexbuf }
  | _ { singleline_comment }