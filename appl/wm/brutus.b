implement Brutus;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Context: import draw;
	ctxt: ref Context;

include "tk.m";
	tk: Tk;

include "wmlib.m";
	wmlib: Wmlib;

include	"tklib.m";
	tklib: Tklib;

include	"bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include	"brutus.m";
include	"brutusext.m";

EXTDIR:	con "/dis/wm/brutus";
NEXTRA:	con NTAG-NFONTTAG;
DEFFONT:	con "/fonts/lucidasans/unicode.8.font";
DEFFONTNAME:	con "Roman";
DEFSIZE:	con 10;
DEFTAG:	con "Roman.10";
SETFONT:	con " -font "+DEFFONT+" ";
FOCUS:	con "focus .ft.t";
NOSEL:	con ".ft.t tag remove sel sel.first sel.last";

BS:		con 8;		# ^h backspace character
BSW:		con 23;		# ^w bacspace word
BSL:		con 21;		# ^u backspace line
ESC:		con 27;		# ^[ cut selection

Name:	con "Brutus";

# build menu
menu_cfg := array[] of {
	# menu
	"menu .m",
	".m add command -text Cut -command {send edit cut}",
	".m add command -text Paste -command {send edit paste}",
	".m add command -text Snarf -command {send edit snarf}",
};

brutus_cfg := array[] of {
	# buttons
	"button .b.Tag -text Tag -command {send cmd tag}",
	"menubutton .b.Font -text Roman -menu .b.Font.menu -underline -1",
	"menu .b.Font.menu",
	".b.Font.menu add command -label Roman -command {send cmd font Roman}",
	".b.Font.menu add command -label Italic -command {send cmd font Italic}",
	".b.Font.menu add command -label Bold -command {send cmd font Bold}",
	".b.Font.menu add command -label Type -command {send cmd font Type}",
	"checkbutton .b.Applyfont -variable Applyfont -command {send cmd applyfont}}",
	"button .b.Applyfontnow -text Font -command {send cmd applyfontnow}",
	"button .b.Applysizenow -text Size -command {send cmd applysizenow}",
	"button .b.Applyfontsizenow -text F&S -command {send cmd applyfontsizenow}",
	"menubutton .b.Size -text 10pt -menu .b.Size.menu -underline -1",
	"menu .b.Size.menu",
	".b.Size.menu add command -label 6pt -command {send cmd size 6}",
	".b.Size.menu add command -label 8pt -command {send cmd size 8}",
	".b.Size.menu add command -label 10pt -command {send cmd size 10}",
	".b.Size.menu add command -label 12pt -command {send cmd size 12}",
	".b.Size.menu add command -label 16pt -command {send cmd size 16}",
	"button .b.Put -text Put -command {send cmd put} -state disabled",

	# text
	"frame .ft",
	"scrollbar .ft.scroll -command {.ft.t yview}",
	"text .ft.t -height 7c -tabs {1c} -wrap word -yscrollcommand {.ft.scroll set}",
	FOCUS,

	# pack
	"pack .b.File .b.Ext .b.Tag .b.Applyfontnow .b.Applysizenow .b.Applyfontsizenow .b.Applyfont .b.Font .b.Size .b.Put -side left",
	"pack .Wm_t -fill x",
	"pack .b -anchor w",
	"pack .ft.scroll -side left -fill y",
	"pack .ft.t -fill both -expand 1",
	"pack .ft -fill both -expand 1",
	"pack propagate . 0",
};

control_cfg := array[] of {
	# text
	"frame .ft",
	"scrollbar .ft.scroll -command {.ft.t yview}",
	"text .ft.t -height 4c -wrap word -yscrollcommand {.ft.scroll set}",
	"pack .Wm_t -fill x",
	"pack .b.File",
	"pack .b -anchor w",
	"pack .ft.scroll -side left -fill y",
	"pack .ft.t -fill both -expand 1",
	"pack .ft -fill both -expand 1",
	"pack propagate . 0",
};

# bindings to build nice controls in text widget
input_cfg := array[] of {
	# input
	"bind .ft.t <Key> {send keys {%A}}",
	"bind .ft.t <Control-h> {send keys {%A}}",
	"bind .ft.t <Button-1> +{grab set .ft.t; send but1 pressed}",
	"bind .ft.t <Double-Button-1> +{grab set .ft.t; send but1 pressed}",
	"bind .ft.t <ButtonRelease-1> +{grab release .ft.t; send but1 released}",
	"bind .ft.t <Button-2> {send but2 pressed}",
	"bind .ft.t <Motion-Button-2-Button-1> {}",
	"bind .ft.t <Motion-Button-2> {}",
	"bind .ft.t <Button-3> {send but3 %X %Y}",
	"bind .ft.t <ButtonRelease-3> {}",
	"bind .ft.t <Motion-Button-3> {}",
	"bind .ft.t <Motion-Button-3-Button-1> {}",
	"bind .ft.t <Double-Button-3> {}",
	"bind .ft.t <Double-ButtonRelease-3> {}",
	"bind .ft.t <FocusIn> +{send cmd focus}",
	"bind .m <ButtonRelease> {.m tkMenuButtonUp %x %y}",
	"update"
};

fontname = array[NFONT] of {
	"Roman",
	"Italic",
	"Bold",
	"Type",
};

sizename = array[NSIZE] of {
	"6",
	"8",
	"10",
	"12",
	"16",
};

tagname = array[NTAG] of {
	# first NFONT*NSIZE are font/size names
	"Roman.6",
	"Roman.8",
	"Roman.10",
	"Roman.12",
	"Roman.16",
	"Italic.6",
	"Italic.8",
	"Italic.10",
	"Italic.12",
	"Italic.16",
	"Bold.6",
	"Bold.8",
	"Bold.10",
	"Bold.12",
	"Bold.16",
	"Type.6",
	"Type.8",
	"Type.10",
	"Type.12",
	"Type.16",
	"Example",
	"List",
	"List-elem",
	"Heading",
	"No-fill",
	"Author",
	"Title",
};

