let
  pkgs = import /home/anand/nixpkgs {};
in
  pkgs.callPackage ./. {
  	opam2nix = pkgs.callPackage /home/anand/opam2nix-packages/nix/local.nix {inherit pkgs;};
  }
/*Install file: https://opam.ocaml.org/doc/manual/dev-manual.html#sec25*/
