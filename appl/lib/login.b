implement Login;

include "sys.m";
sys: Sys;

include "draw.m";
draw: Draw;
Context: import draw;

include "tk.m";
tk: Tk;

include "wmlib.m";
wmlib: Wmlib;

include	"tklib.m";
tklib: Tklib;

include "keyring.m";
kr: Keyring;
IPint: import kr;

include "security.m";
rand: Random;

include "string.m";

#Our own interface into the Cs module so we can access kvopen & kvmap
Cs: module
{
	init:   fn(nil: ref Context, nil: list of string);
	kvopen:	fn(dbfile: string): int;
	kvmap:	fn(key: string): string;
};
cs: Cs;

login(id, password, dest: string): (string, ref Keyring->Authinfo)
{
	lc: Sys->Connection;
	c: ref Sys->Connection;
	ok: int;
	err, s: string;

	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;
	rand = load Random Random->PATH;

	ssl := load SSL SSL->PATH;
	if(ssl == nil)
		return ("can't load ssl", nil);

	info := ref Keyring->Authinfo;

	if(dest == nil)
		dest = "$SIGNER";

	(ok, lc) = sys->dial("tcp!"+dest+"!inflogin", nil);
	if(ok < 0)
		return ("can't contact login daemon", nil);

	# push ssl, leave in clear mode for now
	if(sys->bind("#D", "/n/ssl", Sys->MREPL) < 0)
		return (sys->sprint("cannot bind #D: %r"), nil);

	(err, c) = ssl->connect(lc.dfd);
	if(c == nil)
		return ("can't push ssl: " + err, nil);
	lc.dfd = nil;
	lc.cfd = nil;

	# send name, get ack
	kr->putstring(c.dfd, id);
	(s, err) = kr->getstring(c.dfd);
	if(err != nil)
		return ("remote:" + err, nil);

	# create and send an initialization vector
	ivec := array[8] of byte;
	rand->randombuf(ivec, len ivec);
	kr->putbytearray(c.dfd, ivec, len ivec);

	# start encrypting
	pwbuf := array of byte password;
	digest := array[Keyring->SHAdlen] of byte;
	kr->sha(pwbuf, len pwbuf, digest, nil);
	pwbuf = array[8] of byte;
	for(i := 0; i < 8; i++)
		pwbuf[i] = digest[i] ^ digest[8+i];
	for(i = 0; i < 4; i++)
		pwbuf[i] ^= digest[16+i];
	for(i = 0; i < 8; i++)
		pwbuf[i] ^= ivec[i];
	ssl->secret(c, pwbuf, pwbuf);
	sys->fprint(c.cfd, "alg rc4");

	# get P(alpha**r0 mod p)
	(s, err) = kr->getstring(c.dfd);
	if(err != nil){
		if(err == "failure")
			return ("name or secret incorrect", nil);
		return ("remote:" + err, nil);
	}

	# stop encrypting
	sys->fprint(c.cfd, "alg clear");

	# get alpha, p
	alphar0 := IPint.b64toip(s);
	(s, err) = kr->getstring(c.dfd);
	if(err != nil){
		if(err == "failure")
			return ("name or secret incorrect", nil);
		return ("remote:" + err, nil);
	}
	info.alpha = IPint.b64toip(s);
	(s, err) = kr->getstring(c.dfd);
	if(err != nil){
		if(err == "failure")
			return ("name or secret incorrect", nil);
		return ("remote:" + err, nil);
	}
	info.p = IPint.b64toip(s);

	# sanity check
	bits := info.p.bits();
	abits := info.alpha.bits();
	if(abits > bits || abits < 2)
		return ("bogus diffie hellman constants", nil);

	# generate our random diffie hellman part
	r1 := kr->IPint.random(bits/4, bits);
	alphar1 := info.alpha.expmod(r1, info.p);

	# send alpha**r1 mod p
	kr->putstring(c.dfd, alphar1.iptob64());

	# compute alpha**(r0*r1) mod p
	alphar0r1 := alphar0.expmod(r1, info.p);

	# turn on digesting
	secret := alphar0r1.iptobytes();
	ssl->secret(c, secret, secret);
	sys->fprint(c.cfd, "alg sha");

	# get signer's public key
	(s, err) = kr->getstring(c.dfd);
	if(err != nil)
		return ("remote:" + err, nil);

	info.spk = kr->strtopk(s);

	# generate a key pair
	info.mysk = kr->genSKfromPK(info.spk, id);
	info.mypk = kr->sktopk(info.mysk);

	# send my public key
	kr->putstring(c.dfd, kr->pktostr(info.mypk));

	# get my certificate
	(s, err) = kr->getstring(c.dfd);
	if(err != nil)
		return ("remote:" + err, nil);

	info.cert = kr->strtocert(s);
	return(nil, info);
}