tagconfig = array[NTAG] of {
	"-font /fonts/lucidasans/unicode.6.font",
	"-font /fonts/lucidasans/unicode.7.font",
	"-font /fonts/lucidasans/unicode.8.font",
	"-font /fonts/lucidasans/unicode.10.font",
	"-font /fonts/lucidasans/unicode.13.font",
	"-font /fonts/lucidasans/italiclatin1.6.font",
	"-font /fonts/lucidasans/italiclatin1.7.font",
	"-font /fonts/lucidasans/italiclatin1.8.font",
	"-font /fonts/lucidasans/italiclatin1.10.font",
	"-font /fonts/lucidasans/italiclatin1.13.font",
	"-font /fonts/lucidasans/boldlatin1.6.font",
	"-font /fonts/lucidasans/boldlatin1.7.font",
	"-font /fonts/lucidasans/boldlatin1.8.font",
	"-font /fonts/lucidasans/boldlatin1.10.font",
	"-font /fonts/lucidasans/boldlatin1.13.font",
	"-font /fonts/lucidasans/typelatin1.6.font",
	"-font /fonts/lucidasans/typelatin1.7.font",
	"-font /fonts/pelm/latin1.9.font",
	"-font /fonts/pelm/ascii.12.font",
	"-font /fonts/pelm/ascii.16.font",
	"-foreground #444444 -lmargin1 1c -lmargin2 1c; .ft.t tag lower Example",
	"-foreground #444444 -lmargin1 1c -lmargin2 1c; .ft.t tag lower List",
	"-foreground #0000A0; .ft.t tag lower List-elem",
	"-foreground #444444; .ft.t tag lower Heading",
	"-foreground #444444; .ft.t tag lower No-fill",
	"-foreground #444444; .ft.t tag lower Author",
	"-foreground #444444; .ft.t tag lower Title",
};

File: adt
{
	tk:			ref Tk->Toplevel;
	isctl:			int;
	applyfont:		int;
	fontsused:	int;
	name:		string;
	dirty:		int;
	font:			string;	# set by the buttons, not nec. by the text
	size:			int;		# set by the buttons, not nec. by the text
	fonttag:		string;	# set by the buttons, not nec. by the text
	configed:		array of int;
	button1:		int;
	extensions:	list of ref Ext;
};

Ext: adt
{
	tkname:		string;
	modname:	string;
	mod:		Brutusext;
	args:			string;
};

menuindex := "0";
snarftext := "";
snarfsgml := "";
central: chan of (ref File, string);
files:	array of ref File;	# global but modified only by control thread

init(c: ref Context, argv: list of string)
{
	ctxt = c;

	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	tklib = load Tklib Tklib->PATH;
	wmlib = load Wmlib Wmlib->PATH;
	bufio = load Bufio Bufio->PATH;

	tklib->init(ctxt);
	wmlib->init();
	sys->pctl(Sys->NEWPGRP, nil);	# so we can pass "exit" command to wmlib

	tkargs := "";
	argv = tl argv;
	if(argv != nil && hd argv!="" && (hd argv)[0]=='-'){
		tkargs = hd argv;
		argv = tl argv;
	}

	file := "";
	if(argv != nil)
		file = hd argv;
	central = chan of (ref File, string);
	spawn control(ctxt, tkargs);
	<-central;
	spawn brutus(ctxt, tkargs, file);
}

# build menu button for dynamically generated menu
buttoncfg(label: string): string
{
	return "label .b."+label+" -text "+label +
		";bind .b."+label+" <Button-1> {send cmd "+label+"}" +
		";bind .b."+label+" <ButtonRelease-1> {}" +
		";bind .b."+label+" <Motion-Button-1> {}" +
		";bind .b."+label+" <Double-Button-1> {}" +
		";bind .b."+label+" <Double-ButtonRelease-1> {}" +
		";bind .b."+label+" <Enter> {.b."+label+" configure -background #EEEEEE}" +
		";bind .b."+label+" <Leave> {.b."+label+" configure -background #DDDDDD}";
}

tkchans(t: ref Tk->Toplevel): (chan of string, chan of string, chan of string, chan of string, chan of string, chan of string, chan of string)
{
	keys := chan of string;
	tk->namechan(t, keys, "keys");
	edit := chan of string;
	tk->namechan(t, edit, "edit");
	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");
	but1 := chan of string;
	tk->namechan(t, but1, "but1");
	but2 := chan of string;
	tk->namechan(t, but2, "but2");
	but3 := chan of string;
	tk->namechan(t, but3, "but3");
	drag := chan of string;
	tk->namechan(t, drag, "Wm_drag");
	return (keys, edit, cmd, but1, but2, but3, drag);
}

control(ctxt: ref Context, tkargs: string)
{
	t := tk->toplevel(ctxt.screen, tkargs+SETFONT+"-borderwidth 2 -relief raised");
	# f is not used to store anything, just to simplify interfaces shared by control and brutus
	f := ref File (t, 1, 0, 0, "", 0, DEFFONTNAME, DEFSIZE, DEFTAG, nil, 0, nil);
	titlectl := wmlib->titlebar(t, Name, Wmlib->Appl);
	tkcmds(t, menu_cfg);
	tkcmd(t, "frame .b");
	tkcmd(t, buttoncfg("File"));
	tkcmds(t, control_cfg);
	tkcmds(t, input_cfg);
	files = array[1] of ref File;
	files[0] = f;

	(keys, edit, cmd, but1, but2, but3, drag) := tkchans(t);

	tkcmd(t, ".ft.t mark set typingstart 1.0; .ft.t mark gravity typingstart left");
	central <-= (nil, "");	# signal readiness
	spawn wmlib->titlectl(t, "task");
	curfile: ref File;

	for(;;) alt {
	menu := <-titlectl =>
		if(menu[0] == 'e'){
			if(shutdown(ctxt.screen, t))
				wmlib->titlectl(t, menu);
			break;
		}
		spawn wmlib->titlectl(t, menu);

	ecmd := <-edit =>
		editor(f, ecmd);
		tkcmd(t, FOCUS);

	c := <-cmd =>
		(nil, s) := sys->tokenize(c, " ");
		case hd s {
		* =>
			sys->print("unknown control cmd %s\n",c );
		"File" =>
			filemenu(t, 0);
		"new" =>
			(name, ok) := getfilename(ctxt.screen, t, "file for new window", f.name, 1);
			if(ok)
				spawn brutus(ctxt, tkargs, name);
		"select" =>
			n := int hd tl s;
			if(n > len files)
				break;
			if(n > 0)
				curfile = files[n];
			tkcmd(files[n].tk, ". map; raise .; focus .ft.t");
		"focus" =>
			;
		}

	(file, action) := <-central =>
		(nil, s) := sys->tokenize(action, " ");
		case hd s {
		* =>
			sys->print("control unknown central command %s\n", action);
		"new" =>
			curfile = file;
			nfiles := array[len files+1] of ref File;
			nfiles[0:] = files;
			files = nfiles;
			nfiles = nil;	# make sure references don't linger
			files[len files-1] = file;
		"name" =>
			name := nameof(file);
			index := 0;
			for(i:=1; i<len files; i++)
				if(files[i] == file){
					index = i;
					break;
				}
			if(index == 0)
				sys->print("can't find file\n");
		"focus" =>
			if(file != f)
				curfile = file;
		"select" =>
			n := int hd tl s;
			if(n >= len files)
				break;
			if(n > 0)
				curfile = files[n];
			tkcmd(files[n].tk, ". map; raise .; focus .ft.t; update");
		"exiting" =>
			if(file == nil)
				break;
			if(file == curfile)
				curfile = nil;
			index := 0;
			for(i:=1; i<len files; i++)
				if(files[i] == file){
					index = i;
					break;
				}
			if(index == 0)
				sys->print("can't find file\n");
			else{
				# make a new one rather than slice, to clean up references
				nfiles := array[len files-1] of ref File;
				for(i=0; i<index; i++)
					nfiles[i] = files[i];
				for(; i<len nfiles; i++)
					nfiles[i] = files[i+1];
				files = nfiles;
			}
			file = nil;
		}
	c := <-keys =>
		char := typing(f, c);
		if(curfile!=nil && char=='\n' && insat(t, "end"))
			execute(t, curfile, tkcmd(t, ".ft.t get insert-1line insert"));

	c := <-keys =>
		char := typing(f, c);

	c := <-but1 =>
		mousebut1(f, c);

	c := <-but2 =>
		mousebut2(f, c);

	c := <-but3 =>
		mousebut3(f, c);

	c := <-drag =>
		if(len c < 6 || c[0:5] != "path=")
			break;
		spawn brutus(ctxt, tkargs, c[5:]);
	}
}

