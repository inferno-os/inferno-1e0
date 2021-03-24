implement Wm;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Screen, Display, Image: import draw;

include "tk.m";
	tk: Tk;

include "tklib.m";
	tklib: Tklib;

ToolHeight:	con 48;
Maxsetup:	con 2048;

Wm: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

rband: int;
rr: Draw->Rect;
rubberband:= array[4] of ref Image;
ones: ref Draw->Image;
screen: ref Draw->Screen;
gx: int;
gy: int;
snarf: array of byte;

t: ref Tk->Toplevel;

WinMinX:	con	100;
WinMinY:	con	80;

RbTotk, RbMove, RbTrack, RbSize, RbDrag: con iota;
DragT, DragB, DragL, DragR: con 1<<iota;

wmIO: ref Sys->FileIO;

Rdreq: adt
{
	off:	int;
	nbytes:	int;
	fid:	int;
	rc:	chan of (array of byte, string);
};
rdreq: Rdreq;

Icon: adt
{
	name:	string;
	repl:	int;
	wc:	Sys->Rwrite;
};
icons: list of Icon;

menu_config := array[] of {
	"menu .m",
	".m add command -label About -command {send cmd about}",
	".m add separator",
	".m add command -label {Introduction\n To Inferno} -command {send cmd dsp}",
	".m add separator",
	".m add command -label Local -command {send cmd dir}",
	".m add command -label Remote -command {send cmd rmtdir}",
	".m add command -label Tasks -command {send cmd task}",
	".m add command -label Notepad -command {send cmd edit}",
	".m add command -label Shell -command {send cmd sh}",
};

init(nil: ref Draw->Context, nil: list of string)
{
	sys  = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk   = load Tk Tk->PATH;
	tklib = load Tklib Tklib->PATH;

	sys->bind("#p", "/prog", sys->MREPL);

	sys->pctl(sys->NEWPGRP, nil);

	display := Display.allocate(nil);
	if(display == nil) {
		sys->print("can't initialize display: %r\n");
		return;
	}

	ones = display.ones;
	disp := display.image;
	screen = Screen.allocate(disp, display.rgb(161, 195, 209), 1);
	disp.draw(disp.r, screen.fill, display.ones, disp.r.min);

	ctxt := ref Draw->Context;
	ctxt.screen = screen;
	ctxt.display = display;

	rbdone := chan of int;

	spawn mouse(rbdone);
	spawn keyboard();

	t = tk->toplevel(screen, "-y "+string (screen.image.r.max.y-ToolHeight));
	tklib->init(ctxt);

	cmd := chan of string;
	exec := chan of string;
	task := chan of string;
	tk->namechan(t, cmd, "cmd");
	tk->namechan(t, exec, "exec");
	tk->namechan(t, task, "task");

	tk->cmd(t, "frame .toolbar -height 48 -width "+string screen.image.r.max.x);
	tk->cmd(t, "button .toolbar.start -bitmap inferno.bit -command {send cmd post}");
	tk->cmd(t, "pack propagate .toolbar 0");
	tk->cmd(t, "pack .toolbar.start -side left");
	tk->cmd(t, "pack .toolbar");

	tklib->tkcmds(t, menu_config);

	readsetup(t);

	mh := int tk->cmd(t, ".m cget height");
	postcmd := ".m post 0 " + string (screen.image.r.max.y - ToolHeight - mh - 4);

	tk->cmd(t, "update");

	rband = RbTotk;
	wmIO = sys->file2chan("/chan", "wm", sys->MBEFORE);
	if(wmIO == nil) {
		tklib->notice(nil, "Failed to make /chan/wm");
		return;
	}
	snarfIO := sys->file2chan("/chan", "snarf", sys->MBEFORE);
	if(snarfIO == nil) {
		tklib->notice(nil, "Failed to make /chan/snarf");
		return;
	}
	rdreq.fid = -1;

	req := rdreq;
	for(;;) alt {
	req = <-wmIO.read =>
		if(req.rc == nil)	# not interested in EOF
			break;
		if(rdreq.fid != -1)
			req.rc <-= (nil, "busy");
		else
		if(rband == RbTotk)
			req.rc <-= (array of byte sys->sprint("%5d %5d %5d %5d",
				rr.min.x, rr.min.y, rr.max.x,rr.max.y), nil);
		else
			rdreq = req;
	(off, data, fid, wc) := <-wmIO.write =>
		if(wc == nil)		# not interested in EOF
			break;
		#
		# m rect - request move from this rect
		# s rect - request size change from this rect
		# t name - move to toolbar
		# r name - restore from tool bar
		#
		case int data[0] {
		 *  =>
			wc <-= (0, "bad req len");
		's' =>
			setrr(data);
			rband = RbSize;
			wc <-= (len data, nil);
		'm' =>
			setrr(data);
			rband = RbMove;
			wc <-= (len data, nil);
		't' =>
			iconame := iconify(string data[1:len data], fid);
			icons = Icon(iconame, len data, wc) :: icons;
		}
		data = nil;
	<-rbdone =>
		rband = RbTotk;
		rubberband[0] = nil;
		rubberband[1] = nil;
		rubberband[2] = nil;
		rubberband[3] = nil;
		if(rdreq.fid != -1) {
			rdreq.rc <-= (array of byte sys->sprint("%5d %5d %5d %5d",
				rr.min.x, rr.min.y, rr.max.x,rr.max.y), nil);
			rdreq.fid = -1;
		}
	s := <-cmd =>
		case s {
		"post" =>
			tk->cmd(t, postcmd);
		"edit" =>
			wmedit := load Wm "/dis/wm/edit.dis";
			spawn applinit(wmedit, ctxt,  "edit" :: geom() :: nil);
			wmedit = nil;
		"dsp" =>
			wmdsp := load Wm "/demo/dsp/runprofile.dis";
			spawn applinit(wmdsp, ctxt,  "dsp" :: geom() :: nil);
			wmdsp = nil;
		 * =>
			mwm := load Wm "/dis/wm/"+s+".dis";
			if(mwm == nil) {
				tklib->notice(nil, "Failed to load application\n\""+s+
					"\"\nError: "+sys->sprint("%r"));
				break;
			}
			spawn applinit(mwm, ctxt,  s :: geom() :: "/" :: nil);
			mwm = nil;
		}
	e := <-exec =>
		wm := load Wm e;
		if(wm != nil) {
			spawn applinit(wm, ctxt, e :: geom() :: nil);
			wm = nil;
			break;
		}
		tklib->notice(nil, "Failed to load application\n\""+e+
			"\"\nError: "+sys->sprint("%r"));
	detask := <-task =>
		deiconify(detask);
	(off, data, fid, wc) := <-snarfIO.write =>
		if(wc == nil)
			break;
		snarf = data;
		wc <-= (len data, "");
	req = <-snarfIO.read =>
		if(req.rc == nil)
			break;
		sl := len snarf;
		if(req.off >= sl)
			req.nbytes = 0;
		if(req.nbytes > sl)
			req.nbytes = sl;
		req.rc <-= (snarf[0:req.nbytes], "");		
	}
}

