implement WmSendmail;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Context: import draw;

include "tk.m";
	tk: Tk;
	Toplevel: import tk;

include "wmlib.m";
	wmlib: Wmlib;

include	"tklib.m";
	tklib: Tklib;

WmSendmail: module
{
	init:	fn(ctxt: ref Draw->Context, args: list of string);
};

srv: Sys->Connection;
main: ref Toplevel;
ctxt: ref Context;
username: string;

mail_cfg := array[] of {
	"frame .top",
	"label .top.l -bitmap email.bit",
	"button .top.con -label Connect -command {send msg connect}",
	"label .top.status -text {not connected ...} -anchor w",
	"pack .top.l -side left",
	"pack .top.con -side left -padx 10",
	"pack .top.status -side left -fill x -expand 1",
	"frame .hdr",
	"frame .hdr.l",
	"frame .hdr.e",
	"label .hdr.l.mt -text {Mail To:}",
	"label .hdr.l.cc -text {Mail CC:}",
	"label .hdr.l.sb -text {Subject:}",
	"pack .hdr.l.mt .hdr.l.cc .hdr.l.sb -fill y -expand 1",
	"entry .hdr.e.mt",
	"entry .hdr.e.cc",
	"entry .hdr.e.sb",
	"bind .hdr.e.mt <Key-\n> {}",
	"bind .hdr.e.cc <Key-\n> {}",
	"bind .hdr.e.sb <Key-\n> {}",
	"pack .hdr.e.mt .hdr.e.cc .hdr.e.sb -fill x -expand 1",
	"pack .hdr.l -side left -fill y",
	"pack .hdr.e -side left -fill x -expand 1",
	"frame .body",
	"scrollbar .body.scroll -command {.body.t yview}",
	"text .body.t -width 15c -height 7c -yscrollcommand {.body.scroll set}",
	"pack .body.t -side left -expand 1 -fill both",
	"pack .body.scroll -side left -fill y",
	"frame .b",
	"button .b.send -text Deliver -command {send msg send}",
	"button .b.nocc -text {No CC} -command {.hdr.e.cc delete 0 end}",
	"button .b.new -text New -command {send msg new}",
	"button .b.save -text Save -command {send msg save}",
	"pack .b.send .b.nocc .b.new .b.save -padx 5 -side left -fill x -expand 1",
	"pack .Wm_t -fill x",
	"pack .top -anchor w -padx 5",
	"pack .hdr -fill x -anchor w -padx 5 -pady 5",
	"pack .body -expand 1 -fill both -padx 5 -pady 5",
	"pack .b -padx 5 -pady 5 -fill x",
	"pack propagate . 0",
	"update"
};

con_cfg := array[] of {
	"frame .b",
	"button .b.ok -text {Connect} -command {send cmd ok}",
	"button .b.can -text {Cancel} -command {send cmd can}",
	"pack .b.ok .b.can -side left -fill x -padx 10 -pady 10 -expand 1",
	"frame .l",
	"label .l.h -text {Mail Server:} -anchor w",
	"label .l.u -text {User Name:} -anchor w",
	"pack .l.h .l.u -fill both -expand 1",
	"frame .e",
	"entry .e.h -width 30w",
	"entry .e.u -width 30w",
	"pack .e.h .e.u -fill x",
	"frame .f -borderwidth 2 -relief raised",
	"pack .l .e -fill both -expand 1 -side left -in .f",
	"bind .e.h <Key-\n> {send cmd ok}",
	"bind .e.u <Key-\n> {send cmd ok}",
};

con_pack := array[] of {
	"pack .Wm_t -fill x",
	"pack .f",
	"pack .b -fill x -expand 1",
	"focus .e.u",
	"update",
};

new_cmd := array[] of {
	".hdr.e.mt delete 0 end",
	".hdr.e.cc delete 0 end",
	".hdr.e.sb delete 0 end",
	".body.t delete 1.0 end",
	".body.t see 1.0",
	"update"
};

