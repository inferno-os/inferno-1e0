implement WmDir;

include "sys.m";
	sys: Sys;
	Dir: import sys;

include "draw.m";
	draw: Draw;
	ctxt: ref Draw->Context;

include "tk.m";
	tk: Tk;
	Toplevel: import tk;

include "tklib.m";
	tklib: Tklib;

include "wmlib.m";
	wmlib: Wmlib;

include "readdir.m";
	readdir: Readdir;

include "daytime.m";
	daytime: Daytime;

Fontwidth: 	con 8;
Xwidth:		con 50;

WmDir: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

Wm: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

Filetype: adt
{
	ext:	string;
	cmd:	string;
	tkname:	string;
	bits:	string;
	mask:	string;
	loaded:	int;
	givearg:	int;
};

dirwin_cfg := array[] of {
	# Lay out the screen
	"frame .fc",
	"scrollbar .fc.scroll -command {.fc.c yview}",
	"canvas .fc.c -relief sunken -yscrollincrement 25"+
		" -borderwidth 2 -width 10c -height 300"+
		" -yscrollcommand {.fc.scroll set}"+
		" -font /fonts/misc/latin1.8x13.font",
	"frame .mbar",
	"menubutton .mbar.opt -text {Options} -menu .opt",
	"pack .mbar.opt -side left",
	"pack .fc.scroll -side right -fill y",
	"pack .fc.c -fill both -expand 1",
	"pack .Wm_t -fill x",
	"pack .mbar -fill x",
	"pack .fc -fill both -expand 1",
	"pack propagate . 0",

	# prepare cursor
	"image create bitmap waiting -file cursor.wait",

	# Build the options menu
	"menu .opt",
	".opt add radiobutton -text {by name}"+
		" -variable sort -value n -command {send opt sort}",
	".opt add radiobutton -text {by access}"+
		" -variable sort -value a -command {send opt sort}",
	".opt add radiobutton -text {by modify}"+
		" -variable sort -value m -command {send opt sort}",
	".opt add radiobutton -text {by size}"+
		" -variable sort -value s -command {send opt sort}",
	".opt add separator",
	".opt add radiobutton -text {use icons}"+
		" -variable show -value i -command {send opt icon}",
	".opt add radiobutton -text {use text}"
		+" -variable show -value t -command {send opt text}",
	".opt add separator",
	".opt add checkbutton -text {Walk} -command {send opt walk}",
};

key := Readdir->NAME;
walk: int;
path: string;
usetext: int;
cmdname: string;
sysnam: string;
nde: int;
now: int;
de: array of ref Sys->Dir;

filetypes: array of ref Filetype;
deftype: ref Filetype;
dirtype: ref Filetype;

