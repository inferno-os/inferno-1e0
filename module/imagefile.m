RImagefile: module 
{
	READGIFPATH:	con "/dis/lib/readgif.dis";
	READJPGPATH:	con "/dis/lib/readjpg.dis";

	Rawimage: adt
	{
		r:	Draw->Rect;
		cmap:	array of byte;
		transp:	int;	# transparency flag; can be set only for nchans=1
		trindex:	byte;	# transparency index
		nchans:	int;
		chans:	array of array of byte;
		chandesc:	int;

		fields:	int;	#defined by format
	};

	# chandesc
	CRGB:	con 0;	# three channels, no map
	CY: 	con 1;	# one channel, luminance
	CRGB1:	con 2;	# one channel, map present

	init:	fn(bufio: Bufio);
	read:	fn(fd: ref Bufio->Iobuf): (ref Rawimage, string);
};

Imageremap: module
{
	PATH:	con "/dis/lib/imageremap.dis";

	remap:	fn(i: ref RImagefile->Rawimage, d: ref Draw->Display, errdiff: int): (ref Draw->Image, string);
};
