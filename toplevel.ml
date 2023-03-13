(* toplevel.ml *)
(* BlueShell *)
(* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom *)

open Ast
open Sast

(* type action = Ast *)

let () =
  let channel = ref stdin in
  let lexbuf = Lexing.from_channel !channel in
  let ast = Parser.program Scanner.tokenize lexbuf in 
  let sast = Semant.check ast in 
    print_string (Sast.string_of_sprogram sast)
  