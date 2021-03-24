implement Newns;
#
# Build a new namespace from a file
#
#	fork	split the namespace before modification
#	nodev	disallow device attaches
#	bind	[-abrci] from to
#	mount	[-abrci] [net!]machine to [spec]
#   	cd	directory
#
#	-i to bind/mount means continue in the face of errors
#
include "sys.m";
sys: Sys;
FD, FileIO, Connection: import Sys;
	stderr: ref FD;

include "draw.m";
Context: import Draw;

include "bufio.m";
bio: Bufio;
Iobuf: import Bufio;

include "newns.m";
include "sh.m";

include "keyring.m";
include "security.m";

ignore: int;


newns(user: string, nsfile: string): string
{
	# Load reqd modules 
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);

	# Could do some authentication here, and bail if no good FIXME
	if(user == nil);

	bio = load Bufio Bufio->PATH;
	if(bio == nil)
		return "error loading bufio module";

	if(nsfile == nil)
		nsfile = "namespace"; 
 
	mfp := bio->open(nsfile, bio->OREAD);
	if(mfp==nil)
      		return sys->sprint("newns: can't open %s for read\n", nsfile);

	e := "";
	for(;;) {
		cmdline, tpline: string = nil;
		tpval: int = '\n';
		tpline = bio->mfp.gets(tpval);
		if(tpline == nil)
			break;
		cmdline = tpline[0:len tpline-1];
		(n, slist) := sys->tokenize(cmdline, " \t\r");
		ignore = 0;
		e = nsop(slist);
		if(e != "" && ignore == 0)
			break;
   	}

	bio->mfp.close();
	return e;
}

nsop(argv: list of string): string
{
	# ignore comments 
	if((hd argv)[0] == '#')
		return nil;
 
	e := "";
	c := 0;
	cmdstr := hd argv;
	case cmdstr {
	"fork"  =>
		c = sys->FORKNS;
	"nodev" =>
		c = sys->NODEVS;
	"bind" =>
		e = bind(tl argv);
	"mount" =>
		e = mount(tl argv);
   	"cd" =>
		if(len argv != 1)
			return "cd: <> args";   
		if(sys->chdir(hd argv) < 0)
			return sys->sprint("%r");
	* =>
      		e = "invalid namespace command";
	}
	if(c != 0) {
		if(sys->pctl(c, nil) < 0)
			return sys->sprint("%r");
	}
	return e;
}

rev(l: list of string): list of string
{
	t: list of string;

	while(l != nil) {
		t = hd l :: t;
		l = tl l;
	}
	return t;
}

Moptres: adt {
	argv: list of string;
	flags: int;
	alg: string;
};

mopt(argv: list of string): (ref Moptres, string)
{
	r := ref Moptres(nil, 0, "none");

	while(argv != nil) {
		s := hd argv;
		argv = tl argv;
		if(s[0] != '-') {
			r.argv = s :: r.argv;
			continue;
		}
	opt:	for(i := 1; i < len s; i++) {
			case s[i] {
			'i' => ignore++;
			'a' => r.flags |= sys->MAFTER;
			'b' => r.flags |= sys->MBEFORE;
			'c' => r.flags |= sys->MCREATE;
			'r' => r.flags |= sys->MREPL;
			'C' =>
				r.alg = s[2:];
				if(r.alg == nil || r.alg == "") {
					if(argv == nil)
						return (nil, "no arg to C option");

					r.alg = hd argv;
					argv = tl argv;
				}
				break opt;

			 *  => return (nil, "bad command option " + s[i:]);
			}
		}
	}
	r.argv = rev(r.argv);
	return (r, nil);
}

bind(argv: list of string): string
{
	(r, err) := mopt(argv);
	if(err != nil)
		return err;

	if(len r.argv < 2)
		return "bind: too few args";

	from := hd r.argv;
	r.argv = tl r.argv;
	todir := hd r.argv;
	if(sys->bind(from, todir, r.flags) < 0)
		return sys->sprint("bind %s %s: %r", from, todir);

	return nil;
}

mount(argv: list of string): string
{
	spec: string;

	(r, err) := mopt(argv);
	if(err != nil)
		return err;

	if(len r.argv < 2)
		return "mount: too few args";

	addr := hd r.argv;
	dest := addr+"!styx";
	r.argv = tl r.argv;
	(ok, c) := sys->dial(dest, nil);
	if(ok < 0)
		return sys->sprint("dial: %s: %r", dest);

	fd := auth(addr, r.alg, c.dfd);
	if(fd == nil)
		return sys->sprint("auth: %r");

	dir := hd r.argv;
	r.argv = tl r.argv;
	if(r.argv != nil)
		spec = hd r.argv;
	if(sys->mount(fd, dir, r.flags, "") < 0)
		return sys->sprint("mount: %r");

	return nil;
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
