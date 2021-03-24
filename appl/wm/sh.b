implement WmSh;

include "sys.m";
	sys: Sys;
	FileIO, NEWFD, FORKNS, MBEFORE: import sys;

include "draw.m";
	draw: Draw;
	Context: import draw;

include "tk.m";
	tk: Tk;

include "wmlib.m";
	wmlib: Wmlib;

include	"tklib.m";
	tklib: Tklib;

WmSh: module
{
	init:	fn(ctxt: ref Draw->Context, args: list of string);
};

Command: module
{
	init:	fn(ctxt: ref Draw->Context, args: list of string);
};

BS:		con 8;		# ^h backspace character
BSW:		con 23;		# ^w bacspace word
BSL:		con 21;		# ^u backspace line
EOT:		con 4;		# ^d end of file
ESC:		con 27;		# hold mode

HIWAT:	con 2000;	# maximum number of lines in transcript
LOWAT:	con 1500;	# amount to reduce to after high water

Name:	con "Shell";

Rdreq: adt
{
	off:	int;
	nbytes:	int;
	fid:	int;
	rc:	chan of (array of byte, string);
};

shwin_cfg := array[] of {
	"menu .m",
	".m add command -text Cut -command {send edit cut}",
	".m add command -text Paste -command {send edit paste}",
	".m add command -text Snarf -command {send edit snarf}",
	".m add command -text Send -command {send edit send}",
	"frame .ft",
	"scrollbar .ft.scroll -command {.ft.t yview}",
	"text .ft.t -width 10c -height 7c -yscrollcommand {.ft.scroll set}",
	"pack .ft.scroll -side left -fill y",
	"pack .ft.t -fill both -expand 1",
	"pack .Wm_t -fill x",
	"pack .ft -fill both -expand 1",
	"pack propagate . 0",
	"focus .ft.t",
	"bind .ft.t <Key> {send keys {%A}}",
	"bind .ft.t <Control-d> {send keys {%A}}",
	"bind .ft.t <Control-h> {send keys {%A}}",
	"bind .ft.t <Button-1> +{grab set .ft.t; send but1 pressed}",
	"bind .ft.t <Double-Button-1> +{grab set .ft.t; send but1 pressed}",
	"bind .ft.t <ButtonRelease-1> +{grab release .ft.t; send but1 released}",
	"bind .ft.t <ButtonPress-2> {send but2 pressed}",
	"bind .ft.t <Motion-Button-2-Button-1> {}",
	"bind .ft.t <Motion-ButtonPress-2> {}",
	"bind .ft.t <ButtonPress-3> {send but3 %X %Y}",
	"bind .ft.t <ButtonRelease-3> {}",
	"bind .ft.t <Motion-Button-3> {}",
	"bind .ft.t <Motion-Button-3-Button-1> {}",
	"bind .ft.t <Double-Button-3> {}",
	"bind .ft.t <Double-ButtonRelease-3> {}",
	"bind .m <ButtonRelease> {.m tkMenuButtonUp %x %y}",
	"update"
};

rdreq: list of Rdreq;
menuindex := "0";
holding := 0;

