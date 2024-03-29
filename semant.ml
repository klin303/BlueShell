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

  (* carry a boolean when checking all the arg types of a function *)
  let check_arg_types is_valid args1 args2  = is_valid && (args1 = args2)
  in

  (* Raise an exception if the given rvalue type cannot be assigned to
       the given lvalue type *)
  let check_assign lvaluet rvaluet err =
    (match (lvaluet, rvaluet) with
      (List_type _, EmptyList) -> lvaluet
      | (List_type ty1, List_type ty2) -> (match ty1 = ty2 with
          true -> List_type ty1
          | false -> raise (Failure err))
      | (Function (args1, ret1), Function (args2, ret2)) -> (match ret1 = ret2 with
          true -> (match (List.fold_left2 check_arg_types true args1 args2 ) with
                  true -> Function (args1, ret1)
                  | false -> raise (Failure err))
          | false -> raise (Failure err))
      | (ComplexExec, Exec) | (Exec, ComplexExec) -> rvaluet
      | _ -> (match lvaluet = rvaluet with
              true -> lvaluet
            | false -> raise (Failure err)))
  in

  let rec type_of_identifier (scope : symbol_table) name =
    try
      (* Try to find binding in nearest block *)
      StringMap.find name scope.variables
    with Not_found -> (* Try looking in outer blocks *)
      match scope.parent with
        Some(parent) -> type_of_identifier parent name
      | _ -> raise (Failure ("semant identifier not found"))
  in

  let add_bind (scope : symbol_table) (typ, name) =
    let map = scope.variables in
    let new_map = StringMap.add name typ map in
    { variables = new_map; parent = scope.parent }

  in

  let add_func_symbol_table map fd =
    let n = fd.fname (* Name of the function *)
    and ty = Function(List.map fst fd.formals, fd.typ) in
    add_bind map (ty, n)
  in

  (* Collect all other function names into one symbol table *)
  (* Start with empty environment and map over statements, carrying updated
  environment as you go *)
  let empty_env = { variables = StringMap.empty ; parent = None }
  in
  let env_with_functions = List.fold_left add_func_symbol_table empty_env functions
  in

  (* check function types *)
  let same_func ((ty1 : typ), (ty2 : typ)) =
    (match ty1 = ty2 with
      true -> true
      | _ -> (match (ty1, ty2) with
        (Exec, ComplexExec) | (ComplexExec, Exec) -> true
        | _ -> false))
  in

  let rec expr (curr_symbol_table : symbol_table) expression =
  match expression with
    (* all literals evaluate to their own type *)
    Literal l     -> (curr_symbol_table, (Int, SLiteral l))
  | Fliteral l    -> (curr_symbol_table, (Float, SFliteral l))
  | BoolLit l     -> (curr_symbol_table, (Bool, SBoolLit l))
    (* search symbol table for identifiers *)
  | Id var        -> (curr_symbol_table, (type_of_identifier curr_symbol_table var, SId var))
  | Char s        -> (curr_symbol_table, (Char, SChar s))
  | String s      -> (curr_symbol_table, (String, SString s))
  | Exec(e1, e2)  ->
    let (_, (ty1, e1')) = expr curr_symbol_table e1 in
    let (_, (ty2, e2')) = expr curr_symbol_table e2 in
    (* path must be a string, args must be a list *)
    (match ty1 with
      String ->
        (match ty2 with
          List_type ty ->(match ty with
            Int | Float | Bool | String | Char -> (curr_symbol_table, (Exec, (SExec ((ty1, e1'), (ty2, e2')))))
            | _ -> raise (Failure ("exec args cannot be of type function, list, or exec")))


          | EmptyList -> (curr_symbol_table, (Exec, (SExec ((ty1, e1'), (List_type String, SList [])))))
          | _ -> raise (Failure ("args must be a list of string")))
      | _ -> raise (Failure ("path must be a string")))
  | Index(e1, e2) ->
    let (_, (ty1, e1')) = expr curr_symbol_table e1 in
    let (_, (ty2, e2')) = expr curr_symbol_table e2 in
    (* can only index into lists *)
    (match (ty1, ty2) with
      (List_type ty, Int) -> (curr_symbol_table, (ty, (SIndex ((ty1, e1'), (ty2, e2')))))
      | _ -> raise (Failure ("Indexing takes a list and integer")))
  | Binop(e1, op, e2) ->
    let (symbol_table', (ty2, e2')) = expr curr_symbol_table e2
    in let (symbol_table'', (ty1, e1')) = expr symbol_table' e1 in
    (match e2 with Bind _ -> raise (Failure "Bind cannot happen on left side of binops")
    | _ ->
    (match (e1, op) with
      (* only certain expressions can appear on the left side of an ExprAssign *)
      (* bind allows for "int x = 1;" *)
      (* index allows for assignment of list elements *)
      (* path is valid on the left side to change the path of an executable *)
      (Bind b, ExprAssign) ->
                    let same = same_func(ty1, ty2) in
                    let ty = (match e1' with
                      | SBind b when same -> fst b
                      | _ -> (match ty1 with
                        List_type _ -> (match ty2 with
                          EmptyList -> ty1
                          | _ -> raise (Failure ("invalid assignment")))
                        | _ -> raise (Failure ("invalid assignment"))))
                    in (symbol_table'', (ty, SBinop((ty1, e1'), op, (ty2,
                    e2'))))
      | (Index _, ExprAssign) ->
                    let same = same_func(ty1, ty2) in
                    (match same with
                      true -> (symbol_table'', (ty1, SBinop((ty1, e1'), op, (ty2,
                      e2'))))
                      | false -> raise (Failure ("index exprassign with
                      incompatible types")))
      | (PreUnop (op1, _), ExprAssign) ->
                    (match op1 with
                      Path -> let same = same_func(ty1, ty2) in
                      (match same with
                        true -> (symbol_table'', (ty1, SBinop((ty1, e1'), op, (ty2,
                        e2'))))
                        | false -> raise (Failure ("index exprassign with
                        incompatible types")))
                      | _ -> raise (Failure ("invalid preunop with exprassign")))
      | (_, ExprAssign) -> raise (Failure "expression assignment needs a bind")
      | (Bind _, _) -> raise (Failure "bind needs an expression assignment")
      (* arithmetic and boolean operations require 2 of the same types *)
      (* executable operations can work on any combination of simple and complex executables *)
      | (_, Add) | (_, Mult) ->
                    let same = same_func(ty1, ty2) in
                    (match ty1 with
                      Int | Float when same -> (symbol_table'', (ty1, SBinop((ty1, e1'), op,
                      (ty2, e2'))))
                      | Exec | ComplexExec when same -> (symbol_table'', (ComplexExec, SBinop((ty1, e1'), op,
                      (ty2, e2'))))
                    | _ -> raise (Failure ("+ and * take two integers,
                    floats, or executables")))
      | (_, Sub) | (_, Div) ->
                    let same = same_func (ty1, ty2) in
                    (match ty1 with
                      Int | Float when same -> (symbol_table'', (ty1, SBinop((ty1, e1'), op,
                      (ty2, e2'))))
                    | _ -> raise (Failure ("Operator expected int or float")))
      | (_, Less) | (_, Leq) | (_, Greater) | (_, Geq) ->
                    let same = same_func (ty1, ty2) in
                    (match ty1 with
                      Int | Float when same -> (symbol_table'', (Bool, SBinop((ty1, e1'), op,
                      (ty2, e2'))))
                    | _ -> raise (Failure ("Operator expected int or float")))
      | (_, And) | (_, Or) ->
                    let same = same_func (ty1, ty2) in
                    (match ty1 with
                      Bool when same  -> (symbol_table'', (Bool, SBinop((ty1, e1'), op,
                      (ty2, e2'))))
                    | _ -> raise (Failure ("Boolean operators must take two booleans")))
      | (_, Equal) | (_, Neq) ->
                    let same = same_func (ty1, ty2) in
                    (match ty1 with
                       | Float | Int when same -> (symbol_table'', (Bool, SBinop((ty1, e1'), op,
                              (ty2, e2'))))
                    | _ -> raise (Failure ("operator expected int, or float")))
      (* cons requires the element being appended to match the type of the list *)
      (* any element can be cons'd to an empty list *)
      | (_, Cons) ->
                    (match ty2 with
                      EmptyList -> (symbol_table'', (List_type ty1, SBinop((ty1, e1'), op,
                        (ty2, e2'))))
                     | List_type ty  -> let same = ty = ty1 in
                        (match same with
                        true -> (symbol_table'', (ty2, SBinop((ty1, e1'), op,
                        (ty2, e2'))))
                        | false -> raise (Failure ("lists are monomorphic")))
                    | _ -> raise (Failure ("Cons takes a list and primitive type")))
      | (_, Pipe) ->
                    let same = same_func (ty1, ty2) in
                    (match ty1 with
                      ComplexExec | Exec when same -> (symbol_table'', (ComplexExec, SBinop((ty1, e1'), op,
                      (ty2, e2'))))
                    | _ -> raise (Failure ("Pipe expects two executables")))))
  | PreUnop(op, e)    ->
    let (_, (ty1, e1)) = expr curr_symbol_table e in
    (match e1 with
    SBind _ -> raise (Failure "No bind can occur in a larger expression")
    | _ ->
    (match op with
      Run ->
              (match ty1 with
                Exec | ComplexExec -> (curr_symbol_table, (String, SPreUnop (Run, (ty1, e1))))
              | _ -> raise (Failure ("Run takes type executable")))
    | Neg ->
              (match ty1 with
                Int | Float -> (curr_symbol_table, (ty1, SPreUnop (Neg, (ty1, e1))))
              | _ -> raise (Failure ("Negation takes an interger, float, or list")))
    | Length ->
              (match ty1 with
                EmptyList | List_type _ -> (curr_symbol_table, (Int, SPreUnop (Length,(ty1,e1))))
              | _ -> raise (Failure ("Length takes a list")))
    | Path ->
              (match ty1 with
                Exec -> (curr_symbol_table, (String, SPreUnop (Path, (ty1, e1))))
              | _ -> raise (Failure ("Run takes type executable")))
    | Not ->
              (match ty1 with
                Bool -> (curr_symbol_table, (Bool, SPreUnop (Not, (ty1, e1))))
              | _ -> raise (Failure ("Boolean negation takes a boolean")))))
  | PostUnop(e, op)   ->
    let (_, (ty1, e1)) = expr curr_symbol_table e in
    (match e1 with
      SBind _ -> raise (Failure "No bind can occur in a larger expression")
      | _ ->
    (match op with
      | _ -> raise (Failure ("invalid postunop"))))
  | Assign(var, e) as ex ->
    (* ensure that type of variable matches type of expression being assigned to
    it *)
    (match e with
    Bind _ -> raise (Failure "No bind can occur in a larger expression")
    | _ ->
    let lt = type_of_identifier curr_symbol_table var
    and (_, (rt, e')) = expr curr_symbol_table e in
    let err = "illegal assignment " ^ string_of_typ lt ^ " = " ^
      string_of_typ rt ^ " in " ^ string_of_expr ex
    in (curr_symbol_table, (check_assign lt rt err, SAssign(var, (rt, e')))))
  | Call(fname, args) as call ->
    (* ensure that calling a function is done with the correct parameter types *)
    (* also checks that the return value of the function isn't improperly assigned *)
      (match type_of_identifier curr_symbol_table fname with
          Function (args_typs, ret_typ) ->
            let param_length = List.length args_typs in
            if List.length args != param_length then
              raise (Failure ("expecting " ^ string_of_int param_length ^
                              " arguments in " ^ string_of_expr call))
            else let check_call ft e =
              let (_, (et, e')) = expr curr_symbol_table e in
              let err = "illegal argument found " ^ string_of_typ et ^
                " expected " ^ string_of_typ ft ^ " in " ^ string_of_expr e
              in (check_assign ft et err, e')
            in
            let args' = List.map2 check_call args_typs args
            in (curr_symbol_table, (ret_typ, SCall(fname, args')))
          | _ -> raise (Failure ("Not a function")))
  | List expr_list ->
    (* assert that all elements of a list are the same type *)
    let rec check_list (exprs : expr list) curr_symbol_table =
      match exprs with
      fst_elem :: snd_elem :: rest -> let (_, (ty1, e1)) = expr curr_symbol_table fst_elem in let
                                (_, (ty2, e2)) = expr curr_symbol_table snd_elem
                                in (match (e1, e2) with
                                (SBind _, _) -> raise (Failure ("can't bind in a list"))
                                | (_, SBind _) -> raise (Failure ("can't bind in a list"))
                                | _ -> (ty1 = ty2 && check_list (snd_elem :: rest) curr_symbol_table))
      | fst_elem :: [] -> let (_, (_, e1)) = expr curr_symbol_table fst_elem
      in (match e1 with
          SBind _ -> raise (Failure ("No binds in list"))
          |_ -> true)
      | [] -> true
    in
    let expr_to_sexpr elem =
      let (_, elem') = expr curr_symbol_table elem in
      elem'
    in
    (match expr_list with
      [] -> (curr_symbol_table, (EmptyList, SList([])))
    | elem :: elems -> let (_, elem') = expr curr_symbol_table elem in
      match (check_list elems curr_symbol_table) with
        true -> (curr_symbol_table, (List_type (fst elem'), SList(List.map expr_to_sexpr expr_list)))
        | false -> raise (Failure ("list must be monotype"))
    )
  | Bind bind -> (add_bind curr_symbol_table bind, (fst bind, SBind bind))
  | Noexpr      -> (curr_symbol_table, (Void, SNoexpr))

  in
  let rec check_stmt (curr_symbol_table : symbol_table) statement =
  match statement with
    Block stmts ->
      (* recurse on statements in a block *)
      let rec check_stmt_list (curr_symbol_table' : symbol_table) sl =
        (match sl with
              [Return _ as s] -> [snd (check_stmt curr_symbol_table' s)]
            | Return _ :: _   -> raise (Failure "nothing may follow a return")
            | Block sl :: ss  ->
              let temp = { variables = StringMap.empty ; parent =
              Some curr_symbol_table' } in
              let checked_sl = (check_stmt_list temp sl)
              in
              SBlock(checked_sl) :: (check_stmt_list curr_symbol_table' ss) (* Flatten blocks *)
              | s :: ss         ->
                let checked_first = (check_stmt curr_symbol_table' s) in
                (snd checked_first) :: (check_stmt_list (fst checked_first) ss)
            | []              -> [])
          in (curr_symbol_table, SBlock(check_stmt_list { variables = StringMap.empty ; parent = Some curr_symbol_table} stmts))
  | Expr e ->
    let (new_symbol_table, e') = expr curr_symbol_table e in
    (new_symbol_table, SExpr e')
  | If(e, s1, s2) ->
    let (curr_symbol_table', (ty, e')) = expr curr_symbol_table e in
    (* condition in if statement must be a boolean *)
    (match ty with
      Bool -> (curr_symbol_table, SIf((ty, e'), snd (check_stmt curr_symbol_table' s1), snd (check_stmt
      curr_symbol_table' s2)))
      | _ -> raise (Failure ("if needs a boolean predicate")))
  | For(e1, e2, e3, s) ->
    let (curr_symbol_table', (ty1, e1')) = expr curr_symbol_table e1 in
    let (curr_symbol_table'', (ty2, e2')) = expr curr_symbol_table' e2 in
    let (curr_symbol_table''', (ty3, e3')) = expr curr_symbol_table'' e3 in
    (* second expression in for loop must be a boolean *)
    (match ty2 with
      Bool -> (curr_symbol_table''', SFor((ty1, e1'), (ty2, e2'), (ty3, e3'),
      snd (check_stmt curr_symbol_table''' s)))
      | _ -> raise (Failure ("for needs a boolean as the second expression")))
  | While(e, s) ->
    let (curr_symbol_table', (ty, e')) = expr curr_symbol_table e in
    (* condition in while loop must be a boolean *)
      (match ty with
      Bool -> (curr_symbol_table, SWhile((ty, e'), snd (check_stmt curr_symbol_table' s)))
      | _ -> raise (Failure ("if needs a boolean predicate")))
  | Return e -> raise (Failure ("cannot return from not a function"))
  (* Final checked program to return *)
  in

  (* check statements in a function, slightly different from check_stmt because
  return statements can appear in a function but not in top-level statements *)
  let check_func symbol_table func =
    let add_formals formal_map name typ =
      StringMap.add name typ formal_map
    in
    let formals_map = List.fold_left2 add_formals symbol_table.variables (List.map snd func.formals) (List.map
    fst func.formals) in
    let formals_env = { variables = formals_map ; parent = None } in
    let rec check_stmt_wrap (curr_symbol_table : symbol_table) statement =
      (match statement with
      Return ret ->
        let (curr_symbol_table', (ty_ret, ret')) = expr curr_symbol_table ret in
        let same = ty_ret = func.typ in
        (match same with
          true -> (curr_symbol_table', SReturn (ty_ret, ret'))
          | false -> raise (Failure ("return type invalid")))
      | Block stmts ->
        let rec check_stmt_list (curr_symbol_table' : symbol_table) sl =
          (match sl with
                [Return _ as s] -> [snd (check_stmt_wrap curr_symbol_table' s)]
              | Return _ :: _   -> raise (Failure "nothing may follow a return")
              | Block sl :: ss  ->
                let temp = { variables = StringMap.empty ; parent =
                Some curr_symbol_table' } in
                let checked_sl = (check_stmt_list temp sl)
                in
                SBlock(checked_sl) :: (check_stmt_list curr_symbol_table' ss) (* Flatten blocks *)
              | s :: ss         ->
                let checked_first = (check_stmt_wrap curr_symbol_table' s) in
                (snd checked_first) :: (check_stmt_list (fst checked_first) ss)
              | []              -> [])
            in (curr_symbol_table, SBlock(check_stmt_list { variables = StringMap.empty ; parent = Some curr_symbol_table} stmts))
    | Expr e ->
      let (new_symbol_table, e') = expr curr_symbol_table e in
      (new_symbol_table, SExpr e')
    | If(e, s1, s2) ->
      let (curr_symbol_table', (ty, e')) = expr curr_symbol_table e in
      (match ty with
        Bool -> (curr_symbol_table, SIf((ty, e'), snd (check_stmt_wrap curr_symbol_table' s1), snd (check_stmt_wrap
        curr_symbol_table' s2)))
        | _ -> raise (Failure ("if needs a boolean predicate")))
    | For(e1, e2, e3, s) ->
      let (curr_symbol_table', (ty1, e1')) = expr curr_symbol_table e1 in
      let (curr_symbol_table'', (ty2, e2')) = expr curr_symbol_table' e2 in
      let (curr_symbol_table''', (ty3, e3')) = expr curr_symbol_table'' e3 in
      (match ty2 with
        Bool -> (curr_symbol_table''', SFor((ty1, e1'), (ty2, e2'), (ty3, e3'),
        snd (check_stmt_wrap curr_symbol_table''' s)))
        | _ -> raise (Failure ("for needs a boolean as the second expression")))
    | While(e, s) ->
      let (curr_symbol_table', (ty, e')) = expr curr_symbol_table e in
        (match ty with
        Bool -> (curr_symbol_table, SWhile((ty, e'), snd (check_stmt_wrap curr_symbol_table' s)))
        | _ -> raise (Failure ("if needs a boolean predicate"))))
    in
    let (_, checked_statements) = List.fold_left_map check_stmt_wrap formals_env func.body in
    (symbol_table, {
      styp = func.typ;
      sfname = func.fname;
      sformals = func.formals;
      sbody = checked_statements; (* add new symbol table for body, but references parent st*)
    })

  in
  let (env_with_checked_funcs, checked_functions) = List.fold_left_map check_func env_with_functions (List.rev functions)
  in

  let (_, checked_statements) = List.fold_left_map check_stmt env_with_checked_funcs (List.rev stmts)
  (* go through map called function_decls, put all the fdecls into sfdecls and
  gather  into a list *)

  in (List.rev checked_statements, List.rev checked_functions)