applinit(mod: Wm, ctxt: ref Draw->Context, args: list of string)
{
	sys->pctl(sys->NEWPGRP|sys->FORKFD, nil);
	spawn mod->init(ctxt, args);
}

setrr(data: array of byte)
{
	rr.min.x = int string data[1:6];
	rr.min.y = int string data[6:12];
	rr.max.x = int string data[12:18];
	rr.max.y = int string data[18:];
}

iconify(label: string, fid: int): string
{
	n := sys->sprint(".toolbar.%d", fid);
	c := sys->sprint("button %s -command {send task %s} -text '%s",
				n, n, label);
	tk->cmd(t, c);
	tk->cmd(t, "pack "+n+" -side left -fill y; update");
	return n;
}

deiconify(name: string)
{
	tmp: list of Icon;
	while(icons != nil) {
		i := hd icons;
		if(i.name == name) {
			alt {
			i.wc <-= (i.repl, nil) =>
				break;
			* =>
				break;
			}
		}
		else
			tmp = i :: tmp;
		icons = tl icons;
	}
	icons = tmp;

	tk->cmd(t, "destroy "+name);
	tk->cmd(t, "update");
}

geom(): string
{
	if(gx > 130) {
		gx = 0;
		gy = 0;
	}
	gx += 20;
	gy += 20;
	return "-x "+string gx+" -y "+string gy;
}

mouse(rbdone: chan of int)
{
	xr: Draw->Rect;
	mode, xa, ya: int;
	count := 0;

	fd := sys->open("/dev/pointer", sys->OREAD);
	while ((fd == nil) && (count < 20)) {
		sys->sleep(1);	
		fd = sys->open("/dev/pointer", sys->OREAD);
		count++;
	}

	if (count >= 20) {
		sys->print("open: pointer: %r\n");
		return;
	}

	n := 0;
	buf := array[100] of byte;
	for(;;) {
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		if(int buf[0] != 'm' || n != 37)
			continue;

		x := int(string buf[ 1:13]);
		y := int(string buf[12:25]);
		b := int(string buf[24:37]);
		case rband {
		RbTotk =>
			tk->mouse(x, y, b);
		RbMove =>
			if((b & 1) == 0) {
				rbdone <-= 0;
				break;
			}
			band();
			if(!draw->rr.contains((x, y)))
				break;
			xa = x;
			ya = y;
			xr = rr;
			rband = RbTrack;
		RbTrack=>
			if((b & 1) == 0) {
				rbdone <-= 0;
				break;
			}
			rr = draw->xr.addpt((x-xa, y-ya));
			clamp();
			band();
		RbSize =>
			band();
			if(b == 0)
				break;
			mode = 0;
			tt := draw->rr.dx()/3;
			if(x > rr.min.x && x < rr.min.x+tt)
				mode |= DragL;
			else
			if(x > rr.max.x-tt && x < rr.max.x)
				mode |= DragR;
			tt = draw->rr.dy()/3;
			if(y > rr.min.y && y < rr.min.y+tt)
				mode |= DragT;
			else
			if(y > rr.max.y-tt && y < rr.max.y)
				mode |= DragB;
			if(mode == 0) {
				rbdone <-= 0;
				break;
			}
			rband = RbDrag;
			xa = x;
			ya = y;
			xr = rr;
		RbDrag =>
			if((b & 1) == 0) {
				rbdone <-= 0;
				break;
			}
			dx := x - xa;
			dy := y - ya;
			if(mode & DragL)
				rr.min.x = xr.min.x + dx;
			if(mode & DragR)
				rr.max.x = xr.max.x + dx;
			if(mode & DragT)
				rr.min.y = xr.min.y + dy;
			if(mode & DragB)
				rr.max.y = xr.max.y + dy;
			band();
		}
	}
}

