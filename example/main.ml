(*
 * Copyright (C) 2015 Citrix Inc
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)
open Lwt
open Block_ring_unix

let project_url = "http://github.com/djs55/shared-block-ring"

let produce filename interval =
  let t =
    Producer.attach filename
    >>= function
    | `Error x -> fail (Failure x)
    | `Ok p ->
      let rec loop () =
        Lwt_io.read_line Lwt_io.stdin
        >>= fun line ->
        let buf = Cstruct.create (String.length line) in
        Cstruct.blit_from_string line 0 buf 0 (String.length line);
        let rec write () =
          Producer.push p buf
          >>= function
          | `TooBig -> fail (Failure "input data is too large for this ring")
          | `Retry ->
            Lwt_unix.sleep (float_of_int interval)
            >>= fun () ->
            write ()
          | `Error msg -> fail (Failure msg)
          | `Ok position ->
            ( Producer.advance p position
              >>= function
              | `Error msg -> fail (Failure msg)
              | `Ok () -> return () ) in
        write ()
        >>= fun () ->
        loop () in
      loop () in
  try
    `Ok (Lwt_main.run t)
  with e ->
    `Error(false, Printexc.to_string e)

let consume filename interval =
  let t =
    Consumer.attach filename
    >>= function
    | `Error x -> fail (Failure x)
    | `Ok c ->
      let rec loop () =
        Consumer.pop c
        >>= function
        | `Retry ->
          Lwt_unix.sleep (float_of_int interval)
          >>= fun () ->
          loop ()
        | `Error msg -> fail (Failure msg)
        | `Ok(position, buf) ->
          Lwt_io.write_line Lwt_io.stdout (Cstruct.to_string buf)
          >>= fun () ->
          ( Consumer.advance c position
            >>= function
            | `Error msg -> fail (Failure msg)
            | `Ok () -> loop () ) in
      loop () in
  try
    `Ok (Lwt_main.run t)
  with e ->
    `Error(false, Printexc.to_string e)

let create filename =
  let t =
    Producer.create filename >>= function
    | `Error x -> fail (Failure (Printf.sprintf "Producer.create %s: %s" filename x))
    | `Ok _ -> return () in
  try
    `Ok (Lwt_main.run t)
  with e ->
    `Error(false, Printexc.to_string e)

let diagnostics filename =
  let t =
    Consumer.attach filename
    >>= function
    | `Error x -> fail (Failure x)
    | `Ok c ->
      let item = function
      | `Retry ->
        Lwt_io.write_line Lwt_io.stdout "-- there are no more items"
        >>= fun () ->
        return None
      | `Error msg -> fail (Failure msg)
      | `Ok (position, buf) ->
        Lwt_io.write_line Lwt_io.stdout (Printf.sprintf "%s: %s" (Sexplib.Sexp.to_string (Consumer.sexp_of_position position)) (Cstruct.to_string buf))
        >>= fun () ->
        return (Some position) in
      Consumer.pop c
      >>= fun i ->
      item i
      >>= function
      | None -> return ()
      | Some pos ->
        let rec loop pos =
          Consumer.peek c pos
          >>= fun i ->
          item i
          >>= function
          | None -> return ()
          | Some pos -> loop pos in
        loop pos in
  try
    `Ok (Lwt_main.run t)
  with e ->
    `Error(false, Printexc.to_string e)

open Cmdliner

(* Help sections common to all commands *)

let help = [
 `S "MORE HELP";
 `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command."; `Noblank;
 `S "BUGS"; `P (Printf.sprintf "Check bug reports at %s" project_url);
]

let filename =
  let doc = "Path to the device or file containing the ring." in
  Arg.(value & pos 0 file "test.raw" & info [] ~doc)

let interval =
  let doc = "Time in seconds between I/O retries." in
  Arg.(value & opt int 5 & info [ "interval" ] ~doc)

let produce_cmd =
  let doc = "Push data onto the ring" in
  let man = [
    `S "DESCRIPTION";
    `P "Read lines of text from stdin and push them as individual items onto the ring.";
  ] @ help in
  Term.(ret(pure produce $ filename $ interval)),
  Term.info "produce" ~doc ~man

let consume_cmd =
  let doc = "Pop data from the ring" in
  let man = [
    `S "DESCRIPTION";
    `P "Read lines of text from the ring and print them to stdout.";
  ] @ help in
  Term.(ret(pure consume $ filename $ interval)),
  Term.info "consume" ~doc ~man

let create_cmd =
  let doc = "Create an empty ring" in
  let man = [
    `S "DESCRIPTION";
    `P "Initialise a device or file with an empty ring."
  ] @ help in
  Term.(ret(pure create $ filename)),
  Term.info "create" ~doc ~man

let diagnostics_cmd =
  let doc = "Display the current state of a ring." in
  let man = [
    `S "DESCRIPTION";
    `P "Display the current ring state including producer and consumer pointers, together with the current ring contents for diagnostic purposes.";
    `P "Note: the ring will not be modified."
  ] @ help in
  Term.(ret(pure diagnostics $ filename)),
  Term.info "diagnostics" ~doc ~man

let default_cmd =
  let doc = "manipulate shared rings on block devices" in
  let man = help in
  Term.(ret (pure (`Help (`Pager, None)))),
  Term.info (Sys.argv.(0)) ~version:"1.0.0" ~doc ~man

let cmds = [create_cmd; produce_cmd; consume_cmd; diagnostics_cmd]

let _ =
  match Term.eval_choice default_cmd cmds with
  | `Error _ -> exit 1
  | _ -> exit 0