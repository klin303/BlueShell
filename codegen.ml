module L = Llvm
module A = Ast
open Sast
(* todo
 * strings
 * lists
 * executables
 * run
 *)

module StringMap = Map.Make(String)

type symbol_table = {
  (* Variables bound in current block *)
  variables : L.llvalue StringMap.t;
  (* Enclosing scope *)
  parent : symbol_table option;
}

(* building a string with const_stringz gets u the array type
   u can then build_malloc the type u get back *)

(* build_gep = build get element pointer *)

let translate (stmts, functions) =
  let context = L.global_context () in
  (* Add types to the context so we can use them in our LLVM code *)
  let i32_t      = L.i32_type    context
  and i8_t       = L.i8_type     context
  and i1_t       = L.i1_type     context
  and float_t    = L.double_type context
  and void_t     = L.void_type   context
  in
  let string_t   = L.pointer_type i8_t
  in
  let list_t     = L.struct_type context [| L.pointer_type i8_t (* value *) ; L.pointer_type i8_t (* next*) |]
  in
  let exec_t     = L.struct_type context [| string_t (* path *) ; L.pointer_type list_t (* args *) |]
  (* Create an LLVM module -- this is a "container" into which we'll
     generate actual code *)
  and the_module = L.create_module context "BlueShell" in

  (* Convert BlueShell types to LLVM types *)
  let ltype_of_typ = function
      A.Int     -> i32_t
    | A.Bool    -> i1_t
    | A.Float   -> float_t
    | A.Void    -> void_t
    | A.Char    -> string_t
    | A.String  -> string_t
    | A.Exec    -> exec_t
    | A.List_type ty    -> list_t
    | _ -> raise (Failure "ltype_of_typ fail")
  in
  let execvp_t : L.lltype =
      L.var_arg_function_type i32_t [| L.pointer_type i8_t;  L.pointer_type list_t |] in
  let execvp_func : L.llvalue =
     L.declare_function "execvp_helper" execvp_t the_module in

  (* let *)

  (* the first blocks that appear in the program are the function declarations.
  What should we make the first block in our program for now  *)
  (* let main = L.const_stringz context "main" in *)
  let main_func = L.define_function "main" (L.function_type i32_t [||]) the_module in
  (* Fill in the body of the given function *)
  (* let build_function_body fdecl =
    let (the_function, _) = StringMap.find fdecl.sfname function_decls in
    let builder = L.builder_at_end context (L.entry_block the_function) in *)
  let builder = L.builder_at_end context (L.entry_block main_func) in
  (*let exec : *)
  let rec lookup (curr_symbol_table : symbol_table) s =
    try
      (* Try to find binding in nearest block *)
      StringMap.find s curr_symbol_table.variables
    with Not_found -> (* Try looking in outer blocks *)
      match curr_symbol_table.parent with
        Some(parent) -> lookup parent s
      | _ -> raise (Failure ("codegen identifier not found"))
  in
  let rec expr (curr_symbol_table : symbol_table) builder ((_, e) : sexpr) =
    match e with
      SLiteral x -> (curr_symbol_table, L.const_int i32_t x)
    | SFliteral l -> (curr_symbol_table, L.const_float_of_string float_t l)
    | SBoolLit b -> (curr_symbol_table, L.const_int i1_t (if b then 1 else 0))
    | SId s -> (curr_symbol_table, L.build_load  (lookup curr_symbol_table s) s builder)
    | SChar c -> (curr_symbol_table, L.build_global_stringptr c "char" builder)
    | SString s -> (curr_symbol_table, L.build_global_stringptr s "string" builder)
    | SNoexpr -> (curr_symbol_table, L.const_int i32_t 0)
    | SExec (e1, e2) -> let struct_space = L.build_malloc exec_t "struct_space" builder in
                        let path_ptr = L.build_struct_gep struct_space 0 "path_ptr" builder in
                        let _ = L.build_store (snd (expr curr_symbol_table builder e1)) path_ptr builder in
                        let args_ptr = L.build_struct_gep struct_space 1 "args_ptr" builder in
                        let casted_args_ptr = L.build_pointercast args_ptr (L.pointer_type (L.pointer_type list_t)) "casted_args_ptr" builder in
                        let _ = L.build_store (snd (expr curr_symbol_table builder e2)) casted_args_ptr builder in
                        (curr_symbol_table, struct_space)
    | SBinop (e1, op, e2) ->
      let (t, _) = e1
      in let (curr_symbol_table', e1') = expr curr_symbol_table builder e1
      in let (curr_symbol_table'', e2') = expr curr_symbol_table' builder e2 in
      (match op with
        ExprAssign ->
          let (new_symbol_table, ptr) = expr curr_symbol_table builder e1
          in let (_, e2') = expr curr_symbol_table builder e2 in
          let _ = L.build_store e2' ptr builder in
          (new_symbol_table, e2')
        | Add -> (match t with
          Float -> (curr_symbol_table'', L.build_fadd e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_add e1' e2' "tmp" builder)
          | Exec -> raise (Failure "exec add not implemented yet")
          | _ -> raise (Failure "semant should have caught add with invalid types")
        )
        | Sub -> (match t with
          Float -> (curr_symbol_table'', L.build_fsub e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_sub e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught sub with invalid types")
        )
        | Mult -> (match t with
          Float -> (curr_symbol_table'', L.build_fmul e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_mul e1' e2' "tmp" builder)
          | Exec -> raise (Failure "exec mul not implemented yet")
          | _ -> raise (Failure "semant should have caught mul with invalid types")
        )
        | Div -> (match t with
          Float -> (curr_symbol_table'', L.build_fdiv e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_sdiv e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught div with invalid types")
        )
        | Less -> (match t with
          Float -> (curr_symbol_table'', L.build_fcmp L.Fcmp.Olt e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_icmp L.Icmp.Slt e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught less with invalid types")
        )
        | Leq -> (match t with
          Float -> (curr_symbol_table'', L.build_fcmp L.Fcmp.Ole e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_icmp L.Icmp.Sle e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught leq with invalid types")
        )
        | Greater -> (match t with
          Float -> (curr_symbol_table'', L.build_fcmp L.Fcmp.Ogt e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_icmp L.Icmp.Sgt e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught greater with invalid types")
        )
        | Geq -> (match t with
          Float -> (curr_symbol_table'', L.build_fcmp L.Fcmp.Oge e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_icmp L.Icmp.Sge e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught geq with invalid types")
        )
        | And -> (match t with
          Bool -> (curr_symbol_table'', L.build_and e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught and with invalid types")
        )
        | Or -> (match t with
          Bool -> (curr_symbol_table'', L.build_or e1' e2' "tmp" builder)
          | _ -> raise (Failure "semant should have caught or with invalid types")
        )
        | Equal -> (match t with
          Float -> (curr_symbol_table'', L.build_fcmp L.Fcmp.Oeq e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_icmp L.Icmp.Eq e1' e2' "tmp" builder)
          | _ -> raise (Failure "equals not implemented on other types")
        )
        | Neq -> (match t with
          Float -> (curr_symbol_table'', L.build_fcmp L.Fcmp.One e1' e2' "tmp" builder)
          | Int -> (curr_symbol_table'', L.build_icmp L.Icmp.Ne e1' e2' "tmp" builder)
          | _ -> raise (Failure "equals not implemented on other types")
        )
        | _ -> raise (Failure "not yet implemented other binops")
    )
    | SPreUnop(op, e) -> (match op with
        Run ->
              let (_, exec) = expr curr_symbol_table builder e in

              let path_ptr = L.build_struct_gep exec 0 "path_ptr" builder in
              let path = L.build_load path_ptr "path" builder in
              let args_ptr = L.build_struct_gep exec 1 "args_ptr" builder in
              let args = L.build_load args_ptr "args" builder in
              (curr_symbol_table, L.build_call execvp_func [| path ; args |] "execvp" builder)
      | _   -> raise (Failure "preuop not implemented"))
    | SList l -> (match l with
      [] -> (curr_symbol_table, L.const_pointer_null (L.pointer_type list_t))
                                      (* pointer to first element *)
      | first :: rest -> let (_, value) = expr curr_symbol_table builder first
      in
                        (* allocate space for the element and store *)
                        let value_ptr = L.build_malloc (ltype_of_typ (fst
                        first)) "value_ptr" builder in
                          (* to do: strings are pointers but other things are
                          not *)
                        let _ = L.build_store value value_ptr builder in
                        (* allocate and fill a list node *)

                        let struct_space = L.build_malloc list_t "list_node" builder in
                        let struct_val_ptr = L.build_struct_gep struct_space 0
                        "struct_val_ptr" builder in

                        let struct_ptr_ptr = L.build_struct_gep struct_space 1
                        "struct_ptr_ptr" builder in

                        let (_, list_ptr) = expr curr_symbol_table builder (List_type (fst first), SList(rest))
                        in

                        let casted_ptr_ptr = L.build_pointercast struct_ptr_ptr (L.pointer_type (L.pointer_type list_t)) "casted_ptr_ptr" builder in
                        let _ = L.build_store list_ptr casted_ptr_ptr builder in
                        let casted_val_ptr = L.build_pointercast struct_val_ptr (L.pointer_type (L.pointer_type i8_t)) "casted_val_ptr" builder in
                        let casted_val = L.build_pointercast value_ptr (L.pointer_type i8_t) "casted_val" builder in
                        let _ = L.build_store casted_val casted_val_ptr builder in
                        (* put value of element into the allocated space *)
                        (curr_symbol_table, struct_space ))

                        (* use build store *)
      | SAssign (s, e) -> let (_, e') = expr curr_symbol_table builder e in
                          let _  = L.build_store e' (lookup curr_symbol_table s) builder in (curr_symbol_table, e')
      | SBind (ty, n)  -> let ptr = L.build_malloc ( L.pointer_type (ltype_of_typ ty)) "variable ptr" builder in
                          let new_sym_table = StringMap.add n ptr curr_symbol_table.variables in
                          ({ variables = new_sym_table; parent =
                          curr_symbol_table.parent }, ptr)
      | _ -> raise (Failure "Expression not implemented yet")
  in
  let curr_symbol_table = { variables = StringMap.empty ; parent = None } in
  let rec stmt ((curr_symbol_table : symbol_table), builder) (statement : sstmt) = match statement with
    SExpr e -> let (new_symbol_table, expr_val) = expr curr_symbol_table builder e in ((new_symbol_table, builder), expr_val)
    | _ -> raise (Failure "Statement not implemented yet")
  in
  let _ = (List.fold_left_map stmt (curr_symbol_table, builder) (List.rev stmts)) in
 let _ = L.build_ret (L.const_int i32_t 0) builder  in

  (*
  (* Declare each global variable; remember its value in a map *)
  let global_vars : L.llvalue StringMap.t =
    let global_var m (t, n) =
      let init = match t with
          A.Float -> L.const_float (ltype_of_typ t) 0.0
        | A.String -> L.const_stringz context ""
        | A.Exec   -> L.const_named_struct exec_t [| L.const_stringz context ""; L.const_stringz context "" |]
        | _ -> L.const_int (ltype_of_typ t) 0
      in StringMap.add n (L.define_global n init the_module) m in
    List.fold_left global_var StringMap.empty stmt in *)

  the_module