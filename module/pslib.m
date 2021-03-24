PsLib : module 
{
	ERROR, NEWPAGE, OK : con iota;
	PATH:		con "/dis/lib/pslib.dis";

	getfonts: fn(input: string) : string;
	preamble: fn(ioutb : ref Bufio->Iobuf, bbox: Rect) : int;
	trailer: fn(ioutb : ref Bufio->Iobuf,pages : int) : int;
	printnewpage: fn(pagenum : int,end : int, ioutb : ref Bufio->Iobuf);
	parseTkline: fn(ioutb : ref Bufio->Iobuf,input : string) : int;
	stats: fn() : (int,int,int);
	init : fn(env : ref Draw->Context,t : ref Tk->Toplevel,boxes: int) : int;
	deffont : fn() : string;
	image2psfile: fn(ioutb: ref Bufio->Iobuf, im: ref Draw->Image, dpi: int) : int;
};
