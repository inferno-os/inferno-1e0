Pipe: module
{
	PATH:	con "/dis/lib/pipe.dis";

	# returns pair of file names to be opened; first is read end,
	# second is write end
	files:	fn(): (string, string);

	# returns pair of open files
	fds:	fn(): (ref Sys->FD, ref Sys->FD);
};
