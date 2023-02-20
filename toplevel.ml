(* toplevel.ml *)
(* BlueShell *)
(* Kenny Lin, Alan Luc, Tina Ma, Mary-Joy Sidhom *)

open Ast

let () =
  let lex_buf = Lexing.from_channel stdin in
  let expr = Parser.full_expr Scanner.tokenize lex_buf in
  let module StringMap = Map.Make(String) in
  let (result, _) = eval StringMap.empty expr in
  print_endline (string_of_int result)
  