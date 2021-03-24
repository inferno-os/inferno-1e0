implement Wmlib;

include "sys.m";
	sys: Sys;
	Dir: import sys;

include "draw.m";
	draw: Draw;
	Screen: import draw;

include "tk.m";
	tk: Tk;
	Toplevel: import tk;

include "workdir.m";
	wd: Workdir;

include "readdir.m";
	rdir: Readdir;

include "filepat.m";
	filepat: Filepat;

include "wmlib.m";

init()
{
	sys = load Sys Sys->PATH;
	tk = load Tk Tk->PATH;
}

title_cfg := array[] of {
	"frame .Wm_t -bg #aaaaaa -borderwidth 2",
	"button .Wm_t.e -bitmap exit.bit -command {send wm_title exit}",
	"pack .Wm_t.e -side right",
	"bind .Wm_t <Button-1> { raise .; send wm_title move}",
	"bind .Wm_t <Motion-Button-1> {}",
	"bind .Wm_t <Motion> {}",
	"bind .Wm_t.title <Button-1> { raise .;send wm_title move}",
	"bind .Wm_t.title <Motion-Button-1> {}",
	"bind .Wm_t.title <Motion> {}",
	"bind . <FocusIn> {.Wm_t configure -bg blue;"+
		" .Wm_t.title configure -bg blue;update}",
	"bind . <FocusOut> {.Wm_t configure -bg #aaaaaa;"+
		" .Wm_t.title configure -bg #aaaaaa;update}",
};

#
# Create a window manager title bar called .Wm_t which is ready
# to pack at the top level
#
titlebar(t: ref Toplevel, title: string, flags: int): chan of string
{
	wm_title := chan of string;

	tk->namechan(t, wm_title, "wm_title");

	tk->cmd(t, "label .Wm_t.title -anchor w -bg #aaaaaa -fg white -text {"+title+"}");

	for(i := 0; i < len title_cfg; i++)
		tk->cmd(t, title_cfg[i]);

	if(flags & OK)
		tk->cmd(t, "button .Wm_t.ok -bitmap ok.bit -command {send wm_title ok}; pack .Wm_t.ok -side right");

	if(flags & Hide)
		tk->cmd(t, "button .Wm_t.t -bitmap task.bit -command {send wm_title task}; pack .Wm_t.t -side right");

	if(flags & Resize)
		tk->cmd(t, "button .Wm_t.m -bitmap maxf.bit -command {send wm_title size}; pack .Wm_t.m -side right");

	if(flags & Help)
		tk->cmd(t, "button .Wm_t.h -bitmap help.bit -command {send wm_title help}; pack .Wm_t.h -side right");

	# pack the title last so it gets clipped first
	tk->cmd(t, "pack .Wm_t.title -side left");
	return wm_title;
}

#
# titlectl implements the default window behavior for programs
# using title bars
#
titlectl(t: ref Toplevel, request: string)
{
	tk->cmd(t, "cursor -default");
	case request {
	"move" or "size" =>
		moveresize(t, request[0]);
	"exit" =>
		pid := sys->pctl(0, nil);
		fd := sys->open("/prog/"+string pid+"/ctl", sys->OWRITE);
		sys->fprint(fd, "killgrp");
		exit;
	"task" =>
		fd := sys->open("/chan/wm", sys->ORDWR);
		if(fd == nil) {
			sys->print("open wm: %r\n");
			return;
		}
		tk->cmd(t, ". unmap");
		sys->fprint(fd, "t%s", tk->cmd(t, ".Wm_t.title cget -text"));
		tk->cmd(t, ". map");
	}
}

#
# find upper left corner for new child window
#
geom(t: ref Toplevel): string
{
	x := int tk->cmd(t, ". cget x");
	y := int tk->cmd(t, ". cget y");

	x += 20;
	y += 20;
	return "-x "+string x+" -y "+string y;
}

#
# Set the name that will be displayed on the task bar
#
taskbar(t: ref Toplevel, name: string): string
{
	old := tk->cmd(t, ".Wm_t.title cget -text");
	tk->cmd(t, ".Wm_t.title configure -text '"+name);
	return old;
}

