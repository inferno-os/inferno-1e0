implement Cs;

#
# Connection server translates net!machine!service into
# /net/tcp/clone 135.104.9.53!564
#
# This simple implementation only knows about tcp/udp
#
# This module also contains the interface to any db in the
# simple format of services/cs/db. It is used by modules like
# getauthinfo so that the prompt has has the value of $SIGNER.
# kvopen & kvmap could be one function in their own module!
#

include "sys.m";
include "srv.m";
include "draw.m";
include "bufio.m";

FD, FileIO: import Sys;
Context: import Draw;
Iobuf: import Bufio;

sys: Sys;
srv: Srv;
bufio: Bufio;
stderr: ref FD;

Cs: module
{
	init:	fn(nil: ref Context, nil: list of string);
	kvopen: fn(dbfile: string): int;
	kvmap:	fn(key: string): string;
};

Reply: adt
{
	fid:	int;
	addrs:	list of string;
};
rlist: list of ref Reply;

init(nil: ref Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);

	srv = load Srv Srv->PATH;

	(ok, nil) := sys->stat("/net/cs");
	if(ok >= 0) {
		sys->fprint(stderr, "cs: already started\n");
		return;
	}
	file := sys->file2chan("/net", "cs", sys->MAFTER);
	if(file == nil) {
		sys->fprint(stderr, "cs: failed to make file: %r\n");
		return;
	}
	if((bufio = load Bufio Bufio->PATH) == nil) {
		sys->fprint(stderr, "cs: failed to load bufio: %r\n");
		return;
	}
	if(kvopen("/services/cs/db") == bufio->ERROR){
		sys->fprint(stderr, "cs: Can't kvopen: %r\n");
		return;
	}

	spawn cs(file);
#	sys->fprint(stderr, "cs: installed on /net/cs\n");
}

cs(file: ref FileIO)
{
	data: array of byte;
	off, nbytes, fid: int;
	rc: Sys->Rread;
	wc: Sys->Rwrite;

	for(;;) alt {
	(off, nbytes, fid, rc) = <-file.read =>
		if(rc == nil) {
			cleanfid(fid);
			break;
		}
		rc <-= result(off, nbytes, fid);

	(off, data, fid, wc) = <-file.write =>
		if(wc == nil) {
			cleanfid(fid);
			break;
		}
		wc <-= xlate(data, fid);
		data = nil;
	}
}

cleanfid(fid: int)
{
	new: list of ref Reply;

	for(s := rlist; s != nil; s = tl s) {
		r := hd s;
		if(r.fid != fid)
			new = r :: new;
	}

	rlist = new;
}

result(off, nbytes, fid: int): (array of byte, string)
{
	r: ref Reply;
	ipaddr: string;
	new, s: list of ref Reply;

	for(s = rlist; s != nil; s = tl s) {
		r = hd s;
		if(r.fid == fid) {
			ipaddr = hd r.addrs;
			r.addrs	= tl r.addrs;
			if(r.addrs != nil)	
				new = r :: new;
		}
		else
			new = r :: new;
	}
	rlist = new;

	if(ipaddr != nil)
		return srv->reads(ipaddr, off, nbytes);

	return (nil, "can't translate address");
}

xlate(data: array of byte, fid: int): (int, string)
{
	n: int;
	l, rl: list of string;
	repl, netw, mach, service, s: string;

	(n, l) = sys->tokenize(string data, "!\n");
	if(n != 3)
		return (0, "bad format request");

	netw = hd l;
	mach = hd tl l;
	service = hd tl tl l;

	if(netw == "net")
		netw = "tcp";

	if(netw != "tcp" && netw != "udp")
		return (0, "network unavailable");

	if(mach == "*")
		l = "" :: nil;
	else
	if(isipaddr(mach) == 0) {
		# Symbolic server == "$SVC"
		if(mach[0] == '$'
		  && (mach = kvmap(mach)) == nil)
			return (0, "unknown service");
		l = srv->iph2a(mach);
		if(l == nil)
			return (0, "unknown host");
	}
	else
		l = mach :: nil;

	if(numeric(service) == 0) {
		service = srv->ipn2p(netw, service);
		if(service == nil)
			return (0, "bad service name");
	}

	while(l != nil) {
		s = hd l;
		l = tl l;
		if(s != nil)
			s[len s] = '!';
		s += service;

		repl = "/net/" + netw + "/clone " + s;
		sys->fprint(stderr, "cs: %s!%s!%s -> %s\n",
					netw, mach, service, repl);

		rl = repl :: rl;
	}

	rlist = ref Reply(fid, rl) :: rlist;

	return (len data, nil);
}