init(ctxt: ref Context, argv: list of string)
{
	s: string;

	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	tklib = load Tklib Tklib->PATH;
	wmlib = load Wmlib Wmlib->PATH;

	tklib->init(ctxt);
	wmlib->init();

	tkargs := "";
	argv = tl argv;
	if(argv != nil) {
		tkargs = hd argv;
		argv = tl argv;
	}
	t := tk->toplevel(ctxt.screen, tkargs+" -borderwidth 2 -relief raised");

	edit := chan of string;
	tk->namechan(t, edit, "edit");

	titlectl := wmlib->titlebar(t, Name, Wmlib->Appl);
	tklib->tkcmds(t, shwin_cfg);

	ioc := chan of (int, ref FileIO);
	spawn newsh(ctxt, ioc);

	(pid, file) := <-ioc;
	if(file == nil) {
		sys->print("newsh: %r\n");
		return;
	}

	keys := chan of string;
	tk->namechan(t, keys, "keys");

	but1 := chan of string;
	tk->namechan(t, but1, "but1");
	but2 := chan of string;
	tk->namechan(t, but2, "but2");
	but3 := chan of string;
	tk->namechan(t, but3, "but3");
	button1 := 0;

	rdrpc: Rdreq;

	# outpoint is place in text to insert characters printed by programs
	tk->cmd(t, ".ft.t mark set outpoint end; .ft.t mark gravity outpoint left");

	for(;;) alt {
	menu := <-titlectl =>
		if(menu[0] == 'e') {
			kill(pid);
			return;
		}
		wmlib->titlectl(t, menu);

	ecmd := <-edit =>
		editor(t, ecmd);
		sendinput(t);
		tk->cmd(t, "focus .ft.t");

	c := <-keys =>
		cut(t, 1);
		char := c[1];
		if(char == '\\')
			char = c[2];
		update := ";.ft.t see insert;update";
		case char {
		* =>
			tk->cmd(t, ".ft.t insert insert "+c+update);
		'\n' or EOT =>
			tk->cmd(t, ".ft.t insert insert "+c+update);
			sendinput(t);
		BS =>
			if(!insat(t, "outpoint") && !insat(t, "1.0"))
				tk->cmd(t, ".ft.t delete insert-1chars"+update);
		ESC =>
			holding ^= 1;
			color := "blue";
			if(!holding){
				color = "black";
				wmlib->taskbar(t, Name);
				sendinput(t);
			}else
				wmlib->taskbar(t, Name+" (holding)");
			tk->cmd(t, ".ft.t configure -foreground "+color+update);
		BSL =>
			if(insininput(t))
				tk->cmd(t, ".ft.t delete outpoint insert"+update);
			else
				tk->cmd(t, ".ft.t delete {insert linestart} insert"+update);
		BSW =>
			if(insat(t, "outpoint"))
				break;
			a0 := isalnum(tk->cmd(t, ".ft.t get insert-1chars"));
			a1 := isalnum(tk->cmd(t, ".ft.t get insert"));
			start: string;
			if(a0 && a1)	# middle of word
				start = "{insert wordstart}";
			else if(a0)		# end of word
				start = "{insert-1chars wordstart}";
			else{	# beginning or not in word; must search
				s: string;
				for(n:=1; ;){
					s = tk->cmd(t, ".ft.t get insert-"+ string n +"chars");
					if(s=="" || s=="\n"){
						start = "insert-"+ string n+"chars";
						break;
					}
					if(isalnum(s)){
						start = "{insert-"+ string n+"chars wordstart}";
						break;
					}
					n++;
				}
				
			}
			# don't ^w across outpoint
			if(tk->cmd(t, ".ft.t compare insert >= outpoint") == "1"
			&& tk->cmd(t, ".ft.t compare "+start+" < outpoint") == "1")
				start = "outpoint";
			tk->cmd(t, ".ft.t delete " + start + " insert"+update);
		}

	c := <-but1 =>
		button1 = (c == "pressed");

	c := <-but2 =>
		if(button1){
			cut(t, 1);
			tk->cmd(t, "update");
		}

	c := <-but3 =>
		if(button1){
			paste(t);
			tk->cmd(t, "update");
			break;
		}
		(nil, l) := sys->tokenize(c, " ");
		x := int hd l - 50;
		y := int hd tl l - int tk->cmd(t, ".m yposition "+menuindex) - 10;
		tk->cmd(t, ".m activate "+menuindex+"; .m post "+string x+" "+string y+
			"; grab set .m; update");

	rdrpc = <-file.read =>
		if(rdrpc.rc == nil)
			return;
		append(rdrpc);
		sendinput(t);

	(off, data, fid, wc) := <-file.write =>
		if(wc == nil)
			return;
		cdata := string data;
		ncdata := string len cdata + "chars;";
		moveins := insat(t, "outpoint");
		tk->cmd(t, ".ft.t insert outpoint '"+ cdata);
		wc <-= (len data, nil);
		data = nil;
		s = ".ft.t mark set outpoint outpoint+" + ncdata;
		s += ".ft.t see outpoint;";
		if(moveins)
			s += ".ft.t mark set insert insert+" + ncdata;
		s += "update";
		tk->cmd(t, s);
		nlines := int tk->cmd(t, ".ft.t index end");
		if(nlines > HIWAT){
			s = ".ft.t delete 1.0 "+ string (nlines-LOWAT) +".0;update";
			tk->cmd(t, s);
		}
	}
}

RPCread: type (int, int, int, chan of (array of byte, string));

append(r: RPCread)
{
	t := r :: nil;
	while(rdreq != nil) {
		t = hd rdreq :: t;
		rdreq = tl rdreq;
	}
	rdreq = t;
}

