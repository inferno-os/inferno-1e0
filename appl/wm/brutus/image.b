implement Brutusext;

# <Extension image imagefile>

Name:	con "Brutus image";

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Context, Image, Display, Rect: import draw;

include	"bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include "imagefile.m";
	imageremap: Imageremap;
	readgif: RImagefile;
	readjpg: RImagefile;

include "tk.m";
	tk: Tk;

include	"tklib.m";
	tklib: Tklib;

include "pslib.m";
	pslib: PsLib;

include	"brutus.m";
include	"brutusext.m";

stderr: ref Sys->FD;

Cache: adt
{
	args:		string;
	name:	string;
	r:		Rect;
};

init(s: Sys, d: Draw, b: Bufio, t: Tk, tkl: Tklib)
{
	sys = s;
	draw = d;
	bufio = b;
	tk = t;
	tklib = tkl;
	imageremap = load Imageremap Imageremap->PATH;
	stderr := sys->fildes(2);
}

cache: list of ref Cache;

create(t: ref Tk->Toplevel, name, args: string): string
{
	if(imageremap == nil)
		return sys->sprint(Name + ": can't load remap: %r");
	display := t.image.display;
	file := args;

	for(cl:=cache; cl!=nil; cl=tl cl)
		if((hd cl).args == args)
			break;

	c: ref Cache;
	if(cl != nil)
		c = hd cl;
	else{
		(im, mask, err) := loadimage(display, file);
		if(err != "")
			return err;
		imagename := name+file;
		err = tk->cmd(t, "image create bitmap "+imagename);
		if(tklib->is_err(err))
			return err;
		err = tk->imageput(t, imagename, im, mask);
		if(tklib->is_err(err))
			return err;
		c = ref Cache(args, imagename, im.r);
		cache = c :: cache;
	}

	err := tk->cmd(t, "canvas "+name+" -height "+string c.r.dy()+" -width "+string c.r.dx());
	if(tklib->is_err(err))
		return err;
	err = tk->cmd(t, name+" create image 0 0 -anchor nw -image "+c.name);

	return "";
}

loadimage(display: ref Display, file: string) : (ref Image, ref Image, string)
{
	im := display.open(file);
	mask: ref Image;

	if(im == nil){
		fd := bufio->open(file, Sys->OREAD);
		if(fd == nil)
			return (nil, nil, sys->sprint(Name + ": can't open %s: %r", file));

		mod := filetype(file, fd);
		if(mod == nil)
			return (nil, nil, sys->sprint(Name + ": can't find decoder module for %s: %r", file));

		(ri, err) := mod->read(fd);
		if(ri == nil)
			return (nil, nil, sys->sprint(Name + ": %s: %s", file, err));
		if(err != "")
			sys->fprint(stderr, Name + ": %s: %s", file, err);
		mask = transparency(display, ri, file);

		# if transparency is enabled, errdiff==1 is probably a mistake,
		# but there's no easy solution.
		(im, err) = imageremap->remap(ri, display, 1);
		if(im == nil)
			return (nil, nil, sys->sprint(Name+": remap %s: %s\n", file, err));
		if(err != "")
			sys->fprint(stderr, Name+": remap %s: %s\n", file, err);
		ri = nil;
	}
	return(im, mask, "");
}

cook(fmt: int, args: string): (ref Brutusext->Celem, string)
{
	file := args;
	ans : ref Brutusext->Celem = nil;
	if(fmt == Brutusext->FHtml) {
		s := "<IMG SRC=\"" + file + "\">";
		ans = ref Brutusext->Celem(Brutusext->Special, s, nil, nil, nil, nil);
	}
	else {
		display := draw->Display.allocate("");
		(im, mask, err) := loadimage(display, file);
		if(err != "")
			return (nil, err);
		pslib = load PsLib PsLib->PATH;
		if(pslib == nil)
			return (nil, "can't load PsLib");
		pslib->init(nil, nil, 0);

		# psfile name: in current dir, with .ps suffix
		psfile := file;
		dot := -1;
		lastslash := -1;
		for(i := (len psfile)-1; i >= 0; i--) {
			if(dot < 0 && psfile[i] == '.')
				dot = i;
			if(psfile[i] == '/') {
				lastslash = i;
				break;
			}
		}
		if(dot == -1)
			dot = len psfile;
		psfile = psfile[lastslash+1:dot] + ".ps";
		iob := bufio->create(psfile, Bufio->OWRITE, 8r664);
		if(iob == nil)
			return (nil, "can't create " + psfile);
		if(pslib->image2psfile(iob, im, 100) != PsLib->OK)
			return (nil, "problem converting image to ps");
		s := "\\epsfbox{" + psfile + "}\n";
		ans = ref Brutusext->Celem(Brutusext->Special, s, nil, nil, nil, nil);
	}
	return (ans, "");
}

#
# rest of this is all borrowed from wm/view.
# should probably be packaged - perhaps in RImagefile?
#
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

transparency(display: ref Display, r: ref RImagefile->Rawimage, file: string): ref Image
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
