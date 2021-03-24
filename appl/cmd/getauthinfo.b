implement Getauthinfo;

include "sys.m";
include "draw.m";

include "keyring.m";
kr: Keyring;

include "security.m";
login: Login;

include "string.m";

FD: import Sys;
Context: import Draw;

Getauthinfo: module
{
	init:	fn(ctxt: ref Context, argv: list of string);
};

usage := "Usage: getauthinfo net!mach";

sys: Sys;
stdin, stdout, stderr: ref FD;

#Our own interface into the Cs module so we can access kvopen & kvmap
Cs: module
{
	init:   fn(nil: ref Context, nil: list of string);
	kvopen:	fn(dbfile: string): int;
	kvmap:	fn(key: string): string;
};
cs: Cs;

init(nil: ref Context, argv: list of string)
{
	sys = load Sys Sys->PATH;

	stdin = sys->fildes(0);
	stdout = sys->fildes(1);
	stderr = sys->fildes(2);

	argv = tl argv;
	if(argv == nil){
		sys->fprint(stderr, "%s\n", usage);
		return;
	}
	keyname := hd argv;
	if ( len keyname >= sys->NAMELEN )
	{
		keyname = keyname[0:Sys->NAMELEN-2];
		sys->fprint( stderr, 
		             "getauthinfo: warning: keyname length > %d, truncated to %s\n", 
					 Sys->NAMELEN-1, keyname);
	}

	kr = load Keyring Keyring->PATH;
	str := load String String->PATH;
	if(str == nil){
		sys->fprint(stderr, "getauthinfo: can't load module String\n");
		return;
	}
	login = load Login Login->PATH;
	if(login == nil){
		sys->fprint(stderr, "getauthinfo: can't load module Login\n");
		return;
	}

	user := rf("/dev/user");
	path := "/usr/" + user + "/keyring/" + keyname;

	(dir, file) := str->splitr(path, "/");

        if((cs = load Cs "/dis/lib/cs.dis") == nil) {
                sys->fprint(stderr, "getauthinfo: failed to load cs: %r\n");
                return;
        }

	cs->kvopen("/services/cs/db");
	signer: string;
	if( (signer = cs->kvmap("$SIGNER")) == nil ){
		signer = "$SIGNER";
	}
	passwd := "";
	save := "no";
	for(;;){
		signer = promptstring("use signer", signer, 0);
		user = promptstring("remote user name", user, 0);
		passwd = promptstring("password", passwd, 1);
		save = promptstring("save in file", save, 0);

		info := logon(user, passwd, signer, dir, file, save);
		if(info != nil)
			break;
	}
}

promptstring(prompt, def: string, mute: int): string
{
	if(mute || def == nil || def == "")
		sys->fprint(stdout, "%s: ", prompt);
	else
		sys->fprint(stdout, "%s [%s]: ", prompt, def);
	(eof, resp) := readline(stdin);
	if(eof)
		exit;
	if(resp == "")
		resp = def;
	return resp;
}

readline(fd: ref Sys->FD): (int, string)
{
	i: int;
	eof: int;

	eof = 0;
	buf := array[128] of byte;
	tmp := array[128] of byte;
	for(sofar := 0; sofar < 128; sofar += i){
		i = sys->read(fd, tmp, 128 - sofar);
		if(i <= 0){
			eof = 1;
			break;
		}
		for(j := 0; j < i; j++)
			buf[sofar+j] = tmp[j];
		if(tmp[j-1] == byte '\n'){
			sofar += j-1;
			break;
		}
		
	}
	return (eof, string buf[0:sofar]);
}

logon(user, passwd, server, dir, file, save: string):
	ref Keyring->Authinfo
{
	(err, info) := login->login(user, passwd, server);
	if(err != nil){
		sys->fprint(stderr, "failed to authenticate: %s\n", err);
		return nil;
	}

	# save the info somewhere for later access
	if(save[0] != 'y'){
		filio := sys->file2chan(dir, file, sys->MBEFORE);
		if(filio != nil)
			spawn infofile(filio);
	}

	file = dir + "/" + file;
	if(kr->writeauthinfo(file, info) < 0)
		sys->fprint(stderr, "writeauthinfo to %s failed: %r\n", file);

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
