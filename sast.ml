(* Semantically-checked Abstract Syntax Tree and functions for printing it *)

open Ast

type sexpr = typ * sx
and sx = 
    SLiteral of int
  | SFliteral of string
  | SBoolLit of bool
  | SId of string
  | SChar of string
  | SString of string
  | SExec of sexpr * sexpr
  | SIndex of sexpr * sexpr
  | SBinop of sexpr * op * sexpr
  | SPreUnop of uop * sexpr
  | SPostUnop of sexpr * uop
  | SAssign of string * sexpr
  | SCall of string * sexpr list
  | SList of sexpr list
  | SBind of bind
  | SNoexpr

type sstmt = 
  SBlock of sstmt list
  | SExpr of sexpr
  | SReturn of sexpr
  | SIf of sexpr * sstmt * sstmt
  | SFor of sexpr * sexpr * sexpr * sstmt
  | SWhile of sexpr * sstmt

type sfunc_decl = {
  styp : typ;
  sfname : string;
  sformals : bind list;
  sbody : sstmt list;
}

type sprogram = sstmt list * sfunc_decl list

(* Pretty-printing functions *)

let rec string_of_sexpr (t, e) =
  "(" ^ string_of_typ t ^ " : " ^ (match e with
    SLiteral(l) ->     string_of_int l
  | SFliteral(l) ->    l
  | SBoolLit(true) ->  "true"
  | SBoolLit(false) -> "false"
  | SId(s) ->          s
  | SChar(c) ->        "'" ^ c ^ "'"
  | SString(s) ->      "\"" ^ s ^ "\""
  | SExec(e1, e2) ->   
      "<" ^ string_of_sexpr e1 ^ " withargs " ^ string_of_sexpr e2 ^ ">"
  | SBinop(e1, o, e2) ->
      string_of_sexpr e1 ^ " " ^ string_of_op o ^ " " ^ string_of_sexpr e2
  | SPreUnop(o, e) ->  string_of_uop o ^ string_of_sexpr e
  | SPostUnop(e, o) -> string_of_sexpr e ^ string_of_uop o
  | SAssign(v, e) ->   v ^ " = " ^ string_of_sexpr e
  | SCall(f, el) ->
      f ^ "(" ^ String.concat ", " (List.map string_of_sexpr el) ^ ")"
  | SList(l) ->        "[" ^ (String.concat ", " (List.map string_of_sexpr l)) ^ "]"
  | SIndex(list, index) -> 
      string_of_sexpr list ^ "[" ^ string_of_sexpr index ^ "]"
  | SBind(var) ->      string_of_vdecl var
  | SNoexpr ->         ""
          ) ^ ")"

let rec string_of_sstmt = function
    SBlock(stmts) ->
      "{\n" ^ String.concat "" (List.map string_of_sstmt stmts) ^ "}\n"
  | SExpr(expr) ->     string_of_sexpr expr ^ ";\n";
  | SReturn(expr) ->   "return " ^ string_of_sexpr expr ^ ";\n";
  | SIf(e, s, SBlock([])) -> 
      "if (" ^ string_of_sexpr e ^ ")\n" ^ string_of_sstmt s
  | SIf(e, s1, s2) ->  
      "if (" ^ string_of_sexpr e ^ ")\n" ^ 
      string_of_sstmt s1 ^ "else\n" ^ string_of_sstmt s2
  | SFor(e1, e2, e3, s) ->
      "for (" ^ string_of_sexpr e1  ^ " ; " ^ string_of_sexpr e2 ^ " ; " ^
      string_of_sexpr e3  ^ ") " ^ string_of_sstmt s
  | SWhile(e, s) ->    "while (" ^ string_of_sexpr e ^ ") " ^ string_of_sstmt s

let string_of_sfdecl fdecl =
  string_of_typ fdecl.styp ^ " " ^
  fdecl.sfname ^ "(" ^ String.concat ", " (List.map string_of_args fdecl.sformals) ^
  ")\n{\n" ^ "" ^ String.concat "" (List.map string_of_sstmt fdecl.sbody) ^ "}\n"

let string_of_sprogram (stmts, funcs) =
  String.concat "" (List.rev (List.map string_of_sstmt stmts)) ^ "\n" ^
  String.concat "\n" (List.rev (List.map string_of_sfdecl funcs))