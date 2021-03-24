implement WmRmtdir;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;

include "tk.m";
	tk: Tk;
	Toplevel: import tk;

include	"wmlib.m";
	wmlib: Wmlib;

include "tklib.m";
	tklib: Tklib;

include "keyring.m";
include "security.m";

t: ref Toplevel;

WmRmtdir: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

Wm: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

rmt_config := array[] of {
	"frame .f",
	"label .f.l -text Address:",
	"entry .f.e",
	"pack .f.l .f.e -side left",
	"label .status -text {Enter net!machine ...} -anchor w",
	"pack .Wm_t .status .f -fill x",
	"bind .f.e <Key-\n> {send cmd dial}",
	"frame .b",
	"radiobutton .b.auth -variable alg -value none -anchor w -text '"+
			"authenticate",
	"radiobutton .b.hash -variable alg -value sha  -anchor w -text '"+
			"authenticate and SHA hash",
	"radiobutton .b.encrypt -variable alg -value rc4 -anchor w -text '"+
			"authenticate and RC4 encrypt",
	"pack .b.auth .b.hash .b.encrypt -fill x",
	"pack .b -fill x",
	".b.auth invoke",
	"update",
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys  = load Sys  Sys->PATH;
	draw = load Draw Draw->PATH;
	tk   = load Tk   Tk->PATH;
	tklib= load Tklib Tklib->PATH;
	wmlib= load Wmlib Wmlib->PATH;

	tklib->init(ctxt);
	wmlib->init();

	tkargs := "";
	argv = tl argv;
	if(argv != nil) {
		tkargs = hd argv;
		argv = tl argv;
	}
	t = tk->toplevel(ctxt.screen, tkargs+" -borderwidth 2 -relief raised");

	menubut := wmlib->titlebar(t, sysname()+": Remote Connect", 0);

	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");

	tklib->tkcmds(t, rmt_config);

	for(;;) alt {
	menu := <-menubut =>
		if(menu[0] == 'e')
			return;
		wmlib->titlectl(t, menu);
	<-cmd =>
		addr := tk->cmd(t, ".f.e get");
		sel := addr+"!styx";
		status("Dialing");
		(ok, c) := sys->dial(sel, nil);
		if(ok < 0) {
			tk->cmd(t, ".status configure -text {Failed: "+
					sys->sprint("%r")+"}; update");
			break;
		}
		status("Authenticate");
		alg := tk->cmd(t, "variable alg");
		fd := auth(ctxt, addr, alg, c.dfd);
		if(fd == nil)
			break;
		status("Mount");
		sys->pctl(sys->FORKNS, nil);	# don't fork before authentication
		n := sys->mount(fd, "/n", sys->MREPL, "");
		if(n < 0) {
			tk->cmd(t, ".status configure -text {Mount failed: "+
					sys->sprint("%r")+"}; update");
			break;
		}
		wmdir := load Wm "/dis/wm/dir.dis";
		spawn wmdir->init(ctxt, "wmdir" :: wmlib->geom(t) :: "/n/" :: nil);
		return;
	}
}

status(s: string)
{
	tk->cmd(t, ".status configure -text {"+s+"}; update");
}

sysname(): string
{
	fd := sys->open("#c/sysname", sys->OREAD);
	if(fd == nil)
		return "Anon";
	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0) 
		return "Anon";
	return string buf[0:n];
}

auth(ctxt: ref Draw->Context, keyname, alg: string, dfd: ref Sys->FD): ref Sys->FD
{
	c: ref Sys->Connection;

	kr := load Keyring Keyring->PATH;
	if(kr == nil){
		status(sys->sprint("Can't load module Keyring: %r"));
		return nil;
	}
	login := load Login Login->PATH;
	if(login == nil){
		status(sys->sprint("Can't load module Login: %r"));
		return nil;
	}

	ai := login->getauthinfo(ctxt, keyname, nil);
	if(ai == nil)
		status(sys->sprint("auth: can't get key: %r"));

	(id_or_err, secret) := kr->auth(dfd, ai, 0);
	if(secret == nil){
		status("auth failed: "+id_or_err);
		return dfd;
	} else {
		if(id_or_err != "xyzzy")
			tklib->notice(t, "Authentication succeeded but remote id\nis '"+id_or_err+"' instead of the normal\nservice id.  This may be unsafe.");
	}

	algbuf := array of byte alg;
	kr->sendmsg(dfd, algbuf, len algbuf);
	if(alg == "none")
		return dfd;

	# push ssl and turn on algorithm
	ssl := load SSL SSL->PATH;
	if(ssl == nil){
		status(sys->sprint("Can't load module SSL: %r"));
		return nil;
	}
	if(sys->bind("#D", "/n/ssl", Sys->MREPL) < 0){
		status(sys->sprint("cannot bind #D: %r"));
		return nil;
	}
	(id_or_err, c) = ssl->connect(dfd);
	if(c == nil){
		status("Can't push SSL: " + id_or_err);
		return nil;
	}
	id_or_err = ssl->secret(c, secret, secret);
	if(id_or_err != nil){
		status("Can't write secret: " + id_or_err);
		return nil;
	}
	if(sys->fprint(c.cfd, "alg %s", alg) < 0){
		status(sys->sprint("Can't start %s: %r", alg));
		return nil;
	}

	return c.dfd;
}
