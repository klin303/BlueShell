(* scanner.mll *)
(* BlueShell *)
(* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom *)

{ open Parser } (* Header which opens Parser file *)

let digit = ['0' - '9']
let digits = digit+

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
| "'"      { SNGLQUOTE }
| '"'      { DBLQUOTE }
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
| "else if" { ELSEIF }
| "else"   { ELSE }
| "for"    { FOR }
| "while"  { WHILE }
| "return" { RETURN }
| "print"   { PRINT }
| "int"    { INT }      (* types *)
| "bool"   { BOOL }
| "float"  { FLOAT }
| "void"    { VOID }
| "exec"    { EXEC }
| "char"    { CHAR }
| "string"  { STRING }
| "list"    { LIST }
| "true"    { BLIT(true) }
| "false"   { BLIT(false) }
| "|"       { PIPE }      (* executable operators *)
| "./"      { RUN }
| "?"       { EXITCODE }
| '['       { LBRACKET }  (* list operators *)
| ']'       { RBRACKET }
| "::"      { CONS }
| "len"     { LENGTH }
| digits as lxm { LITERAL(int_of_string lxm) }
| digits '.'  digit* as lxm { FLIT(lxm) }
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9' '_']* + as lit { ID(lit) }
| eof { EOF }
| _ as char { raise (Failure("illegal character " ^ Char.escaped char)) }

and multiline_comment = parse
  "*/" { tokenize lexbuf }
  | _ { comment lexbuf }

and singleline_comment = parse
  "\n"{ tokenize lexbuf }
  | _ { singleline_comment }