include Logs
open Lwt.Infix

let log_src = Logs.Src.create "Opium_crunch" ~doc:"Serves static modules generated with mirage-crunch over Opium"
let log (lvl : Logs.level) msg (tags : Logs.Tag.set) =
  Logs.msg ~src:log_src lvl (fun m -> m msg ~tags:tags)
let uri_tag : Uri.t Logs.Tag.def =
  Logs.Tag.def "uri" (fun f u -> Format.pp_print_string f @@ Uri.to_string u)
let fname_tag : string Logs.Tag.def =
  Logs.Tag.def "filename" (fun f n -> Format.pp_print_string f n)
let error_tag : string Logs.Tag.def =
  Logs.Tag.def "error" (fun f n -> Format.pp_print_string f n)
let request_tags (fname : string) (req : Opium_rock.Request.t) =
    Logs.Tag.(empty
              |> add uri_tag @@ Cohttp.Request.uri req.Opium_rock.Request.request
              |> add fname_tag fname)

module type Crunch = sig
  type t
  type error
  type page_aligned_buffer
  val connect: unit -> [ `Ok of t | `Error of error] Lwt.t
  val read: t -> string -> int -> int -> [ `Ok of Cstruct.t list | `Error of error ] Lwt.t
end

let batch_cstructs (headers : Cohttp.Header.t option) (cstructs: Cstruct.t list) : Opium_rock.Response.t Lwt.t =
  let str = String.concat "" (List.map Cstruct.to_string cstructs) in
  let headers = match headers with
    | None -> Cohttp.Header.init ()
    | Some h -> h
  in
  let headers = Cohttp.Header.add headers "Content-length" (string_of_int @@ String.length str) in
  Lwt.return @@ Opium_rock.Response.create ~headers ~body:(`String str) ()

let stream_cstructs (headers : Cohttp.Header.t option) (cstructs: Cstruct.t list) : Opium_rock.Response.t Lwt.t =
  let headers = match headers with
    | None -> Cohttp.Header.init ()
    | Some h -> h
  in
  let headers = Cohttp.Header.add headers "Transfer-encoding" "chunked" in
  let stream = (Lwt_stream.map Cstruct.to_string @@ Lwt_stream.of_list cstructs) in
  Lwt.return @@ Opium_rock.Response.create ~headers ~body:(`Stream stream) ()

let crunched_file (module C : Crunch) (fname : string) (max_length : int) : [> `Ok of Cstruct.t list | `NotFound | `ConnectFailed] Lwt.t =
  C.connect () >>= fun src_ ->
  match src_ with
  | `Error e -> Lwt.return @@ `ConnectFailed
  | `Ok src -> C.read src fname 0 max_length >>= fun ocstructs ->
    match ocstructs with
    | `Error e -> Lwt.return @@ `NotFound
    | `Ok cstructs -> Lwt.return @@ `Ok cstructs

let join_paths (p1 : string) (p2 : string) : string =
  let split s = Str.split (Str.regexp_string "/") s in
  let parts = (split p1) @ (split p2) in
  "/" ^ String.concat "/" parts

let serve_folder ?(stream=false) ?(headers=(None : Cohttp.Header.t option)) (route : string) (module C : Crunch) (max_length : int) : Opium_app.builder =
  let crunch = crunched_file (module C) in
  Opium_app.get (join_paths route "/:fname") @@ fun req ->
    let fname = Opium_app.param req "fname" in
    let tags = request_tags fname req in
    log Logs.Debug "Received file request" tags;
    crunch fname max_length >>= function
    | `ConnectFailed ->
      log Logs.Error "Failed to connect" tags;
      Opium_app.respond' ~code:`Internal_server_error (`String "Internal server error")
    | `NotFound ->
      log Logs.Error "File not found in crunch" tags;
      Opium_app.respond' ~code:`Not_found (`String "File Not Found")
    | `Ok cstructs ->
      match stream with
      | true ->
        log Logs.Debug "Streaming response" tags;
        stream_cstructs headers cstructs
      | false ->
        log Logs.Debug "Sending batch response" tags;
        batch_cstructs headers cstructs

let serve_file ?(stream=false) ?(headers=(None : Cohttp.Header.t option)) (route : string) (module C : Crunch) (fname : string) (max_length : int) : Opium_app.builder Lwt.t =
  crunched_file (module C) fname max_length >>= function
  | `ConnectFailed -> Lwt.fail_with "Failed to connect"
  | `NotFound -> Lwt.fail_with "File not found in crunch"
  | `Ok cstructs ->
    Lwt.return (Opium_app.get "/" @@ fun req ->
      let tags = request_tags fname req in
      match stream with
      | true ->
        log Logs.Debug "Received file request, streaming response" tags;
        stream_cstructs headers cstructs
      | false ->
        log Logs.Debug "Received file request, sending batch response" tags;
        batch_cstructs headers cstructs)