brutus(ctxt: ref Context, tkargs: string, filename: string)
{
	t := tk->toplevel(ctxt.screen, tkargs+SETFONT+"-borderwidth 2 -relief raised");
	f := ref File (t, 0, 0, 0, filename, 0, DEFFONTNAME, DEFSIZE, DEFTAG, nil, 0, nil);
	f.configed = array[NTAG] of {* => 0};

	titlectl := wmlib->titlebar(t, Name, Wmlib->Appl);

	tkcmds(t, menu_cfg);
	tkcmd(t, "frame .b");
	tkcmd(t, buttoncfg("File"));
	tkcmd(t, buttoncfg("Ext"));
	tkcmds(t, brutus_cfg);
	tkcmds(t, input_cfg);

	# buttons work better when they grab the mouse
	a := array[] of {".b.Tag", ".b.Applyfontnow", ".b.Applysizenow", ".b.Applyfontsizenow"};
	for(i:=0; i<len a; i++){
		tkcmd(t, "bind "+a[i]+" <Button-1> +{grab set "+a[i]+"}");
		tkcmd(t, "bind "+a[i]+" <ButtonRelease-1> +{grab release "+a[i]+"}");
	}

	(keys, edit, cmd, but1, but2, but3, drag) := tkchans(t);

	configfont(f, "Heading");
	configfont(f, "Title");
	configfont(f, f.fonttag);
	tkcmd(t, ".ft.t mark set typingstart 1.0; .ft.t mark gravity typingstart left");
	tkcmd(t, "image create bitmap waiting -file cursor.wait");

	central <-= (f, "new");
	setfilename(f, filename);

	if(filename != "")
		if(loadfile(f, filename) < 0)
			tklib->notice(t, sys->sprint("Can't read %s:\n%r", filename));

	for(;;) alt {
	menu := <-titlectl =>
		case menu {
		"exit" =>
			if(f.dirty){
				action := confirm(ctxt.screen, t, nameof(f)+" is dirty");
				case action {
				"cancel" =>
					continue;
				"exitclean" =>
					if(dumpfile(f, f.name) < 0)
						continue;
					break;
				"exitdirty" =>
					break;
				}
			}
			central <-= (f, "exiting");
			# this one tears down temporaries holding references to f
			central <-= (nil, "exiting");
			return;
		"task" =>
			tkcmd(t, ". unmap");
		* =>
			wmlib->titlectl(t, menu);
		}

	ecmd := <-edit =>
		editor(f, ecmd);
		tkcmd(t, FOCUS);

	command := <-cmd =>
		(nil, c) := sys->tokenize(command, " ");
		case hd c {
		* =>
			sys->print("unknown command %s\n", command);
		"File" =>
			filemenu(t, 1);
		"Ext" =>
			extmenu(t);
		"new" =>
			(name, ok) := getfilename(ctxt.screen, t, "file for new window", f.name, 1);
			if(ok)
				spawn brutus(ctxt, tkargs, name);
		"open" =>
			if(f.dirty){
				action := confirm(ctxt.screen, t, nameof(f)+" is dirty");
				case action {
				"cancel" =>
					continue;
				"exitclean" =>
					if(dumpfile(f, f.name) < 0)
						continue;
					break;
				"exitdirty" =>
					break;
				}
			}
			(name, ok) := getfilename(ctxt.screen, t, "file for this window", f.name, 1);
			if(ok && name!=""){
				setfilename(f, name);
				if(loadfile(f, name) < 0){
					tkcmd(t, ".ft.t delete 1.0 end");
					tklib->notice(t, sys->sprint("Can't open %s:\n%r", name));
				}
			}
		"name" =>
			(name, ok) := getfilename(ctxt.screen, t, "remembered file name", f.name, 1);
			if(ok){
				if(name != f.name){
					setfilename(f, name);
					dirty(f, 1);
				}
			}
		"write" =>
			(name, ok) := getfilename(ctxt.screen, t, "file to write", f.name, 1);
			if(ok && name!=""){
				if(f.name == ""){
					setfilename(f, name);
					dirty(f, 1);
				}
				dumpfile(f, name);
			}
		"addext" =>
			ext := hd tl c;
			(args, ok) := getfilename(ctxt.screen, t, "parameters for "+ext, "", 0);
			if(ok){
				tkcmd(t, "cursor -image waiting; update");
				addextension(f, ext+" "+args, nil);
				usingfonts(f);
				dirty(f, 1);
				tkcmd(t, "cursor -default; update");
			}
		"select" =>
			central <-= (f, command);
		"tag" =>
			tageditor(ctxt.screen, f);
			tkcmd(t, FOCUS);
		"font" =>
			f.font = hd tl c;
			tkcmd(t, ".b.Font configure -text "+f.font+";update");
			f.fonttag = f.font+"."+string f.size;
			configfont(f, f.fonttag);
			if(changefont(f, f.font))
				dirty(f, 1);
		"size" =>
			sz := hd tl c;
			tkcmd(t, ".b.Size configure -text "+sz+"pt; update");
			f.size = int sz;
			f.fonttag = f.font+"."+string f.size;
			configfont(f, f.fonttag);
			if(changesize(f, string f.size))
				dirty(f, 1);
		"applyfont" =>
			f.applyfont = int tkcmd(t, "variable Applyfont");
			if(f.applyfont)
				configfont(f, f.fonttag);
		"applyfontnow" =>
			if(changefont(f, f.font))
				dirty(f, 1);
		"applysizenow" =>
			if(changesize(f, string f.size))
				dirty(f, 1);
		"applyfontsizenow" =>
			if(changefontsize(f, f.fonttag))
				dirty(f, 1);
		"put" =>
			dumpfile(f, f.name);
		"focus" =>
			central <-= (f, "focus");
		}

	c := <-keys =>
		typing(f, c);

	c := <-but1 =>
		mousebut1(f, c);

	c := <-but2 =>
		mousebut2(f, c);

	c := <-but3 =>
		mousebut3(f, c);

	c := <-drag =>
		if(len c < 6 || c[0:5] != "path=")
			break;
		spawn brutus(ctxt, tkargs, c[5:]);
	}
}

