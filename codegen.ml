module L = Llvm
module A = Ast
open Sast

module StringMap = Map.Make(String)

type symbol_table = {
  (* Variables bound in current block *)
  variables : L.llvalue StringMap.t;
  (* Enclosing scope *)
  parent : symbol_table option;
}

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
  in
  let complex_exec_t = L.struct_type context [| i1_t (* 0 for simple, 1 for complex *) ; L.pointer_type i8_t (* left operand *) ; L.pointer_type i8_t (* right operand *) ; i32_t (* op *) |]

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
    | A.Exec    -> complex_exec_t
    | A.ComplexExec -> complex_exec_t
    | A.List_type ty    -> list_t
    | A.Function (ty_list, ty) -> let ret_type = L.pointer_type (ltype_of_typ ty) in
                                 let ltype_helper ty1 =  (L.pointer_type (ltype_of_typ ty1)) in
                                 let args_type =  Array.of_list (List.map ltype_helper ty_list ) in
    L.function_type ret_type args_type
    | _ -> raise (Failure "ltype_of_typ fail")
  in

  (* Define and link execvp helper *)
  let execvp_t : L.lltype =
      L.var_arg_function_type (L.pointer_type i8_t) [| L.pointer_type i8_t;  L.pointer_type list_t |] in
  let execvp_func : L.llvalue =
     L.declare_function "execvp_helper" execvp_t the_module in
  let recurse_exec_t : L.lltype =
      L.var_arg_function_type (L.pointer_type i8_t) [| L.pointer_type complex_exec_t |] in
  let recurse_exec_func : L.llvalue =
     L.declare_function "recurse_exec" recurse_exec_t the_module in

  (* Helper function, since the llvalue being returned from expr is the 4th elem of a tuple *)
  let fourth x =
    (match x with
    (_, _, _, y) -> y)
  in

  (* Make a fake "main" that contains our toplevel statements *)
  let main_func = L.define_function "main" (L.function_type i32_t [||]) the_module in
  let main_builder = L.builder_at_end context (L.entry_block main_func) in

  (* Helper function to find a name in a symbol table *)
  let rec lookup (curr_symbol_table : symbol_table) s =
    try
      (* Try to find binding in nearest block *)
      StringMap.find s curr_symbol_table.variables
    with Not_found -> (* Try looking in outer blocks *)
      match curr_symbol_table.parent with
        Some(parent) -> lookup parent s
      | _ -> raise Not_found
  in

  let rec expr (curr_symbol_table : symbol_table) function_decls builder (func_llvalue : L.llvalue) ((_, e) : sexpr) =
    (* All literals are allocated on the stack, with pointers to them being returned *)
    match e with
      SLiteral x -> let int_val = L.const_int i32_t x in
        let int_mem = L.build_alloca i32_t "int_mem" builder in
        let _ = L.build_store int_val int_mem builder in
        (curr_symbol_table, function_decls, builder, int_mem)
    | SFliteral l -> let float_val = L.const_float_of_string float_t l in
        let float_mem = L.build_alloca float_t "float_mem" builder in
        let _ = L.build_store float_val float_mem builder in
        (curr_symbol_table, function_decls, builder, float_mem)
    | SBoolLit b -> let bool_val = L.const_int i1_t (if b then 1 else 0) in
        let bool_mem = L.build_alloca i1_t "bool_mem" builder in
        let _ = L.build_store bool_val bool_mem builder in
        (curr_symbol_table, function_decls, builder, bool_mem)
    | SId s ->
        (* Dereference a pointer to the variable's memory location *)
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
    | SExec (e1, e2) ->
      (* Create space for an exec struct, populate it, and return the pointer *)
      let struct_space = L.build_malloc exec_t "struct_space" builder in
      let path_ptr = L.build_struct_gep struct_space 0 "path_ptr" builder in
      let (_, _, builder, new_value) = (expr curr_symbol_table function_decls builder func_llvalue e1) in
      let _ = L.build_store new_value path_ptr builder in
      let args_ptr = L.build_struct_gep struct_space 1 "args_ptr" builder in
      let casted_args_ptr = L.build_pointercast args_ptr (L.pointer_type (L.pointer_type list_t)) "casted_args_ptr" builder in
      let (_, _, builder, new_value') = (expr curr_symbol_table function_decls builder func_llvalue e2) in
      let _ = L.build_store new_value' casted_args_ptr builder in
      let complex_exec_space = L.build_malloc complex_exec_t "complex exec struct" builder in
      let bool_ptr = L.build_struct_gep complex_exec_space 0 "complex bool" builder in
      let exec_ptr = L.build_struct_gep complex_exec_space 1 "complex e1" builder in
      let _ = L.build_store (L.const_int i1_t 1) bool_ptr builder in
      let casted_struct_space = L.build_pointercast struct_space (L.pointer_type i8_t) "casted_malloc" builder in
      let _ = L.build_store casted_struct_space exec_ptr builder in
      (curr_symbol_table, function_decls, builder, complex_exec_space)
    | SIndex (e1, e2) ->
      (* Get the list pointer and the index value *)
      let (curr_symbol_table', new_function_decls, builder, e1') = expr curr_symbol_table function_decls builder func_llvalue e1 in
      let (curr_symbol_table'', new_function_decls', builder, e2') = expr curr_symbol_table' new_function_decls builder func_llvalue e2 in
      let index_val = L.build_load e2' "index_val" builder in
      let e1_pointer = L.build_malloc (L.pointer_type list_t) "e1 pointer" builder in
      let _ = L.build_store e1' e1_pointer builder in

      (* Basically have a while loop that goes until counter == index *)
      let counter_ptr = L.build_malloc i32_t "counter_ptr" builder in
      let _ = L.build_store (L.const_int i32_t 0) counter_ptr builder in
      let pred_bb = L.append_block context "index" func_llvalue in
      let _ = L.build_br pred_bb builder in
      let pred_builder = L.builder_at_end context pred_bb in
      let bool_val = L.build_icmp L.Icmp.Ne index_val (L.build_load counter_ptr "counter" pred_builder) "index pred" pred_builder in

      (* In body of this loop, index to next node *)
      let index_body_bb = L.append_block context "index_body" func_llvalue in
      let index_body_builder = L.builder_at_end context index_body_bb in
      let counter = L.build_add (L.build_load counter_ptr "counter" index_body_builder) (L.const_int i32_t 1) "increment counter" index_body_builder in
      let _ = L.build_store counter counter_ptr index_body_builder in
      let next_ptr_ptr = L.build_struct_gep (L.build_load e1_pointer "get struct" index_body_builder) 1 "next_struct_ptr" index_body_builder in
      let temp = L.build_load next_ptr_ptr "e1' in while loop" index_body_builder in
      let temp' = L.build_pointercast temp ((L.pointer_type list_t)) "temp'" index_body_builder in
      let _ = L.build_store temp' e1_pointer index_body_builder in
      let casted_ptr_ptr = L.build_pointercast temp (L.pointer_type list_t) "casted_ptr_ptr" index_body_builder in

      let _ = L.build_store casted_ptr_ptr e1_pointer index_body_builder in
      let _ = L.build_br pred_bb index_body_builder in

      (* Once loop is done, dereference ptr to get element *)
      let merge_bb = L.append_block context "merge" func_llvalue in
      let _ = L.build_cond_br bool_val index_body_bb merge_bb pred_builder in
      let merge_body_builder = L.builder_at_end context merge_bb in
      let elem_ptr_ptr = L.build_struct_gep (L.build_load e1_pointer "get struct" merge_body_builder) 0 "elem_ptr_ptr" merge_body_builder in

      (* Cast pointer to the type of the list element *)
      let ty = (match (fst e1) with
              List_type typ  -> typ
              | _ -> raise (Failure "should have been caught in semant"))
      in
      let casted_ptr = L.build_pointercast elem_ptr_ptr  (L.pointer_type (L.pointer_type (L.pointer_type (ltype_of_typ ty)) )) "casted" merge_body_builder in
      let loaded_temp = L.build_load casted_ptr "elem_to_return" merge_body_builder in
      let elem_to_return = L.build_load loaded_temp "elem_to_return" merge_body_builder in
      (curr_symbol_table'', new_function_decls', merge_body_builder, elem_to_return)
    | SBinop (e1, op, e2) ->
      let (t, _) = e1
      in let (curr_symbol_table', new_function_decls, builder, e1') = expr curr_symbol_table function_decls builder func_llvalue e1
      in let (curr_symbol_table'', new_function_decls', builder, e2') = expr curr_symbol_table' new_function_decls builder func_llvalue e2 in
      (match op with
        ExprAssign ->
          let e2' = (match (snd e1) with
            (* Special cases for index and path because those need to dereference the value being assigned to them *)
            SIndex _ -> L.build_load e2' "true_value" builder
            | SPreUnop (Path, _ ) -> L.build_load e2' "true_value" builder
            | _ -> e2')
          in
          let _ = L.build_store e2' e1' builder in
          let new_function_decls'' =
          (* If it's a function variable, update the function_decls *)
          (match (fst e2) with
              Function _ -> (match (snd e2) with
                              SId s1 -> (match (snd e1) with
                                SBind (ty, n) ->
                                let mapping = StringMap.find s1 new_function_decls'
                                          in StringMap.add n mapping new_function_decls'
                                  | _  -> raise (Failure "Only binds can be assigned"))
                              | _ -> raise (Failure "Only ids can be assigned"))
              | _ -> new_function_decls')
          in
          (curr_symbol_table'', new_function_decls'', builder, e2')
        (* For operations, need to dereference both sides and store the result back to the memory location *)
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
          | Exec | ComplexExec ->
            let complex_exec_space = L.build_malloc complex_exec_t "complex exec struct" builder in
            let bool_ptr = L.build_struct_gep complex_exec_space 0 "complex bool" builder in
            let exec1_ptr = L.build_struct_gep complex_exec_space 1 "complex e1" builder in
            let exec2_ptr = L.build_struct_gep complex_exec_space 2 "complex e2" builder in
            let op_ptr = L.build_struct_gep complex_exec_space 3 "complex op" builder in
            let _ = L.build_store (L.const_int i1_t 0) bool_ptr builder in
            let casted_e1 = L.build_pointercast e1' (L.pointer_type i8_t) "casted_e1" builder in
            let _ = L.build_store casted_e1 exec1_ptr builder in
            let casted_e2 = L.build_pointercast e2' (L.pointer_type i8_t) "casted_e2" builder in
            let _ = L.build_store casted_e2 exec2_ptr builder in
            let _ = L.build_store (L.const_int i32_t 0) op_ptr builder in
            (curr_symbol_table'', function_decls, builder, complex_exec_space)

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
          | Exec | ComplexExec ->
            let complex_exec_space = L.build_malloc complex_exec_t "complex exec struct" builder in
            let bool_ptr = L.build_struct_gep complex_exec_space 0 "complex bool" builder in
            let exec1_ptr = L.build_struct_gep complex_exec_space 1 "complex e1" builder in
            let exec2_ptr = L.build_struct_gep complex_exec_space 2 "complex e2" builder in
            let op_ptr = L.build_struct_gep complex_exec_space 3 "complex op" builder in
            let _ = L.build_store (L.const_int i1_t 0) bool_ptr builder in
            let casted_e1 = L.build_pointercast e1' (L.pointer_type i8_t) "casted_e1" builder in
            let _ = L.build_store casted_e1 exec1_ptr builder in
            let casted_e2 = L.build_pointercast e2' (L.pointer_type i8_t) "casted_e2" builder in
            let _ = L.build_store casted_e2 exec2_ptr builder in
            let _ = L.build_store (L.const_int i32_t 1) op_ptr builder in
            (curr_symbol_table'', function_decls, builder, complex_exec_space)
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
            (* Cons to an empty list means we need to make a new list *)
            EmptyList -> expr curr_symbol_table function_decls builder func_llvalue (List_type t, (SList [e1]))
            (* Cons to an existing list means that we need to append a new node to an already existing head and move the head to the new node *)
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
            | _ -> raise (Failure "incorrect type in cons"))
        | Pipe ->
            let complex_exec_space = L.build_malloc complex_exec_t "complex exec struct" builder in
            let bool_ptr = L.build_struct_gep complex_exec_space 0 "complex bool" builder in
            let exec1_ptr = L.build_struct_gep complex_exec_space 1 "complex e1" builder in
            let exec2_ptr = L.build_struct_gep complex_exec_space 2 "complex e2" builder in
            let op_ptr = L.build_struct_gep complex_exec_space 3 "complex op" builder in
            let _ = L.build_store (L.const_int i1_t 0) bool_ptr builder in
            let casted_e1 = L.build_pointercast e1' (L.pointer_type i8_t) "casted_e1" builder in
            let _ = L.build_store casted_e1 exec1_ptr builder in
            let casted_e2 = L.build_pointercast e2' (L.pointer_type i8_t) "casted_e2" builder in
            let _ = L.build_store casted_e2 exec2_ptr builder in
            let _ = L.build_store (L.const_int i32_t 2) op_ptr builder in
            (curr_symbol_table'', function_decls, builder, complex_exec_space)
    )
    | SPreUnop(op, e) -> (match op with
        Run ->
          (* Grab path and args from exec struct and pass to execvp *)
          let (_, _, builder, exec) = expr curr_symbol_table function_decls builder func_llvalue e in

          (* Determine whether to recurse or not *)
          let complex_bool_ptr = L.build_struct_gep exec 0 "complex_bool_ptr" builder in
          let complex_bool = L.build_load complex_bool_ptr "complex_bool" builder in
          let return_str_ptr = L.build_malloc (L.pointer_type i8_t) "return_str_ptr" builder in

          (* Connect then block for simple executables *)
          let merge_bb = L.append_block context "merge" func_llvalue in
          let then_bb = L.append_block context "then" func_llvalue in
          let then_builder = L.builder_at_end context then_bb in

          (* Build then block for simple executables *)
          let simple_exec_ptr = L.build_struct_gep exec 1 "exec_ptr" then_builder in
          let casted_ptr = L.build_pointercast simple_exec_ptr (L.pointer_type (L.pointer_type exec_t)) "cast_run" then_builder in
          let simple_exec = L.build_load casted_ptr "exec" then_builder in

          let dbl_path_ptr = L.build_struct_gep simple_exec 0 "dbl_path_ptr" then_builder in
          let path_ptr = L.build_load dbl_path_ptr "path_ptr" then_builder in
          let path = L.build_load path_ptr "path" then_builder in
          let args_ptr = L.build_struct_gep simple_exec 1 "args_ptr" then_builder in
          let args = L.build_load args_ptr "args" then_builder in

          (* Execvp will convert from our list representation to the array needed *)
          let return_str = L.build_call execvp_func [| path ; args |] "execvp" then_builder in
          let _ = L.build_store return_str return_str_ptr then_builder in
          let _ = L.build_br merge_bb then_builder in
          (* End of then block *)

          (* Build else block for complex executables *)
          let else_bb = L.append_block context "else" func_llvalue in
          let else_builder = L.builder_at_end context else_bb in

          let return_str = L.build_call recurse_exec_func [| exec |] "recurse_exec" else_builder in
          let _ = L.build_store return_str return_str_ptr else_builder in

          (* After switch statement, finish getting the resulting string *)
          let _ = L.build_br merge_bb else_builder in
          (* End of else block *)

          (* Execute correct code depending on whether the executable is complex or not *)
          let _ = L.build_cond_br complex_bool then_bb else_bb builder in

          (curr_symbol_table, function_decls, (L.builder_at_end context merge_bb), return_str_ptr)
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
      | Path ->
          (* Get a pointer to the path of a list *)
          let (curr_symbol_table', function_decls', builder, comp_exec) = expr curr_symbol_table function_decls builder func_llvalue e in
          let simple_exec_ptr = L.build_struct_gep comp_exec 1 "exec_ptr" builder in
          let casted_ptr = L.build_pointercast simple_exec_ptr (L.pointer_type (L.pointer_type exec_t)) "cast_run" builder in
          let simple_exec = L.build_load casted_ptr "exec" builder in
          let dbl_path_ptr = L.build_struct_gep simple_exec 0 "dbl_path_ptr" builder in
          let path_ptr = L.build_load dbl_path_ptr "path_ptr" builder in
          (curr_symbol_table', function_decls', builder, path_ptr)
      | Length ->
          (* Get the list pointer and the index value *)
          let (curr_symbol_table', new_function_decls, builder, e1') = expr curr_symbol_table function_decls builder func_llvalue e in

          let e1_pointer = L.build_malloc (L.pointer_type list_t) "e1 pointer" builder in
          let _ = L.build_store e1' e1_pointer builder in

          (* Basically have a while loop that goes until counter == index *)
          let counter_ptr = L.build_malloc i32_t "counter_ptr" builder in
          let _ = L.build_store (L.const_int i32_t 0) counter_ptr builder in
          let pred_bb = L.append_block context "length" func_llvalue in
          let _ = L.build_br pred_bb builder in
          let pred_builder = L.builder_at_end context pred_bb in

          let bool_mem = L.build_malloc i1_t "bool_mem" pred_builder in
          let _ = L.build_store (L.build_is_not_null (L.build_load e1_pointer "" pred_builder) "" pred_builder) bool_mem pred_builder in

          (* In body of this loop, traverse to next node *)
          let index_body_bb = L.append_block context "index_body" func_llvalue in
          let index_body_builder = L.builder_at_end context index_body_bb in
          let counter = L.build_add (L.build_load counter_ptr "counter" index_body_builder) (L.const_int i32_t 1) "increment counter" index_body_builder in
          let _ = L.build_store counter counter_ptr index_body_builder in
          let next_ptr_ptr = L.build_struct_gep (L.build_load e1_pointer "get struct" index_body_builder) 1 "next_struct_ptr" index_body_builder in
          let temp = L.build_load next_ptr_ptr "e1' in while loop" index_body_builder in
          let temp' = L.build_pointercast temp ((L.pointer_type list_t)) "temp'" index_body_builder in
          let _ = L.build_store temp' e1_pointer index_body_builder in
          let casted_ptr_ptr = L.build_pointercast temp (L.pointer_type list_t) "casted_ptr_ptr" index_body_builder in

          let _ = L.build_store casted_ptr_ptr e1_pointer index_body_builder in
          let _ = L.build_br pred_bb index_body_builder in

          (* Once loop is done, return counter *)
          let merge_bb = L.append_block context "merge" func_llvalue in
          let _ = L.build_cond_br (L.build_load bool_mem "bool_mem" pred_builder) index_body_bb merge_bb pred_builder in
          let merge_body_builder = L.builder_at_end context merge_bb in

          (curr_symbol_table', new_function_decls, merge_body_builder, counter_ptr)
      | _   -> raise (Failure "preuop not implemented"))
    | SList l -> (* Returns a pointer to the first node in the list *)
      (match l with
      [] -> (curr_symbol_table, function_decls, builder, L.const_pointer_null (L.pointer_type list_t))
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
      | SAssign (s, e) ->
          (* Get memory associated with a variable and update it *)
          let address = lookup curr_symbol_table s in
          let (_, function_decls', builder, e') = expr curr_symbol_table function_decls builder func_llvalue e in
          let _  = L.build_store e' address builder in
          let new_function_decls = (match (fst e) with
            Function _ -> (match (snd e) with
                            SId s1 -> let mapping = StringMap.find s1 function_decls'
                                      in StringMap.add s mapping function_decls'
                                | _  -> raise (Failure "Only ids can be assigned"))
            | _ -> function_decls')
          in (curr_symbol_table, new_function_decls, builder, e')
      | SBind (ty, n)  ->
          (* Bind is the only case where we need to allocate memory corresponding to a variable *)
          let ptr = L.build_malloc ( L.pointer_type (ltype_of_typ ty)) "variable ptr" builder in
          let new_sym_table = StringMap.add n ptr curr_symbol_table.variables in
          ({ variables = new_sym_table ; parent = curr_symbol_table.parent }, function_decls, builder, ptr)
      | SCall (f, args) ->
        (* Get all the variables for args, pass them to the function *)
        let (_, fdecl) = StringMap.find f function_decls in
        let fptr = lookup curr_symbol_table f in

        (* All functions are held as pointers to the address of the function, so dereference *)
        let fval = L.build_load fptr "fval" builder in
        let llargs = List.map fourth (List.rev (List.map (expr curr_symbol_table function_decls builder func_llvalue) (List.rev args))) in
        let result = (match fdecl.styp with
                      A.Void -> ""
                    | _ -> f ^ "_result") in
        (curr_symbol_table, function_decls, builder, L.build_call fval (Array.of_list llargs) result builder)
        | _ -> raise(Failure "Calling a non function")
  in
  let rec stmt ((curr_symbol_table : symbol_table), (function_decls : (L.llvalue * sfunc_decl) StringMap.t), builder, (fdecl_option: sfunc_decl option), (func_llvalue : L.llvalue)) (statement : sstmt) =
    match statement with
      SReturn e -> (match fdecl_option with
        Some(fdecl) ->
          (* Get the function return type and build the right return *)
          (match fdecl.styp with
            Void -> let _ = L.build_ret_void builder in
              (curr_symbol_table, function_decls, builder, fdecl_option, func_llvalue)
            | _ -> let ret_mem = L.build_malloc (ltype_of_typ fdecl.styp) "return malloc" builder in
                    let ret = L.build_load (fourth (expr curr_symbol_table function_decls builder func_llvalue e)) "return load" builder in
                    let _ = L.build_store ret ret_mem builder in
                    let _ = L.build_ret ret_mem builder in
            (curr_symbol_table, function_decls, builder, fdecl_option, func_llvalue))
      | None -> raise (Failure "semant should have caught return outside of a function"))
    | SBlock sl ->
      (* Fold stmt over a block *)
      let new_symbol_table = { variables = StringMap.empty ; parent = Some curr_symbol_table} in
      List.fold_left stmt (new_symbol_table, function_decls, builder, fdecl_option, func_llvalue) sl
    | SExpr e ->
      (* Evaluate an expression, but may possible lead to changes in the function_decls or builder *)
      let (new_symbol_table, new_function_decls, builder, expr_val) = expr curr_symbol_table function_decls builder func_llvalue e in (new_symbol_table, new_function_decls, builder, fdecl_option, func_llvalue)
    | SIf (predicate, then_stmt, else_stmt) ->
      (* Branch and return new builder to continue building from *)
      let (curr_symbol_table', new_function_decls, builder, bool_val) = expr curr_symbol_table function_decls builder func_llvalue predicate in
      let merge_bb = L.append_block context "merge" func_llvalue in
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
      (* Branch and return new builder to continue building from *)
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
      (* Branch and return new builder to continue building from *)
      stmt (curr_symbol_table, function_decls, builder, fdecl_option, func_llvalue) (SBlock [SExpr e1 ; SWhile (e2, SBlock [body ; SExpr e3])])
  in

  (* Define addresses for the body of each function to go *)
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

  (* Helper function to add pointers to each global function to a map *)
  let func_def name (fdef, fdecl) (m, builder) =
    let formal_types =
      Array.of_list (List.map (fun (t,_) -> L.pointer_type (ltype_of_typ t)) fdecl.sformals) in
    let return_type =
      (match fdecl.styp with
      Void -> void_t
      | _ -> (L.pointer_type (ltype_of_typ fdecl.styp))) in
    let ftype = L.function_type return_type formal_types in
    let variable = L.build_alloca (L.pointer_type ftype) "function def" builder in
    let _ = L.build_store fdef variable builder in
    (StringMap.add name variable m, builder)
  in

  (* Add every function to the main scope *)
  let curr_symbol_table = { variables = (fst (StringMap.fold func_def function_decls (StringMap.empty, main_builder))) ; parent = None }
  in

  (* Build the body of each function using the addresses corresponding to each one *)
  let build_function_body fdecl =
    let (the_function, _) = StringMap.find fdecl.sfname function_decls in
    let func_builder = L.builder_at_end context (L.entry_block the_function) in

    (* Use a symbol table that contains all the globally defined function *)
    let curr_symbol_table = { variables = (fst (StringMap.fold func_def function_decls (StringMap.empty, func_builder))) ; parent = None } in

    (* Create space for parameters *)
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

    (* Go through the statements in each function body *)
    in let _ = (List.fold_left stmt (formals_table, new_function_decls, func_builder, Some fdecl, fst (StringMap.find fdecl.sfname new_function_decls)) (fdecl.sbody))
    in ()
  in

  (* Build all functions *)
  let _ = List.iter build_function_body functions in

  (* Build all toplevel statements *)
  let (_, _, curr_builder, _, _) = (List.fold_left stmt (curr_symbol_table, function_decls, main_builder, None, main_func) (List.rev stmts)) in

  (* Wherever the program finishes, make that basic block return 0 *)
  let _ = L.build_ret (L.const_int i32_t 0) curr_builder in
  the_module