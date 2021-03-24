implement Sleep;

include "sys.m";
sys: Sys;

include "draw.m";

Sleep: module
{
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	if(sys == nil || argv == nil)
		return;
	argv = tl argv;
	if(argv != nil)
		sys->sleep(int (hd argv) * 1000);
}