typing(f: ref File, c: string): int
{
	t := f.tk;
	char := c[1];
	if(char == '\\')
		char = c[2];
	update := ";.ft.t see insert;update";
	if(char != ESC)
		cut(f, 1);
	case char {
	* =>
		s := ".ft.t insert insert "+c;
		if(f.applyfont){
			usingfonts(f);
			s += f.fonttag;
		}
		tkcmd(t, s+update);
		if(f.fontsused && f.applyfont==0){
			# nasty goo to make sure we don't insert text without a font tag;
			# must ask after the fact if default rules set a tag.
			names := tkcmd(t, ".ft.t tag names insert-1chars");
			if(names == "")
				tkcmd(t, ".ft.t tag add "+DEFTAG+" insert-1chars");
		}
		dirty(f, 1);
	ESC =>
		if(nullsel(t))
			tkcmd(t, ".ft.t tag add sel typingstart insert;"+
					".ft.t mark set typingstart insert");
		else
			cut(f, 1);
		tkcmd(t, "update");
	BS =>
		if(!insat(t, "1.0")){
			tkcmd(t, ".ft.t delete insert-1chars"+update);
			dirty(f, 1);
		}
	BSL =>
		tkcmd(t, ".ft.t delete {insert linestart} insert"+update);
		dirty(f, 1);
	BSW =>
		# if at beginning of file, tk->cmd will return !error and a0 will be false.
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
				s = tkcmd(t, ".ft.t get insert-"+ string n +"chars");
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
		tkcmd(t, ".ft.t delete " + start + " insert"+update);
		dirty(f, 1);
	}
	return char;
}

mousebut1(f: ref File, c: string)
{
	f.button1 = (c == "pressed");
	tkcmd(f.tk, ".ft.t mark set typingstart insert");
}

mousebut2(f: ref File, c: string)
{
	c = nil;	# USED
	if(f.button1){
		cut(f, 1);
		tk->cmd(f.tk, "update");
	}
}

mousebut3(f: ref File, c: string)
{
	if(f.button1){
		paste(f);
		tk->cmd(f.tk, "update");
	}else{
		(nil, l) := sys->tokenize(c, " ");
		x := int hd l - 50;
		y := int hd tl l - int tk->cmd(f.tk, ".m yposition "+menuindex) - 10;
#		tkcmd(f.tk, "focus .ft.t");
		tkcmd(f.tk, ".m activate "+menuindex+"; .m post "+string x+" "+string y+
			"; update");
	}
}

filemenu(t: ref tk->Toplevel, buttons: int)
{
	tkcmd(t, "menu .b.Filemenu");
	tkcmd(t, ".b.Filemenu add command -label New -command {send cmd new}");
	if(buttons){
		tkcmd(t, ".b.Filemenu add command -label Open -command {send cmd open}");
		tkcmd(t, ".b.Filemenu add command -label Name -command {send cmd name}");
		tkcmd(t, ".b.Filemenu add command -label Write -command {send cmd write}");
	}
	tkcmd(t, ".b.Filemenu add command -label {["+Name+"]} -command {send cmd select 0}");
	if(files != nil)
		for(i:=1; i<len files; i++){
			name := nameof(files[i]);
			if(files[i].dirty)
				name = "{' "+name+"}";
			else
				name = "{  "+name+"}";
			tkcmd(t, ".b.Filemenu add command -label "+name+
				" -command {send cmd select "+string i+"}");
		}
	tkcmd(t, "bind .b.Filemenu <Unmap> {destroy .b.Filemenu}");
	x := tk->cmd(t, ".ft.scroll cget actx");
	y := tk->cmd(t, ".ft.scroll cget acty");
	tkcmd(t, ".b.Filemenu post "+x+" "+y+"; update");
}

extmenu(t: ref tk->Toplevel)
{
	fd := sys->open(EXTDIR, Sys->OREAD);
	dir := array[100] of Sys->Dir;
	if(fd == nil || (n:=sys->dirread(fd, dir))<=0){
		sys->print("%s: can't find extension directory %s: %r\n", Name, EXTDIR);
		return;
	}

	tkcmd(t, "menu .b.Extmenu");
	for(i:=0; i<n; i++){
		name := dir[i].name;
		if(len name>4 && name[len name-4:]==".dis"){
			name = name[0:len name-4];
			tkcmd(t, ".b.Extmenu add command -label {Add "+name+
				"} -command {send cmd addext "+name+"}");
		}
	}

	tkcmd(t, "bind .b.Extmenu <Unmap> {destroy .b.Extmenu}");
	x := tk->cmd(t, ".ft.scroll cget actx");
	y := tk->cmd(t, ".ft.scroll cget acty");
	tkcmd(t, ".b.Extmenu post "+x+" "+y+"; update");
}

basepath(file: string): (string, string)
{
	for(i := len file-1; i >= 0; i--) {
		if(file[i] == '/')
			return (file[0:i], file[i+1:]);
	}
	return (".", file);
}

putbut(f: ref File)
{
	state := (array[] of {"disabled", "normal"})[f.dirty];
	if(f.name != "")
		tkcmd(f.tk, ".b.Put configure -state "+state+"; update");
}