#
# Dialog with wm to rubberband the window and return a new position
# or size
#
moveresize(t: ref Toplevel, mode: int)
{
	ox := int tk->cmd(t, ". cget -x");
	oy := int tk->cmd(t, ". cget -y");
	w := int tk->cmd(t, ". cget -width");
	h := int tk->cmd(t, ". cget -height");
	bw := int tk->cmd(t, ". cget -borderwidth");

	h += 2*bw;
	w += 2*bw;
	fd := sys->open("/chan/wm", sys->ORDWR);
	if(fd == nil) {
		sys->print("open wm: %r\n");
		return;
	}
	sys->fprint(fd, "%c%5d %5d %5d %5d", mode, ox, oy, ox+w, oy+h);

	reply := array[128] of byte;
	n := sys->read(fd, reply, len reply);
	if(n < 0)
		return;

	s := string reply[0:n];
	x := int s;
	y := int s[6:];
	if(mode == 'm') {
		if(ox != x || oy != y)
			tk->cmd(t, ". configure -x "+string x+" -y "+string y+"; update");
		return;
	}
	w = int s[12:] - x;
	h = int s[18:] - y;

	tk->cmd(t, ". configure -x "+ string x +
		   " -y "+string y+
		   " -width "+string w+
		   " -height "+string h+
		   "; update");
}

snarfget(): string
{
	fd := sys->open("/chan/snarf", sys->OREAD);
	if(fd == nil)
		return "";

	buf := array[8192] of byte;
	n := sys->read(fd, buf, len buf);
	if(n <= 0)
		return "";

	return string buf[0:n];
}

snarfput(buf: string)
{
	fd := sys->open("/chan/snarf", sys->OWRITE);
	if(fd != nil)
		sys->fprint(fd, "%s", buf);
}

getfilename_config := array[] of {
	"frame .df",
	"frame .f",
	"frame .d",
	"entry .fent -relief sunken -bd 2 -width 20w",
	"entry .dent -relief sunken -bd 2 -width 20w",
	"listbox .flb -width 20w -height 200 -yscrollcommand {.fscry set}"+
			" -xscrollcommand {.fscrx set}",
	"bind .flb <Double-Button> {send g ok}",
	"listbox .dlb -width 20w -height 200 -yscrollcommand {.dscry set}"+
			" -xscrollcommand {.dscrx set}",
	"scrollbar .fscry -width 18 -command {.flb yview}",
	"scrollbar .dscry -width 18 -command {.dlb yview}",
	"scrollbar .fscrx -height 18 -command {.flb xview} -orient horizontal",
	"scrollbar .dscrx -height 18 -command {.dlb xview} -orient horizontal",
	"frame .newf",
	"frame .dlbf",
	"pack .dlb -fill both -expand 1 -in .dlbf",
	"pack .dscrx -fill x -in .dlbf",
	"frame .flbf",
	"pack .flb .fscrx -fill x -in .flbf",
	"pack .fent -pady 5 -fill x -in .f -side top",
	"pack .newf -fill x -in .f -side top",
	"pack .flbf .fscry -expand 1 -fill y -in .f -side left",
	"pack .dent -pady 5 -fill x -in .d -side top",
	"pack .dlbf .dscry -expand 1 -fill both -in .d -side left",
	"pack .d .f -padx 10 -side left -anchor n -fill y -expand 1 -in .df",
	"pack .Wm_t .df -side top -fill x",
	"bind .fent <Key-\n> {send g newpat}",
	"bind .dent <Key-\n> {send g newdir}",
	"bind .dlb <ButtonRelease-1> +{send g newd}"
};

lastdir := "";

