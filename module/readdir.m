Readdir: module
{
	PATH:	con	"/dis/lib/readdir.dis";

	# sortkey is one of NAME, ATIME, MTIME, SIZE, or NONE
	# possibly with DESCENDING or'd in

	NAME, ATIME, MTIME, SIZE, NONE: con iota;
	DESCENDING:	con (1<<5);

	init:	fn(path: string, sortkey: int): (array of ref Sys->Dir, int);
	sortdir:fn(a: array of ref Sys->Dir, key: int): (array of ref Sys->Dir, int);
};