init(xctxt: ref Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	tklib = load Tklib Tklib->PATH;
	wmlib = load Wmlib Wmlib->PATH;

	ctxt = xctxt;

	tklib->init(ctxt);
	wmlib->init();

	tkargs := "";
	argv = tl argv;
	if(argv != nil) {
		tkargs = hd argv;
		argv = tl argv;
	}

	main = tk->toplevel(ctxt.screen, tkargs+" -borderwidth 2 -relief raised");

	msg := chan of string;
	tk->namechan(main, msg, "msg");

	titlectl := wmlib->titlebar(main, "MailStop: Sender", Wmlib->Appl);
	tklib->tkcmds(main, mail_cfg);

	if(argv != nil)
		fromreadmail(hd argv);

	for(;;) alt {
	menu := <-titlectl =>
		if(menu[0] == 'e') {
			if(srv.dfd == nil)
				return;
			status("Closing connection...");
			smtpcmd("QUIT");
			return;
		}
		wmlib->titlectl(main, menu);
	cmd := <-msg =>
		case cmd {
		"connect" =>
			if(srv.dfd == nil) {
				connect(main, 1);
				fixbutton();
				break;
			}
			disconnect();
		"save" =>
			save();
		"send" =>
			sendmail();
		"new" =>
			tklib->tkcmds(main, new_cmd);
		}
	}
}

fixbutton()
{
	s := "Connect";
	if(srv.dfd != nil)
		s = "Disconnect";

	tk->cmd(main, ".top.con configure -text "+s+"; update");
}

sendmail()
{
	if(srv.dfd == nil) {
		tklib->notice(main, "You must be connected to deliver mail");
		return;
	}

	mto := tk->cmd(main, ".hdr.e.mt get");
	if(mto == "") {
		tklib->notice(main, "You must fill in the \"Mail To\" entry");
		return;
	}

	if(tk->cmd(main, ".body.t index end") == "1.0") {
		opt := "Cancel" :: "Send anyway" :: nil;
		if(tklib->dialog(main, "The body of the mail is empty", 0, opt) == 0)
			return;
	}

	(err, s) := smtpcmd("MAIL FROM:<"+username+">");
	if(err != nil) {
		tklib->notice(main, "Failed to specify FROM correctly:\n"+err);
		return;
	}
	status(s);
	(err, s) = smtpcmd("RCPT TO:<"+mto+">");
	if(err != nil) {
		tklib->notice(main, "Failed to specify TO correctly:\n"+err);
		return;
	}
	status(s);
	cc := tk->cmd(main, ".hdr.e.cc get");
	if(cc != nil) {
		(nil, l) := sys->tokenize(cc, "\t ,");
		while(l != nil) {
			copy := hd l;
			(err, s) = smtpcmd("RCPT TO:<"+copy+">");
			if(err != nil) {
				tklib->notice(main, "Carbon copy to "+
						copy+"failed:\n"+err);
			}
		}
	}
	(err, s) = smtpcmd("DATA");
	if(err != nil) {
		tklib->notice(main, "Failed to enter DATA mode:\n"+err);
		return;
	}

	sub := tk->cmd(main, ".hdr.e.sb get");
	if(sub != nil)
		sys->fprint(srv.dfd, "Subject: %s\n", sub);

	b := array of byte tk->cmd(main, ".body.t get 1.0 end");
	n := sys->write(srv.dfd, b, len b);
	b = nil;
	if(n < 0) {
		tklib->notice(main, "Error writing server:\n"+sys->sprint("%r"));
		return;
	}
	(err, s) = smtpcmd("\r\n.");
	if(err != nil) {
		tklib->notice(main, "Failed to terminate message:\n"+err);
		return;
	}
	status(s);
}

