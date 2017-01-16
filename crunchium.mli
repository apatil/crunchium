(**
   Helpers to serve ocaml-crunched folders of static files over Opium.
*)

(**
   This module signature is satisfied by ocaml-crunch generated modules.
*)
module type Crunch = sig
  type t
  type error
  type page_aligned_buffer
  (* Note: For this kind of syntax, check out https://caml.inria.fr/pub/docs/manual-ocaml/types.html *)
  val connect: unit -> [ `Ok of t | `Error of error] Lwt.t
  val read: t -> string -> int -> int -> [ `Ok of Cstruct.t list | `Error of error ] Lwt.t
end

(**
   Creates an Opium builder (route handler) that serves any single filename under
   a route from a crunched folder, which is provided as a first-class module.
*)
val serve_folder : ?stream:bool -> ?headers:Cohttp.Header.t option -> string -> (module Crunch) -> int -> Opium_app.builder

(**
   Serves a particular file from a crunched folder. The crunched folder
   is provided as a first-class module. If the file does not exist, returns an
   exception. If the file does exist, this will never return a 404.
*)
val serve_file : ?stream:bool -> ?headers:Cohttp.Header.t option -> string -> (module Crunch) -> string -> int -> Opium_app.builder Lwt.t

val log_src : Logs.src
