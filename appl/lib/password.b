implement Password;

include "sys.m";
include "draw.m";
include "keyring.m";
include "security.m";

sys: Sys;

Oid:	con 0;
Opw:	con Oid+32;
Oexp:	con Opw+Keyring->SHAdlen;
Oother:	con Oexp+4;
Oend:	con Oother+72;

#
#  read and parse a password entry
#
get(id: string): ref PW
{

	sys = load Sys Sys->PATH;

	fd := sys->open("/keydb/password", Sys->OREAD);
	if(fd == nil)
		return nil;

	for(pw := next(fd); pw != nil; pw = next(fd)){
		if(id == pw.id)
			break;
	}

	return pw;
}

#
#  write a password entry, > 0 == OK, <= 0 == error
#
put(pw: ref PW): int
{
	sys = load Sys Sys->PATH;

	fd := sys->open("/keydb/password", Sys->ORDWR);
	if(fd == nil)
		fd = sys->create("/keydb/password", Sys->ORDWR, 8r600);
	if(fd == nil)
		return -1;

	for(opw := next(fd); opw != nil; opw = next(fd)){
		if(pw.id == opw.id)
			break;
	}
	if(opw != nil)
		sys->seek(fd, -Oend, 1);

	buf := array[Oend] of byte;
	for(i := 0; i < Oend; i++)
		buf[i] = byte 0;

	buf[0:] = array of byte pw.id;
	buf[Opw:] = pw.pw;
	for(i = Oexp; i < Oother; i++)
		buf[i] = byte (pw.expire>>((Oother - i - 1)*8));
	buf[Oother:] = array of byte pw.other;

	return sys->write(fd, buf, len buf);
}

next(fd: ref Sys->FD): ref PW
{
	buf := array[Oend] of byte;
	n := sys->read(fd, buf, len buf);
	if(n != len buf)
		return nil;
	pw := ref PW;

	for(i := Oid; i < Opw; i++)
		if((int buf[i]) == 0)
			break;
	pw.id = string buf[0:i];

	pw.pw = buf[Opw:Oexp];

	pw.expire = 0;
	for(i = Oexp; i < Oother; i++)
		pw.expire = (pw.expire<<8) | int buf[i];

	for(i = Oother; i < Oend; i++)
		if((int buf[i]) == 0)
			break;
	pw.other = string buf[Oother:i];

	return pw;
}
