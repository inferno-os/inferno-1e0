implement Cat;

include "sys.m";
include "draw.m";

Cat: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

sys: Sys;
stderr, stdout: ref Sys->FD;

init(nil: ref Draw->Context, argl: list of string)
{
	sys = load Sys Sys->PATH;

	stdout = sys->fildes(1);
	stderr = sys->fildes(2);

	argl = tl argl;
	if(argl == nil)
		argl = "-" :: nil;
	while(argl != nil) {
		cat(hd argl);
		argl = tl argl;
	}
}

cat(file: string)
{
	n: int;
	fd: ref Sys->FD;
	buf := array[8192] of byte;

	if(file == "-")
		fd = sys->fildes(0);
	else {
		fd = sys->open(file, sys->OREAD);
		if(fd == nil) {
			sys->fprint(stderr, "cat: %s: %r\n", file);
			return;
		}
	}
	for(;;) {
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;
		if(sys->write(stdout, buf, n) < n) {
			sys->fprint(stderr, "cat: write error: %r\n");
			return;
		}
	}
	if(n < 0) {
		sys->fprint(stderr, "cat: read error: %r\n");
		return;
	}
}
