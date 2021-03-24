implement WmReadmail;

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

WmReadmail: module
{
	init:	fn(ctxt: ref Draw->Context, args: list of string);
};

WmSendmail: module
{
	init:	fn(ctxt: ref Draw->Context, args: list of string);
};

srv: Sys->Connection;
main: ref Toplevel;
ctxt: ref Context;
nmesg: int;
cmesg: int;
map: array of byte;
Ok, Deleted: con iota;
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
	"scrollbar .hdr.scroll -command {.hdr.t yview}",
	"text .hdr.t -height 3c -yscrollcommand {.hdr.scroll set}",
	"frame .hdr.pad -width 2c",
	"pack .hdr.t -side left -fill x -expand 1",
	"pack .hdr.scroll -side left -fill y",
	"pack .hdr.pad",
	"frame .body",
	"scrollbar .body.scroll -command {.body.t yview}",
	"text .body.t -width 15c -height 7c -yscrollcommand {.body.scroll set}",
	"pack .body.t -side left -expand 1 -fill both",
	"pack .body.scroll -side left -fill y",
	"frame .b",
	"button .b.next -text Next -command {send msg next}",
	"button .b.prev -text Prev -command {send msg prev}",
	"button .b.del -text Delete -command {send msg dele}",
	"button .b.reply -text Reply -command {send msg reply}",
	"button .b.fwd -text Forward",
	"button .b.hdr -text Headers -command {send msg hdrs}",
	"button .b.save -text Save -command {send msg save}",
	"pack .b.next .b.prev .b.del .b.reply .b.fwd .b.hdr .b.save -padx 5 -side left -fill x -expand 1",
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
	"label .l.s -text {Secret:} -anchor w",
	"pack .l.h .l.u .l.s -fill both -expand 1",
	"frame .e",
	"entry .e.h",
	"entry .e.u",
	"entry .e.s -show •",
	"pack .e.h .e.u .e.s -fill x",
	"frame .f -borderwidth 2 -relief raised",
	"pack .l .e -fill both -expand 1 -side left -in .f",
	"pack .Wm_t -fill x",
	"pack .f",
	"pack .b -fill x -expand 1",
	"bind .e.h <Key-\n> {send cmd ok}",
	"bind .e.u <Key-\n> {send cmd ok}",
	"bind .e.s <Key-\n> {send cmd ok}",
	"focus .e.s",
};

hdr_cfg := array[] of {
	"scrollbar .sh -orient horizontal -command {.f.l xview}",
	"scrollbar .f.sv -command {.f.l yview}",
	"frame .f",
	"listbox .f.l -width 80w -height 20h -yscrollcommand { .f.sv set} -xscrollcommand { .sh set}",
	"pack .f.l -side left -fill both -expand 1",
	"pack .f.sv -side left -fill y",
	"pack .Wm_t -fill x",
	"pack .f -fill both -expand 1",
	"pack .sh -fill x",
	"pack propagate . 0",
	"bind .f.l <Double-Button> { send tomain [.f.l get [.f.l curselection]] }",
	"update",
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
	hdr := chan of string;

	titlectl := wmlib->titlebar(main, "MailStop: Reader", Wmlib->Appl);
	tklib->tkcmds(main, mail_cfg);


	for(;;) alt {
	menu := <-titlectl =>
		if(menu[0] == 'e') {
			if(srv.dfd != nil) {
				status("Updating mail box...");
				pop3cmd("QUIT");
			}
			return;
		}
		wmlib->titlectl(main, menu);
	cmd := <-msg =>
		case cmd {
		"connect" =>
			if(srv.dfd == nil) {
				connect(main);
				if(srv.dfd != nil)
					initialize();
				break;
			}
			disconnect();
		"prev" =>
			if(cmesg > nmesg) {
				status("no more messages.");
				break;
			}
			for(new := cmesg+1; new <= nmesg; new++) {
				if(map[new] == byte Ok) {
					cmesg = new;
					loadmesg();
					break;
				}
			}
		"next" =>
			for(new := cmesg-1; new >= 1; new--) {
				if(map[new] == byte Ok) {
					cmesg = new;
					loadmesg();
					break;
				}
			}
		"dele" =>
			delete();
			if(cmesg < nmesg) {
				cmesg++;
				loadmesg();
			}
		"hdrs" =>
			headers(hdr);
		"save" =>
			save();
		"reply" =>
			reply();
		}
	get := <-hdr =>
		new := int get;
		if(new < 1 || new > nmesg)
			break;		
		cmesg = new;
		loadmesg();
	}
}

