implement Webget;

# Protocol
#
# Client opens /chan/webget and writes one of
#		GET  0 reqid url types cachectl authcookie\n
#	    or
#		POST bodylength reqid url types cachectl authcookie\n
#		body
#
# The possibilities for cachectl are
#		max-stale=seconds
#			client is willing to accept a response whose age exceeds
#			its freshness lifetime (by at most specified seconds)
#			without revalidation
#		max-age=seconds
#			client is unwilling to accept a response whose age
#			(now - generation time) exceeds specified seconds
#			without revalidiation
#		no-cache
#			unconditional reload
# Both max-stale and max-age may be specified (separated by comma),
# but no-cache must appear by itself.
#
# Authcookie is optional.  If present, it goes in an Authorization: header.
#
# The appropriate transport mechanism gets the entity and
# responds with one of
#		OK bodylength reqid type url\n
#		body
#	    or
#		ERROR reqid message\n
#
# (In the ERROR case, the message might be "Unauthorized: challenge\n",
# where challenge is of the form "BASIC realm=xxx (param, param, ...)\n".
# The user can be prompted for a name:password, and the request repeated
# with authcookie containing the base64 encoding of name:password).

include	"sys.m";
	sys: Sys;
	FD: import sys;

include "draw.m";

include "string.m";
	S: String;

include "bufio.m";
	B: Bufio;

include "message.m";
	M: Message;
	Msg: import M;

include "url.m";
	U: Url;
	ParsedUrl: import U;

include "webget.m";

include "wgutils.m";
	W: WebgetUtils;
	Fid, Req: import W;

include "transport.m";
	
fhash := array[128] of ref Fid;

Transports: adt
{
	scheme:		int;
	path:		string;
	m:		Transport;
};
transports: array of ref Transports;

transtab := array[] of {
	(Url->HTTP,	"/dis/svc/webget/http.dis"),
	(Url->FILE,	"/dis/svc/webget/file.dis")
};

Rchunk: con 10;

logfile: con "/services/webget/webget.log";

stderr: ref FD;

init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);

	log := sys->create(logfile, Sys->OWRITE, 8r666);

	io := sys->file2chan("/chan", "webget", Sys->MBEFORE);
	if(io == nil) {
		sys->fprint(stderr, "webget: failed to post: %r\n");
		return;
	}

	B = load Bufio Bufio->PATH;
	if(B == nil) {
		sys->fprint(stderr, "webget: failed to load Bufio: %r\n");
		return;
	}
	S = load String String->PATH;
	if(S == nil) {
		sys->fprint(stderr, "webget: failed to load String: %r\n");
		return;
	}
	M = load Message Message->PATH;
	if(M == nil) {
		sys->fprint(stderr, "webget: failed to load Message: %r\n");
		return;
	}
	M->init(B, S);
	U = load Url Url->PATH;
	if(U == nil) {
		sys->fprint(stderr, "webget: failed to load Url: %r\n");
		return;
	}
	U->init(S);
	W = load WebgetUtils WebgetUtils->PATH;
	if(W == nil) {
		sys->fprint(stderr, "webget: failed to load WebgetUtils: %r\n");
		return;
	}
	W->init(M, S, B, U, log);

	loadtransmod();

	donec := chan of ref Fid;

    altloop:
	for(;;) alt {
	(nil, data, fid, wc) := <-io.write =>
		if(wc == nil) {
			finish(fid);
			continue altloop;
		}
		ndata := len data;
		c := lookup(fid);
		W->log(c, "\nREQUEST: " + string data);
		iw := c.writer;
		n := len c.reqs;
		if(iw == n) {
			newrs := array[n + Rchunk] of ref Req;
			newrs[0:] = c.reqs;
			c.reqs = newrs;
		}
		r := c.reqs[iw];
		err := "";
		if(r == nil) {
			# initial part (or all) of a request
			r = ref Req(iw, "", 0, "", "", "", "", "", nil, nil, nil);
			c.reqs[iw] = r;

			# expect at least the prefix line to be in data
			prefix := "";
			for(i := 0; i < ndata; i++) {
				if(int data[i] == '\n') {
					prefix = string data[0:i];
					if(i+1 < ndata) {
						r.body = array[ndata-i-1] of byte;
						r.body[0:] = data[i:ndata];
					}
					break;
				}
			}
			if(prefix == "")
				err = "no prefix line";
			else {
				(nl, l) := sys->tokenize(prefix, " ");
				if(nl != 6 && nl != 7)
					err = "wrong number of fields in " + prefix;
				else {
					r.method = hd l;
					l = tl l;
					r.bodylen = int hd(l);
					l = tl l;
					r.reqid = hd l;
					l = tl l;
					r.loc = hd l;
					l = tl l;
					r.types = hd l;
					l = tl l;
					r.cachectl = hd l;
					l = tl l;
					if(l != nil)
						r.auth = hd l;
					locurl := U->makeurl(r.loc);
					if(locurl.scheme == U->MAILTO)
						err = "webget shouldn't get mailto";
					else if(locurl.scheme == U->NOSCHEME || 
					   (locurl.scheme != U->FILE && (locurl.host == "" || locurl.pstart != "/")))
						err = "url not absolute: " + r.loc;
					r.url = locurl;
				}
			}
			if(err != "")
				err = "webget protocol error: " + err;
		}
		else {
			# continuation of request: more body
			olen := len r.body;
			newa := array[olen + ndata] of byte;
			newa[0:] = r.body[0:olen];
			newa[olen:] = data[0:ndata];
			r.body = newa;
		}
		if(err == "" && len r.body == r.bodylen) {
			# request complete: spawn off transport handler
			c.writer++;
			scheme := r.url.scheme;
			found := 0;
			for(i := 0; i < len transports; i++) {
				if(transports[i].scheme == scheme) {
					found = 1;
					break;
				}
			}
			if(found == 0)
				err = "don't know how to fetch " + r.loc;
			else {
				W->log(c, "transport " + string scheme + ":  get " + r.loc);
				spawn transports[i].m->connect(c, r, donec);
			}
		}
		if(err != "") {
			writereply(wc, -1, err);
			W->log(c, err);
			c.reqs[iw] = nil;
		}
		else
			writereply(wc, ndata, "");

	(nil, nbyte, fid, rc) := <-io.read =>
		if(rc == nil) {
			finish(fid);
			continue altloop;
		}
		c := lookup(fid);
		c.nbyte = nbyte;
		c.rc = rc;
		readans(c);
	c := <- donec =>
		readans(c);
		c = nil;
	}
}

