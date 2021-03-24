Brutusext: module
{
	# More tags, needed by Cook
	SGML, Text, Par, Extension, Special: con Brutus->NTAG + iota;

	# Output formats
	FLatex, FLatexProc, FLatexBook, FHtml: con iota;

	# Cook element
	Celem: adt
	{
		tag: int;
		s: string;
		contents: cyclic ref Celem;
		parent: cyclic ref Celem;
		next: cyclic ref Celem;
		prev: cyclic ref Celem;
	};


	init:	fn(sys: Sys, draw: Draw, bufio: Bufio, tk: Tk, tklib: Tklib);
	create:	fn(t: ref Tk->Toplevel, name, args: string): string;
	cook:	fn(fmt: int, args: string) : (ref Celem, string);
};