dirty(f: ref File, nowdirty: int)
{
	if(f.isctl)
		return;
	old := f.dirty;
	f.dirty = nowdirty;
	if(old != nowdirty){
		setfilename(f, f.name);
		putbut(f);
	}
}

setfilename(f: ref File, name: string)
{
	oldname := f.name;
	f.name = name;
	if(oldname=="" && name!="")
		putbut(f);
	name = Name + ": \"" +nameof(f)+ "\"";
	if(f.dirty)
		name += " (dirty)";
	wmlib->taskbar(f.tk, name);
	tkcmd(f.tk, "update");
	central <-= (f, "name");
}

configfont(f: ref File, tag: string)
{
	for(i:=0; i<NTAG; i++)
		if(tag == tagname[i]){
			if(f.configed[i] == 0){
				tkcmd(f.tk, ".ft.t tag configure "+tag+" "+tagconfig[i]);
				f.configed[i] = 1;
			}
			return;
		}
	sys->print("Brutus: can't configure font %s\n", tag);
}

insat(t: ref Tk->Toplevel, mark: string): int
{
	return tkcmd(t, ".ft.t compare insert == "+mark) == "1";
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

editor(f: ref File, ecmd: string)
{

	case ecmd {
	"cut" =>
		menuindex = "0";
		cut(f, 1);
	
	"paste" =>
		menuindex = "1";
		paste(f);

	"snarf" =>
		if(nullsel(f.tk))
			return;
		menuindex = "2";
		snarf(f);
	}
	tkcmd(f.tk, "update");
}

nullsel(t: ref Tk->Toplevel): int
{
	return tkcmd(t, ".ft.t tag ranges sel") == "";
}

cut(f: ref File, snarfit: int)
{
	if(nullsel(f.tk))
		return;
	dirty(f, 1);
	if(snarfit)
		snarf(f);
	tkcmd(f.tk, ".ft.t delete sel.first sel.last");
}

snarf(f: ref File)
{
	# convert sel.first and sel.last to numeric forms because sgml()
	# must clear selection to avoid <sel> tags in result.
	(nil, sel) := sys->tokenize(tkcmd(f.tk, ".ft.t tag ranges sel"), " ");
	snarftext = tkcmd(f.tk, ".ft.t get "+hd sel+" "+hd tl sel);
	snarfsgml = sgml(f.tk, "-sgml", hd sel, hd tl sel);
	wmlib->snarfput(snarftext);
}

paste(f: ref File)
{
#	good question
#	snarf := wmlib->snarfget();
	if(snarftext == "")
		return;
	cut(f, 0);
	dirty(f, 1);

	t := f.tk;
	start := tkcmd(t, ".ft.t index insert");
	if(f.fontsused == 0)
		tkcmd(t, ".ft.t insert insert '"+snarftext);
	else if(f.applyfont)
		tkcmd(t, ".ft.t insert insert "+tklib->tkquote(snarftext)+" "+f.fonttag);
	else
		insert(f, snarfsgml);
	tkcmd(t, ".ft.t tag add sel "+start+" insert");
}

# First time fonts are used explicitly, establish font tags for all extant text.
usingfonts(f: ref File)
{
	if(f.fontsused)
		return;
	tkcmd(f.tk, ".ft.t tag add "+DEFTAG+" 1.0 end");
	f.fontsused = 1;
}

word(t: ref Tk->Toplevel): (string, string)
{
	start := "sel.first";
	end := "sel.last";
	if(nullsel(t)){
		insert := tkcmd(t, ".ft.t index insert");
		start = tkcmd(t, ".ft.t index {insert wordstart}");
		if(insert == start){	# tk's definition of 'wordstart' is bogus
			# if at beginning, tk->cmd will return !error and a0 will be false.
			a0 := isalnum(tk->cmd(t, ".ft.t get insert-1chars"));
			a1 := isalnum(tk->cmd(t, ".ft.t get insert"));
			if(a0==0 && a1==0)
				return (nil, nil);
			if(a1 == 0)
				start = tkcmd(t, ".ft.t index {insert-1chars wordstart}");
		}
		end = tkcmd(t, ".ft.t index {"+start+" wordend}");
		if(start == end)
			return (nil, nil);
	}
	return (start, end);
}

# Change the font associated with the selection
changefont(f: ref File, font: string): int
{
	t := f.tk;
	(sel0, sel1) := word(f.tk);
	mod := 0;
	if(sel0 == nil)
		return mod;
	usingfonts(f);
	for(i:=0; i<NFONT; i++){
		if(fontname[i] == font)
			continue;
		for(j:=0; j<NSIZE; j++){
			tag := fontname[i]+"."+sizename[j];
			start := sel0;
			for(;;){
				range := tkcmd(t, ".ft.t tag nextrange "+tag+" "+start+" "+sel1);
				if(tklib->is_err(range))
					break;
				(nil, tt) := sys->tokenize(range, " ");
				if(tt == nil)
					break;
				tkcmd(t, ".ft.t tag remove "+tag+" "+hd tt+" "+hd tl tt);
				fs := font+"."+sizename[j];
				tkcmd(t, ".ft.t tag add "+fs+" "+hd tt+" "+hd tl tt);
				configfont(f, fs);
				start = hd tl tt;
				mod = 1;
			}
		}
	}
	tkcmd(t, "update");
	return mod;
}

# Change the size associated with the selection
changesize(f: ref File, size: string): int
{
	t := f.tk;
	(sel0, sel1) := word(f.tk);
	mod := 0;
	if(sel0 == nil)
		return mod;
	usingfonts(f);
	for(i:=0; i<NFONT; i++){
		for(j:=0; j<NSIZE; j++){
			if(sizename[j] == size)
				continue;
			tag := fontname[i]+"."+sizename[j];
			start := sel0;
			for(;;){
				range := tkcmd(t, ".ft.t tag nextrange "+tag+" "+start+" "+sel1);
				if(tklib->is_err(range))
					break;
				(nil, tt) := sys->tokenize(range, " ");
				if(tt == nil)
					break;
				tkcmd(t, ".ft.t tag remove "+tag+" "+hd tt+" "+hd tl tt);
				fs := fontname[i]+"."+size;
				tkcmd(t, ".ft.t tag add "+fs+" "+hd tt+" "+hd tl tt);
				configfont(f, fs);
				start = hd tl tt;
				mod = 1;
			}
		}
	}
	tkcmd(t, "update");
	return mod;
}

# Change the font and size associated with the selection
changefontsize(f: ref File, newfontsize: string): int
{
	t := f.tk;
	(sel0, sel1) := word(f.tk);
	if(sel0 == nil)
		return 0;
	usingfonts(f);
	(nil, names) := sys->tokenize(tkcmd(t, ".ft.t tag names"), " ");
	# clear old tags
	tags := tagname[0:NFONT*NSIZE];
	for(l:=names; l!=nil; l=tl l)
		for(i:=0; i<len tags; i++)
			if(tags[i] == hd l)
				tkcmd(t, ".ft.t tag remove "+hd l+" "+sel0+" "+sel1);
	tkcmd(t, ".ft.t tag add "+newfontsize+" "+sel0+" "+sel1+"; update");
	return 1;
}

listtostring(l: list of string): string
{
	s := "{";
	while(l != nil){
		if(len s == 1)
			s += hd l;
		else
			s += " " + hd l;
		l = tl l;
	}
	s += "}";
	return s;
}

# splitl based on indices rather than slices.  this version returns char
# position of the matching character.
splitl(str: string, i, j: int, pat: string): int
{
	while(i < j){
		c := str[i];
		for(k:=len pat-1; k>=0; k--)
			if(c == pat[k])
				return i;
		i++;
	}
	return i;
}

# splitstrl based on indices rather than slices. this version returns char
# position of the beginning of the matching string.
splitstrl(str: string, i, j: int, pat: string): int
{
	l := len pat;
	if(l == 0)	# shouldn't happen, but be safe
		return j;
	first := pat[0];
	while(i <= j-l){
		# check first char for speed
		if(str[i] == first){
			for(k:=1; k<l && str[i+k]==pat[k]; k++)
				;
			if(k == l)
				return i;
		}
		i++;
	}
	return j;
}

# place the text, as annotated by SGML tags, into document
# where indicated by insert mark
insert(f: ref File, sgml: string)
{
	taglist: list of string;

	t := f.tk;
	usingfonts(f);
	if(f.applyfont)
		taglist = f.fonttag :: taglist;
	tag := listtostring(taglist);
	end := len sgml;
	j: int;
	for(i:=0; i<end; i=j){
		j = splitl(sgml, i, end, "<&");
		tt := tag;
		if(tt=="" || tt=="{}")
			tt = DEFTAG;	# can happen e.g. when pasting plain text
		if(j > i)
			tkcmd(t, ".ft.t insert insert "+tklib->tkquote(sgml[i:j])+" "+tt);
		if(j < end)
			case sgml[j] {
			'&' =>
				if(j+4<=end && sgml[j:j+4]=="&lt;"){
					tkcmd(t, ".ft.t insert insert "+"{<} "+tt);
					j += 4;
				}else{
					tkcmd(t, ".ft.t insert insert {&} "+tt);
					j += 1;
				}
			'<' =>
				(nc, newtag, on) := tagstring(sgml, j, end);
				if(nc < 0){
					tkcmd(t, ".ft.t insert insert "+"{<} "+tt);
					j += 1;
				}else if(len newtag>9 && newtag[0:10]=="Extension "){
					addextension(f, newtag[10:], taglist);
					j += nc;
				}else if(len newtag>9 && newtag[0:7]=="Window "){
					repostextension(f, newtag[7:], taglist);
					j += nc;
				}else{
					if(on){
						taglist = newtag :: taglist;
						configfont(f, newtag);
					}else{
						taglist = drop(taglist, newtag);
						if(f.applyfont && hasfonts(taglist)==0)
							taglist = f.fonttag :: taglist;
					}
					j += nc;
					tag = listtostring(taglist);
				}
			}
	}
}

drop(l: list of string, s: string): list of string
{
	n: list of string;
	while(l != nil){
		if(s != hd l)
			n = hd l :: n;
		l = tl l;
	}
	return n;
}

extid := 0;
addextension(f: ref File, s: string, taglist: list of string)
{
	for(i:=0; i<len s; i++)
		if(s[i] == ' ')
			break;
	if(i == 0 || i == len s){
		sys->print("Brutus: badly formed extension %s\n", s);
		return;
	}
	modname := s[0:i];
	s = s[i+1:];

	mod: Brutusext;
	for(el:=f.extensions; el!=nil; el=tl el)
		if(modname == (hd el).modname){
			mod = (hd el).mod;
			break;
		}

	if(mod == nil){
		file := modname;
		if(i < 4 || file[i-4:i] != ".dis")
			file += ".dis";
		if(file[0] != '/')
			file = "/dis/wm/brutus/" + file;
		mod = load Brutusext file;
		if(mod == nil){
			sys->print("%s: can't load module %s: %r\n", Name, file);
			return;
		}
	}
	mkextension(f, mod, modname, s, taglist);
}

repostextension(f: ref File, tkname: string, taglist: list of string)
{
	mod: Brutusext;
	for(el:=f.extensions; el!=nil; el=tl el)
		if(tkname == (hd el).tkname){
			mod = (hd el).mod;
			break;
		}
	if(mod == nil){
		sys->print("Brutus: can't find extension widget %s: %r\n", tkname);
		return;
	}

	mkextension(f, mod, (hd el).modname, (hd el).args, taglist);
}

mkextension(f: ref File, mod: Brutusext, modname, args: string, taglist: list of string)
{
	t := f.tk;

	name := ".ext"+string extid++;
	mod->init(sys, draw, bufio, tk, tklib);
	err := mod->create(t, name, args);
	if(err != ""){
		sys->print("%s: can't create extension widget %s: %s\n", Name, modname, err);
		return;
	}
	tkcmd(t, ".ft.t window create insert -window "+name);
	while(taglist != nil){
		tkcmd(t, ".ft.t tag add "+hd taglist+" "+name);
		taglist = tl taglist;
	}
	f.extensions = ref Ext(name, modname, mod, args) :: f.extensions;
}

# rewrite <window .ext1> tags into <Extension module args>
extrewrite(f: ref File, sgml: string): string
{
	if(f.extensions == nil)
		return sgml;

	new := "";

	end := len sgml;
	j: int;
	for(i:=0; i<end; i=j){
		j = splitstrl(sgml, i, end, "<Window ");
		if(j > i)
			new += sgml[i:j];
		if(j < end){
			j += 8;
			for(k:=j; sgml[k]!='>' && k<end; k++)
				;
			tkname := sgml[j:k];
			for(el:=f.extensions; el!=nil; el=tl el)
				if((hd el).tkname == tkname)
					break;
			if(el == nil)
				sys->print("%s: unrecognized extension %s\n", Name, tkname);
			else{
				e := hd el;
				new += "<Extension "+e.modname+" "+e.args+">";
			}
			j = k+1;	# skip '>'
		}
	}
	return new;
}

hasfonts(l: list of string): int
{
	for(i:=0; i<NFONT*NSIZE; i++)
		for(ll:=l; ll!=nil; ll=tl ll)
			if(hd ll == tagname[i])
				return 1;
	return 0;
}

# s[i] is known to be a less-than sign
tagstring(s: string, i, end: int): (int, string, int)
{
	tag: string;

	j := splitl(s, i+1, end, ">");
	if(j==end || s[j]!='>')
		return (-1, "", 0);
	nc := (j-i)+1;
	on := 1;
	if(s[i+1] == '/'){
		on = 0;
		i++;
	}
	tag = s[i+1:j];
# NEED TO CHECK VALIDITY OF TAG
	return (nc, tag, on);
}

sgml(t: ref Tk->Toplevel, flag, start, end: string): string
{
	# turn off selection, to avoid getting that in output
	sel := tkcmd(t, ".ft.t tag ranges sel");
	if(sel != "")
		tkcmd(t, ".ft.t tag remove sel "+sel);
	s := tkcmd(t, ".ft.t dump "+flag+" "+start+" "+end);
	if(sel != "")
		tkcmd(t, ".ft.t tag add sel "+sel);
	return s;
}

loadfile(f: ref File, file: string): int
{
	f.size = DEFSIZE;
	f.font = DEFFONTNAME;
	f.fonttag = DEFTAG;
	f.fontsused = 0;
	t := f.tk;
	tkcmd(t, ".b.Font configure -text "+f.font);
	tkcmd(t, ".b.Size configure -text "+string f.size+"pt");
	tkcmd(t, "cursor -image waiting; update");
	r := loadfile1(f, file);
	tkcmd(t, "cursor -default");
	return r;
}

loadfile1(f: ref File, file: string): int
{
	fd := bufio->open(file, Sys->OREAD);
	if(fd == nil)
		return -1;
	(ok, dir) := sys->fstat(fd.fd);
	if(ok < 0){
		fd.close();
		return -1;
	}
	a := array[dir.length] of byte;
	n := fd.read(a, len a);
	fd.close();
	if(n != len a)
		return -1;
	t := f.tk;
	tkcmd(t, ".ft.t delete 1.0 end");
	if(len a>=7 && string a[0:7]=="<SGML>\n")
		insert(f, string a[7:n]);
	else{
		f.fontsused = 0;
		tkcmd(t, ".ft.t insert 1.0 '"+string a[0:n]);
	}
	dirty(f, 0);
	tkcmd(t, ".ft.t mark set insert 1.0; update");
	return 1;
}

dumpfile(f: ref File, file: string): int
{
	tkcmd(f.tk, "cursor -image waiting");
	r := dumpfile1(f, file);
	tkcmd(f.tk, "cursor -default");
	return r;
}

dumpfile1(f: ref File, file: string): int
{
	if(writefile(f, file) < 0){
		tklib->notice(f.tk, sys->sprint("Can't write %s:\n%r", file));
		tkcmd(f.tk, FOCUS);
		return -1;
	}
	return 1;
}

writefile(f: ref File, file: string): int
{
	if(file == "")
		return -1;
	fd := bufio->create(file, Sys->OWRITE, 8r666);
	if(fd == nil)
		return -1;

	t := f.tk;
	flag := "";
	if(f.fontsused){
		flag = "-sgml";
		prefix := array of byte "<SGML>\n";
		if(fd.write(prefix, len prefix) != len prefix)
			return -1;
	}
	sgmltext := sgml(t, flag, "1.0", "end");
	if(f.fontsused)
		sgmltext = extrewrite(f, sgmltext);
	a := array of byte sgmltext;
	if(fd.write(a, len a) != len a)
		return -1;
	if(fd.flush() < 0)
		return -1;
	if(file == f.name){
		dirty(f, 0);
		tkcmd(t, "update");
	}
	return 1;
}

shutdown(s: ref Draw->Screen, t: ref Tk->Toplevel): int
{
	for(i:=1; i<len files; i++){
		f := files[i];
		if(f.dirty){
			action := confirm(s, t, "file "+nameof(f)+" is dirty");
			case action {
			"cancel" =>
				return 0;
			"exitclean" =>
				if(dumpfile(f, f.name) < 0)
					return 0;
			"exitdirty" =>
				break;
			}
		}
	}
	return 1;
}

nameof(f: ref File): string
{
	s := f.name;
	if(s == "")
		s = "(unnamed)";
	return s;
}

tkcmd(t: ref Tk->Toplevel, s: string): string
{
	res := tk->cmd(t, s);
	if(tklib->is_err(res))
		sys->print("%s: tk error executing '%s': %s\n", Name, s, res);
	return res;
}

confirm_cfg := array[] of {
	"frame .f -borderwidth 2 -relief groove -padx 3 -pady 3",
	"frame .f.f",
#	"label .f.f.l -bitmap error -foreground red",
	"label .f.f.l -text Warning:",
	"label .f.f.m",
	"button .f.exitclean -text {  Write and Proceed  } -width 17w -command {send cmd exitclean}",
	"button .f.exitdirty -text {  Proceed  } -width 17w -command {send cmd exitdirty}",
	"button .f.cancel -text {  Cancel  } -width 17w -command {send cmd cancel}",
	"pack .f.f.l .f.f.m -side left",
	"pack .f.f .f.exitclean .f.exitdirty .f.cancel -padx 10 -pady 10",
	"pack .f",
};

widget(parent: ref Tk->Toplevel, screen: ref Draw->Screen, cfg: array of string): ref Tk->Toplevel
{
	x := int tk->cmd(parent, ". cget -x");
	y := int tk->cmd(parent, ". cget -y");
	where := sys->sprint("-x %d -y %d", x+45, y+25);
	t := tk->toplevel(screen, where+SETFONT+" -borderwidth 2 -relief raised");
	tkcmds(t, cfg);
	return t;
}

tkcmds(top: ref Tk->Toplevel, a: array of string)
{
	n := len a;
	for(i := 0; i < n; i++)
		v := tk->cmd(top, a[i]);
}

confirm(screen: ref Draw->Screen, parent: ref Tk->Toplevel, message: string): string
{
	s := confirm1(screen, parent, message);
	tkcmd(parent, FOCUS);
	return s;
}

confirm1(screen: ref Draw->Screen, parent: ref Tk->Toplevel, message: string): string
{
	t := widget(parent, screen, confirm_cfg);
	tkcmd(t, ".f.f.m configure -text '"+message);
	tkcmd(t, "update");
	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");
	return <-cmd;
}

getfilename_cfg := array[] of {
	"frame .f",
	"label .f.Message",
	"entry .f.Name -width 25w",
	"button .f.Ok -text {  OK  } -width 14w -command {send cmd ok}",
	"button .f.Browse -text {  Browse  } -width 14w -command {send cmd browse}",
	"button .f.Cancel -text {  Cancel  } -width 14w -command {send cmd cancel}",
	"bind .f.Name <Control-j> {send cmd ok}",
	"pack .f.Message .f.Name .f.Ok .f.Browse .f.Cancel -padx 10 -pady 10",
	"pack .f",
	"focus .f.Name",
};

getfilename(screen: ref Draw->Screen, parent: ref Tk->Toplevel, message, name: string, browse: int): (string, int)
{
	(s, i) := getfilename1(screen, parent, message, name, browse);
	tkcmd(parent, FOCUS);
	return (s, i);
}

getfilename1(screen: ref Draw->Screen, parent: ref Tk->Toplevel, message, name: string, browse: int): (string, int)
{
	t := widget(parent, screen, getfilename_cfg);
	tkcmd(t, ".f.Message configure -text '"+message);
	tk->cmd(t, ".f.Name insert 0 "+name);
	if(browse == 0)
		tkcmd(t, "destroy .f.Browse");
	tkcmd(t, "update");
	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");
	for(;;){
		case <-cmd {
		"ok" =>
			return (tkcmd(t, ".f.Name get"), 1);
		"cancel" =>
			return ("", 0);
		"browse" =>
			name := tkcmd(t, ".f.Name get");
			(dir, path) := basepath(name);
			path = wmlib->getfilename(screen, parent, message, "*", dir);
			if(path != "")
				name = path;
			tk->cmd(t, ".f.Name delete 0 end; .f.Name insert 0 "+name+";focus .f.Name; update");
		}
	}
}

tageditor(screen: ref Draw->Screen, f: ref File)
{
	(start, end) := word(f.tk);
	if(start == nil)
		return;
	cfg := array[100] of string;
	i := 0;
	cfg[i++] = "frame .f";
	(nil, names) := sys->tokenize(tkcmd(f.tk, ".ft.t tag names "+start), " ");
	pack := "pack";
	set := array[NEXTRA] of int;
	for(j:=0; j<NEXTRA; j++){
		n := tagname[j+NFONT*NSIZE];
		cfg[i++] = "checkbutton .f.c"+string j+" -variable c"+string j+
			" -text {"+n+"} -command {send cmd "+string j+"}";
		pack += " .f.c"+string j;
		set[j] = 0;
		for(l:=names; l!=nil; l=tl l)
			if(hd l == n){
				cfg[i++] = ".f.c"+string j+" select";
				set[j] = 1;
			}
	}
	cfg[i++] = "button .f.Ok -text {  OK  } -width 6w -command {send cmd ok}";
	cfg[i++] = "button .f.Cancel -text {  Cancel  } -width 6w -command {send cmd cancel}";
	cfg[i++] = pack + " .f.Ok .f.Cancel -padx 10 -pady 5 -anchor w";
	cfg[i++] = "pack .f; grab set .f; update";
	t := widget(f.tk, screen, cfg[0:i]);
	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");

    loop:
	for(;;){
		case c := <-cmd {
		"ok" =>
			break loop;
		"cancel" =>
			return;
		* =>
			j = int c;
			set[j] = (tkcmd(t, "variable c"+c) == "1");
		}
	}
	for(j=0; j<NEXTRA; j++){
		s := tagname[j+NFONT*NSIZE];
		if(set[j]){
			configfont(f, s);
			tkcmd(f.tk, ".ft.t tag add "+s+" "+start+" "+end);
		}else
			tkcmd(f.tk, ".ft.t tag remove "+s+" "+start+" "+end);
	}
	dirty(f, 1);
	usingfonts(f);
	tkcmd(f.tk, "update");
}

lastpat: string;

execute(cmdwin: ref Tk->Toplevel, f: ref File, cmd: string)
{
	if(len cmd>1 && cmd[len cmd-1]=='\n')
		cmd = cmd[0:len cmd-1];
	if(cmd == "")
		return;
	if(cmd[0] == '/' || cmd[0]=='?'){
		search(cmdwin, f, cmd[1:], cmd[0]=='?');
		return;
	}
	for(i:=0; i<len cmd; i++)
		if(cmd[i]<'0' || '9'<cmd[i]){
			sys->print("bad command %s\n", cmd);
			return;
		}
	t := f.tk;
	line := int cmd;
	if(!nullsel(t))
		tkcmd(t, NOSEL);
	tkcmd(t, ".ft.t tag add sel "+string line+".0 {"+string line+".0 lineend+1char}");
	tkcmd(t, ".ft.t mark set insert "+string line+".0; .ft.t see insert;update");
}

search(cmdwin: ref Tk->Toplevel, f: ref File, pat: string, backwards: int)
{
	t := f.tk;
	if(pat == nil)
		pat = lastpat;
	else
		lastpat = pat;
	if(pat == nil){
		error(cmdwin, "no pattern");
		return;
	}
	cmd := ".ft.t search ";
	if(backwards)
		cmd += "-backwards ";
	p := "";
	for(i:=0; i<len pat; i++){
		if(pat[i]== '\\' || pat[i]=='{')
			p[len p] = '\\';
		p[len p] = pat[i];
	}
	cmd += "{"+p+"} ";
	null := nullsel(t);
	if(null)
		cmd += "insert";
	else if(backwards)
		cmd += "sel.first";
	else
		cmd += "sel.last";
	s := tk->cmd(t, cmd);
	if(s == "")
		error(cmdwin, "not found");
	else{
		if(!null)
			tkcmd(t, NOSEL);
		tkcmd(t, ".ft.t tag add sel "+s+" "+s+"+"+string len pat+"chars");
		tkcmd(t, ".ft.t mark set insert "+s+";.ft.t see insert; update");
	}
}

error(cmdwin: ref Tk->Toplevel, err: string)
{
	tkcmd(cmdwin, ".ft.t insert end '?"+err+"\n");
	if(!nullsel(cmdwin))
		tkcmd(cmdwin, NOSEL);
	tkcmd(cmdwin, ".ft.t mark set insert end");
	tkcmd(cmdwin, ".ft.t mark set typingstart end; update");
}
