implement Echo;

include "sys.m";
include "draw.m";

Context: import Draw;

Echo: module
{
	init:	fn(nil: ref Context, argv: list of string);
};

sys: Sys;

init(nil: ref Context, argv: list of string)
{
	s: string;
	a: array of byte;

	sys = load Sys Sys->PATH;

	argv = tl argv;

	if(argv == nil)
		exit;

	s = "";
	while(argv != nil) {
		s += " " + hd argv;
		argv = tl argv;
	}
	s += "\n";
	a = array of byte s[1:];
	if(sys->write(sys->fildes(1), a, len a) != len a)
		sys->fprint(sys->fildes(2), "echo: write error: %r\n");
}
