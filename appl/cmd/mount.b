implement Mount;

include "sys.m";
	sys: Sys;
	FD, Connection: import Sys;
	stderr: ref FD;

include "draw.m";
	Context: import Draw;

include "keyring.m";

include "security.m";

Mount: module
{
	init:	fn(ctxt: ref Context, argv: list of string);
};

init(nil: ref Context, argv: list of string)
{
	c: Connection;
	ok: int;

	sys = load Sys Sys->PATH;

	stderr = sys->fildes(2);

	argv = tl argv;

	copt := 0;
	flags := sys->MREPL;
	alg := "none";
	while(argv != nil) {
		s := hd argv;
		if(s[0] != '-')
			break;
	opt:	for(i := 1; i < len s; i++) {
			case s[i] {
			'a' =>
				flags = sys->MAFTER;
			'b' =>
				flags = sys->MBEFORE;
			'r' =>
				flags = sys->MREPL;
			'c' =>
				copt++;
			'C' =>
				alg = s[i+1:];
				if(alg == nil) {
					argv = tl argv;
					if(argv != nil) {
						alg = hd argv;
						if(alg[0] == '-')
							usage();
					}
					else
						usage();
				}
				break opt;
			*   =>
				usage();
			}
		}
		argv = tl argv;
	}
	if(copt)
		flags |= sys->MCREATE;

	if(len argv != 2)
		usage();

	addr := hd argv;
	dest := addr+"!styx";
	argv = tl argv;
	(ok, c) = sys->dial(dest, nil);
	if(ok < 0) {
		sys->fprint(stderr, "dial: %s: %r\n", dest);
		return;
	}

	fd := auth(addr, alg, c.dfd);
	if(fd == nil)
		return;

	dir := hd argv;
	ok = sys->mount(fd, dir, flags, "");
	if(ok < 0)
		sys->fprint(stderr, "mount: %r\n");
}

usage()
{
	sys->fprint(stderr, "Usage: mount [-rabcA] [-C cryptoalg] net!mach old\n");
	exit;
}

auth(keyname, alg: string, dfd: ref Sys->FD): ref Sys->FD
{
	c: ref Sys->Connection;

	kr := load Keyring Keyring->PATH;
	if(kr == nil){
		sys->fprint(stderr, "Can't load module Keyring %r\n");
		return nil;
	}
	login := load Login Login->PATH;
	if(login == nil){
		sys->fprint(stderr, "Can't load module Login %r\n");
		return nil;
	}

	ai := login->getauthinfo(nil, keyname, nil);
	if(ai == nil)
		sys->fprint(stderr, "Key for %s not found, proceeding...\n", keyname);

	(id_or_err, secret) := kr->auth(dfd, ai, 0);
	if(secret == nil){
		sys->fprint(stderr, "Authentication failed, proceeding unauthenticated...\n");
		return dfd;
	} else if(id_or_err != "xyzzy"){
		sys->fprint(stderr, "Remote server authenticated as %s\n", id_or_err);
		sys->fprint(stderr, "instead of normal service id. Mount may be unsafe.\n");
	}

	algbuf := array of byte alg;
	kr->sendmsg(dfd, algbuf, len algbuf);
	if(alg == "none")
		return dfd;

	# push ssl and turn on algorithm
	ssl := load SSL SSL->PATH;
	if(ssl == nil){
		sys->fprint(stderr, "Can't load module SSL %r\n");
		return nil;
	}
	if(sys->bind("#D", "/n/ssl", Sys->MREPL) < 0){
		sys->fprint(stderr, "Can't bind #D: %r\n");
		return nil;
	}
	(id_or_err, c) = ssl->connect(dfd);
	if(c == nil){
		sys->fprint(stderr, "Can't push SSL %s\n", id_or_err);
		return nil;
	}
	id_or_err = ssl->secret(c, secret, secret);
	if(id_or_err != nil){
		sys->fprint(stderr, "Can't set secret %s\n", id_or_err);
		return nil;
	}
	if(sys->fprint(c.cfd, "alg %s", alg) < 0){
		sys->fprint(stderr, "Can't turn on %s: %r\n", alg);
		return nil;
	}

	return c.dfd;
}
