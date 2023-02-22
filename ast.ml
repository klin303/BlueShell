(* ast.ml *)
(* BlueShell *)
(* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom *)

type op = Add | Sub | Mult | Div | Equal | Neq | Less | Leq | Greater | Geq |
          And | Or | Pipe

type idop = Index | Cons

type iduop = Length

type uop = Neg | Not | ExitCode | Run | Path

type typ = Int | Bool | Float | Void | Exec | Char | String | List | Function

type bind = typ * string

type expr =
    Literal of int
  | Fliteral of string
  | BoolLit of bool
  | Id of string
  | Char of string
  | String of string
  | Exec of expr * expr list
  | Binop of expr * op * expr
  | Idop of string * expr * idop
  | Iduop of string * iduop
  | PreUnop of uop * expr
  | PostUnop of expr * uop
  | Assign of string * expr
  | Call of string * expr list
  | List of expr * expr
  | Noexpr

type stmt =
    Block of stmt list
  | Expr of expr
  | Return of expr
  | If of expr * stmt * stmt
  | For of expr * expr * expr * stmt
  | While of expr * stmt

(* type func_body = FuncBind of bind | FuncStmt of stmt *)

type func_decl = {
    typ : typ;
    fname : string;
    formals : bind list;
    locals : bind list;
    body : stmt list;
  }

type program = bind list * func_decl list

(* Pretty-printing functions *)

let string_of_op = function
    Add -> "+"
  | Sub -> "-"
  | Mult -> "*"
  | Div -> "/"
  | Equal -> "=="
  | Neq -> "!="
  | Less -> "<"
  | Leq -> "<="
  | Greater -> ">"
  | Geq -> ">="
  | And -> "&&"
  | Or -> "||"
  | Pipe -> "|"

let string_of_uop = function
    Neg -> "-"
  | ExitCode -> "?"
  | Run -> "./"
  | Path -> "$"
  | Not -> "!"

let string_of_idop = function
    Index -> "index"
  | Cons -> "::"

let string_of_iduop = function
    Length -> "length"

let rec string_of_expr = function
    Literal(l) -> string_of_int l
  | Fliteral(l) -> l
  | BoolLit(true) -> "true"
  | BoolLit(false) -> "false"
  | Id(s) -> s
  | Exec(e1, e2) -> "exec"
  | Binop(e1, o, e2) ->
      string_of_expr e1 ^ " " ^ string_of_op o ^ " " ^ string_of_expr e2
  | Idop(s, e, o) -> s ^ string_of_expr e ^ string_of_idop o
  | Iduop(s, o) -> s ^ string_of_iduop o
  | PreUnop(o, e) -> string_of_uop o ^ string_of_expr e
  | PostUnop(e, o) -> string_of_expr e ^ string_of_uop o
  | Assign(v, e) -> v ^ " = " ^ string_of_expr e
  | Call(f, el) ->
      f ^ "(" ^ String.concat ", " (List.map string_of_expr el) ^ ")"
  | Char(c) -> c
  | String(s) -> s
  | List((fst, rest)) ->string_of_expr fst ^ ", " ^ string_of_expr rest
  | Noexpr -> ""

let rec string_of_stmt = function
    Block(stmts) ->
      "{\n" ^ String.concat "" (List.map string_of_stmt stmts) ^ "}\n"
  | Expr(expr) -> string_of_expr expr ^ ";\n";
  | Return(expr) -> "return " ^ string_of_expr expr ^ ";\n";
  | If(e, s, Block([])) -> "if (" ^ string_of_expr e ^ ")\n" ^ string_of_stmt s
  | If(e, s1, s2) ->  "if (" ^ string_of_expr e ^ ")\n" ^
      string_of_stmt s1 ^ "else\n" ^ string_of_stmt s2
  | For(e1, e2, e3, s) ->
      "for (" ^ string_of_expr e1  ^ " ; " ^ string_of_expr e2 ^ " ; " ^
      string_of_expr e3  ^ ") " ^ string_of_stmt s
  | While(e, s) -> "while (" ^ string_of_expr e ^ ") " ^ string_of_stmt s

let string_of_typ = function
    Int -> "int"
  | Bool -> "bool"
  | Float -> "float"
  | Void -> "void"
  | Exec -> "exec"
  | Char -> "char"
  | String -> "string"
  | List -> "list"
  | Function -> "func"

let string_of_vdecl (t, id) = string_of_typ t ^ " " ^ id ^ ";\n"

(* let string_of_func_body = function
    FuncBind(b) -> string_of_vdecl b
  | FuncStmt(s) -> string_of_stmt s *)

(* let string_of_fdecl fdecl =
  string_of_typ fdecl.typ ^ " " ^
  fdecl.fname ^ "(" ^ String.concat ", " (List.map snd fdecl.formals) ^
  ")\n{\n" ^
  String.concat "" (List.map string_of_func_body fdecl.body) ^
  "}\n" *)

let string_of_fdecl fdecl =
  string_of_typ fdecl.typ ^ " " ^
  fdecl.fname ^ "(" ^ String.concat ", " (List.map snd fdecl.formals) ^
  ")\n{\n" ^
  String.concat "" (List.map string_of_vdecl fdecl.locals) ^
  String.concat "" (List.map string_of_stmt fdecl.body) ^
  "}\n"

(* let string_of_program_elem elem =
    match elem with
      bind -> string_of_vdecl elem
    | stmt -> string_of_stmt elem
    | func_decl -> string_of_fdecl elem *)

let string_of_program (vars, funcs) =
  String.concat "" (List.map string_of_vdecl vars) ^ "\n" ^
  String.concat "\n" (List.map string_of_fdecl funcs)