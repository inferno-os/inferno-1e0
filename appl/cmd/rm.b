implement Rm;

include "sys.m";
include "draw.m";

FD: import Sys;
Context: import Draw;

Rm: module
{
	init:	fn(ctxt: ref Context, argv: list of string);
};

sys: Sys;
stderr, stdout: ref FD;

init(nil: ref Context, argv: list of string)
{
	sys = load Sys Sys->PATH;

	stdout = sys->fildes(1);
	stderr = sys->fildes(2);

	argv = tl argv;
	while(argv != nil) {
		if(sys->remove(hd argv) < 0)
			sys->fprint(stderr, "rm: %s: %r\n", hd argv);
		argv = tl argv;
	}
}
