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
| '\''     { character_of lexbuf }
| '"'      { string_of (Buffer.create 10) lexbuf }
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
| "else"   { ELSE }
| "for"    { FOR }
| "while"  { WHILE }
| "return" { RETURN }
| "int"    { INT }      (* types *)
| "bool"   { BOOL }
| "float"  { FLOAT }
| "void"    { VOID }
| "exec"    { EXEC }
| "char"    { CHR }
| "string"  { STR }
| "list"    { LIST }
| "true"    { BLIT(true) }
| "false"   { BLIT(false) }
| "|"       { PIPE }      (* executable operators *)
| "./"      { RUN }
| "?"       { EXITCODE }
| "$"       { PATH }
| "&"       { AMP }
| '['       { LBRACKET }  (* list operators *)
| ']'       { RBRACKET }
| "::"      { CONS }
| "len"     { LEN }
| digits as lxm { LITERAL(int_of_string lxm) }
| digits '.'  digit* as lxm { FLIT(lxm) }
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9' '_']* + as lit { ID(lit) }
| eof { EOF }
| _ as char { raise (Failure("illegal character " ^ Char.escaped char)) }

and multiline_comment = parse
  "*/" { tokenize lexbuf }
  | _ { multiline_comment lexbuf }

and singleline_comment = parse
  "\n" { tokenize lexbuf }
  | _ { singleline_comment lexbuf }

and character_of = parse
  '\'' { CHAR("") }
  | '\\' '\'' '\'' { CHAR("'") }
  | '\\' 'n' '\'' { CHAR("\n") }
  | [^ '"' '\\'] as single_char '\'' { CHAR(String.make 1 single_char) }
  | _ { raise (Failure("invalid char")) }
  | eof { raise (Failure("read EOF with char open")) }

and string_of buf = parse
  '"' { STRING(Buffer.contents buf) }
  | '\\' 'n' { Buffer.add_char buf '\n'; string_of buf lexbuf }
  | '\\' '"' { Buffer.add_char buf '"'; string_of buf lexbuf }
  | [^ '"' '\\']+ as cont_string { Buffer.add_string buf cont_string; string_of buf lexbuf }
  | _ as char { raise (Failure("illegal character in string" ^ Char.escaped char)) }
  | eof { raise (Failure("read EOF with string open")) }