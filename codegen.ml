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
  let exec_t     = L.struct_type context [| string_t (* path *) ; list_t (* args *) |]
  (* Create an LLVM module -- this is a "container" into which we'll
     generate actual code *)
  and the_module = L.create_module context "BlueShell" in

  (* Convert BlueShell types to LLVM types *)
  let ltype_of_typ = function
      A.Int     -> i32_t
    | A.Bool    -> i1_t
    | A.Float   -> float_t
    | A.Void    -> void_t
    | A.Char    -> i8_t
    | A.String  -> string_t
    | A.Exec    -> exec_t
    | A.List_type ty    -> list_t
    | _ -> raise (Failure "ltype_of_typ fail")
  in
  let execvp_t : L.lltype =
      L.var_arg_function_type i32_t [| L.pointer_type i8_t;  L.pointer_type (L.pointer_type i8_t)|] in
  let execvp_func : L.llvalue =
     L.declare_function "execvp_helper" execvp_t the_module in

  (* the first blocks that appear in the program are the function declarations.
  What should we make the first block in our program for now  *)
  let main = L.const_stringz context "main" in
  let main_func = L.define_function "main" (L.function_type i32_t [||]) the_module in
  (* Fill in the body of the given function *)
  (* let build_function_body fdecl =
    let (the_function, _) = StringMap.find fdecl.sfname function_decls in
    let builder = L.builder_at_end context (L.entry_block the_function) in *)
  let builder = L.builder_at_end context (L.entry_block main_func) in
  (*let exec : *)
  let rec expr builder ((_, e) : sexpr) = match e with
      SString s -> (*let string_ptr = *)L.build_global_stringptr s "" builder (*in
                   let string = L.const_string context s in

                   let _ = L.build_store string string_ptr builder in string_ptr*)(* first s is string
      value to put in memory, second s is name *)
                                              (* string name + list of args(can
                                              empty ) *)
    | SLiteral x -> L.const_int i32_t x
    | SExec (e1, e2) -> (*let struct_wtf = L.const_struct context [| expr builder e1 ; expr builder e2 |] in*)
                        let struct_space = L.build_malloc exec_t "" builder in

                        let path_ptr = L.build_struct_gep struct_space 0 ""
                        builder in
                        let _ = L.build_store (expr builder e1) path_ptr builder in
                        (*
                        in let list_ptr = L.build_struct_gep struct_space 1 ""
                        builder in
                        list_ptr
                        let _ = L.build_store (expr builder e2) list_ptr builder in*)
                        struct_space
    (*L.const_struct context [| expr builder e1 ; expr builder e2 |]*)
    | SPreUnop(op, e) -> (match op with
        Run -> let exec = expr builder e in
              let second_arg =  L.const_pointer_null (L.pointer_type i8_t) in
              let double_pointer = L.build_malloc (L.pointer_type i8_t) "" builder in
              let _ = L.build_store second_arg double_pointer builder in
              let path_ptr = L.build_struct_gep exec 0 "" builder in

              let path = L.build_load path_ptr "" builder in

              L.build_call execvp_func [| path; double_pointer |] "execvp" builder
      | _   -> raise (Failure "preuop not implemented"))
    | SList l -> (match l with
      [] -> L.const_pointer_null list_t
                                      (* pointer to first element *)
      | first :: rest -> let value = L.build_malloc (ltype_of_typ (fst first)) ""
      builder in
                          (* to do: strings are pointers but other things are
                          not *)
                         let first_elem = expr builder first in
                         (* put value of element into the allocated space *)
                         let _ =  L.build_store first_elem value builder in
                         let head_ptr = L.build_malloc list_t "" builder in
                                          (* pointer to rest of list *)
                         let slist = (A.List_type (fst first), SList(rest)) in
                         let rest_SList = expr builder slist
                         (* rest of the list *)
                                  (* make struct and put values in there *)
                         in let head = L.const_struct context [| first_elem ; rest_SList|] in
                         (* put the struct into the place in memory  *)
                         let _ = L.build_store head head_ptr builder
                         in head_ptr )

                        (* use build store *)
      | _ -> raise (Failure "Expression not implemented yet")
  in
  let rec stmt builder (statement : sstmt) = match statement with
    SExpr e -> let expr_val = expr builder e in (builder, expr_val)
  (*| SPreUnop (uop, e) -> *)
  | _ -> raise (Failure "Statement not implemented yet")
  in
  let _ = (List.fold_left_map stmt builder stmts) in
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