headers(tomain: chan of string)
{
	targ := wmlib->geom(main)+" -borderwidth 2 -relief raised";
	hdr := tk->toplevel(ctxt.screen, targ);


	tk->namechan(hdr, tomain, "tomain");

	hdrctl := wmlib->titlebar(hdr, "MailStop: Headers", Wmlib->Appl);

	tklib->tkcmds(hdr, hdr_cfg);

	for(i := 1; i <= nmesg; i++) {
		if(map[i] == byte Deleted)
			continue;
		if(topit(hdr, i) == 0)
			break;
		alt {
		s := <-hdrctl =>
			if(s[0] == 'e')
				return;
			wmlib->titlectl(hdr, s);
		* =>
		}
		if((i%10) == 9)
			tk->cmd(hdr, "update");
	}
	tk->cmd(hdr, "update");

	spawn hproc(hdrctl, hdr);
}

topit(hdr: ref Toplevel, msg: int): int
{
	(err, s) := pop3cmd("TOP "+string msg+" 0");
	if(err != nil) {
		tklib->notice(hdr, "Encountered error fetching header\n"+err);
		return 0;
	}

	size := int s;
	b := pop3body(size);
	if(b == nil)
		return 0;

	from := getfield("from", b);
	date := getfield("date", b);
	subj := getfield("subject", b);

	info := sys->sprint("%4d %5d %s %s %s", msg, size, date, from, subj);
	tk->cmd(hdr, ".f.l insert 0 '"+info);
	return 1;
}

mapdown(b: array of byte): string
{
	lb := len b;
	l := array[lb] of byte;
	for(i := 0; i < lb; i++) {
		c := b[i];
		if(c >= byte 'A' && c <= byte 'Z')
			c += byte('a' - 'A');
		l[i] = c;
	}
	return string l;	
}

getfield(key: string, text: array of byte): string
{
	key[len key] = ':';
	lk := len key;
	cl := byte key[0];
	cu := cl - byte ('a' - 'A');

	for(i := 0; i < len text - lk; i++) {
		t := text[i];
		if(t != cu && t != cl)
			continue;
		if(key == mapdown(text[i:i+lk])) {
			i += lk+1;
			for(j := i+1; j < len text; j++) {
				c := text[j];
				if(c == byte '\r' || c == byte '\n')
					break;
			}
			return string text[i:j-1];
		}
	}
	return "";
}

hproc(ctl: chan of string, hdr: ref Toplevel)
{
	for(;;) {
		s := <-ctl;
		if(s[0] == 'e')
			return;
		wmlib->titlectl(hdr, s);
	}
}

reply()
{
	if(cmesg == 0) {
		tklib->notice(main, "No message to reply to");
		return;
	}

	hdr := tk->cmd(main, ".hdr.t get 1.0 end");
	if(hdr == "") {
		tklib->notice(main, "Mail has no header to reply to");
		return;
	}

	wmsender := load WmSendmail "/dis/wm/sendmail.dis";
	if(wmsender == nil) {
		tklib->notice(main, "Failed to load sender:\n"+
					sys->sprint("%r"));
		return;
	}

	spawn wmsender->init(ctxt, "sendmail" :: wmlib->geom(main) :: hdr :: nil);
}

