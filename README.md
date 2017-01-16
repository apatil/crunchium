### Serve [ocaml-crunch](https://github.com/mirage/ocaml-crunch)'ed static files and folders over [Opium](https://github.com/rgrinberg/opium)

Say your static files live in a folder called `assets`. First, crunch it:

```shell
#!/bin/bash
opam install crunchium
ocaml-crunch -o assets.ml assets
```

Now, you can write an OCaml web server that serves your `assets` folder under `/assets` on port 8080:

```ocaml
let () =
  let max_file_len = 1024 * 1024 in
  Opium_app.empty
  |> Crunchium.serve_folder "/assets" (module Assets) max_file_len
  |> Opium_app.port 8080
  |> Opium_app.run_command
```

If you want to be sure a particular file exists before trying to run your server, you can use `Crunchium.serve_file` instead:

```ocaml
let () =
  let max_file_len = 1024 * 1024 in
  let serve_index = Crunchium.serve_file "/" (module Assets) "index.html" max_file_len in
  Lwt_main.run @@ serve_index >>= function
  | `Error Crunchium.Not_found -> Lwt.fail Not_found
  | `Ok builder ->
    Opium_app.empty
    |> builder
    |> Opium_app.port 8080
    |> Opium_app.run_command
```
