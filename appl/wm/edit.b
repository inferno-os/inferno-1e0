implement WmEdit;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Screen: import draw;

include "tk.m";
	tk: Tk;

include "tklib.m";
	tklib: Tklib;

include "wmlib.m";
	wmlib: Wmlib;

WmEdit: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

ed: ref Tk->Toplevel;
screen: ref Screen;

ed_config := array[] of {
	"frame .m -relief raised -bd 2",
	"frame .b",
	"menubutton .m.file -text File -menu .m.file.menu",
	"menubutton .m.edit -text Edit -menu .m.edit.menu",
	"menubutton .m.search -text Search -menu .m.search.menu",
	"label .m.filename",
	"pack .m.file .m.edit .m.search -side left",
	"pack .m.filename -padx 10 -side left",
	"menu .m.file.menu",
	".m.file.menu add command -label Open... -command {send c open}",
	".m.file.menu add separator",
	".m.file.menu add command -label Save -command {send c save}",
	".m.file.menu add command -label {Save As...} -command {send c saveas}",
	"menu .m.edit.menu",
	".m.edit.menu add command -label Cut -command {send c cut}",
	".m.edit.menu add command -label Copy -command {send c copy}",
	".m.edit.menu add command -label Paste -command {send c paste}",
	"menu .m.search.menu",
	".m.search.menu add command -label Search -command {send c search}",
	".m.search.menu add command -label {Search For...} -command {send c searchf}",
	"text .b.t -width 12c -height 7c -yscrollcommand {.b.s set}",
	"scrollbar .b.s -command {.b.t yview}",
	"pack .b.s -fill y -side left",
	"pack .b.t -fill both -expand 1",
	"pack .Wm_t .m -fill x",
	"pack .b -fill both -expand 1",
	"focus .b.t",
	"pack propagate . 0",
	"update",
};

curfile := "";
snarf := "";
searchfor := "";
path := ".";

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys  = load Sys  Sys->PATH;
	draw = load Draw Draw->PATH;
	tk   = load Tk   Tk->PATH;
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
	screen = ctxt.screen;
	ed = tk->toplevel(screen, tkargs+" -borderwidth 2 -relief raised");

	wmctl := wmlib->titlebar(ed, "Notepad", Wmlib->Appl);

	c := chan of string;
	tk->namechan(ed, c, "c");
	drag := chan of string;
	tk->namechan(ed, drag, "Wm_drag");
	tklib->tkcmds(ed, ed_config);

	if(argv != nil) {
		e := loadtfile(hd argv);
		if(e != nil)
			tklib->notice(ed, e);
	}

	tk->cmd(ed, "update");

	e := tk->cmd(ed, "variable lasterror");
	if(e != "") {
		sys->print("edit error: %s\n", e);
		return;
	}

	cmdloop: for(;;) {
		alt {
		s := <-c =>
			case s {
			"open" =>
				do_open();
			"save" =>
				do_save(0);
			"saveas" =>
				do_save(1);
			"cut" =>
				do_snarf(1);
			"copy" =>
				do_snarf(0);
			"paste" =>
				do_paste();
			"search" =>
				do_search(0);
			"searchf" =>
				do_search(1);
			}
		s := <-wmctl =>
			if(s == "exit")
				break cmdloop;
			wmlib->titlectl(ed, s);
		s := <-drag =>
			if(len s < 6 || s[0:5] != "path=")
				break;
			tk->cmd(ed, "raise .; .b.t delete 1.0 end");
			e = loadtfile(s[5:]);
			if(e != nil)
				tklib->notice(ed, e);
		}
		tk->cmd(ed, "update");
		e = tk->cmd(ed, "variable lasterror");
		if(e != "") {
			sys->print("edit error: %s\n", e);
			break cmdloop;
		}
	}
}