cfg := array[] of {
	"frame .l",
	"label .l.u -text {User Name:} -anchor w",
	"label .l.s -text {Secret:} -anchor w",
	"label .l.g -text {Key Signer:} -anchor w",
	"pack .l.u .l.s .l.g -fill x",
	"frame .e",
	"entry .e.u",
	"entry .e.s -show •",
	"entry .e.g",
	"pack .e.u .e.s .e.g -fill x",
	"frame .b",
	"checkbutton .b.save -variable save -text 'Save Key in file",
	"pack .b.save -fill x",
	"frame .f -borderwidth 2 -relief raised",
	"pack .l .e -side left -in .f",
	"pack .Wm_t -fill x",
	"pack .f -fill x",
	"pack .b -fill x",
	"bind .e.u <Key-\n> {send cmd oku}",
	"bind .e.s <Key-\n> {send cmd oks}",
	"bind .e.g <Key-\n> {send cmd okg}",
	"bind .e.f <Key-\n> {send cmd okf}",
	"focus .e.u",
	"update"
};

getauthinfo(ctxt: ref Context, keyname, path: string): ref Keyring->Authinfo
{
	signer: string;

	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;
	str := load String String->PATH;

	user := rf("/dev/user");
	if(len keyname >= Sys->NAMELEN) {
		keyname = keyname[0:Sys->NAMELEN-2];
		sys->fprint( sys->fildes(2), 
		             "getauthinfo: warning: keyname length > %d, truncated to %s\n", 
					 Sys->NAMELEN-1, keyname);
	}
	if(path == nil)
		path = "/usr/" + user + "/keyring/" + keyname;

	# try to read the file, if this works no need for the rest
	info := kr->readauthinfo(path);
	if(info != nil || ctxt == nil)
		return info;

	(dir, file) := str->splitr(path, "/");

	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	tklib = load Tklib Tklib->PATH;
	wmlib = load Wmlib Wmlib->PATH;

	tklib->init(ctxt);
	wmlib->init();

        if((cs = load Cs "/dis/lib/cs.dis") == nil) {
                return nil;
        }

	# default signer
	cs->kvopen("/services/cs/db");
	if( (signer = cs->kvmap("$SIGNER")) == nil ){
		signer = "$SIGNER";
	}

	top := tk->toplevel(ctxt.screen, " -borderwidth 2 -relief raised ");

	titlectl := wmlib->titlebar(top, "Authentication for " + keyname, Wmlib->Appl);
	tklib->tkcmds(top, cfg);

	# put defaults into frame
	tk->cmd(top, ".e.u insert end '" + user);
	tk->cmd(top, ".e.g insert end '" + signer);

	cmd := chan of string;
	tk->namechan(top, cmd, "cmd");

	for(;;){
		tk->cmd(top, "update");
		alt {
		menu := <-titlectl =>
			if(menu[0] == 'e')
				return nil;
			wmlib->titlectl(top, menu);
		rdy := <-cmd =>
			usr := tk->cmd(top, ".e.u get");
			passwd := tk->cmd(top, ".e.s get");
			signer = tk->cmd(top, ".e.g get");
			save := tk->cmd(top, "variable save");
	
			if(usr == "") {
				tk->cmd(top, ".e.s delete 0 end");
				tklib->notice(top, "You must supply a user name to login");
				continue;
			}
	
			if(passwd == ""){
				tk->cmd(top, "focus .e.s");
				tk->cmd(top, "update");
				continue;
			}

			tk->cmd(top, "cursor -bitmap cursor.wait");
			info = logon(top, usr, passwd, signer, dir, file, save);
			tk->cmd(top, "cursor -default");
			if(info != nil)
				return info;
	
			tk->cmd(top, ".e.s delete 0 end; .e.u delete 0 end");
			tk->cmd(top, "focus .e.u");
		}
	}
}

logon(top: ref Tk->Toplevel, user, passwd, server, dir, file, save: string):
	ref Keyring->Authinfo
{
	(err, info) := login(user, passwd, server);
	if(err != nil){
		tklib->notice(top, "failed to authenticate:" + err);
		return nil;
	}

	# save the info somewhere for later access
	if(save == "0"){
		filio := sys->file2chan(dir, file, sys->MBEFORE);
		if(filio != nil)
			spawn infofile(filio);
	}

	file = dir + "/" + file;
	if(kr->writeauthinfo(file, info) < 0)
		tklib->notice(top, "error writing " + file + ": " + sys->sprint("%r"));

	return info;
}


rf(file: string): string
{
	fd := sys->open(file, sys->OREAD);
	if(fd == nil)
		return "";

	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0)
		return "";

	return string buf[0:n];	
}

infodata: array of byte;

infofile(file:ref Sys->FileIO)
{
	data: array of byte;
	off, nbytes, fid: int;
	rc: Sys->Rread;
	wc: Sys->Rwrite;

	infodata = array[0] of byte;

	sys->pctl(Sys->NEWPGRP, nil);

	for(;;) alt {
	(off, nbytes, fid, rc) = <-file.read =>
		if(rc == nil)
			break;
		if(off > len infodata){
			rc <-= (infodata[off:off], nil);
		} else {
			if(off + nbytes > len infodata)
				nbytes = len infodata - off;
			rc <-= (infodata[off:off+nbytes], nil);
		}

	(off, data, fid, wc) = <-file.write =>
		if(wc == nil)
			break;

		if(off != len infodata){
			wc <-= (0, "cannot be rewritten");
		} else {
			nid := array[len infodata+len data] of byte;
			nid[0:] = infodata;
			nid[len infodata:] = data;
			infodata = nid;
			wc <-= (len data, nil);
		}
		data = nil;
	}
}
