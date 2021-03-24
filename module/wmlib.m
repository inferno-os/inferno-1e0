Wmlib: module
{
	PATH:		con "/dis/lib/wmlib.dis";

	Resize,
	Hide,
	Help,
	OK:		con 1 << iota;

	Appl:		con Resize | Hide;

	init:		fn();
	titlebar:	fn(t: ref Tk->Toplevel, name: string, buts: int): chan of string;
	titlectl:	fn(t: ref Tk->Toplevel, request: string);
	taskbar:	fn(t: ref Tk->Toplevel, name: string): string;
	getfilename:	fn(screen: ref Draw->Screen, parent: ref Tk->Toplevel, title, pat, dir: string): string;
	geom:		fn(t: ref Tk->Toplevel): string;
	snarfput:	fn(buf: string);
	snarfget:	fn(): string;
};
