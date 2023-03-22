module L = Llvm
module A = Ast
open Sast
(* todo
 * variable declaration
 * assign 
 * executable 
 * Run
 *)

module StringMap = Map.Make(String)

let translate (stmts, functions) =
  let context = L.global_context () in
  (* Add types to the context so we can use them in our LLVM code *)
  let i32_t      = L.i32_type    context
  and i8_t       = L.i8_type     context
  and i1_t       = L.i1_type     context
  and float_t    = L.double_type context
  and void_t     = L.void_type   context 
  (* in
  let string_t   = L.vector_type i8_t 10; context *)
  (* Create an LLVM module -- this is a "container" into which we'll 
     generate actual code *)
  and the_module = L.create_module context "BlueShell" in

  (* Convert MicroC types to LLVM types *)
  let ltype_of_typ = function
      A.Int     -> i32_t
    | A.Bool    -> i1_t
    | A.Float   -> float_t
    | A.Void    -> void_t
    | A.Char    -> i8_t
    | _ -> raise (Failure "wat")
  in

  the_module