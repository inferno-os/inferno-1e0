implement Rcmd;

include "sys.m";
include "draw.m";

Context: import Draw;

sys: Sys;

Rcmd: module
{
	init:	fn(ctxt: ref Context, argv: list of string);
};

init(nil: ref Context, argv: list of string)
{
	sys = load Sys Sys->PATH;

	mach := "hati";
	args := "sh";
	if(argv != nil)
		case len argv{
		1 =>
			break;
		2 =>
			mach = hd tl argv;
		* =>
			mach = hd tl argv;
			args = "";
			a := tl tl argv;
			while(a != nil){
				args += " " + hd a;
				a = tl a;
			}
		}

	stderr := sys->fildes(2);

	# To make visible remotely
	sys->bind("#i", "/dev", sys->MAFTER);

#	sys->print("sys->dial('%s', nil);\n", "tcp!"+mach+"!rstyx");

	(ok, c) := sys->dial("tcp!"+mach+"!rstyx", nil);
	if(ok < 0){
		sys->fprint(stderr, "dial: %r\n");
		return;
	}

	t := array of byte sys->sprint("%d\n%s\n", len (array of byte args)+1, args);
	if(sys->write(c.dfd, t, len t) != len t){
		sys->fprint(stderr, "export args write: %r\n");
		return;
	}

	if(sys->export(c.dfd, sys->EXPWAIT) < 0){
		sys->fprint(stderr, "export: %r\n");
		return;
	}
}
