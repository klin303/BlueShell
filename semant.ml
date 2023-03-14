(* Semantic checking for the Blue Shell compiler *)

open Ast
open Sast

module StringMap = Map.Make(String)

type symbol_table = {
  (* Variables bound in current block *)
  variables : typ StringMap.t;
  (* Enclosing scope *)
  parent : symbol_table option;
}

(* Semantic checking of the AST. Returns an SAST if successful,
   throws an exception if something is wrong.

   Check each global variable, then check each function *)

let check (stmts, functions) =
      
  (* Check if a certain kind of binding has void type or is a duplicate
    of another, previously checked binding *)
  let check_binds (kind : string) (to_check : bind list) = 
    let name_compare (_, n1) (_, n2) = compare n1 n2 in
    let check_it checked binding = 
      let void_err = "illegal void " ^ kind ^ " " ^ snd binding
      and dup_err = "duplicate " ^ kind ^ " " ^ snd binding
      in match binding with
        (* No void bindings *)
        (Void, _) -> raise (Failure void_err)
      | (_, n1) -> match checked with
                    (* No duplicate bindings *)
                      ((_, n2) :: _) when n1 = n2 -> raise (Failure dup_err)
                    | _ -> binding :: checked

    in let _ = List.fold_left check_it [] (List.sort name_compare to_check) 
        in to_check
  in 

  (* Raise an exception if the given rvalue type cannot be assigned to
       the given lvalue type *)
  let check_assign lvaluet rvaluet err =
    if lvaluet = rvaluet then lvaluet else raise (Failure err)
  in 

  let rec type_of_identifier (scope : symbol_table) name =
    try
      (* Try to find binding in nearest block *)
      StringMap.find name scope.variables
    with Not_found -> (* Try looking in outer blocks *)
      match scope.parent with
        Some(parent) -> type_of_identifier parent name
      | _ -> raise Not_found
  in

  let rec expr curr_symbol_table expression =
  match expression with
    Literal l     -> (Int, SLiteral l)
  | Fliteral l    -> (Float, SFliteral l)
  | BoolLit l     -> (Bool, SBoolLit l)
  | Id var        -> (type_of_identifier curr_symbol_table var, SId var)
  (* | Id s          -> raise (Failure ("not yet implemented")) *)
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
  | List expr_list -> raise (Failure ("not yet implemented"))
  | Bind bind -> raise (Failure ("not yet implemented"))
  | Noexpr      -> (Void, SNoexpr)

  in
  let rec check_stmt curr_symbol_table statement =
  match statement with
    Block stmts -> raise (Failure ("not yet implemented"))
  | Expr e -> (curr_symbol_table, SExpr (expr curr_symbol_table e))
  | Return e -> raise (Failure ("not yet implemented"))
  | If(e, s1, s2) -> raise (Failure ("not yet implemented"))
  | For(e1, e2, e3, s) -> raise (Failure ("not yet implemented"))
  | While(e, s) -> raise (Failure ("not yet implemented"))

  in
  let check_function = raise (Failure ("not yet implemented"))

  (* Final checked program to return *)
  in
  (* Start with empty environment and map over statements, carrying updated environment as you go *)
  let empty_env = { variables = StringMap.empty ; parent = None }
  in
  let (_,checked_statements) = List.fold_left_map check_stmt empty_env stmts
  (* in
  let get_statements (table, sstatement) = sstatement *)
  in (checked_statements, [])
  (* in (List.fold_left check_stmt { variables = StringMap.empty ; parent = None } stmts, []) *)