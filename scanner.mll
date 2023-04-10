(* scanner.mll *)
(* BlueShell *)
(* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom *)

{ open Parser } (* Header which opens Parser file *)

let digit = ['0' - '9']
let digits = digit+

(* general token rule *)
rule tokenize = parse
  [' ' '\t' '\r' '\n'] { tokenize lexbuf }
(* comments *)
| "/*"       { multiline_comment lexbuf }
| "//"       { singleline_comment lexbuf }
(* structural tokens *)
| '('        { LPAREN }
| ')'        { RPAREN }
| '{'        { LBRACE }
| '}'        { RBRACE }
| ';'        { SEMI }
| ','        { COMMA }
| '\''       { character_of lexbuf }
| '"'        { string_of (Buffer.create 10) lexbuf }
| "&"        { AMPERSAND }
| "<"        { LANGLE }
| ">"        { RANGLE }
(* arithmetic symbols *)
| '+'        { PLUS }
| '-'        { MINUS }
| '*'        { TIMES }
| '/'        { DIVIDE }
| '='        { ASSIGN }
(* boolean operators *)
| "and"      { AND }
| "&&"       { AND }
| "or"       { OR }
| "||"       { OR }
| "not"      { NOT }
| "!"        { NOT }
| "=="       { EQ }
| "!="       { NEQ }
| ">"        { GT }
| "<"        { LT }
| ">="       { GEQ }
| "<="       { LEQ }
(* stmts *)
| "if"       { IF }
| "else"     { ELSE }
| "for"      { FOR }
| "while"    { WHILE }
| "return"   { RETURN }
(* types *)
| "int"      { INT }
| "bool"     { BOOL }
| "float"    { FLOAT }
| "void"     { VOID }
| "exec"     { EXEC }
| "char"     { CHR }
| "string"   { STR }
| "list"     { LIST }
| "true"     { BLIT(true) }
| "false"    { BLIT(false) }
| "function" { FUNCTION }
(* executable operators *)
| "|"        { PIPE }
| "./"       { RUN }
| "?"        { EXITCODE }
| "$"        { PATH }
| "withargs" { WITHARGS }
(* list operators *)
| '['        { LBRACKET }
| ']'        { RBRACKET }
| "::"       { CONS }
| "len"      { LEN }
| "of"       { OF }
(* first-class function operators *)
| "->"       { ARROW }
| digits as lxm { LITERAL(int_of_string lxm) }
| digits '.'  digit* as lxm { FLIT(lxm) }
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9' '_']* + as lit { ID(lit) }
| eof { EOF }
| _ as char { raise (Failure("illegal character " ^ Char.escaped char)) }

(* multiline comment rule *)
and multiline_comment = parse
  "*/"  { tokenize lexbuf }
  | _   { multiline_comment lexbuf }
  | eof { raise (Failure("did not close multiline comment")) }

(* single line comment rule *)
and singleline_comment = parse
  "\n"  { tokenize lexbuf }
  | eof { EOF }
  | _   { singleline_comment lexbuf }

(* character of rule *)
and character_of = parse
  '\''              { CHAR("")   }
  | '\\' '\'' '\''  { CHAR("'")  }
  | '\\' 'n' '\''   { CHAR("\n") }
  | '\\' 'r' '\''   { CHAR("\r") }
  | '\\' 't' '\''   { CHAR("\t") }
  | '\\' '\\' '\''  { CHAR("\\") }
  | [^ '"' '\\'] as single_char '\'' { CHAR(String.make 1 single_char) }
  | _ { raise (Failure("invalid char")) }
  | eof { raise (Failure("read EOF with char open")) }

(* string of rule *)
and string_of buf = parse
  '"'         {  STRING(Buffer.contents buf) }
  | '\\' 'n'  { Buffer.add_char buf '\n'; string_of buf lexbuf }
  | '\\' '"'  { Buffer.add_char buf '"'; string_of buf lexbuf  }
  | '\\' 'r'  { Buffer.add_char buf '\r'; string_of buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; string_of buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; string_of buf lexbuf }
  | [^ '"' '\\']+ as cont_string { Buffer.add_string buf cont_string; string_of buf lexbuf }
  | _ as char { raise (Failure("illegal character in string" ^ Char.escaped char)) }
  | eof       { raise (Failure("read EOF with string open"))   }