save()
{
	mto := tk->cmd(main, ".hdr.e.to get");
	if(mto == "") {
		tklib->notice(main, "No message to save");
		return;
	}

	fname := wmlib->getfilename(ctxt.screen, main, "mailbox", "saved.letter/*",
					  "/usr/"+rf("/dev/user")+"/mail");
	if(fname == nil)
		return;

	fd := sys->create(fname, sys->OWRITE, 8r660);
	if(fd == nil) {
		tklib->notice(main, "Failed to create "+fname+
				    "\n"+sys->sprint("%r"));
		return;
	}

	r := sys->fprint(srv.dfd, "Mail To: %s\n", mto);
	cc := tk->cmd(main, ".hdr.e.cc get");
	if(cc != nil)
		r += sys->fprint(srv.dfd, "Mail CC: %s\n", cc);
	sb := tk->cmd(main, ".hdr.e.sb get");
	if(sb != nil)
		r += sys->fprint(srv.dfd, "Subject: %s\n\n", sb);

	s := tk->cmd(main, ".body.t get 1.0 end");
	b := array of byte s;
	n := sys->write(fd, b, len b);
	if(n < 0) {
		tklib->notice(main, "Error writing file"+fname+
				    "\n"+sys->sprint("%r"));
		return;
	}
	status("wrote "+string(n+r)+" bytes.");
}

status(msg: string)
{
	tk->cmd(main, ".top.status configure -text {"+msg+"}; update");
}

disconnect()
{
	(err, s) := smtpcmd("QUIT");
	srv.dfd = nil;
	fixbutton();
	if(err != nil) {
		tklib->notice(main, err);
		return;
	}
	status(s);
}

connect(parent: ref Toplevel, interactive: int)
{
	topcfg := postposn(parent)+" -borderwidth 2 -relief raised";
	t := tk->toplevel(ctxt.screen, topcfg);

	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");

	conctl := wmlib->titlebar(t, "Connection Parameters", 0);
	tklib->tkcmds(t, con_cfg);

	username = rf("/dev/user");
	s := rf("/usr/"+username+"/mail/smtpserver");
	if(s != "")
		tk->cmd(t, ".e.h insert 0 '"+s);

	s = rf("/usr/"+username+"/mail/domain");
	if(s != nil)
		username += "@"+s;

	u := tk->cmd(t, ".e.u get");
	if(u == "")
		tk->cmd(t, ".e.u insert 0 '"+username);

	if(interactive == 0 && checkthendial(t) != 0)
		return;

	tklib->tkcmds(t, con_pack);

	for(;;) alt {
	ctl := <-conctl =>
		if(ctl[0] == 'e')
			return;
		wmlib->titlectl(t, ctl);
	s = <-cmd =>
		if(s == "can")
			return;
		if(checkthendial(t) != 0)
			return;
		status("not connected");
	}
	srv.dfd = nil;
}

checkthendial(t: ref Toplevel): int
{
	server := tk->cmd(t, ".e.h get");
	if(server == "") {
		tklib->notice(t, "You must supply a server address");
		return 0;
	}
	user := tk->cmd(t, ".e.u get");
	if(user == "") {
		tklib->notice(t, "You must supply a user name");
		return 0;
	}
	if(dom(user) == "") {
		tklib->notice(t, "The user name must contain an '@'");
		return 0;
	}
	return dialer(t, server, user);
}

