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
  let list_t     = L.struct_type context [| L.pointer_type i8_t (* value *) ; L.pointer_type i8_t (* next*) ; i32_t |]
  in
  let exec_t     = L.struct_type context [| L.pointer_type string_t (* path *) ; L.pointer_type list_t (* args *) |]
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

  (* the first blocks that appear in the program are the function declarations.
  What should we make the first block in our program for now  *)
  let main_func = L.define_function "main" (L.function_type i32_t [||]) the_module in

  let main_builder = L.builder_at_end context (L.entry_block main_func) in

  let rec lookup (curr_symbol_table : symbol_table) s =
    try
      (* Try to find binding in nearest block *)
      StringMap.find s curr_symbol_table.variables
    with Not_found -> (* Try looking in outer blocks *)
      match curr_symbol_table.parent with
        Some(parent) -> lookup parent s
      | _ -> raise (Failure ("codegen identifier not found"))
  in
  let rec expr (curr_symbol_table : symbol_table) function_decls builder ((_, e) : sexpr) =
    match e with
      SLiteral x -> let int_val = L.const_int i32_t x in (* this leaks memory
      but who cares *)
        let int_mem = L.build_alloca i32_t "int_mem" builder in
        let _ = L.build_store int_val int_mem builder in
        (curr_symbol_table, int_mem)
    | SFliteral l -> let float_val = L.const_float_of_string float_t l in (* this *)
        let float_mem = L.build_alloca float_t "float_mem" builder in
        let _ = L.build_store float_val float_mem builder in
        (curr_symbol_table, float_mem)
    | SBoolLit b -> let bool_val = L.const_int i1_t (if b then 1 else 0) in (* this *)
        let bool_mem = L.build_alloca i1_t "bool_mem" builder in
        let _ = L.build_store bool_val bool_mem builder in
        (curr_symbol_table, bool_mem)
    | SId s -> (curr_symbol_table, L.build_load  (lookup curr_symbol_table s) s builder)
    | SChar c ->
      let char_ptr = L.build_global_stringptr c "char" builder in
      let dbl_char_ptr = L.build_alloca string_t "double_char_ptr" builder in
      let _ = L.build_store char_ptr dbl_char_ptr builder in
      (curr_symbol_table, dbl_char_ptr)
    | SString s ->
      let string_ptr = L.build_global_stringptr s "string" builder in
      let dbl_string_ptr = L.build_alloca string_t "double_string_ptr" builder in
      let _ = L.build_store string_ptr dbl_string_ptr builder in
      (curr_symbol_table, dbl_string_ptr)
    | SNoexpr -> (curr_symbol_table, L.const_int i32_t 0)
    | SExec (e1, e2) -> let struct_space = L.build_malloc exec_t "struct_space" builder in
                        let path_ptr = L.build_struct_gep struct_space 0 "path_ptr" builder in
                        let _ = L.build_store (snd (expr curr_symbol_table function_decls builder e1)) path_ptr builder in
                        let args_ptr = L.build_struct_gep struct_space 1 "args_ptr" builder in
                        let casted_args_ptr = L.build_pointercast args_ptr (L.pointer_type (L.pointer_type list_t)) "casted_args_ptr" builder in
                        let _ = L.build_store (snd (expr curr_symbol_table function_decls builder e2)) casted_args_ptr builder in
                        (curr_symbol_table, struct_space)
    | SBinop (e1, op, e2) ->
      let (t, _) = e1
      in let (curr_symbol_table', e1') = expr curr_symbol_table function_decls builder e1
      in let (curr_symbol_table'', e2') = expr curr_symbol_table' function_decls builder e2 in
      (match op with
        ExprAssign ->
          let (new_symbol_table, ptr) = expr curr_symbol_table function_decls builder e1
          in let (_, e2') = expr curr_symbol_table function_decls builder e2 in
          let _ = L.build_store e2' ptr builder in
          (new_symbol_table, e2')
        | Add -> (match t with
          Float -> (curr_symbol_table'', L.build_fadd (L.build_load e1' "left side of add" builder ) (L.build_load e2' "right side of add" builder) "tmp" builder)
          | Int ->
            let int_mem = L.build_alloca i32_t "int_mem" builder in
            let new_int =L.build_add (L.build_load e1' "left side of add" builder) (L.build_load e2' "right side of add" builder) "tmp" builder in
            let _ = L.build_store new_int int_mem builder in
            (curr_symbol_table'', int_mem)
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
            (* let (exp, sexp) = e in
            (match sexp with 
              (SId _) -> raise (Failure "hello")
              | _ -> raise (Failure "yo"))
              (let enum_val = (match exp with
                List_type Int -> L.const_int i32_t 0
              | List_type Float -> L.const_int i32_t 1
              | List_type Bool -> L.const_int i32_t 2
              | List_type Char -> L.const_int i32_t 3
              | List_type String -> L.const_int i32_t 4
              | _ -> raise (Failure "semant should have caught invalid args type"))
              in *)
              let (_, exec) = expr curr_symbol_table function_decls builder e in

              let dbl_path_ptr = L.build_struct_gep exec 0 "dbl_path_ptr" builder in
              let path_ptr = L.build_load dbl_path_ptr "path_ptr" builder in
              let path = L.build_load path_ptr "path" builder in
              let args_ptr = L.build_struct_gep exec 1 "args_ptr" builder in
              let args = L.build_load args_ptr "args" builder in
              (curr_symbol_table, L.build_call execvp_func [| path ; args |] "execvp" builder)
              (* | _ -> raise (Failure "not an exec in run")) *)
              
      | _   -> raise (Failure "preuop not implemented"))
    | SList l -> (match l with
      [] -> (curr_symbol_table, L.const_pointer_null (L.pointer_type list_t))
                                      (* pointer to first element *)
      | first :: rest ->
                        let enum_type = match (fst first) with
                        Int -> L.const_int i32_t 0
                        | Float -> L.const_int i32_t 1
                        | Bool -> L.const_int i32_t 2
                        | Char -> L.const_int i32_t 3
                        | String -> L.const_int i32_t 4
                        | _  -> L.const_int i32_t 5
                        in
                        let (_, value) = expr curr_symbol_table function_decls builder first
                        in
                        (* let ty_string = L.string_of_lltype (ltype_of_typ (fst
                        first)) in *)
                        (* allocate space for the element and store *)
                        let value_ptr = L.build_malloc (L.pointer_type (ltype_of_typ (fst
                        first))) "value_ptr" builder in
                        (* let ty_ptr = L.build_malloc (L.pointer_type i32_t) "ty_ptr" builder in *)
                          (* to do: strings are pointers but other things are
                          not *)
                        let _ = L.build_store value value_ptr builder in
                        (* allocate and fill a list node *)
                        (* let _ = L.build_store ty_string ty_ptr builder in *)
                        (* allocate and fill a list node *)

                        let struct_space = L.build_malloc list_t "list_node" builder in
                        let struct_val_ptr = L.build_struct_gep struct_space 0
                        "struct_val_ptr" builder in
                        let struct_ty_ptr = L.build_struct_gep struct_space 2
                        "struct_val_ptr" builder in

                        let struct_ptr_ptr = L.build_struct_gep struct_space 1
                        "struct_ptr_ptr" builder in

                        let (_, list_ptr) = expr curr_symbol_table function_decls builder (List_type (fst first), SList(rest))
                        in

                        let casted_ptr_ptr = L.build_pointercast struct_ptr_ptr (L.pointer_type (L.pointer_type list_t)) "casted_ptr_ptr" builder in
                        let _ = L.build_store list_ptr casted_ptr_ptr builder in
                        let casted_val_ptr = L.build_pointercast struct_val_ptr (L.pointer_type (L.pointer_type i8_t)) "casted_val_ptr" builder in
                        let casted_val = L.build_pointercast value_ptr (L.pointer_type i8_t) "casted_val" builder in
                        let casted_ty_ptr = L.build_pointercast struct_ty_ptr (L.pointer_type i32_t) "casted_ty_ptr" builder in
                        let casted_ty = L.build_pointercast enum_type i32_t "casted_ty" builder in
                        let _ = L.build_store casted_val casted_val_ptr builder in
                        let _ = L.build_store casted_ty casted_ty_ptr builder in
                        (* put value of element into the allocated space *)
                        (curr_symbol_table, struct_space ))

                        (* use build store *)
      | SAssign (s, e) -> let (_, e') = expr curr_symbol_table function_decls builder e in
                          let _  = L.build_store e' (lookup curr_symbol_table s) builder in (curr_symbol_table, e')
      | SBind (ty, n)  ->
          let ptr = L.build_malloc ( L.pointer_type (ltype_of_typ ty)) "variable ptr" builder in
                          let new_sym_table = StringMap.add n ptr curr_symbol_table.variables in
                          ({ variables = new_sym_table; parent =
                          curr_symbol_table.parent }, ptr)
      | SCall (f, args) ->
         let (fdef, fdecl)  = StringMap.find f function_decls in
         let llargs = List.map snd (List.rev (List.map  (expr curr_symbol_table function_decls builder) (List.rev args))) in
	        let result = (match fdecl.styp with
                        A.Void -> ""
                      | _ -> f ^ "_result") in
         (curr_symbol_table, L.build_call fdef (Array.of_list llargs) result builder)
         | _ -> raise(Failure "Calling a non function")

      (* | _ -> raise (Failure "Expression not implemented yet") *)
  in
  let curr_symbol_table = { variables = StringMap.empty ; parent = None } in
  let rec stmt ((curr_symbol_table : symbol_table), (function_decls : (L.llvalue * sfunc_decl) StringMap.t), builder) (statement : sstmt) = match statement with
    (* SBlock sl -> List.fold_left stmt (curr_symbol_table, builder) sl *)
    SReturn e -> ((curr_symbol_table, function_decls, builder), L.build_ret_void builder)
    | SExpr e -> let (new_symbol_table, expr_val) = expr curr_symbol_table function_decls builder e in ((new_symbol_table, function_decls, builder), expr_val)
    | _ -> raise (Failure "Statement not implemented yet")
  in
let function_decls : (L.llvalue * sfunc_decl) StringMap.t =
    let function_decl m fdecl =
      let name = fdecl.sfname
      and formal_types =
  Array.of_list (List.map (fun (t,_) -> ltype_of_typ t) fdecl.sformals)
      in let ftype = L.function_type (ltype_of_typ fdecl.styp) formal_types in
      StringMap.add name (L.define_function name ftype the_module, fdecl) m in
    List.fold_left function_decl StringMap.empty functions in

  let build_function_body fdecl =
    let (the_function, _) = StringMap.find fdecl.sfname function_decls in
    let func_builder = L.builder_at_end context (L.entry_block the_function) in

    let add_formal (curr_symbol_table : symbol_table) (t, n) p =
      let old_map = curr_symbol_table.variables in
      let variable = L.build_alloca (ltype_of_typ t) n func_builder in
      let _ = L.build_store p variable func_builder in
      let new_map = StringMap.add n variable old_map in
      { variables = new_map ; parent = curr_symbol_table.parent }
    in
    let formals_table = List.fold_left2 add_formal { variables = StringMap.empty ; parent = None } fdecl.sformals
        (Array.to_list (L.params the_function))
    in let _ = (List.fold_left_map stmt (formals_table, function_decls, func_builder) (fdecl.sbody))
    in ()
  in
  let _ = List.iter build_function_body functions in
  let _ = (List.fold_left_map stmt (curr_symbol_table, function_decls, main_builder) (List.rev stmts)) in
  let _ = L.build_ret (L.const_int i32_t 0) main_builder in
  the_module