save()
{
	if(cmesg == 0) {
		tklib->notice(main, "No current message");
		return;
	}
	fname := wmlib->getfilename(ctxt.screen, main, "mailbox", "saved.letter/*", 
					  "/usr/"+username+"/mail");
	if(fname == nil)
		return;

	fd := sys->create(fname, sys->OWRITE, 8r660);
	if(fd == nil) {
		tklib->notice(main, "Failed to create "+fname+
				    "\n"+sys->sprint("%r"));
		return;
	}
	s := tk->cmd(main, ".hdr.t get 1.0 end");
	b := array of byte s;
	r := sys->write(fd, b, len b);
	if(r < 0) {
		tklib->notice(main, "Error writing file"+fname+
				    "\n"+sys->sprint("%r"));
		return;
	}
	s = tk->cmd(main, ".body.t get 1.0 end");
	b = array of byte s;
	n := sys->write(fd, b, len b);
	if(n < 0) {
		tklib->notice(main, "Error writing file"+fname+
				    "\n"+sys->sprint("%r"));
		return;
	}
	status("wrote "+string(n+r)+" bytes.");
}

delete()
{
	if(srv.dfd == nil) {
		tklib->notice(main, "You must be connected to delete messages");
		return;
	}
	(err, s) := pop3cmd("DELE "+string cmesg);
	if(err != nil) {
		tklib->notice(main, "Encountered error during delete\n"+err);
		return;
	}
	map[cmesg] = byte Deleted;
	status(s);
}

status(msg: string)
{
	tk->cmd(main, ".top.status configure -text {"+msg+"}; update");
}

disconnect()
{
	(err, s) := pop3cmd("QUIT");
	srv.dfd = nil;
	tk->cmd(main, ".top.con configure -text Connect");
	if(err != nil) {
		tklib->notice(main, err);
		return;
	}
	status(s);
}

connect(parent: ref Toplevel)
{
	topcfg := postposn(parent)+" -borderwidth 2 -relief raised";
	t := tk->toplevel(ctxt.screen, topcfg);

	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");

	conctl := wmlib->titlebar(t, "Connection Parameters", 0);
	tklib->tkcmds(t, con_cfg);

	username = rf("/dev/user");
	s := rf("/usr/"+username+"/mail/popserver");
	if(s != "")
		tk->cmd(t, ".e.h insert 0 '"+s);

	u := tk->cmd(t, ".e.u get");
	if(u == "")
		tk->cmd(t, ".e.u insert 0 '"+username);

	tk->cmd(t, "update");

	for(;;) alt {
	ctl := <-conctl =>
		if(ctl[0] == 'e')
			return;
		wmlib->titlectl(t, ctl);
	s = <-cmd =>
		if(s == "can")
			return;
		server := tk->cmd(t, ".e.h get");
		if(server == "") {
			tklib->notice(t, "You must supply a server address");
			break;
		}
		user := tk->cmd(t, ".e.u get");
		if(user == "") {
			tklib->notice(t, "You must supply a user name");
			break;
		}
		pass := tk->cmd(t, ".e.s get");
		if(pass == "") {
			tklib->notice(t, "You must give a secret or password");
			break;
		}
		if(dialer(t, server, user, pass) != 0)
			return;
		status("not connected");
	}
	srv.dfd = nil;
}

initialize()
{
	(err, s) := pop3cmd("STAT");
	if(err != nil) {
		tklib->notice(main, "The following error occurred while "+
				    "checking your mailbox:\n"+err);
		srv.dfd = nil;
		status("not connected");
		return;
	}

	tk->cmd(main, ".top.con configure -text Disconnect; update");
	nmesg = int s;
	if(nmesg == 0) {
		status("There are no messages.");
		return;
	}

	map = array[nmesg+1] of byte;
	for(i := 0; i <= nmesg; i++)
		map[i] = byte Ok;

	s = "";
	if(nmesg > 1)
		s = "s";
	status("You have "+string nmesg+" message"+s);
	cmesg = nmesg;
	loadmesg();
}

loadmesg()
{
	if(srv.dfd == nil) {
		tklib->notice(main, "You must be connected to read messages");
		return;
	}
	(err, s) := pop3cmd("RETR "+sys->sprint("%d", cmesg));
	if(err != nil) {
		tklib->notice(main, "Error retrieving message:\n"+err);
		return;
	}

	tk->cmd(main, ".hdr.t delete 1.0 end; .body.t delete 1.0 end");
	size := int s;

	status("reading "+string size+" bytes ...");

	b := pop3body(size);

	(headr, body) := split(string b);
	b = nil;
	tk->cmd(main, ".hdr.t insert end '"+headr);
	tk->cmd(main, ".body.t insert end '"+body);
	tk->cmd(main, ".hdr.t see 1.0; .body.t see 1.0");
	status("read message "+string cmesg+" of "+string nmesg+" , ready...");
}

