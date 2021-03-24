implement Random;

include "sys.m";
include "draw.m";
include "keyring.m";
include "security.m";

sys: Sys;

randfd(): ref sys->FD
{
	sys = load Sys Sys->PATH;
	fd := sys->open("/dev/random", sys->OREAD);
	if(fd == nil){
		sys->print("can't open /dev/random\n");
		return nil;
	}
	return fd;
}

randomint(): int
{
	fd := randfd();
	if(fd == nil)
		return 0;
	buf := array[4] of byte;
	sys->read(fd, buf, 4);
	rand := 0;
	for(i := 0; i < 4; i++)
		rand = (rand<<8) | int buf[i];
	return rand;
}

randombuf(buf: array of byte, n: int): int
{
	fd := randfd();
	if(fd == nil)
		return 0;
	return sys->read(fd, buf, n);
}