do_open()
{
	for(;;) {
		fname := wmlib->getfilename(screen, ed, "", "*", path);
		if(fname == "")
			break;
		tk->cmd(ed, ".b.t delete 1.0 end");
		e := loadtfile(fname);
		if(e == nil) {
			basepath(fname);
			break;
		}
		if(tklib->dialog(ed, e, 0, "Cancel" :: "Open another file" :: nil) == 0)
			break;
	}
}

basepath(file: string)
{
	for(i := len file-1; i >= 0; i--) {
		if(file[i] == '/') {
			path = file[0:i];
			return;
		}
	}
}

do_save(prompt: int)
{
	fname := curfile;

	contents := tk->cmd(ed, ".b.t get 1.0 end");
	if(tklib->is_err(contents)) {
		sys->print("problem getting contents: %s\n", contents);
		return;
	}
	for(;;) {
		if(prompt || curfile == "")
			fname = tklib->getstring(ed, "File");
		if(savetfile(fname, contents))
			break;
		if(tklib->dialog(ed, "Can't save file " + fname, 0, "Cancel" :: "Try another file" :: nil) == 0)
			break;
		prompt = 1;
	}
}

do_snarf(del: int)
{
	range := tk->cmd(ed, ".b.t tag nextrange sel 1.0");
	if(range == "" || tklib->is_err(range))
		return;
	snarf = tk->cmd(ed, ".b.t get " + range);
	if(del)
		tk->cmd(ed, ".b.t delete " + range);
}

do_paste()
{
	if(snarf == "")
		return;
	tk->cmd(ed, ".b.t insert insert '" + snarf);
}

do_search(prompt: int)
{
	if(prompt)
		searchfor = tklib->getstring(ed, "Search For");
	if(searchfor == "")
		return;
	ix := tk->cmd(ed, ".b.t search -- " + tklib->tkquote(searchfor) + " insert+1c");
	if(!tklib->is_err(ix) && ix != "") {
		tk->cmd(ed, ".b.t tag remove sel 0.0 end");
		tk->cmd(ed, ".b.t mark set anchor " + ix);
		tk->cmd(ed, ".b.t mark set insert " + ix);
		tk->cmd(ed, ".b.t tag add sel " + ix + " " + ix + "+" + string(len searchfor) + "c");
		tk->cmd(ed, ".b.t see " + ix);
	}
}

loadtfile(path: string): string
{
	fd := sys->open(path, sys->OREAD);
	if(fd == nil)
		return "Can't open "+path+", the error was:\n"+sys->sprint("%r");
	(ok, d) := sys->fstat(fd);
	if(ok < 0)
		return "Can't stat "+path+", the error was:\n"+sys->sprint("%r");
	if(d.mode & sys->CHDIR)
		return path+" is a directory";

	tk->cmd(ed, "cursor -bitmap cursor.wait");
	BLEN: con 8192;
	buf := array[BLEN+Sys->UTFmax] of byte;
	inset := 0;
	for(;;) {
		n := sys->read(fd, buf[inset:], BLEN);
		if(n <= 0)
			break;
		n += inset;
		nutf := sys->utfbytes(buf, n);
		s := string buf[0:nutf];
		# move any partial rune to beginning of buffer
		inset = n-nutf;
		buf[0:] = buf[nutf:n];
		tk->cmd(ed, ".b.t insert end '" + s);
	}
	curfile = path;
	newcurfile();
	tk->cmd(ed, "cursor -default");
	return "";
}

savetfile(path: string, contents: string): int
{
	buf := array of byte contents;
	n := len buf;

	fd := sys->create(path, sys->OWRITE, 8r664);
	if(fd == nil)
		return 0;
	i := sys->write(fd, buf, n);
	if(i != n) {
		sys->print("savetfile only wrote %d of %d: %r\n", i, n);
		return 0;
	}
	curfile = path;

	return 1;
}

newcurfile()
{
	tk->cmd(ed, ".m.filename configure -text '" + curfile);
}