insat(t: ref Tk->Toplevel, mark: string): int
{
	return tk->cmd(t, ".ft.t compare insert == "+mark) == "1";
}

insininput(t: ref Tk->Toplevel): int
{
	if(tk->cmd(t, ".ft.t compare insert >= outpoint") != "1")
		return 0;
	return tk->cmd(t, ".ft.t compare {insert linestart} == {outpoint linestart}") == "1";
}

isalnum(s: string): int
{
	if(s == "")
		return 0;
	c := s[0];
	if('a' <= c && c <= 'z')
		return 1;
	if('A' <= c && c <= 'Z')
		return 1;
	if('0' <= c && c <= '9')
		return 1;
	if(c == '_')
		return 1;
	if(c > 16rA0)
		return 1;
	return 0;
}

editor(t: ref Tk->Toplevel, ecmd: string)
{
	s, snarf: string;

	case ecmd {
	"cut" =>
		menuindex = "0";
		cut(t, 1);
	
	"paste" =>
		menuindex = "1";
		paste(t);

	"snarf" =>
		menuindex = "2";
		if(tk->cmd(t, ".ft.t tag ranges sel") == "")
			break;
		snarf = tk->cmd(t, ".ft.t get sel.first sel.last");
		wmlib->snarfput(snarf);

	"send" =>
		menuindex = "3";
		if(tk->cmd(t, ".ft.t tag ranges sel") != ""){
			snarf = tk->cmd(t, ".ft.t get sel.first sel.last");
			wmlib->snarfput(snarf);
		}else
			snarf = wmlib->snarfget();
		if(snarf != "")
			s = snarf;
		else
			return;
		if(s[len s-1] != '\n' && s[len s-1] != EOT)
			s[len s] = '\n';
		tk->cmd(t, ".ft.t see end; .ft.t insert end '"+s);
		tk->cmd(t, ".ft.t mark set insert end");
		tk->cmd(t, ".ft.t tag remove sel sel.first sel.last");
	}
	tk->cmd(t, "update");
}

cut(t: ref Tk->Toplevel, snarfit: int)
{
	if(tk->cmd(t, ".ft.t tag ranges sel") == "")
		return;
	if(snarfit)
		wmlib->snarfput(tk->cmd(t, ".ft.t get sel.first sel.last"));
	tk->cmd(t, ".ft.t delete sel.first sel.last");
}

paste(t: ref Tk->Toplevel)
{
	snarf := wmlib->snarfget();
	if(snarf == "")
		return;
	cut(t, 0);
	tk->cmd(t, ".ft.t insert insert '"+snarf);
	tk->cmd(t, ".ft.t tag add sel insert-"+string len snarf+"chars insert");
	sendinput(t);
}

sendinput(t: ref Tk->Toplevel)
{
	if(holding)
		return;
	input := tk->cmd(t, ".ft.t get outpoint end");
	slen := len input;
	if(slen == 0 || rdreq == nil)
		return;

	r := hd rdreq;
	for(i := 0; i < slen; i++)
		if(input[i] == '\n' || input[i] == EOT)
			break;

	if(i >= slen && slen < r.nbytes)
		return;

	if(i > r.nbytes)
		i = r.nbytes;
	advance := string (i+1);
	if(input[i] == EOT)
		input = input[0:i];
	else
		input = input[0:i+1];

	rdreq = tl rdreq;

	alt {
	r.rc <-= (array of byte input, "") =>
		tk->cmd(t, ".ft.t mark set outpoint outpoint+" + advance + "chars");
	* =>
		# requester has disappeared; ignore his request and try again
		sendinput(t);
	}
}

newsh(ctxt: ref Context, ioc: chan of (int, ref FileIO))
{
	pid := sys->pctl(NEWFD|FORKNS, nil);

	sh := load Command "/dis/sh.dis";
	if(sh == nil) {
		ioc <-= (0, nil);
		return;
	}

	fio := sys->file2chan("/dev", "cons", MBEFORE);
	ioc <-= (pid, fio);
	if(fio == nil)
		return;

	fd0 := sys->open("/dev/cons", sys->OREAD);
	fd1 := sys->open("/dev/cons", sys->OWRITE);
	fd2 := sys->open("/dev/cons", sys->OWRITE);

	sh->init(ctxt, "/dis/sh.dis" :: nil);
}

kill(pid: int)
{
	fd := sys->open("#p/"+string pid+"/ctl", sys->OWRITE);
	if(fd != nil)
		sys->fprint(fd, "kill");
}
