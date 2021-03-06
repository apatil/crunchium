.PHONY: all build install remove clean

all : build

build :
	ocamlfind ocamlc -package lwt,opium,logs -linkpkg crunchium.mli crunchium.ml -c
	ocamlfind ocamlc -a -o crunchium.cma crunchium.cmo

	ocamlfind ocamlopt -package lwt,opium,logs -linkpkg crunchium.mli crunchium.ml crunchium.mli crunchium.ml -c
	ocamlfind ocamlopt -a -o crunchium.cmxa crunchium.cmx

install : all
	ocamlfind install crunchium *

clean :
	- rm *.cmi
	- rm *.cma
	- rm *.cmo
	- rm *.cmx
	- rm *.o
	- rm *.a
	- rm *.cmxa
