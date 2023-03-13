(* Semantic checking for the Blue Shell compiler *)

open Ast
open Sast

module StringMap = Map.Make(String)

(* Semantic checking of the AST. Returns an SAST if successful,
   throws an exception if something is wrong.

   Check each global variable, then check each function *)

let check (stmts, functions) =

  (* Raise an exception if the given rvalue type cannot be assigned to
       the given lvalue type *)
  (* let check_assign lvaluet rvaluet err =
    if lvaluet = rvaluet then lvaluet else raise (Failure err)
  in  *)

(* NEED TO FIGURE OUT SCOPE FOR THIS *)
  (* Return a variable from our local symbol table *)
  (* let type_of_identifier s =
    try StringMap.find s symbols
    with Not_found -> raise (Failure ("undeclared identifier " ^ s))
  in *)

  let rec expr = function
    Literal l     -> (Int, SLiteral l)
  | Fliteral l    -> (Float, SFliteral l)
  | BoolLit l     -> (Bool, SBoolLit l)
  (* | Id s          -> (type_of_identifier s, SId s) *)
  | Id s          -> raise (Failure ("not yet implemented"))
  | Char s        -> (Char, SChar s)
  | String s      -> (String, SString s)
  | Exec(e1, e2)  -> raise (Failure ("not yet implemented"))
  | Index(e1, e2) -> raise (Failure ("not yet implemented"))
  | Binop(e1, op, e2) -> raise (Failure ("not yet implemented"))
  | PreUnop(op, e)    -> raise (Failure ("not yet implemented"))
  | PostUnop(e, op)   -> raise (Failure ("not yet implemented"))
  (* | Assign(var, e) as ex ->
    let lt = type_of_identifier var
    and (rt, e') = expr e in
    let err = "illegal assignment " ^ string_of_typ lt ^ " = " ^ 
      string_of_typ rt ^ " in " ^ string_of_expr ex
    in (check_assign lt rt err, SAssign(var, (rt, e'))) *)
  | Assign(var, e) -> raise (Failure ("not yet implemented"))
  | Call(fname, args) -> raise (Failure ("not yet implemented"))
  | List expr -> raise (Failure ("not yet implemented"))
  | Bind bind -> raise (Failure ("not yet implemented"))
  | Noexpr      -> (Void, SNoexpr)

  in
  let rec check_stmt = function
    Block stmts -> raise (Failure ("not yet implemented"))
  | Expr e -> SExpr (expr e)
  | Return e -> raise (Failure ("not yet implemented"))
  | If(e, s1, s2) -> raise (Failure ("not yet implemented"))
  | For(e1, e2, e3, s) -> raise (Failure ("not yet implemented"))
  | While(e, s) -> raise (Failure ("not yet implemented"))

  (* Final checked program to return *)
  in (List.map check_stmt stmts, [])