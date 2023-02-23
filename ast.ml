(* ast.ml *)
(* BlueShell *)
(* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom *)

type op = Add | Sub | Mult | Div | Equal | Neq | Less | Leq | Greater | Geq |
          And | Or | Pipe  | Cons | ExprAssign

(* type idop = Index | Cons *)

(* type iduop = Length *)

type index = Index

type uop = Neg | Not | ExitCode | Run | Path | Length

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
  (* | Idop of string * expr * idop *)
  (* | Iduop of string * iduop *)
  | PreUnop of uop * expr
  | PostUnop of expr * uop
  | Assign of string * expr
  | Call of string * expr list
  | List of expr list
  | Bind of bind
  | Noexpr
  | Index of expr * expr

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
    body : stmt list;
  }

type program = stmt list * func_decl list

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
  | Cons -> "::"
  | ExprAssign -> "="

let string_of_uop = function
    Neg -> "-"
  | ExitCode -> "?"
  | Run -> "./"
  | Path -> "$"
  | Not -> "!"
  | Length -> "len "

(* let string_of_idop = function
    Index -> "index"
  | Cons -> "::" *)

(* let string_of_iduop = function
    Length -> "length" *)

let string_of_path = function
    Id(s) -> s
    | String(s) -> "\"" ^ s ^ "\""
    | _ ->  "Error: not a viable path type"

(*let rec string_of_list = function
  [] -> ""
  | l -> string_of_cont_list l

let rec string_of_cont_list = function
  [] -> ""
  | (fst :: []) -> string_of_expr fst
  | (fst :: rest) -> string_of_expr fst ^ ", " ^string_of_cont_list rest*)

(* string_of_expr e1 ^ "{" ^ string_of_list e2 ^ "}" *)

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

  let string_of_vdecl (t, id) = string_of_typ t ^ " " ^ id

let rec string_of_expr = function
    Literal(l) -> string_of_int l
  | Fliteral(l) -> l
  | BoolLit(true) -> "true"
  | BoolLit(false) -> "false"
  | Id(s) -> s
  | Char(c) -> "'" ^ c ^ "'"
  | String(s) -> "\"" ^ s ^ "\""
  | Exec(e1, e2) -> string_of_path e1 ^ " " ^ "{" ^ (String.concat ", " (List.map string_of_expr e2)) ^ "}"
  | Binop(e1, o, e2) ->
      string_of_expr e1 ^ " " ^ string_of_op o ^ " " ^ string_of_expr e2
  (* | Idop(s, e, o) -> s ^ string_of_expr e ^ string_of_idop o *)
  (* | Iduop(s, o) -> s ^ string_of_iduop o *)
  | PreUnop(o, e) -> string_of_uop o ^ string_of_expr e
  | PostUnop(e, o) -> string_of_expr e ^ string_of_uop o
  | Assign(v, e) -> v ^ " = " ^ string_of_expr e
  | Call(f, el) ->
      f ^ "(" ^ String.concat ", " (List.map string_of_expr el) ^ ")"
  | List(l) -> "[" ^ (String.concat ", " (List.map string_of_expr l)) ^ "]"
  | Index(list, index) -> string_of_expr list ^ "[" ^ string_of_expr index ^ "]"
  | Bind(var) -> string_of_vdecl var
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





(* let string_of_func_body = function
    FuncBind(b) -> string_of_vdecl b
  | FuncStmt(s) -> string_of_stmt s *)

(* let string_of_fdecl fdecl =
  string_of_typ fdecl.typ ^ " " ^
  fdecl.fname ^ "(" ^ String.concat ", " (List.map snd fdecl.formals) ^
  ")\n{\n" ^
  String.concat "" (List.map string_of_func_body fdecl.body) ^
  "}\n" *)

let string_of_args args =
  string_of_typ (fst args) ^ " " ^ (snd args)

let string_of_fdecl fdecl =
  string_of_typ fdecl.typ ^ " " ^
  fdecl.fname ^ "(" ^ String.concat ", " (List.map string_of_args fdecl.formals) ^
  ")\n{\n" ^ "" ^
  String.concat "" (List.map string_of_stmt fdecl.body) ^
  "}\n"

(* let string_of_program_elem elem =
    match elem with
      bind -> string_of_vdecl elem
    | stmt -> string_of_stmt elem
    | func_decl -> string_of_fdecl elem *)

let string_of_program (stmts, funcs) =
  String.concat "" (List.rev (List.map string_of_stmt stmts)) ^ "\n" ^
  String.concat "\n" (List.rev (List.map string_of_fdecl funcs))