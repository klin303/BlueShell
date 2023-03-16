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
      | _ -> raise (Failure ("here"))
  in

  let add_bind (scope : symbol_table) (typ, name) =
    let map = scope.variables in
    let new_map = StringMap.add name typ map in
    { variables = new_map; parent = scope.parent }
  
  in
  
  let rec expr (curr_symbol_table : symbol_table) expression =
  match expression with
    Literal l     -> (curr_symbol_table, (Int, SLiteral l))
  | Fliteral l    -> (curr_symbol_table, (Float, SFliteral l))
  | BoolLit l     -> (curr_symbol_table, (Bool, SBoolLit l))
  | Id var        -> (curr_symbol_table, (type_of_identifier curr_symbol_table var, SId var))
  (* | Id var -> raise (Failure ("id")) *)
  | Char s        -> (curr_symbol_table, (Char, SChar s))
  | String s      -> (curr_symbol_table, (String, SString s))
  | Exec(e1, e2)  -> 
    let (_, (ty1, e1')) = expr curr_symbol_table e1 in
    let (_, (ty2, e2')) = expr curr_symbol_table e2 in
    (match ty1 with
      String -> 
        (match ty2 with
          List_type String -> (curr_symbol_table, (Exec, (SExec ((ty1, e1'), (ty2, e2')))))
          | _ -> raise (Failure ("args must be a list of string")))
      | _ -> raise (Failure ("path must be a string")))
  | Index(e1, e2) -> raise (Failure ("not yet implemented index"))
  | Binop(e1, op, e2) -> 
    (match op with
      ExprAssign -> let (symbol_table', (ty2, e2')) = expr curr_symbol_table e2 
                    in let (symbol_table'', (ty1, e1')) = expr symbol_table' e1 in 
                    let same = ty2 = ty1 in 
                    let ty = match e1' with 
                      SBind b when same ->  fst b 
                      | SId var when same -> type_of_identifier symbol_table'' var
                      | _ -> raise (Failure ("invalid assignment"))
                    in (symbol_table'', (ty, SBinop((ty1, e1'), op, (ty2, e2'))))
      | _ -> raise (Failure ("not yet implemented other binops")))
  | PreUnop(op, e)    -> 
    (match op with 
    Run -> let (_, (ty1, e1)) = expr curr_symbol_table e in 
              match ty1 with
                Exec -> (curr_symbol_table, (String, SPreUnop (Run, (ty1, e1)))) (* what do we put here*)
                | _ -> raise (Failure ("Run takes type executable"))
    | _ -> raise (Failure ("other preunops not implemented yet")))
  | PostUnop(e, op)   -> raise (Failure ("not yet implemented post"))
  | Assign(var, e) as ex ->
    let lt = type_of_identifier curr_symbol_table var
    and (_, (rt, e')) = expr curr_symbol_table e in
    let err = "illegal assignment " ^ string_of_typ lt ^ " = " ^ 
      string_of_typ rt ^ " in " ^ string_of_expr ex
    in (curr_symbol_table, (check_assign lt rt err, SAssign(var, (rt, e'))))
  (* | Assign(var, e) -> raise (Failure ("not yet implemented")) *)
  | Call(fname, args) -> raise (Failure ("not yet implemented call"))
  | List expr_list -> 
    let rec check_list (exprs : expr list) curr_symbol_table =
      match exprs with
      fst_elem :: snd_elem :: rest -> let (_, (ty1, _)) = expr curr_symbol_table fst_elem in let
                                (_, (ty2, _)) = expr curr_symbol_table snd_elem in (ty1 = ty2 && check_list rest curr_symbol_table)
      | fst_elem :: [] -> true
      | [] -> true
    in
    let expr_to_sexpr elem =
      let (_, elem') = expr curr_symbol_table elem in
      elem'
    in
    (match expr_list with
      [] -> raise (Failure ("we didn't think about empty list yet"))
    | elem :: elems -> let (_, elem') = expr curr_symbol_table elem in
      match (check_list elems curr_symbol_table) with
        true -> (curr_symbol_table, (List_type (fst elem'), SList(List.map expr_to_sexpr expr_list)))
        | false -> raise (Failure ("list must be monotype"))
    )
    
  | Bind bind -> (add_bind curr_symbol_table bind, (fst bind, SBind bind))
  (* | Bind(bind) -> raise (Failure ("bind")) *)
  | Noexpr      -> (curr_symbol_table, (Void, SNoexpr))

  in
  let rec check_stmt (curr_symbol_table : symbol_table) statement =
  match statement with
    Block stmts -> raise (Failure ("not yet implemented block"))
  | Expr e -> 
    let (new_symbol_table, e') = expr curr_symbol_table e in
    (new_symbol_table, SExpr e')
  | Return e -> raise (Failure ("not yet implemented return"))
  | If(e, s1, s2) -> raise (Failure ("not yet implemented if"))
  | For(e1, e2, e3, s) -> raise (Failure ("not yet implemented for"))
  | While(e, s) -> raise (Failure ("not yet implemented while"))

  (* in
  let check_function = raise (Failure ("not yet implemented check func")) *)

  (* Final checked program to return *)
  in
  (* Start with empty environment and map over statements, carrying updated environment as you go *)
  let empty_env = { variables = StringMap.empty ; parent = None }
  in
  let (_, checked_statements) = List.fold_left_map check_stmt empty_env (List.rev stmts)
  (* in
  let get_statements (table, sstatement) = sstatement *)
  in (List.rev checked_statements, [])
  (* in (List.fold_left check_stmt { variables = StringMap.empty ; parent = None } stmts, []) *)