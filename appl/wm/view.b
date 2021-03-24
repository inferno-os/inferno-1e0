implement View;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Rect, Display, Screen, Image: import draw;

include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include "imagefile.m";
	imageremap: Imageremap;
	readgif: RImagefile;
	readjpg: RImagefile;

include "tk.m";
	tk: Tk;
	Toplevel: import tk;

include "tklib.m";
	tklib: Tklib;

include	"wmlib.m";
	wmlib: Wmlib;

stderr: ref Sys->FD;
screen: ref Screen;
display: ref Display;
x := 25;
y := 25;

View: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	wmlib = load Wmlib Wmlib->PATH;
	tklib = load Tklib Tklib->PATH;
	tklib->init(ctxt);
	wmlib->init();

	stderr = sys->fildes(2);
	display = ctxt.display;
	screen = ctxt.screen;

	imageremap = load Imageremap Imageremap->PATH;
	if(imageremap == nil){
		sys->fprint(stderr, "View: can't load remap: %r\n");
		return;
	}

	bufio = load Bufio Bufio->PATH;
	if(bufio == nil){
		sys->fprint(stderr, "View: can't load bufio: %r\n");
		return;
	}

	# tk args come in with blanks; turn them into separate arguments
	# to extract -x and -y
	a: list of string;
	while(argv != nil){
		(nil, l) := sys->tokenize(hd argv, " ");
		if(l == nil)
			a = hd argv :: a;
		else
			while(l != nil){
				a = hd l :: a;
				l = tl l;
			}
		argv = tl argv;
	}
	while(a != nil){
		argv = hd a :: argv;
		a = tl a;
	}

	argv = tl argv;
	while(argv!=nil && (s:=hd argv)[0]=='-' && len s>1){
		if(s[1]!='x' && s[1]!='y')
			break;
		i := 0;
		if(len s > 2)
			i = int s[2:];
		else{
			argv = tl argv;
			if(argv != nil)
				i = int hd argv;
		}
		if(s[1] == 'x')
			x = i;
		else
			y = i;
		argv = tl argv;
	}

	if(argv == nil){
		f := wmlib->getfilename(screen, nil, "View file name", "*", ".");
		if(f == "")
			return;
		argv = f :: nil;
	}

	errdiff := 1;
	viewer := 0;

	while(argv != nil){
		file := hd argv;
		argv = tl argv;
		if(file == "-f"){
			errdiff = 0;
			continue;
		}

		im := display.open(file);
		mask: ref Image;

		if(im == nil){
			fd := bufio->open(file, Sys->OREAD);
			if(fd == nil){
				sys->fprint(stderr, "View: can't open %s\n", file);
				break;
			}

			mod := filetype(file, fd);
			if(mod == nil)
				return;

			(ri, err) := mod->read(fd);
			if(err != "")
				sys->fprint(stderr, "View: %s: %s\n", file, err);
			if(ri == nil)
				continue;
			mask = transparency(ri, file);

			# if transparency is enabled, errdiff==1 is probably a mistake,
			# but there's no easy solution.
			(im, err) = imageremap->remap(ri, display, errdiff);
			if(err != "")
				sys->fprint(stderr, "View: remap %s: %s\n", file, err);
			if(im == nil)
				break;
			ri = nil;
		}

		spawn view(im, mask, file, viewer);
		viewer++;
	}
}

viewcfg := array[] of {
	"canvas .c -height 1 -width 1",
	"pack .Wm_t -fill x",
	"pack .c -side bottom -fill both -expand 1",
};