clamp()
{
	dx, dy: int;

	if(rr.max.x >= screen.image.r.max.x) {
		dx = rr.max.x - screen.image.r.max.x;
		rr.max.x -= dx;
		rr.min.x -= dx;
	}
	if(rr.min.x < 0) {
		rr.max.x += -rr.min.x;
		rr.min.x = 0;
	}
	if(rr.max.y >= screen.image.r.max.y) {
		dy =  rr.max.y - screen.image.r.max.y;
		rr.max.y -= dy;
		rr.min.y -= dy;
	}
	if(rr.min.y < 0) {
		rr.max.y += -rr.min.y;
		rr.min.y = 0;
	}
}

keyboard()
{
	dfd := sys->open("/dev/keyboard", sys->OREAD);
	if(dfd == nil)
		return;

	b:= array[1] of byte;
	buf := array[10] of byte;
	i := 0;
	for(;;) {
		n := sys->read(dfd, buf[i:], len buf - i);
		if(n < 1)
			break;
		i += n;
		while(i >0 && (nutf := sys->utfbytes(buf, i)) > 0){
			s := string buf[0:nutf];
			tk->keyboard(int s[0]);
			buf[0:] = buf[nutf:i];
			i -= nutf;
		}
	}
}

band()
{
	r: Draw->Rect;

	(rr, nil) = draw->rr.clip(screen.image.r);
	if(draw->rr.dx() < WinMinX)
		rr.max.x = rr.min.x + WinMinX;
	if(draw->rr.dy() < WinMinY)
		rr.max.y = rr.min.y + WinMinY;

	r = (rr.min, (rr.min.x+2, rr.max.y));
	rubberband[0] = screen.newwindow(r, Draw->White);

	r = (rr.min, (rr.max.x-2, rr.min.y+2));
	rubberband[1] = screen.newwindow(r, Draw->White);

	r = ((rr.max.x-2, rr.min.y), rr.max);
	rubberband[2] = screen.newwindow(r, Draw->White);

	r = ((rr.min.x, rr.max.y-2), rr.max);
	rubberband[3] = screen.newwindow(r, Draw->White);
}

readsetup(t: ref Tk->Toplevel)
{
	fd := sys->open("wmsetup", sys->OREAD);
	if(fd == nil)
		return;

	buf := array[Maxsetup] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0) {
		tklib->notice(nil, "error reading wmsetup");
		return;
	}
	if(n >= len buf) {
		tklib->notice(nil, "wmsetup file is too big");
		return;
	}
	(nline, line) := sys->tokenize(string buf[0:n], "\r\n");
	mintok: con 3;
	extracascade: con 2;
	maxtok: con mintok + extracascade;
	while(line != nil) {
		s := hd line;
		line = tl line;
		if(s[0] == '#')
			continue;
		(nfield, field) := sys->tokenize(s, ":");
		if(nfield < mintok || nfield > maxtok) {
			tklib->notice(nil, "error parsing wmsetup file");
			continue;
		}
		menu := hd field;
		mpath0 := ".m";
		for(k := nfield; k >= mintok; k--) {
			mpath1 := mpath0;
			mpath0 = mpath0+"."+menu;
			for(j := 0; j < len mpath0; j++)
				if(mpath0[j] == ' ')
					mpath0[j] = '_';
			e := tk->cmd(t, mpath0+" cget -width");
			if(e[0] == '!') {
				tk->cmd(t, "menu "+mpath0);
				tk->cmd(t, mpath1+" insert 1 cascade -label {"+menu+"} -menu "+mpath0);
			}
			field = tl field;
			menu = hd field;
		}
		name := hd field;
		field = tl field;
		tk->cmd(t, mpath0+" add command -label {"+name+
			"} -command {send exec "+hd field+"}");
	}
}