isipaddr(a: string): int
{
	i, c: int;

	for(i = 0; i < len a; i++) {
		c = a[i];
		if((c < '0' || c > '9') && c != '.')
			return 0;
	}
	return 1;
}

numeric(a: string): int
{
	i, c: int;

	for(i = 0; i < len a; i++) {
		c = a[i];
		if(c < '0' || c > '9')
			return 0;
	}
	return 1;
}

#
# Maps key strings to value strings from flat file database.  Rereads
# database file if mod time changes.
#

Dir, fstat: import sys;

mapfd: ref FD;
mapfp: ref Iobuf;
mtime: int;
KVpair: adt {
	key:	string;
	value:	string;
};
kvlist: list of KVpair;

kvopen(dbfile: string): int
{
	if( sys == nil ){
		sys = load Sys Sys->PATH;
		stderr = sys->fildes(2);
	}
	if(bufio == nil) {
		bufio = load Bufio Bufio->PATH;
	}
	if(dbfile == nil){
		sys->fprint(stderr, "kvopen: nil dbfile\n");
		return bufio->ERROR;
	}
	if((mapfd = sys->open(dbfile, sys->OREAD)) == nil){
		sys->fprint(stderr,
			"kvopen: Can't open dbfile %s %r\n", dbfile);
		return bufio->ERROR;
	}
	if((mapfp = bufio->fopen(mapfd, bufio->OREAD)) == nil){
		sys->fprint(stderr,
			"kvopen: Can't fopen dbfile %s %r\n", dbfile);
		return bufio->ERROR;
	}
	return 0;
}

kvmap(key: string): string
{
	dir:	Dir;
	n:	int;
	kvstr:	string;
	slist:	list of string;
	nkvlist: list of KVpair;
	kv: KVpair;

	# Continue with possibly stale info after most errors.
	if(key == nil){
		sys->fprint(stderr,
			"kvmap Attempt to map nil key\n");
		return nil;
	}
	if(mapfp == nil){
		sys->fprint(stderr,
			"kvmap Attempt to map key %s from unopened file\n",
			key);
		return nil;
	}
	(n, dir) = fstat(mapfd);
	if(n < 0)
		sys->fprint(stderr, "Ktove: cannot fstat %r\n");
	if(mtime == 0 || mtime != dir.mtime){
		# (re)populate kvlist atomically.
		if(bufio->mapfp.seek(0,0) < 0)
			sys->fprint(stderr, "seek /lib/ndb/csmap %r\n");
		else {
			mtime = dir.mtime;
			while((kvstr = bufio->mapfp.gets('\n')) != nil){
				if(kvstr[0] == '#')
					continue;
				(n, slist) = sys->tokenize(kvstr, " \t\r\n");
				if (n == 0)	# blank line
					continue;
				if(n != 2){
					sys->fprint(stderr,
						"kvmap record with %d fields\n",
						n);
					nkvlist = nil;
					break;
				}
				nkvlist = KVpair(hd slist, hd tl slist)
					:: nkvlist;
			}
			slist = nil;
			kvstr = nil;
			if(nkvlist != nil)
				kvlist = nkvlist;
		}
	}
	for(nkvlist = kvlist; nkvlist != nil; nkvlist = tl nkvlist){
		kv = hd nkvlist;
		if(kv.key == key)
			return kv.value;
	}
	return nil;
}