split(text: string): (string, string)
{
	c, lc: int;
	hdr, body: string;

	hp := 0;
	for(i := 0; i < len text; i++) {
		c = text[i];
		if(c == '\r')
			continue;
		hdr[hp++] = c;
		if(lc == '\n' && c == '\n')
			break;
		lc = c;
	}
	bp := 0;
	while(i < len text) {
		c = text[i++];
		if(c != '\r')
			body[bp++] = c;
	}
	return (hdr, body);
}

dialer(t: ref Toplevel, server, user, pass: string): int
{
	ok: int;

	status("dialing server...");
	(ok, srv) = sys->dial(server+"!110", nil);
	if(ok < 0) {
		tklib->notice(t, "The following error occurred while\n"+
				 "dialing the server: "+sys->sprint("%r"));
		return 0;
	}
	status("connected...");
	(err, s) := pop3resp();
	if(err != nil) {
		tklib->notice(t, "An error occurred during sign on.\n"+err);
		return 0;
	}
	status(s);
	(err, s) = pop3cmd("USER "+user);
	if(err != nil) {
		tklib->notice(t, "An error occurred during login.\n"+err);
		return 0;
	}
	(err, s) = pop3cmd("PASS "+pass);
	if(err != nil) {
		tklib->notice(t, "An error occurred during login.\n"+err);
		return 0;
	}
	status("ready to serve...");
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

#
# Talk POP3
#
pop3cmd(cmd: string): (string, string)
{
	cmd += "\r\n";
#	sys->print("->%s", cmd);
	b := array of byte cmd;
	l := len b;
	n := sys->write(srv.dfd, b, l);
	if(n != l)
		return ("send to server:"+sys->sprint("%r"), nil);

	return pop3resp();
}

pop3resp(): (string, string)
{
	s := "";
	i := 0;
	lastc := 0;
	for(;;) {
		c := pop3getc();
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
	if(s[0:3] == "+OK") {
		i = 3;
		while(i < len s && s[i] == ' ')
			i++;
		return (nil, s[i:]);
	}
	if(s[0:4] == "-ERR") {
		i = 4;
		while(s[i] == ' ' && i < len s)
			i++;
		return (s[i:], nil);
	}
	return ("invalid server response", nil);
}

pop3body(size: int): array of byte
{
	size += 512;
	b := array[size] of byte;

	cnt := emptypopbuf(b);
	size -= cnt;

	for(;;) {

		if(cnt > 5 && string b[cnt-5:cnt] == "\r\n.\r\n") {
			b = b[0:cnt-5];
			break;
		}
		# resize buffer
		if(size == 0) {
			nb := array[len b + 4096] of byte;
			nb[0:] = b;
			size = len nb - len b;
			b = nb;
			nb = nil;
		}
		n := sys->read(srv.dfd, b[cnt:], len b - cnt);
		if(n <= 0) {
			tklib->notice(main, "Error retrieving message:\n"+
						sys->sprint("%r"));
			return nil;
		}
		size -= n;
		cnt += n;
	}
	return b;
}

Iob: adt
{
	nbyte:	int;
	posn:	int;
	buf:	array of byte;
};
popbuf: Iob;

pop3getc(): int
{
	if(popbuf.nbyte > 0) {
		popbuf.nbyte--;
		return int popbuf.buf[popbuf.posn++];
	}
	if(popbuf.buf == nil)
		popbuf.buf = array[512] of byte;

	popbuf.posn = 0;
	n := sys->read(srv.dfd, popbuf.buf, len popbuf.buf);
	if(n < 0)
		return -1;

	popbuf.nbyte = n-1;
	return int popbuf.buf[popbuf.posn++];
}

emptypopbuf(a: array of byte) : int
{
	i := popbuf.nbyte;

	if (i) {
		a[0:] = popbuf.buf[popbuf.posn:(popbuf.posn+popbuf.nbyte)];
		popbuf.nbyte = 0;
	}
	
	return i;
}