view(im, mask: ref Image, file: string, viewer: int)
{
	for(k:=len file-2; k>=0; k--)
		if(file[k] == '/'){
			file = file[k+1:];
			break;
		}
	vx := string (x+20*(viewer%5));
	vy := string (y+20*(viewer%5));
	t := tk->toplevel(screen, " -x "+vx+" -y "+vy+" -borderwidth 2 -relief raised");

	menubut := wmlib->titlebar(t, "View: "+file, Wmlib->Hide);

	cmd := chan of string;
	tk->namechan(t, cmd, "cmd"+string viewer);

	tklib->tkcmds(t, viewcfg);

	tk->cmd(t, "bind . <Configure> {send cmd"+string viewer+" resize}");
	tk->cmd(t, "update");

	r := canvposn(t);
	if(im.r.dx() > r.dx() || im.r.dy() > r.dy()){
		str := ".c configure";
		if(im.r.dx() > r.dx())	
			str += " -width " + string im.r.dx();
		if(im.r.dy() > r.dy())	
			str += " -height " + string im.r.dy();
		tk->cmd(t, str+"; update");
		r = canvposn(t);
	}

	t.image.draw(r, im, mask, im.r.min);

	for(;;) alt{
	menu := <-menubut =>
		if(menu == "exit")
			return;
		wmlib->titlectl(t, menu);
		if(menu == "task")
			t.image.draw(r, im, display.ones, im.r.min);

	conf := <-cmd =>
		case conf {
		"resize" =>
			r = canvposn(t);
			t.image.draw(r, im, display.ones, im.r.min);
		}
	}
}

canvposn(t: ref Toplevel): Rect
{
	r: Rect;

	r.min.x = int tk->cmd(t, ".c cget -actx") + int tk->cmd(t, ".dx get");
	r.min.y = int tk->cmd(t, ".c cget -acty") + int tk->cmd(t, ".dy get");
	r.max.x = r.min.x + int tk->cmd(t, ".c cget -width") + int tk->cmd(t, ".dw get");
	r.max.y = r.min.y + int tk->cmd(t, ".c cget -height") + int tk->cmd(t, ".dh get");

	return r;
}

filetype(file: string, fd: ref Iobuf): RImagefile
{
	if(len file>4 && file[len file-4:]==".gif")
		return loadgif();
	if(len file>4 && file[len file-4:]==".jpg")
		return loadjpg();

	# sniff the header looking for a magic number
	buf := array[20] of byte;
	if(fd.read(buf, len buf) != len buf){
		sys->fprint(stderr, "View: can't read %s: %r\n", file);
		return nil;
	}
	fd.seek(0, 0);
	if(string buf[0:6]=="GIF87a" || string buf[0:6]=="GIF89a")
		return loadgif();
	jpmagic := array[] of {byte 16rFF, byte 16rD8, byte 16rFF, byte 16rE0,
		byte 0, byte 0, byte 'J', byte 'F', byte 'I', byte 'F', byte 0};
	for(i:=0; i<len jpmagic; i++)
		if(jpmagic[i]>byte 0 && buf[i]!=jpmagic[i])
			break;
	if(i == len jpmagic)
		return loadjpg();
	sys->fprint(stderr, "View: can't recognize type of %s\n", file);
	return nil;
}

loadgif(): RImagefile
{
	if(readgif == nil){
		readgif = load RImagefile RImagefile->READGIFPATH;
		if(readgif == nil)
			sys->fprint(stderr, "View: can't load readgif: %r\n");
		else
			readgif->init(bufio);
	}
	return readgif;
}

loadjpg(): RImagefile
{
	if(readjpg == nil){
		readjpg = load RImagefile RImagefile->READJPGPATH;
		if(readjpg == nil)
			sys->fprint(stderr, "View: can't load readjpg: %r\n");
		else
			readjpg->init(bufio);
	}
	return readjpg;
}

transparency(r: ref RImagefile->Rawimage, file: string): ref Image
{
	if(r.transp == 0)
		return nil;
	if(r.nchans != 1){
		sys->fprint(stderr, "View: can't do transparency for multi-channel image %s\n", file);
		return nil;
	}
	i := display.newimage(r.r, 3, 0, 0);
	if(i == nil){
		sys->fprint(stderr, "View: can't allocate mask for %s: %r\n", file);
		return nil;
	}
	pic := r.chans[0];
	npic := len pic;
	mpic := array[npic] of byte;
	index := r.trindex;
	for(j:=0; j<npic; j++)
		if(pic[j] == index)
			mpic[j] = byte 0;
		else
			mpic[j] = byte 16rFF;
	i.writepixels(i.r, mpic);
	return i;
}