loadtransmod()
{
	transports = array[len transtab] of ref Transports;
	j := 0;
	for(i := 0; i < len transtab; i++) {
		(scheme, path) := transtab[i];
		t := load Transport path;
		if(t == nil) {
			sys->fprint(stderr, "failed to load %s: %r\n", path);
			continue;
		}

		t->init(W);

		ts := ref Transports(scheme, path, t);
		transports[j++] = ts;
	}
}

# Answer a read request c.nbyte bytes, reply to go to c.rc.
# If c.readr is not -1, it is the index of a req with the currently
# being consumed reply.
# c.nread contains the number of bytes of this message read so far.
readans(c: ref Fid)
{
	n := c.nbyte;
	if(n <= 0)
		return;
	ir := c.readr;
	if(ir == -1) {
		# look for ready reply
		for(i := 0; i < c.writer; i++) {
			r := c.reqs[i];
			if(r != nil && r.reply != nil)
				break;
		}
		if(i == c.writer)
			return;
		ir = i;
	}
	r := c.reqs[ir];
	m := r.reply;
	if(m == nil) {
		sys->fprint(stderr, "readans bad state: nil reply\n");
		readreply(c.rc, nil, "");
		return;
	}
	if(m.prefixbytes == nil && m.prefixline != "")
		m.prefixbytes = array of byte m.prefixline;
	plen := len m.prefixbytes;
	blen := m.bodylen;	
	ntot := plen + blen;
	nread := c.nread;
	nrest := ntot - nread;
	if(nrest <= 0) {
		sys->fprint(stderr, "readans bad state: 0 left\n");
		readreply(c.rc, nil, "");
		return;
	}
	if(n > nrest)
		n = nrest;
	n1 := plen - nread;
	if(n1 > 0) {
		if(n1 > n)
			n1 = n;
		readreply(c.rc, m.prefixbytes[nread:nread + n1], "");
		c.nread += n1;
	}
	else {
		bpos := nread - plen;
		n2 := blen - bpos;
		if(n > n2)
			n = n2;
		readreply(c.rc, m.body[bpos:bpos+n], "");
		c.nread += n;
	}
	if(c.nread >= ntot) {
		c.reqs[ir] = nil;
		c.readr = -1;
		c.nbyte = 0;
		c.nread = 0;
		c.rc = nil;
		# move back write pointer as far as possible
		if(c.writer == ir+1) {
			while(ir >= 0 && c.reqs[ir] == nil)
				ir--;
			c.writer = ir+1;
		}
	}
	else
		c.readr = ir;
}

# Reply to a write command.
# The send will just hang if the other end went away, and we
# know that he is waiting if he hasn't gone away, so use a
# non-blocking alt to tell.
writereply(wc: Sys->Rwrite, n: int, err: string)
{
	alt {
		wc <-= (n, err) => ;
		* => ;
	}
}

readreply(rc: Sys->Rread, a: array of byte, err: string)
{
	if(rc != nil) {
		alt {
			rc <-= (a, err) => ;
			* => ;
		}
	}
}

lookup(fid: int): ref Fid
{
	h := fid%len fhash;
	for(f := fhash[h]; f != nil; f = f.link)
		if(f.fid == fid)
			return f;
	f = ref Fid(fid, fhash[h], array[Rchunk] of ref Req, 0, -1, 0, 0, nil);
	fhash[h] = f;

	W->log(f, "\nNEW CLIENT");

	return f;	
}

finish(fid: int)
{
	h := fid%len fhash;

	prev: ref Fid;
	for(f := fhash[h]; f != nil; f = f.link) {
		if(f.fid == fid) {
			f.rc = nil;
			W->log(f, "client finished");
			if(prev == nil)
				fhash[h] = f.link;
			else
				prev.link = f.link;
			return;
		}
	}
}
