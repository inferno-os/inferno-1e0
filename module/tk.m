Tk: module
{
	PATH:	con	"$Tk";

	Tki:	type ref Draw->Image;

	Toplevel: adt
	{
		id:	int;
		image:	Tki;
	};

	toplevel:	fn(screen: ref Draw->Screen, arg: string): ref Toplevel;
	intop:		fn(screen: ref Draw->Screen, x, y: int): ref Toplevel;
	namechan:	fn(t: ref Toplevel, c: chan of string, n: string): string;
	cmd:		fn(t: ref Toplevel, arg: string): string;
	mouse:		fn(x, y, button: int);
	keyboard:	fn(key: int);
	imageput:	fn(t: ref Toplevel, name: string, i, m: Tki): string;
	imageget:	fn(t: ref Toplevel, name: string) : (Tki, Tki, string);
};
