{ pkgs, stdenv, opam2nix }:
opam2nix.buildOpamPackage rec {
	version = "0.0.1";
	name = "crunchium-${version}";
	src = ./.;
	ocamlAttr = "ocaml_4_03";
}