getfilename(screen: ref Screen, parent: ref Toplevel, title, pat, dir: string): string
{
	if(wd == nil) {
		wd = load Workdir Workdir->PATH;
		rdir = load Readdir Readdir->PATH;
		filepat = load Filepat Filepat->PATH;
	}
	# start at  directory of previous file
	if(dir == ""){
		if (lastdir != "")
			dir = lastdir;
		else
			dir = ".";
	}
	where := "-x 50 -y 50";
	if(parent != nil) {
		x := int tk->cmd(parent, ". cget -x");
		y := int tk->cmd(parent, ". cget -y");
		where = sys->sprint("-x %d -y %d", x+30, y+30);
	}
	t := tk->toplevel(screen, where + " -borderwidth 2 -relief raised");
	g := chan of string;
	tk->namechan(t, g, "g");

	tc := titlebar(t, "Open "+title, OK);
	for(i := 0; i < len getfilename_config; i++)
		tk->cmd(t, getfilename_config[i]);
	if(pat == "")
		pat = "*";
	new := 0;
	for(i = 0; i < len pat; i++) {
		if(pat[i] == '/') {
			new = 1;
			tk->cmd(t, "entry .new -width 20w");
			tk->cmd(t, ".new insert end '"+pat[0:i]);
			tk->cmd(t, "pack .new -in .newf -fill x");
			tk->cmd(t, "bind .new <Key-\n> {send g ok}");
			pat = pat[i+1:];
			break;
		}
	}
	tk->cmd(t, ".fent insert end '" + pat);

	nd := dodir(t, pat, dir);
	if(nd == "")
		return "";
	else
		dir = nd;
	tk->cmd(t, "update");

	e := tk->cmd(t, "variable lasterror");
	if(e != "") {
		sys->print("getfilename error: %s\n", e);
		return "";
	}

	loop: for(;;) {
		alt {
		s := <-g =>
			case s{
			"cancel" =>
				return "";
			"ok" =>
				break loop;
			"newpat" =>
				pat = tk->cmd(t, ".fent get");
				if(pat == "")
					pat = "*";
				dodir(t, pat, dir);
			"newdir" =>
				odir := dir;
				dir = tk->cmd(t, ".dent get");
				nd = dodir(t, pat, dir);
				if(nd == "")
					dir = odir;
				else
					dir = nd;
			"newd" =>
				dind := tk->cmd(t, ".dlb curselection");
				if(dind != "") {
					odir := dir;
					sel := tk->cmd(t, ".dlb get " + dind);
					if(len sel > 4 && sel[0:4] == "    ")
						dir = dir + "/" + sel[4:];
					if(len sel < 2 || sel[0:2] != "  ")
						dir = dir + "/" + "..";
					nd = dodir(t, pat, dir);
					if(nd == "")
						dir = odir;
					else
						dir = nd;
				}
			}
		s := <-tc =>
			case s{
			"exit" =>
				return "";
			"ok" =>
				break loop;
			}
			titlectl(t, s);
		}
		tk->cmd(t, "update");
		e = tk->cmd(t, "variable lasterror");
		if(e != "") {
			sys->print("getfilename error: %s\n", e);
			return "";
		}
	}

	find := tk->cmd(t, ".flb curselection");
	if(find == "") {
		if(new != 0) {
			find = dir+"/"+tk->cmd(t, ".new get");
		}
		return find;
	}
	fname := tk->cmd(t, ".flb get " + find);
	if(fname == "" || fname[0] == '!')
		return "";

	tk->cmd(t, "destroy .");
	e = tk->cmd(t, "variable lasterror");
	if(e != "") {
		sys->print("getfilename error: %s\n", e);
		return "";
	}

	lastdir = dir;
	if(dir == "/")
		return dir + fname;
	else
		return dir + "/" + fname;
}

dodir(t: ref Toplevel, pat: string, dir: string): string
{
	d := array[200] of Dir;

	(cdir, parelem, elem) := canondir(dir);
	if(cdir == "")
		return "";

	(a, n) := rdir->init(dir, rdir->NAME);
	if(a == nil)
		return "";

	tk->cmd(t, ".dent delete 0 end");
	tk->cmd(t, ".dent insert end '" + cdir);
	tk->cmd(t, ".flb delete 0 end");
	tk->cmd(t, ".dlb delete 0 end");
	if(!(parelem == "/" && elem == "/"))
		tk->cmd(t, ".dlb insert end '" + parelem);
	tk->cmd(t, ".dlb insert end '  " + elem);
	for(i := 0; i < n; i++) {
		if(a[i].mode & sys->CHDIR)
			tk->cmd(t, ".dlb insert end '    " + a[i].name);
		else {
			if(filepat->match(pat, a[i].name))
				tk->cmd(t, ".flb insert end '" + a[i].name);
		}
	}
	return cdir;
}

# Turn dir into an absolute path, and return
# (absolute path, name of parent element, name of dir within parent);
# return ("","","") on error.
# Remove uses of "." and ".."
canondir(dir: string): (string, string, string)
{
	path, ppath, p : list of string;
	canon, elem, parelem : string;
	n : int;

	if(dir == "")
		return ("", "", "");
	if(dir[0] != '/') {
		pwd := wd->init();
		if(pwd == "")
			return ("", "", "");
		(n,path) = sys->tokenize(pwd + "/" + dir, "/");
	}
	else
		(n,path) = sys->tokenize(dir, "/");

	ppath = nil;
	for(p = path; p != nil; p = tl p) {
		if(hd p == "..") {
			if(ppath != nil)
				ppath = tl ppath;
		}
		else if(hd p != ".")
			ppath = (hd p) :: ppath;
	}
	canon = "/";
	elem = canon;
	parelem = canon;
	if(ppath != nil) {
		elem = hd ppath;
		canon = "/" + elem;
		if(tl ppath != nil)
			parelem = hd(tl ppath);
		ppath = tl ppath;
		while(ppath != nil) {
			canon ="/" +  (hd ppath) + canon;
			ppath = tl ppath;
		}
	}
	return (canon, parelem, elem);
}