inittypes()
{
	deftype = ref Filetype("", "/dis/wm/edit.dis",
				"WmDir_Dis", "file.bit", "file.mask", 0, 1);
	dirtype = ref Filetype("", nil,
				"WmDir_Dir", "dir.bit",  "dir.mask", 0, 1);
	filetypes = array[] of {
		ref Filetype(".dis", nil,
				"WmDis_Pic", "dis.bit", "dis.mask", 0, 0),
		ref Filetype(".bit", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".gif", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".jpg", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".jpeg", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".mask", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".DIS", nil,
				"WmDis_Pic", "dis.bit", "dis.mask", 0, 1),
		ref Filetype(".BIT", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".GIF", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".JPG", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".JPEG", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
		ref Filetype(".MASK", "/dis/wm/view.dis",
				"WmDir_Pic", "pic.bit", "pic.mask", 0, 1),
	};
}

init(env: ref Draw->Context, argv: list of string)
{
	ctxt = env;

	sys  = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk   = load Tk Tk->PATH;
	tklib = load Tklib Tklib->PATH;
	wmlib = load Wmlib Wmlib->PATH;
	readdir = load Readdir Readdir->PATH;

	tklib->init(ctxt);
	wmlib->init();
	inittypes();

	cmdname = hd argv;
	sysnam = sysname()+":";

	tkargs := "";
	argv = tl argv;
	if(argv != nil) {
		tkargs = hd argv;
		argv = tl argv;
	}
	t := tk->toplevel(ctxt.screen, tkargs+" -borderwidth 2 -relief raised");

	tk->cmd(t, "cursor -image waiting");

	filecmd := chan of string;
	tk->namechan(t, filecmd, "fc");
	conf := chan of string;
	tk->namechan(t, conf, "cf");
	opt := chan of string;
	tk->namechan(t, opt, "opt");

	titlebut := wmlib->titlebar(t, "", Wmlib->Appl);

	if(argv == nil)
		getdir(t, "");
	else
		getdir(t, hd argv);

	tklib->tkcmds(t, dirwin_cfg);
	drawdir(t);
	tk->cmd(t, "update; cursor -default");
	tk->cmd(t, "bind . <Configure> {send cf conf}");

	menu := "";

f:	for(;;) alt {
	menu = <-titlebut =>
		if(menu[0] == 'e')
			return;
		wmlib->titlectl(t, menu);
	<-conf =>
		#
		# Only recompute contents if the size changed
		#
		if(menu[0] != 's')
			break;
		tk->cmd(t, ".fc.c delete all");
		drawdir(t);
		tk->cmd(t, ".fc.c yview moveto 0; update");
	mopt := <-opt =>
		case mopt {
		"sort" =>
			case tk->cmd(t, "variable sort") {
			"n" => key = readdir->NAME;
			"a" => key = readdir->ATIME;
			"m" => key = readdir->MTIME;
			"s" => key = readdir->SIZE;
			}
			(de, nde) = readdir->sortdir(de, key);
		"walk" =>
			walk = !walk;
			continue f;
		"text" =>
			usetext = 1;
		"icon" =>
			usetext = 0;
		}
		tk->cmd(t, ".fc.c delete all");
		drawdir(t);
		tk->cmd(t, ".fc.c yview moveto 0; update");
	action := <-filecmd =>
		nd := int action[1:];
		if(nd > len de)
			break;
		case action[0] {
		'1' =>
			button1(t, de[nd]);
		'3' =>
			button3(t, de[nd]);
		}
	}
}

getdir(t: ref Toplevel, dir: string)
{
	if(dir == "")
		dir = "/";

	path = dir;

	(de, nde) = readdir->init(path, key);
	if(nde < 0) {
		tklib->notice(t, sys->sprint("reading %s: %r", path));
		exit;
	}

	if(path != "/") {
		(ok, d) := sys->stat("..");
		if(ok >= 0) {
			dot := array[nde+1] of ref Dir;
			dot[0] = ref d;
			dot[0].name = "..";
			dot[1:] = de;
			de = dot;
			nde++;
		}
	}

	for(i := 0; i < nde; i++) {
		s := de[i].name;
		l := len s;
		if(l > 4 && s[l-4:] == ".dis")
			de[i].mode |= 8r111;
	}
	wmlib->taskbar(t, sysnam+path);
}

defcursor(t: ref Toplevel)
{
	tk->cmd(t, "cursor -default");
}

button1(t: ref Toplevel, item: ref Dir)
{
	mod: Wm;

	tk->cmd(t, "cursor -image waiting");
	npath := path;
	name := item.name + "/";
	if(item.name == "..") {
		i := len path - 2;
		while(i > 0 && path[i] != '/')
			i--;
		npath = path[0:i];
		name = "/";
	}

	exec := npath+name[0:len name-1];
	ft := filetype(t, item, exec);

	if(item.mode & sys->CHDIR) {
		if(walk != 0) {
			path = npath;
			getdir(t, npath+name);
			tk->cmd(t, ".fc.c delete all");
			drawdir(t);
			tk->cmd(t, ".fc.c yview moveto 0; update");
			defcursor(t);
			return;
		}
		mod = load Wm "/dis/wm/dir.dis";
		defcursor(t);
		if(mod == nil) {
			tklib->notice(t, "Failed to load wmdir");
			return;
		}
		args := npath+name :: nil;
		args = wmlib->geom(t) :: args;
		args = cmdname :: args;
		spawn mod->init(ctxt,  args);
		return;
	}

	cmd := ft.cmd;
	if(cmd == nil)
		cmd = npath+name;

	mod = load Wm cmd;
	defcursor(t);
	if(mod == nil)
		tklib->notice(t, sys->sprint("Can't load %s: %r", cmd));
	else{
		if(ft.givearg)
			spawn applinit(mod, ctxt, item.name :: wmlib->geom(t) :: exec :: nil);
		else
			spawn applinit(mod, ctxt, item.name :: wmlib->geom(t) :: nil);
	}
}

applinit(mod: Wm, ctxt: ref Draw->Context, args: list of string)
{
	sys->pctl(sys->NEWPGRP|sys->FORKFD, nil);
	spawn mod->init(ctxt, args);
}

button3(t: ref Toplevel, stat: ref Sys->Dir)
{
	ft := filetype(t, stat, stat.name);
	img := "-file "+ft.bits+" -maskfile "+ft.mask;

	# create off screen
	d := tk->toplevel(ctxt.screen, "-x -50 -y -50");
	ds := chan of string;
	tk->namechan(d, ds, "ds");

	tk->cmd(d, "image create bitmap icon "+img);
	tk->cmd(d, "label .l -image icon; pack .l; grab set .l; update");
	tk->cmd(d, "bind .l <Motion> {. configure -x %X -y %Y}");
	tk->cmd(d, "bind .l <ButtonRelease> {send ds %X,%Y}");
	pos := <-ds;
	x := int pos;
	for(i := 0; i < len pos && pos[i] != ','; i++)
		;
	y := int pos[i+1:];
	d = tk->intop(ctxt.screen, x, y);
	if(d != nil && d != t)
		tk->cmd(d, "send Wm_drag path="+path+stat.name);
}

filetype(t: ref Toplevel, d: ref Dir, path: string): ref Filetype
{
	if(d.mode & Sys->CHDIR)
		return loadtype(t, dirtype);
	suffix := "";
	for(j := len path-2; j >= 0; j--)
		if(path[j] == '.'){
			suffix = path[j:];
			break;
		}
	if(suffix == "")
		return loadtype(t, deftype);
	for(i := 0; i<len filetypes; i++)
		if(suffix == filetypes[i].ext)
			return loadtype(t, filetypes[i]);
	return loadtype(t, deftype);
}

loadtype(t: ref Toplevel, ft: ref Filetype): ref Filetype
{
	if(ft.loaded)
		return ft;

	tk->cmd(t, "image create bitmap "+
			ft.tkname+" -file "+ft.bits+" -maskfile "+ft.mask);

	ft.loaded = 1;
	return ft;
}

drawdir(t: ref Toplevel)
{
	if(usetext)
		drawdirtxt(t);
	else
		drawdirico(t);
}

drawdirtxt(t: ref Toplevel)
{
	if(daytime == nil) {
		daytime = load Daytime Daytime->PATH;
		if(daytime == nil) {
			tklib->notice(t, "failed to load daytime");
			return;
		}
		now = daytime->now();
	}

	y := 10;
	for(i := 0; i < nde; i++) {
		tp := "file";
		if(de[i].mode & sys->CHDIR)
			tp = "dir ";
		else
		if(de[i].mode & 8r111)
			tp = "exe ";
		s := sys->sprint("%s %7d %s %s",
			tp,
			de[i].length,
			daytime->filet(now, de[i].mtime),
			de[i].name);
		id := tk->cmd(t, ".fc.c create text 10 "+string y+
				" -anchor w -text {"+s+"}");

		base := ".fc.c bind "+id;
		tk->cmd(t, base+" <Double-Button-1> {send fc %b "+string i+"}");
		tk->cmd(t, base+" <Button-3> {send fc %b "+string i+"}");
		tk->cmd(t, base+" <Motion-Button-3> {}");
		y += 15;
	}

	x := int tk->cmd(t, ".fc.c cget actwidth");
	tk->cmd(t, ".fc.c configure -scrollregion { 0 0 "+string x+" "+string y+"}");
}

drawdirico(t: ref Toplevel)
{
	w := int tk->cmd(t, ".fc.c cget actwidth");

	longest := 0;
	for(i := 0; i < nde; i++) {
		l := len de[i].name;
		if(l > longest)
			longest = l;
	}
	longest += 2;

	minw := (longest*Fontwidth);
	if( w < minw ){
		w = minw + int tk->cmd(t, ".fc.scroll cget actwidth");
		tk->cmd(t, ". configure -width "+string w);
		w = minw;
	}

	xwid := Xwidth;
	x := w/minw;
	x = w/x;
	if(x > xwid)
		xwid = x;

	x = xwid/2;
	y := 20;

	for(i = 0; i < nde; i++) {
		sx := string x;
		ft := filetype(t, de[i], de[i].name);
		img := ft.tkname;
		
		id := tk->cmd(t, ".fc.c create image "+sx+" "+
				string y+" -image "+img);
		tk->cmd(t, ".fc.c create text "+sx+
				" "+string (y+25)+" -text "+de[i].name);

		base := ".fc.c bind "+id;
		tk->cmd(t, base+" <Double-Button-1> {send fc %b "+string i+"}");
		tk->cmd(t, base+" <Button-3> {send fc %b "+string i+"}");
		tk->cmd(t, base+" <Motion-Button-3> {}");
		x += xwid;
		if(x > w) {
			x = xwid/2;
			y += 50;
		}
	}
	y += 50;
	x = int tk->cmd(t, ".fc.c cget actwidth");
	tk->cmd(t, ".fc.c configure -scrollregion { 0 0 "+string x+" "+string y+"}");
}

sysname(): string
{
	syspath := "#c";
	if ( cmdname == "wmdir" )
		syspath = "/n/dev";
	fd := sys->open(syspath+"/sysname", sys->OREAD);
	if(fd == nil)
		return "Anon";
	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0) 
		return "Anon";
	return string buf[0:n];
}