dialer(t: ref Toplevel, server, user: string): int
{
	ok: int;

	status("dialing server...");
	(ok, srv) = sys->dial(server+"!25", nil);
	if(ok < 0) {
		tklib->notice(t, "The following error occurred while\n"+
				 "dialing the server: "+sys->sprint("%r"));
		return 0;
	}
	status("connected...");
	(err, s) := smtpresp();
	if(err != nil) {
		tklib->notice(t, "An error occurred during sign on.\n"+err);
		return 0;
	}
	status(s);
	(err, s) = smtpcmd("HELO "+dom(user));
	if(err != nil) {
		tklib->notice(t, "An error occurred during login.\n"+err);
		return 0;
	}
	status("ready to send...");
	return 1;
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

postposn(parent: ref Toplevel): string
{
	x := int tk->cmd(parent, ".top.con cget -actx");
	y := int tk->cmd(parent, ".top.con cget -acty");
	h := int tk->cmd(parent, ".top.con cget -height");

	return "-x "+string(x-2)+" -y "+string(y+h+2);
}

dom(name: string): string
{
	for(i := 0; i < len name; i++)
		if(name[i] == '@')
			return name[i+1:];
	return nil;
}

fromreadmail(hdr: string)
{
	(nil, l) := sys->tokenize(hdr, "\n");
	while(l != nil) {
		s := hd l;
		l = tl l;
		n := match(s, "subject: ");
		if(n != nil) {
			tk->cmd(main, ".hdr.e.sb insert end '"+n);
			continue;
		}
		n = match(s, "cc: ");
		if(n != nil) {
			tk->cmd(main, ".hdr.e.cc insert end '"+n);
			continue;
		}
		n = match(s, "from: ");
		if(n != nil) {
			n = extract(n);
			tk->cmd(main, ".hdr.e.mt insert end '"+n);
		}
	}
	connect(main, 0);
}

extract(name: string): string
{
	for(i := 0; i < len name; i++) {
		if(name[i] == '<') {
			for(j := i+1; j < len name; j++)
				if(name[j] == '>')
					break;
			return name[i+1:j];
		}
	}
	for(i = 0; i < len name; i++)
		if(name[i] == ' ')
			break;
	return name[0:i];
}

lower(c: int): int
{
	if(c >= 'A' && c <= 'Z')
		c = 'a' + (c - 'A');
	return c;
}

match(text, pat: string): string
{
	for(i := 0; i < len pat; i++) {
		c := text[i];
		p := pat[i];
		if(c != p && lower(c) != p)
			return "";
	}
	return text[i:];
}

#
# Talk SMTP
#
smtpcmd(cmd: string): (string, string)
{
	cmd += "\r\n";
#	sys->print("->%s", cmd);
	b := array of byte cmd;
	l := len b;
	n := sys->write(srv.dfd, b, l);
	if(n != l)
		return ("send to server:"+sys->sprint("%r"), nil);

	return smtpresp();
}

smtpresp(): (string, string)
{
	s := "";
	i := 0;
	lastc := 0;
	for(;;) {
		c := smtpgetc();
		if(c == -1)
			return ("read from server:"+sys->sprint("%r"), nil);
		if(lastc == '\r' && c == '\n')
			break;
		s[i++] = c;
		lastc = c;
	}
#	sys->print("<-%s\n", s);
	if(i < 3)
		return ("short read from server", nil);
	s = s[0:i-1];
	case s[0] {
	'1' or '2' or '3' =>
		i = 3;
		while(s[i] == ' ' && i < len s)
			i++;
		return (nil, s[i:]);
	'4'or '5' =>
		i = 3;
		while(s[i] == ' ' && i < len s)
			i++;
		return (s[i:], nil);
	 * =>
		return ("invalid server response", nil);
	}
}

Iob: adt
{
	nbyte:	int;
	posn:	int;
	buf:	array of byte;
};
smtpbuf: Iob;

smtpgetc(): int
{
	if(smtpbuf.nbyte > 0) {
		smtpbuf.nbyte--;
		return int smtpbuf.buf[smtpbuf.posn++];
	}
	if(smtpbuf.buf == nil)
		smtpbuf.buf = array[512] of byte;

	smtpbuf.posn = 0;
	n := sys->read(srv.dfd, smtpbuf.buf, len smtpbuf.buf);
	if(n < 0)
		return -1;

	smtpbuf.nbyte = n-1;
	return int smtpbuf.buf[smtpbuf.posn++];
}
