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

(* type symbol_value = L.llvalue *)

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
  and void_t     = L.void_type context
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
  let rec ltype_of_typ = function
      A.Int     -> i32_t
    | A.Bool    -> i1_t
    | A.Float   -> float_t
    | A.Void    -> void_t
    | A.Char    -> string_t
    | A.String  -> string_t
    | A.Exec    -> exec_t
    | A.List_type ty    -> list_t
    | A.Function (ty_list, ty) -> let ret_type = L.pointer_type (ltype_of_typ ty) in
                                 let ltype_helper ty1 =  (L.pointer_type (ltype_of_typ ty1)) in
                                 let args_type =  Array.of_list (List.map ltype_helper ty_list ) in
    L.function_type ret_type args_type
    | _ -> raise (Failure "ltype_of_typ fail")
  in
  let execvp_t : L.lltype =
      L.var_arg_function_type (L.pointer_type i8_t) [| L.pointer_type i8_t;  L.pointer_type list_t |] in
  let execvp_func : L.llvalue =
     L.declare_function "execvp_helper" execvp_t the_module in
  let fourth x =
    (match x with
    (_, _, _, y) -> y
    | _ -> raise (Failure "not three!"))
  in
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
      | _ -> raise Not_found
  in

  (* let rec func_lookup (curr_symbol_table : symbol_table) function_decls s =
    (* for functions, we want to make sure we don't have links from a higher scope table back down *)
    let rec nested_lookup (curr_symbol_table : symbol_table) s =
      try
        (curr_symbol_table, StringMap.find s curr_symbol_table.variables)
      with Not_found -> (* Try looking in outer blocks *)
        match curr_symbol_table.parent with
          Some(parent) -> nested_lookup parent s
        | _ -> raise (Failure "name not found")
    in

    try
      StringMap.find s function_decls
    with Not_found ->
      let (new_scope, name) = nested_lookup curr_symbol_table s in
      (match name with
        FuncName n ->
          (try StringMap.find n function_decls
          with Not_found ->
            func_lookup new_scope function_decls n)
        | _ -> raise (Failure "not a function"))
  in *)

  let rec expr (curr_symbol_table : symbol_table) function_decls builder (func_llvalue : L.llvalue) ((_, e) : sexpr) =
    match e with
      SLiteral x -> let int_val = L.const_int i32_t x in (* this leaks memory
      but who cares *)
        let int_mem = L.build_alloca i32_t "int_mem" builder in
        let _ = L.build_store int_val int_mem builder in
        (curr_symbol_table, function_decls, builder, int_mem)
    | SFliteral l -> let float_val = L.const_float_of_string float_t l in (* this *)
        let float_mem = L.build_alloca float_t "float_mem" builder in
        let _ = L.build_store float_val float_mem builder in
        (curr_symbol_table, function_decls, builder, float_mem)
    | SBoolLit b -> let bool_val = L.const_int i1_t (if b then 1 else 0) in (* this *)
        let bool_mem = L.build_alloca i1_t "bool_mem" builder in
        let _ = L.build_store bool_val bool_mem builder in
        (curr_symbol_table, function_decls, builder, bool_mem)
    | SId s ->
        let address = lookup curr_symbol_table s in
        (curr_symbol_table, function_decls, builder, L.build_load address s builder)
    | SChar c ->
      let char_ptr = L.build_global_stringptr c "char" builder in
      let dbl_char_ptr = L.build_alloca string_t "double_char_ptr" builder in
      let _ = L.build_store char_ptr dbl_char_ptr builder in
      (curr_symbol_table, function_decls, builder, dbl_char_ptr)
    | SString s ->
      let string_ptr = L.build_global_stringptr s "string" builder in
      let dbl_string_ptr = L.build_alloca string_t "double_string_ptr" builder in
      let _ = L.build_store string_ptr dbl_string_ptr builder in
      (curr_symbol_table, function_decls, builder, dbl_string_ptr)
    | SNoexpr -> (curr_symbol_table, function_decls, builder, L.const_int i32_t 0)
    | SExec (e1, e2) -> let struct_space = L.build_malloc exec_t "struct_space" builder in
                        let path_ptr = L.build_struct_gep struct_space 0 "path_ptr" builder in
                        let (_, _, builder, new_value) = (expr curr_symbol_table function_decls builder func_llvalue e1) in
                        let _ = L.build_store new_value path_ptr builder in
                        let args_ptr = L.build_struct_gep struct_space 1 "args_ptr" builder in
                        let casted_args_ptr = L.build_pointercast args_ptr (L.pointer_type (L.pointer_type list_t)) "casted_args_ptr" builder in
                        let (_, _, builder, new_value') = (expr curr_symbol_table function_decls builder func_llvalue e2) in
                        let _ = L.build_store new_value' casted_args_ptr builder in
                        (curr_symbol_table, function_decls, builder, struct_space)
    | SIndex (e1, e2) ->
      let (curr_symbol_table', new_function_decls, builder, e1') = expr curr_symbol_table function_decls builder func_llvalue e1 in
      let (curr_symbol_table'', new_function_decls', builder, e2') = expr curr_symbol_table' new_function_decls builder func_llvalue e2 in
      let index_val = L.build_load e2' "index_val" builder in
      let e1_pointer = L.build_malloc (L.pointer_type list_t) "e1 pointer" builder in
      let _ = L.build_store e1' e1_pointer builder in

      (* we basically have a while loop that goes until counter == index *)
      let counter_ptr = L.build_malloc i32_t "counter_ptr" builder in
      let _ = L.build_store (L.const_int i32_t 0) counter_ptr builder in
      let pred_bb = L.append_block context "index" func_llvalue in
      let _ = L.build_br pred_bb builder in
      let pred_builder = L.builder_at_end context pred_bb in
      let bool_val = L.build_icmp L.Icmp.Ne index_val (L.build_load counter_ptr "counter" pred_builder) "index pred" pred_builder in

      (* in body of this loop, index to next node *)
      let index_body_bb = L.append_block context "index_body" func_llvalue in
      let index_body_builder = L.builder_at_end context index_body_bb in
      let counter = L.build_add (L.build_load counter_ptr "counter" index_body_builder) (L.const_int i32_t 1) "increment counter" index_body_builder in
      let _ = L.build_store counter counter_ptr index_body_builder in
      let next_ptr_ptr = L.build_struct_gep (L.build_load e1_pointer "get struct" index_body_builder) 1 "next_struct_ptr" index_body_builder in
      let temp = L.build_load next_ptr_ptr "e1' in while loop" index_body_builder in
      let temp' = L.build_pointercast temp ((L.pointer_type list_t)) "temp'" index_body_builder in
      let _ = L.build_store temp' e1_pointer index_body_builder in
      let casted_ptr_ptr = L.build_pointercast temp (L.pointer_type list_t) "casted_ptr_ptr" index_body_builder in
      (* let _ = L.build_store temp e1' builder in *)

      let _ = L.build_store casted_ptr_ptr e1_pointer index_body_builder in
      let _ = L.build_br pred_bb index_body_builder in

      (* once loop is done, dereference ptr to get element *)
      let merge_bb = L.append_block context "merge" func_llvalue in
      let _ = L.build_cond_br bool_val index_body_bb merge_bb pred_builder in
      let merge_body_builder = L.builder_at_end context merge_bb in
      let elem_ptr_ptr = L.build_struct_gep (L.build_load e1_pointer "get struct" merge_body_builder) 0 "elem_ptr_ptr" merge_body_builder in
      let casted_ptr = L.build_pointercast elem_ptr_ptr  (L.pointer_type (L.pointer_type (L.pointer_type i32_t) )) "casted" merge_body_builder in
      let loaded_temp = L.build_load casted_ptr "elem_to_return" merge_body_builder in
      let elem_to_return = L.build_load loaded_temp "elem_to_return" merge_body_builder in
      (curr_symbol_table'', new_function_decls', merge_body_builder, elem_to_return)
    | SBinop (e1, op, e2) ->
      let (t, _) = e1
      in let (curr_symbol_table', new_function_decls, builder, e1') = expr curr_symbol_table function_decls builder func_llvalue e1
      in let (curr_symbol_table'', new_function_decls', builder, e2') = expr curr_symbol_table' new_function_decls builder func_llvalue e2 in
      (match op with
        ExprAssign ->
          let (new_symbol_table, new_function_decls'', builder, ptr) = expr curr_symbol_table new_function_decls' builder func_llvalue e1
          in let (_, _, builder, e2') = expr curr_symbol_table new_function_decls'' builder func_llvalue e2 in
          let e2' = (match (snd e1) with
            SIndex _ -> L.build_load e2' "true_value" builder
            | _ -> e2')
          in
          let _ = L.build_store e2' ptr builder in
          let new_function_decls''' = (match (fst e2) with
                            Function _ -> (match (snd e2) with
                                            SId s1 -> (match (snd e1) with
                                              SBind (ty, n) ->
                                              let mapping = StringMap.find s1 new_function_decls''
                                                        in StringMap.add n mapping new_function_decls''
                                                | _  -> raise (Failure "Only binds can be assigned"))
                                            | _ -> raise (Failure "Only ids can be assigned"))
                            | _ -> new_function_decls'')
          in
          (new_symbol_table, new_function_decls''', builder, e2')
        | Add -> (match t with
          Float ->
            let float_mem = L.build_alloca float_t "int_mem" builder in
            let new_float = L.build_fadd (L.build_load e1' "left side of fadd" builder ) (L.build_load e2' "right side of fadd" builder) "tmp" builder in
            let _ = L.build_store new_float float_mem builder in
            (curr_symbol_table'', function_decls, builder, float_mem)
          | Int ->
            let int_mem = L.build_alloca i32_t "int_mem" builder in
            let new_int = L.build_add (L.build_load e1' "left side of add" builder) (L.build_load e2' "right side of add" builder) "tmp" builder in
            let _ = L.build_store new_int int_mem builder in
            (curr_symbol_table'', function_decls, builder, int_mem)
          | Exec -> raise (Failure "exec add not implemented yet")
          | _ -> raise (Failure "semant should have caught add with invalid types")
        )
        | Sub -> (match t with
          Float ->
            let float_mem = L.build_alloca float_t "int_mem" builder in
            let new_float = L.build_fsub (L.build_load e1' "left side of fsub" builder ) (L.build_load e2' "right side of fsub" builder) "tmp" builder in
            let _ = L.build_store new_float float_mem builder in
            (curr_symbol_table'', function_decls, builder, float_mem)
          | Int ->
            let int_mem = L.build_alloca i32_t "int_mem" builder in
            let new_int = L.build_sub (L.build_load e1' "left side of sub" builder) (L.build_load e2' "right side of sub" builder) "tmp" builder in
            let _ = L.build_store new_int int_mem builder in
            (curr_symbol_table'', function_decls, builder, int_mem)
          | _ -> raise (Failure "semant should have caught sub with invalid types")
        )
        | Mult -> (match t with
          Float ->
            let float_mem = L.build_alloca float_t "int_mem" builder in
            let new_float = L.build_fmul (L.build_load e1' "left side of fmult" builder ) (L.build_load e2' "right side of fmult" builder) "tmp" builder in
            let _ = L.build_store new_float float_mem builder in
            (curr_symbol_table'', function_decls, builder, float_mem)
          | Int ->
            let int_mem = L.build_alloca i32_t "int_mem" builder in
            let new_int = L.build_mul (L.build_load e1' "left side of mult" builder) (L.build_load e2' "right side of mult" builder) "tmp" builder in
            let _ = L.build_store new_int int_mem builder in
            (curr_symbol_table'', function_decls, builder, int_mem)
          | Exec -> raise (Failure "exec mul not implemented yet")
          | _ -> raise (Failure "semant should have caught mul with invalid types")
        )
        | Div -> (match t with
          Float ->
            let float_mem = L.build_alloca float_t "int_mem" builder in
            let new_float = L.build_fdiv (L.build_load e1' "left side of fdiv" builder ) (L.build_load e2' "right side of fdiv" builder) "tmp" builder in
            let _ = L.build_store new_float float_mem builder in
            (curr_symbol_table'', function_decls, builder, float_mem)
          | Int ->
            let int_mem = L.build_alloca i32_t "int_mem" builder in
            let new_int = L.build_sdiv (L.build_load e1' "left side of div" builder) (L.build_load e2' "right side of div" builder) "tmp" builder in
            let _ = L.build_store new_int int_mem builder in
            (curr_symbol_table'', function_decls, builder, int_mem)
          | _ -> raise (Failure "semant should have caught div with invalid types")
        )
        | Less -> (match t with
          Float ->
            let bool_mem = L.build_alloca i1_t "int_mem" builder in
            let new_bool = L.build_fcmp L.Fcmp.Olt (L.build_load e1' "left side of flt" builder) (L.build_load e2' "right side of flt" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | Int ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_icmp L.Icmp.Slt (L.build_load e1' "left side of lt" builder) (L.build_load e2' "right side of lt" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught less with invalid types")
        )
        | Leq -> (match t with
          Float ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_fcmp L.Fcmp.Ole (L.build_load e1' "left side of fleq" builder) (L.build_load e2' "right side of fle" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | Int ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_icmp L.Icmp.Sle (L.build_load e1' "left side of leq" builder) (L.build_load e2' "right side of le" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught leq with invalid types")
        )
        | Greater -> (match t with
          Float ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_fcmp L.Fcmp.Ogt (L.build_load e1' "left side of fgt" builder) (L.build_load e2' "right side of fgt" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | Int ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_icmp L.Icmp.Sgt (L.build_load e1' "left side of gt" builder) (L.build_load e2' "right side of gt" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught gt with invalid types")
        )
        | Geq -> (match t with
          Float ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_fcmp L.Fcmp.Oge (L.build_load e1' "left side of fgeq" builder) (L.build_load e2' "right side of fgeq" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | Int ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_icmp L.Icmp.Sge (L.build_load e1' "left side of geq" builder) (L.build_load e2' "right side of geq" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught geq with invalid types")
        )
        | And -> (match t with
          Bool ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_and (L.build_load e1' "left side of and" builder) (L.build_load e2' "right side of and" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught and with invalid types")
        )
        | Or -> (match t with
          Bool ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_or (L.build_load e1' "left side of or" builder) (L.build_load e2' "right side of or" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught or with invalid types")
        )
        | Equal -> (match t with
           Float ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_fcmp L.Fcmp.Oeq (L.build_load e1' "left side of feq" builder) (L.build_load e2' "right side of feq" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | Int ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_icmp L.Icmp.Eq (L.build_load e1' "left side of eq" builder) (L.build_load e2' "right side of eq" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught eq with invalid types")
        )
        | Neq -> (match t with
          Float ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_fcmp L.Fcmp.One (L.build_load e1' "left side of fneq" builder) (L.build_load e2' "right side of nfeq" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder,bool_mem)
          | Int ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_icmp L.Icmp.Ne (L.build_load e1' "left side of neq" builder) (L.build_load e2' "right side of neq" builder) "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls, builder, bool_mem)
          | _ -> raise (Failure "semant should have caught neq with invalid types")
        )
        | Cons -> let (t2, _) = e2 in
        (match t2 with
            EmptyList -> expr curr_symbol_table function_decls builder func_llvalue (List_type t, (SList [e1]))
            | List_type _ ->
              let value = e1' in
              let enum_type = match (fst e1) with
                        Int -> L.const_int i32_t 0
                        | Float -> L.const_int i32_t 1
                        | Bool -> L.const_int i32_t 2
                        | Char -> L.const_int i32_t 3
                        | String -> L.const_int i32_t 4
                        | _  -> L.const_int i32_t 5
                        in
              (* allocate space for the element and store *)
              let value_ptr = L.build_malloc (L.pointer_type (ltype_of_typ (fst
              e1))) "value_ptr" builder in
              let _ = L.build_store value value_ptr builder in
              (* allocate and fill a list node *)

              (* allocate and fill a list node *)
              let struct_space = L.build_malloc list_t "list_node" builder in
              let struct_val_ptr = L.build_struct_gep struct_space 0
              "struct_val_ptr" builder in
              let struct_ptr_ptr = L.build_struct_gep struct_space 1
              "struct_ptr_ptr" builder in
              let struct_ty_ptr = L.build_struct_gep struct_space 2
              "struct_ty_ptr" builder in
              let list_ptr = e2' in

              let casted_ptr_ptr = L.build_pointercast struct_ptr_ptr (L.pointer_type (L.pointer_type list_t)) "casted_ptr_ptr" builder in
              let _ = L.build_store list_ptr casted_ptr_ptr builder in
              let casted_val_ptr = L.build_pointercast struct_val_ptr (L.pointer_type (L.pointer_type i8_t)) "casted_val_ptr" builder in
              let casted_val = L.build_pointercast value_ptr (L.pointer_type i8_t) "casted_val" builder in
              let casted_ty_ptr = L.build_pointercast struct_ty_ptr (L.pointer_type i32_t) "casted_ty_ptr" builder in
              let casted_ty = L.build_pointercast enum_type i32_t "casted_ty" builder in
              let _ = L.build_store casted_val casted_val_ptr builder in
              let _ = L.build_store casted_ty casted_ty_ptr builder in
              (* put value of element into the allocated space *)
              (curr_symbol_table, function_decls, builder, struct_space )
        )
        | _ -> raise (Failure "not yet implemented other binops")
    )
    | SPreUnop(op, e) -> (match op with
        Run ->
              let (_, _, builder, exec) = expr curr_symbol_table function_decls builder func_llvalue e in

              let dbl_path_ptr = L.build_struct_gep exec 0 "dbl_path_ptr" builder in
              let path_ptr = L.build_load dbl_path_ptr "path_ptr" builder in
              let path = L.build_load path_ptr "path" builder in
              let args_ptr = L.build_struct_gep exec 1 "args_ptr" builder in
              let args = L.build_load args_ptr "args" builder in
              let return_str = L.build_call execvp_func [| path ; args |] "execvp" builder in
              let return_str_ptr = L.build_malloc (L.pointer_type i8_t) "return_str_ptr" builder in
              let return_str_store = L.build_store return_str return_str_ptr builder in
              (curr_symbol_table, function_decls, builder, return_str_ptr)
      | Neg ->
          let (curr_symbol_table'', function_decls', builder, e') = expr curr_symbol_table function_decls builder func_llvalue e in
          let (t,_) = e in
          (match t with
          Float ->

            let float_mem = L.build_alloca float_t "float_mem" builder in
            let new_float =  L.build_fneg (L.build_load e' "neg float" builder ) "tmp" builder in
            let _ = L.build_store new_float float_mem builder in
            (curr_symbol_table'', function_decls', builder, float_mem)
          | Int ->
            (* let (_, _, e') = expr curr_symbol_table function_decls builder e in *)
            let int_mem = L.build_alloca i32_t "int_mem" builder in
            let new_int =L.build_neg (L.build_load e' "neg int" builder) "tmp" builder in
            let _ = L.build_store new_int int_mem builder in
            (curr_symbol_table'', function_decls', builder, int_mem)
          | List_type _ ->  raise (Failure "List remove not implemented")
          | _ -> raise (Failure "semant should have caught neg with invalid types"))
      | Not ->
          let (curr_symbol_table'', function_decls', builder, e') = expr curr_symbol_table function_decls builder func_llvalue e in
          let (t,_) = e in
          (match t with
            Bool ->
            let bool_mem = L.build_alloca i1_t "bool_mem" builder in
            let new_bool = L.build_not (L.build_load e' "not bool" builder)  "tmp" builder in
            let _ = L.build_store new_bool bool_mem builder in
            (curr_symbol_table'', function_decls', builder, bool_mem)
            | _ -> raise (Failure "semant should have caught not invalid type"))
      | _   -> raise (Failure "preuop not implemented"))
    | SList l -> (match l with
      [] -> (curr_symbol_table, function_decls, builder, L.const_pointer_null (L.pointer_type list_t))
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
                        let (_, function_decls', builder, value) = expr curr_symbol_table function_decls builder func_llvalue first
                        in

                        (* allocate space for the element and store *)
                        let value_ptr = L.build_malloc (L.pointer_type (ltype_of_typ (fst
                        first))) "value_ptr" builder in
                          (* to do: strings are pointers but other things are
                          not *)
                        let _ = L.build_store value value_ptr builder in
                        (* allocate and fill a list node *)

                        (* allocate and fill a list node *)
                        let struct_space = L.build_malloc list_t "list_node" builder in
                        let struct_val_ptr = L.build_struct_gep struct_space 0
                        "struct_val_ptr" builder in
                        let struct_ptr_ptr = L.build_struct_gep struct_space 1
                        "struct_ptr_ptr" builder in
                        let struct_ty_ptr = L.build_struct_gep struct_space 2
                        "struct_ty_ptr" builder in

                        let (_, function_decls'', builder, list_ptr) = expr curr_symbol_table function_decls' builder func_llvalue (List_type (fst first), SList(rest))
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
                        (curr_symbol_table, function_decls'', builder, struct_space ))

                        (* use build store *)
      | SAssign (s, e) -> let address = lookup curr_symbol_table s in
                          let (_, function_decls', builder, e') = expr curr_symbol_table function_decls builder func_llvalue e in
                          let _  = L.build_store e' address builder in
                          let new_function_decls = (match (fst e) with
                            Function _ -> (match (snd e) with
                                            SId s1 -> let mapping = StringMap.find s1 function_decls'
                                                      in StringMap.add s mapping function_decls'
                                               | _  -> raise (Failure "Only ids can be assigned"))
                           | _ -> function_decls')
                          in (curr_symbol_table, new_function_decls, builder, e')
                          (* (match address with

                            Llvalue llval ->
                              let (_, e') = expr curr_symbol_table function_decls builder e in
                              let _  = L.build_store e' llval builder in (curr_symbol_table, e')
                          | FuncName _ ->
                            (match e with
                            (_, SId fname) -> let new_vars = StringMap.add s (FuncName(fname)) curr_symbol_table.variables in
                                              ({ variables = new_vars ; parent = curr_symbol_table.parent }, L.const_stringz context fname)
                            | _ -> raise (Failure "semant should have caught assignment to nonexistent function"))) *)
      | SBind (ty, n)  ->
            let ptr = L.build_malloc ( L.pointer_type (ltype_of_typ ty)) "variable ptr" builder in
            let new_sym_table = StringMap.add n ptr curr_symbol_table.variables in
            ({ variables = new_sym_table ; parent = curr_symbol_table.parent }, function_decls, builder, ptr)
        (* (match ty with
          Function _ -> let new_sym_table = StringMap.add n (FuncName("")) curr_symbol_table.variables in
                  ({ variables = new_sym_table ; parent = curr_symbol_table.parent }, L.const_stringz context n)
          | _ ->  let ptr = L.build_malloc ( L.pointer_type (ltype_of_typ ty)) "variable ptr" builder in
                  let new_sym_table = StringMap.add n (Llvalue (ptr)) curr_symbol_table.variables in
                  ({ variables = new_sym_table ; parent = curr_symbol_table.parent }, ptr)) *)
      | SCall (f, args) ->
        let (_, fdecl) = StringMap.find f function_decls in
        let fptr = lookup curr_symbol_table f in
        let fval = L.build_load fptr "fval" builder in
        let llargs = List.map fourth (List.rev (List.map (expr curr_symbol_table function_decls builder func_llvalue) (List.rev args))) in
        let result = (match fdecl.styp with
                      A.Void -> ""
                    | _ -> f ^ "_result") in
        (curr_symbol_table, function_decls, builder, L.build_call fval (Array.of_list llargs) result builder)
        | _ -> raise(Failure "Calling a non function")

      (* | _ -> raise (Failure "Expression not implemented yet") *)
  in
  let curr_symbol_table = { variables = StringMap.empty ; parent = None } in
  let rec stmt ((curr_symbol_table : symbol_table), (function_decls : (L.llvalue * sfunc_decl) StringMap.t), builder, (fdecl_option: sfunc_decl option), (func_llvalue : L.llvalue)) (statement : sstmt) =
    match statement with
      SReturn e -> (match fdecl_option with
        Some(fdecl) ->  (match fdecl.styp with
                      Void -> let _ = L.build_ret_void builder in
                        (curr_symbol_table, function_decls, builder, fdecl_option, func_llvalue)
                      | _ -> let ret_mem = L.build_malloc (ltype_of_typ fdecl.styp) "return malloc" builder in
                              let ret = L.build_load (fourth (expr curr_symbol_table function_decls builder func_llvalue e)) "return load" builder in
                              let _ = L.build_store ret ret_mem builder in
                              let _ = L.build_ret ret_mem builder in
                      (curr_symbol_table, function_decls, builder, fdecl_option, func_llvalue))
      | None -> raise (Failure "semant should have caught return outside of a function"))
    | SBlock sl ->
      let new_symbol_table = { variables = StringMap.empty ; parent = Some curr_symbol_table} in
      List.fold_left stmt (new_symbol_table, function_decls, builder, fdecl_option, func_llvalue) sl
    | SExpr e -> let (new_symbol_table, new_function_decls, builder, expr_val) = expr curr_symbol_table function_decls builder func_llvalue e in (new_symbol_table, new_function_decls, builder, fdecl_option, func_llvalue)
    | SIf (predicate, then_stmt, else_stmt) ->
      let (curr_symbol_table', new_function_decls, builder, bool_val) = expr curr_symbol_table function_decls builder func_llvalue predicate in
      let merge_bb = L.append_block context "merge" func_llvalue in
      let branch_instr = L.build_br merge_bb in
      let then_bb = L.append_block context "then" func_llvalue in
      let (_, _, then_builder, _, _) = stmt (curr_symbol_table', new_function_decls, (L.builder_at_end context then_bb), fdecl_option, func_llvalue) then_stmt in
      let _ = L.build_br merge_bb then_builder in
      let else_bb = L.append_block context "else" func_llvalue in
      let (_, _, else_builder, _, _) = stmt (curr_symbol_table', new_function_decls, (L.builder_at_end context else_bb), fdecl_option, func_llvalue) else_stmt in
      let _ = L.build_br merge_bb else_builder in
      let dereferenced_bool = L.build_load bool_val "bool" builder in
      let _ = L.build_cond_br dereferenced_bool then_bb else_bb builder in
      (curr_symbol_table', new_function_decls, (L.builder_at_end context merge_bb), fdecl_option, func_llvalue)
    | SWhile (predicate, body) ->
      let pred_bb = L.append_block context "while" func_llvalue in
      let _ = L.build_br pred_bb builder in
      let body_bb = L.append_block context "while_body" func_llvalue in
      let (_, _, while_builder, _, _) = stmt (curr_symbol_table, function_decls, (L.builder_at_end context body_bb), fdecl_option, func_llvalue) body in
      let _ = L.build_br pred_bb while_builder in
      let pred_builder = L.builder_at_end context pred_bb in
      let (curr_symbol_table', new_function_decls, builder, bool_val) = expr curr_symbol_table function_decls pred_builder func_llvalue predicate in
      let dereferenced_bool = L.build_load bool_val "bool" pred_builder in
      let merge_bb = L.append_block context "merge" func_llvalue in
      let _ = L.build_cond_br dereferenced_bool body_bb merge_bb pred_builder in
      (curr_symbol_table, new_function_decls, (L.builder_at_end context merge_bb), fdecl_option, func_llvalue)
    | SFor (e1, e2, e3, body) ->
      stmt (curr_symbol_table, function_decls, builder, fdecl_option, func_llvalue) (SBlock [SExpr e1 ; SWhile (e2, SBlock [body ; SExpr e3])])
  in
(* let func_builder = L.builder_at_end context (L.entry_block the_function) in *)
let function_decls : (L.llvalue * sfunc_decl) StringMap.t =
    let function_decl m fdecl =
      let name = fdecl.sfname
      and formal_types =
  Array.of_list (List.map (fun (t,_) -> (L.pointer_type (ltype_of_typ t))) fdecl.sformals)
      in let return_type =
        (match fdecl.styp with
        Void -> void_t
        | _ -> (L.pointer_type (ltype_of_typ fdecl.styp)))
      in let ftype = L.function_type return_type formal_types in
      StringMap.add name (L.define_function name ftype the_module, fdecl) m in
    List.fold_left function_decl StringMap.empty functions
  in
  let func_def name (fdef, fdecl) m =
        let formal_types =
      Array.of_list (List.map (fun (t,_) -> L.pointer_type (ltype_of_typ t)) fdecl.sformals) in
      let return_type =
        (match fdecl.styp with
        Void -> void_t
        | _ -> (L.pointer_type (ltype_of_typ fdecl.styp))) in
      let ftype = L.function_type return_type formal_types in
      let variable = L.build_malloc (L.pointer_type ftype) "function def" main_builder in
      let _ = L.build_store fdef variable main_builder in
      StringMap.add name variable m
    in
  let curr_symbol_table = { variables = StringMap.fold func_def function_decls StringMap.empty ; parent = None } in
  let build_function_body fdecl =
    let (the_function, _) = StringMap.find fdecl.sfname function_decls in
    let func_builder = L.builder_at_end context (L.entry_block the_function) in

    let add_formal ((curr_symbol_table : symbol_table), function_decls) ((t : A.typ), n) p =
      let new_map =
          let old_map = curr_symbol_table.variables in
          let variable = L.build_alloca (L.pointer_type (ltype_of_typ t)) n func_builder in
          let _ = L.build_store p variable func_builder in
          StringMap.add n variable old_map
      in
      let new_function_decls =
          let function_decl m (t , name) =
            (match t with
              A.Function ( _, ty_ret) -> StringMap.add name (L.const_int i32_t 32, { styp = ty_ret; sbody = []; sformals = []; sfname = name }) m
              | _ -> m)
          in List.fold_left function_decl function_decls fdecl.sformals
      in ( { variables = new_map; parent = None }, new_function_decls )
    in
    let ( formals_table, new_function_decls ) = List.fold_left2 add_formal (curr_symbol_table, function_decls) fdecl.sformals
        (Array.to_list (L.params the_function))
    in let _ = (List.fold_left stmt (formals_table, new_function_decls, func_builder, Some fdecl, fst (StringMap.find fdecl.sfname new_function_decls)) (fdecl.sbody))
    in ()
  in
  let _ = List.iter build_function_body functions in

  (* let curr_symbol_table =
         let add_functions (curr_symbol_table : symbol_table) ((t : A.typ), n) p =
            let old_map = curr_symbol_table.variables in
            let variable = L.build_alloca (L.pointer_type (ltype_of_typ t)) n func_builder in
            let _ = L.build_store p variable func_builder in
            let new_map = StringMap.add n (Llvalue(variable)) old_map in
            { variables = new_map ; parent = curr_symbol_table.parent }
      in List.fold_left2 add_formal { variables = StringMap.empty ; parent = None } fdecl.sformals
        (Array.to_list (L.params the_function)) *)
  (* let curr_symbol_table = *)
  let (_, _, curr_builder, _, _) = (List.fold_left stmt (curr_symbol_table, function_decls, main_builder, None, main_func) (List.rev stmts)) in
  let _ = L.build_ret (L.const_int i32_t 0) curr_builder in
  the_module