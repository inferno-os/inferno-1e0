implement Debug;

include "sys.m";
sys: Sys;
sprint, FD: import sys;

include "string.m";
str: String;

include "draw.m";

include "debug.m";

Command: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

Spin: adt
{
	spin:	int;
	pspin:	int;
};

SrcState: adt
{
	files:	array of string;
	lastf:	int;
	lastl:	int;
	vers:	int;			# minor version number: 1 => more srouce states
};

Terror, Tadt, Tarray, Tbig, Tbyte, Tchan, Treal,
	Tfn, Targ, Tlocal, Tglobal, Tint, Tlist, Tmodule, Tnil, Tnone,
	Tref, Tstring, Ttuple, Tend, Targs: con iota;

IBY2WD:		con 4;
IBY2LG:		con 8;
H:		con int 16rffffffff;

ModHash:	con 32;
SymHash:	con 32;
mods:=		array[ModHash] of list of ref Module;
syms:=		array[SymHash] of list of ref Sym;

sblpath :=	array[] of
{
	("/dis/",	"/appl/cmd/"),
	("/dis/mux/",	"/appl/mux/"),
	("/dis/lib/",	"/appl/lib/"),
	("/dis/wm/",	"/appl/wm/"),
};

init(): int
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	if(sys == nil || str == nil)
		return 0;
	return 1;
}

prog(pid: int): (ref Prog, string)
{
	spid := string pid;
	h := sys->open("/prog/"+spid+"/heap", sys->ORDWR);
	if(h == nil)
		return (nil, sprint("can't open heap file: %r"));
	c := sys->open("/prog/"+spid+"/ctl", sys->OWRITE);
	if(c == nil)
		return (nil, sprint("can't open ctl file: %r"));
	d := sys->open("/prog/"+spid+"/dbgctl", sys->ORDWR);
	if(d == nil)
		return (nil, sprint("can't open debug ctl file: %r"));
	s := sys->open("/prog/"+spid+"/stack", sys->OREAD);
	if(s == nil)
		return (nil, sprint("can't open stack file: %r"));
	return (ref Prog(pid, h, c, d, s), "");
}

startprog(dis, dir: string, ctxt: ref Draw->Context, argv: list of string): (ref Prog, string)
{
	c := load Command dis;
	if(c == nil)
		return (nil, "module not loaded");

	ack := chan of int;
	spin := ref Spin(1, 1);
	spawn execer(ack, dir, c, ctxt, argv, spin);
	kid := <-ack;

	fd := sys->open("/prog/"+string kid+"/dbgctl", sys->ORDWR);
	if(fd == nil){
		spin.spin = -1;
		return (nil, sprint("can't open debug ctl file: %r"));
	}
	done := chan of string;
	spawn stepper(done, fd, spin);

wait:	for(;;){
		alt{
		<-ack =>
			sys->sleep(0);
		err := <-done =>
			if(err != "")
				return(nil, err);
			break wait;
		}
	}

	b := array[20] of byte;
	n := sys->read(fd, b, len b);
	if(n <= 0)
		return(nil, sprint("%r"));
	msg := string b[:n];
	if(!str->prefix("new ", msg))
		return (nil, msg);

	kid = int msg[len "new ":];

	# clean up the execer slave
	b = array of byte "start";
	sys->write(fd, b, len b);

	return prog(kid);
}

stepper(done: chan of string, ctl: ref FD, spin: ref Spin)
{
	b := array of byte "step1";
	while(spin.pspin){
		if(sys->write(ctl, b, len b) != len b)
			done <-= sprint("can't start new thread: %r");
		spin.spin = 0;
	}
	done <-= "";
}

execer(ack: chan of int, dir: string, c: Command, ctxt: ref Draw->Context, args: list of string, spin: ref Spin)
{
	pid := sys->pctl(Sys->NEWPGRP|Sys->FORKNS, nil);
	sys->chdir(dir);
	while(spin.spin == 1)
		ack <-= pid;
	if(spin.spin == -1)
		exit;
	spawn c->init(ctxt, args);
	spin.pspin = 0;
	exit;
}

# format of each line is
# fp pc mp prog compiled path
# fp, pc, mp, and prog are %.8lux
# compile is  or 1
# path is a string
Prog.stack(p: self ref Prog): (array of ref Exp, string)
{
	buf := array[8192] of byte;
	sys->seek(p.stk, 0, 0);
	n := sys->read(p.stk, buf, len buf - 1);
	if(n < 0)
		return (nil, sprint("can't read stack file: %r"));
	buf[n] = byte 0;

	t := 0;
	nf := 0;
	for(s := 0; s < n; s = t+1){
		t = strchr(buf, s, '\n');
		if(buf[t] != byte '\n' || t-s < 40)
			continue;
		nf++;
	}

	e := array[nf] of ref Exp;
	nf = 0;
	for(s = 0; s < n; s = t+1){
		t = strchr(buf, s, '\n');
		if(buf[t] != byte '\n' || t-s < 40)
			continue;
		e[nf] = ref Exp("unknown fn",
				hex(buf[s+0:s+8]), 
				hex(buf[s+9:s+17]),
				mkmod(hex(buf[s+18:s+26]), hex(buf[s+27:s+35]), buf[36] != byte '0', string buf[s+38:t]),
				p,
				nil);
		nf++;
	}

	return (e, "");
}

Prog.step(p: self ref Prog, how: int): string
{
	(stack, nil) := p.stack();
	if(stack == nil)
		return "can't find initial pc";
	src := stack[0].srcstr();
	stmt := ftostmt(stack[0]);

	sym := stack[0].m.sym;
	if(sym == nil)
		how = -1;

	buf := array of byte("step1");
	if(how == StepOut)
		buf = array of byte("toret");
	while(sys->write(p.dbgctl, buf, len buf) == len buf){
		(stk, err) := p.stack();
		if(err != nil)
			return "";
		case how{
		StepExp =>
			if(src != stk[0].srcstr())
				return "";
		StepStmt =>
			if(stmt != ftostmt(stk[0]))
				return "";
			if(stk[0].offset != stack[0].offset)
				return "";
		StepOut =>
			if(returned(stack, stk))
				return "";
		StepOver =>
			if(stk[0].offset == stack[0].offset){
				if(stmt != ftostmt(stk[0]))
					return "";
				buf = array of byte("step1");
				break;
			}
			if(returned(stack, stk))
				return "";
			buf = array of byte("toret");
		* =>
			return "";
		}
	}
	return sprint("%r");
}

Prog.stop(p: self ref Prog): string
{
	return dbgctl(p, "stop");
}

Prog.unstop(p: self ref Prog): string
{
	return dbgctl(p, "unstop");
}

Prog.grab(p: self ref Prog): string
{
	return dbgctl(p, "step0");
}

Prog.start(p: self ref Prog): string
{
	return dbgctl(p, "start");
}

Prog.cont(p: self ref Prog): string
{
	return dbgctl(p, "cont");
}

dbgctl(p: ref Prog, msg: string): string
{
	b := array of byte msg;
	while(sys->write(p.dbgctl, b, len b) != len b)
		return sprint("%r");
	return "";
}

returned(old, new: array of ref Exp): int
{
	n := len old;
	if(n > len new)
		return 1;
	return 0;
}

Prog.setbpt(p: self ref Prog, dis: string, pc:int): string
{
	b := array of byte("bpt set "+dis+" "+string pc);
	if(sys->write(p.dbgctl, b, len b) != len b)
		return sprint("can't set breakpoint: %r");
	return "";
}

Prog.delbpt(p: self ref Prog, dis: string, pc:int): string
{
	b := array of byte("bpt del "+dis+" "+string pc);
	if(sys->write(p.dbgctl, b, len b) != len b)
		return sprint("can't del breakpoint: %r");
	return "";
}

Prog.kill(p: self ref Prog): string
{
	b := array of byte "kill";
	if(sys->write(p.ctl, b, len b) != len b)
		return sprint("can't kill process: %r");
	return "";
}

Prog.event(p: self ref Prog): string
{
	b := array[100] of byte;
	n := sys->read(p.dbgctl, b, len b);
	if(n < 0)
		return sprint("error: %r");
	return string b[:n];
}

ftostmt(e: ref Exp): int
{
	m := e.m;
	if(!m.comp && m.sym != nil && e.pc < len m.sym.srcstmt)
		return m.sym.srcstmt[e.pc];
	return -1;
}

Exp.srcstr(e: self ref Exp): string
{
	m := e.m;
	if(!m.comp && m.sym != nil && e.pc < len m.sym.src){
		src := m.sym.src[e.pc];
		ss := src.start.file+":"+string src.start.line+"."+string src.start.pos+", ";
		if(src.stop.file != src.start.file)
			ss += src.stop.file+":"+string src.stop.line+".";
		else if(src.stop.line != src.start.line)
			ss += string src.stop.line+".";
		return ss+string src.stop.pos;
	}
	return sprint("Module %s PC %d", e.m.path, e.pc);
}

Exp.findsym(e: self ref Exp): string
{
	m := e.m;
	if(m.comp)
		return "compiled module";
	if(m.sym != nil){
		n := e.pc;
		fns := m.sym.fns;
		for(i := 0; i < len fns; i++){
			if(n >= fns[i].offset && n < fns[i].stoppc){
				e.name = fns[i].name;
				e.id = fns[i];
				return "";
			}
		}
		return "pc out of bounds";
	}
	return "no symbol file";
}

Exp.src(e: self ref Exp): ref Src
{
	m := e.m;
	if(e.id == nil || m.sym == nil)
		return nil;
	src := e.id.src;
	if(src != nil)
		return src;
	if(e.id.t.kind == Tfn && !m.comp && e.pc < len m.sym.src && e.pc >= 0)
		return m.sym.src[e.pc];
	return nil;
}

Exp.expand(e: self ref Exp): array of ref Exp
{
	if(e.id == nil)
		return nil;

	t := e.id.t;
	off := e.offset;
	ids := t.ids;
	case t.kind{
	Tfn or Targ or Tlocal or Ttuple =>
		;
	Tglobal =>
		ids = e.m.sym.vars;
		off = e.m.data;
	Tadt =>
		ids = e.m.sym.adts[int t.name].ids;
	Tref =>
		(s, err) := pdata(e.p, off, "P");
		if(s == "nil" || err != "")
			return nil;
		off = hex(array of byte s);
		ids = e.m.sym.adts[int t.Of.name].ids;
	Tlist =>
		(s, err) := pdata(e.p, off, "L");
		if(err != "")
			return nil;
		(tloff, hdoff) := str->splitl(s, ".");
		hdoff = hdoff[1:];
		k := array[2] of ref Exp;
		k[0] = ref Exp("hd", hex(array of byte hdoff), e.pc, e.m, e.p, ref Id(nil, "hd", H, H, t.Of));
		k[1] = ref Exp("tl", hex(array of byte tloff), e.pc, e.m, e.p, ref Id(nil, "tl", H, H, t));
		return k;
	Tarray =>
		(s, err) := pdata(e.p, e.offset, "A");
		if(s == "nil")
			return nil;
		(sn, sa) := str->splitl(s, ".");
		n := int sn;
		if(sa == "" || n <= 0)
			return nil;
		(off, nil) = str->toint(sa[1:], 16);
		et := t.Of;
		esize := et.size;
		k := array[n] of ref Exp;
		for(i := 0; i < n; i++){
			name := string i;
			k[i] = ref Exp(name, off+i*esize, e.pc, e.m, e.p, ref Id(nil, name, H, H, et));
		}
		return k;
	* =>
		return nil;
	}
	k := array[len ids] of ref Exp;
	for(i := 0; i < len k; i++){
		id := hd ids;
		ids = tl ids;
		k[i] = ref Exp(id.name, off+id.offset, e.pc, e.m, e.p, id);
	}
	return k;
}

Exp.val(e: self ref Exp): (string, int)
{
	if(e.id == nil)
		return (e.m.path+" unknown fn", 0);
	t := e.id.t;

	w := 0;
	s := "";
	err := "";
	p := e.p;
	case t.kind{
	Tfn =>
		if(t.ids != nil)
			w = 1;
		src := e.m.sym.src[e.pc];
		ss := src.start.file+":"+string src.start.line+"."+string src.start.pos+", ";
		if(src.stop.file != src.start.file)
			ss += src.stop.file+":"+string src.stop.line+".";
		else if(src.stop.line != src.start.line)
			ss += string src.stop.line+".";
		return (ss+string src.stop.pos, w);
	Targ or Tlocal or Tglobal or Tadt or Ttuple =>
		return ("", 1);
	Tnil =>
		s = "nil";
	Tbyte =>
		(s, err) = pdata(p, e.offset, "B");
	Tint =>
		(s, err) = pdata(p, e.offset, "W");
	Tbig =>
		(s, err) = pdata(p, e.offset, "V");
	Treal =>
		(s, err) = pdata(p, e.offset, "R");
	Tarray =>
		(s, err) = pdata(p, e.offset, "A");
		if(s == "nil")
			break;
		(n, a) := str->splitl(s, ".");
		if(a == "")
			return ("", 0);
		s = "["+n+"] @"+a[1:];
		w = 1;
	Tstring =>
		n : int;
		(n, s, err) = pstring(p, e.offset);
		if(err != "")
			return ("", 0);
		for(i := 0; i < len s; i++)
			if(s[i] == '\n')
				s[i] = '\u008a';
		s = "["+string n+"] \""+s+"\"";
	Tref or Tlist or Tchan or Tmodule =>
		(s, err) = pdata(p, e.offset, "P");
		if(s == "nil")
			break;
		s = "@" + s;
		w = 1;
	}
	if(err != "")
		return ("", 0);
	return (s, w);
}

Sym.srctopc(s: self ref Sym, src: ref Src): int
{
	srcs := s.src;
	line := src.start.line;
	pos := src.start.pos;
	(nil, file) := str->splitr(src.start.file, "/");
	backup := -1;
	delta := 80;
	for(i := 0; i < len srcs; i++){
		ss := srcs[i];
		if(ss.start.file != file)
			continue;
		if(ss.start.line <= line && ss.start.pos <= pos
		&& ss.stop.line >= line && ss.stop.pos >= pos)
			return i;
		d := ss.start.line - line;
		if(d >= 0 && d < delta){
			delta = d;
			backup = i;
		}
	}
	return backup;
}

Sym.pctosrc(s: self ref Sym, pc: int): ref Src
{
	if(pc < 0 || pc >= len s.src)
		return nil;
	return s.src[pc];
}

sym(sbl: string): (ref Sym, string)
{
	h := 0;
	for(i := 0; i < len sbl; i++)
		h = (h << 1) + sbl[i];
	h &= SymHash - 1;
	for(sl := syms[h]; sl != nil; sl = tl sl){
		s := hd sl;
		if(sbl == s.path)
			return (s, "");
	}
	(sym, err) := loadsyms(sbl);
	if(err != "")
		return (nil, err);
	syms[h] = sym :: syms[h];
	return (sym, "");
}

Module.addsym(m: self ref Module, sym: ref Sym)
{
	m.sym = sym;
}

Module.sbl(m: self ref Module): string
{
	if(m.sym != nil)
		return m.sym.path;
	return "";
}

Module.dis(m: self ref Module): string
{
	return m.path;
}

Module.stdsym(m: self ref Module)
{
	if(m.sym != nil)
		return;
	sbl := m.path;
	n := len sbl;
	if(n > 4 && sbl[n-4:n] == ".dis")
		sbl = sbl[:n-4]+".sbl";
	else
		sbl = sbl+".sbl";
	path := sbl;
	fd := sys->open(sbl, sys->OREAD);
	for(i := 0; fd == nil && i < len sblpath; i++){
		(dis, src) := sblpath[i];
		nd := len dis;
		if(len sbl > nd && sbl[:nd] == dis){
			path = src + sbl[nd:];
			fd = sys->open(path, sys->OREAD);
		}
	}
	if(fd == nil)
		return;
	(m.sym, nil) = sym(path);
}

mkmod(data, code, comp: int, dis: string): ref Module
{
	h := 0;
	for(i := 0; i < len dis; i++)
		h = (h << 1) + dis[i];
	h &= ModHash - 1;
	sym : ref Sym;
	for(ml := mods[h]; ml != nil; ml = tl ml){
		m := hd ml;
		if(m.path == dis && m.code == code && m.comp == comp){
			sym = m.sym;
			if(m.data == data)
				return m;
		}
	}
	m := ref Module(dis, code, data, comp, sym);
	mods[h] = m :: mods[h];
	return m;
}

pdata(p: ref Prog, a: int, fmt: string): (string, string)
{
	b := array of byte sprint("0x%ux.%s1", a, fmt);
	if(sys->write(p.heap, b, len b) != len b)
		return ("", sprint("can't write heap: %r"));

	buf := array[20] of byte;
	sys->seek(p.heap, 0, 0);
	n := sys->read(p.heap, buf, len buf);
	if(n <= 1)
		return ("", sprint("can't read heap: %r"));
	return (string buf[:n-1], "");
}

pstring(p: ref Prog, a: int): (int, string, string)
{
	b := array of byte sprint("0x%ux.C1", a);
	if(sys->write(p.heap, b, len b) != len b)
		return (-1, "", sprint("can't write heap: %r"));

	buf := array[64] of byte;
	sys->seek(p.heap, 0, 0);
	n := sys->read(p.heap, buf, len buf-1);
	if(n <= 1)
		return (-1, "", sprint("can't read heap: %r"));
	buf[n] = byte 0;
	m := strchr(buf, 0, '.');
	if(buf[m++] != byte '.')
		m = 0;
	return (int string buf[0:m], string buf[m:n], "");
}

Prog.status(p: self ref Prog): (int, string, string, string)
{
	fd := sys->open(sprint("/prog/%d/status", p.id), sys->OREAD);
	if(fd == nil)
		return (-1, "", sprint("can't open status file: %r"), "");
	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0)
		return (-1, "", sprint("can't read status file: %r"), "");
	(ni, info) := sys->tokenize(string buf[:n], " \t");
	if(ni != 6)
		return (-1, "", "can't parse status file", "");
	info = tl info;
	return (int hd info, hd tl info, hd tl tl info, hd tl tl tl tl info);
}

loadsyms(sbl: string): (ref Sym, string)
{
	fd := sys->open(sbl, sys->OREAD);
	if(fd == nil)
		return (nil, sprint("Can't open symbol file '%s': %r", sbl));

	(ok, dir) := sys->fstat(fd);
	if(ok < 0)
		return (nil, sprint("Can't read symbol file '%s': %r", sbl));
	n := dir.length;
	buf := array[n+1] of byte;
	if(sys->read(fd, buf, n) != n)
		return (nil, sprint("Can't read symbol file '%s': %r", sbl));
	fd = nil;
	buf[n] = byte 0;

	s := ref Sym;
	s.path = sbl;

	n = strchr(buf, 0, '\n');
	vers := 0;
	if(string buf[:n] == "limbo .sbl 1.1")
		vers = 1;
	else if(string buf[:n] != "limbo .sbl 1.")
		return (nil, "Symbol file "+sbl+" out of date");
	o := n += 1;
	n = strchr(buf, o, '\n');
	if(buf[n] != byte '\n')
		return (nil, "Corrupted symbol file "+sbl);
	s.name = string buf[o:n++];
	ss := ref SrcState(nil, 0, 0, vers);
	err : string;
	if(n >= 0){
		err = "file";
		n = debugfiles(ss, buf, n);
	}
	if(n >= 0){
		err = "pc";
		n = debugpc(ss, s, buf, n);
	}
	if(n >= 0){
		err = "adt";
		n = debugadts(ss, s, buf, n);
	}
	if(n >= 0){
		err = "fn";
		n = debugfns(ss, s, buf, n);
	}
	vs: array of ref Id;
	if(n >= 0){
		err = "global";
		(vs, n) = debugid(ss, buf, n);
	}
	if(n < 0)
		return (nil, "Corrupted "+err+" symbol table in "+sbl);
	s.vars = idlist(vs);
	return (s, "");
}

#
# parse a source location
# format[file:][line.]pos,[file:][line.]pos' '
#
debugsrc(ss: ref SrcState, buf: array of byte, p: int): (ref Src, int)
{
	n: int;
	src: ref Src;

	(n, p) = strtoi(buf, p);
	if(buf[p] == byte ':'){
		ss.lastf = n;
		(n, p) = strtoi(buf, p + 1);
	}
	if(buf[p] == byte '.'){
		ss.lastl = n;
		(n, p) = strtoi(buf, p + 1);
	}
	if(buf[p++] != byte ',' || ss.lastf >= len ss.files || ss.lastf < 0)
		return (nil, -1);
	src = ref Src;
	src.start.file = ss.files[ss.lastf];
	src.start.line = ss.lastl;
	src.start.pos = n;

	(n, p) = strtoi(buf, p);
	if(buf[p] == byte ':'){
		ss.lastf = n;
		(n, p) = strtoi(buf, p+1);
	}
	if(buf[p] == byte '.'){
		ss.lastl = n;
		(n, p) = strtoi(buf, p + 1);
	}
	if(buf[p++] != byte ' ' || ss.lastf >= len ss.files || ss.lastf < 0)
		return (nil, -1);
	src.stop.file = ss.files[ss.lastf];
	src.stop.line = ss.lastl;
	src.stop.pos = n;
	return (src, p);
}

#
# parse the file table
# item format: file: string
#
debugfiles(ss: ref SrcState, buf: array of byte, p: int): int
{
	n, q: int;

	(n, p) = strtoi(buf, p);
	if(buf[p++] != byte '\n')
		return -1;
	ss.files = array[n] of string;
	for(i := 0; i < n; i++){
		q = strchr(buf, p, '\n');
		ss.files[i] = string buf[p:q];
		p = q + 1;
	}
	return p;
}

#
# parse the pc to source table
# item format: Source stmt
#
debugpc(ss: ref SrcState, s: ref Sym, buf: array of byte, p: int): int
{
	ns: int;

	(ns, p) = strtoi(buf, p);
	if(buf[p++] != byte '\n')
		return -1;
	s.src = array[ns] of ref Src;
	s.srcstmt = array[ns] of int;
	for(i := 0; i < ns; i++){
		(s.src[i], p) = debugsrc(ss, buf, p);
		if(p < 0)
			return -1;
		(s.srcstmt[i], p) = strtoi(buf, p);
		if(buf[p++] != byte '\n')
			return -1;
	}
	return p;
}

#
# parse the adt table
# format: name ' ' src size '\n' ids
#
debugadts(ss: ref SrcState, s: ref Sym, buf: array of byte, p: int): int
{
	d: array of ref Id;
	na, pp, q, qq, sq: int;
	src: ref Src;

	(na, p) = strtoi(buf, p);
	if(buf[p++] != byte '\n')
		return -1;
	s.adts = array[na] of ref Type;
	adts := s.adts;
	for(i := 0; i < na; i++){
		q = strchr(buf, p, ' ');
		if(buf[q] != byte ' ')
			return -1;
		sq = q + 1;
		if(ss.vers){
			(src, sq) = debugsrc(ss, buf, sq);
			if(sq < 0)
				return -1;
		}
		qq = strchr(buf, sq, '\n');
		if(buf[qq] != byte '\n')
			return -1;
		(d, pp) = debugid(ss, buf, qq + 1);
		if(pp == -1)
			return -1;
		adts[i] = ref Type(src, Tadt, int string buf[sq:qq], string buf[p:q], nil, idlist(d));
		d = nil;
		p = pp;
	}
	return p;
}

#
# parse the function table
# format: pc:name:argids localids rettype
#
debugfns(ss: ref SrcState, s: ref Sym, buf: array of byte, p: int): int
{
	t: ref Type;
	args, locals: array of ref Id;
	nf, pc, q: int;

	(nf, p) = strtoi(buf, p);
	if(buf[p++] != byte '\n')
		return -1;
	s.fns = array[nf] of ref Id;
	fns := s.fns;
	for(i := 0; i < nf; i++){
		(pc, p) = strtoi(buf, p);
		if(buf[p++] != byte ':')
			return -2;
		q = strchr(buf, p, '\n');
		if(buf[q] != byte '\n')
			return -3;
		name := string buf[p:q];
		(args, p) = debugid(ss, buf, q + 1);
		if(p == -1)
			return -4;
		(locals, p) = debugid(ss, buf, p);
		if(p == -1)
			return -5;
		(t, p) = debugtype(ss, buf, p);
		if(p == -1)
			return -6;
		kids := ref Id(nil, "module", 0, 0, ref Type(nil, Tglobal, 0, nil, nil, nil)) :: nil;
		if(len args != 0)
			kids = ref Id(nil, "args", 0, 0, ref Type(nil, Targ, 0, nil, nil, idlist(args))) :: kids;
		args = nil;
		if(len locals != 0)
			kids = ref Id(nil, "locals", 0, 0, ref Type(nil, Tlocal, 0, nil, nil, idlist(locals))) :: kids;
		locals = nil;
		fns[i] = ref Id(nil, name, pc, 0, ref Type(nil, Tfn, 0, name, t, kids));
	}
	for(i = 1; i < nf; i++)
		fns[i-1].stoppc = fns[i].offset;
	fns[i-1].stoppc = len s.src;
	return p;
}

#
# parse a list of ids
# format: offset ':' name ':' src type '\n'
#
debugid(ss: ref SrcState, buf: array of byte, p: int): (array of ref Id, int)
{
	t: ref Type;
	off, nd, q, qq, tq: int;
	src: ref Src;

	(nd, p) = strtoi(buf, p);
	if(buf[p++] != byte '\n')
		return (nil, -1);
	d := array[nd] of ref Id;
	for(i := 0; i < nd; i++){
		(off, q) = strtoi(buf, p);
		if(buf[q++] != byte ':')
			return (nil, -1);
		qq = strchr(buf, q, ':');
		if(buf[qq] != byte ':')
			return (nil, -1);
		tq = qq + 1;
		if(ss.vers){
			(src, tq) = debugsrc(ss, buf, tq);
			if(tq < 0)
				return (nil, -1);
		}
		(t, p) = debugtype(ss, buf, tq);
		if(p == -1 || buf[p++] != byte '\n')
			return (nil, -1);
		d[i] = ref Id(src, string buf[q:qq], off, 0, t);
	}
	return (d, p);
}

idlist(a: array of ref Id): list of ref Id
{
	n := len a;
	ids : list of ref Id = nil;
	while(n-- > 0)
		ids = a[n] :: ids;
	return ids;
}

#
# parse a type description
#
debugtype(ss: ref SrcState, buf: array of byte, p: int): (ref Type, int)
{
	t: ref Type;
	d: array of ref Id;
	q, k: int;
	src: ref Src;

	size := 0;
	case int buf[p++]{
	'a' =>	k = Tadt;	size = -1;
	'm' =>	k = Tmodule;	size = IBY2WD;
	'R' =>	k = Tref;	size = IBY2WD;
	'A' =>	k = Tarray;	size = IBY2WD;
	'L' =>	k = Tlist;	size = IBY2WD;
	'C' =>	k = Tchan;	size = IBY2WD;
	'n' =>	k = Tnone;	size = 0;
	'N' =>	k = Tnil;	size = IBY2WD;
	'B' =>	k = Tbig;	size = IBY2LG;
	'b' =>	k = Tbyte;	size = 1;
	'i' =>	k = Tint;	size = IBY2WD;
	'f' =>	k = Treal;	size = IBY2LG;
	's' =>	k = Tstring;	size = IBY2WD;
	't' =>	k = Ttuple; 	size = -1;
#	'F' =>	k = Tfn;	size = IBY2WD;
	* =>	k = Terror;	size = 0;
	}

	if(size == -1){
		q = strchr(buf, p, '.');
		if(buf[q] == byte '.'){
			size = int string buf[p:q];
			p = q+1;
		}
	}

	case k{
	Tadt or Tmodule =>
		q = strchr(buf, p, '\n');
		if(buf[q] != byte '\n')
			return (nil, -1);
		t = ref Type(nil, k, size, string buf[p:q], nil, nil);
		p = q + 1;
		if(k == Tmodule && ss.vers){
			(src, p) = debugsrc(ss, buf, p);
			t.src = src;
		}

	Tref or Tarray or Tlist or Tchan =>		# ref, array, list, chan
		(t, p) = debugtype(ss, buf, p);
		t = ref Type(nil, k, size, "", t, nil);

	Tnone or Tnil or Tbyte or Tint or Tbig or Treal or Tstring =>	# none, nil, byte, int, big, float, string
		t = ref Type(nil, k, size, "", nil, nil);

	Ttuple =>						# tuple
		(d, p) = debugid(ss, buf, p);
		t = ref Type(nil, k, size, "", nil, idlist(d));

#	Tfn =>						# fn
#		(d, p) = debugid(ss, buf, p);
#		(t, p) = debugtype(ss, buf, p);
#		t = ref Type(nil, k, size, "", t, d);

	* =>
		p = -1;
	}
	return (t, p);
}

strchr(a: array of byte, p, c: int): int
{
	bc := byte c;
	while((b := a[p]) != byte 0 && b != bc)
		p++;
	return p;
}

strtoi(a: array of byte, start: int): (int, int)
{
	p := start;
	for(; c := int a[p]; p++){
		case c{
		' ' or '\t' or '\n' or '\r' =>
			continue;
		}
		break;
	}

	# sign
	neg := c == '-';
	if(neg || c == '+')
		p++;

	# digits
	n := 0;
	nn := 0;
	ndig := 0;
	over := 0;
	for(; c = int a[p]; p++){
		if(c < '0' || c > '9')
			break;
		ndig++;
		nn = n * 10 + (c - '0');
		if(nn < n)
			over = 1;
		n = nn;
	}
	if(ndig == 0)
		return (0, start);
	if(neg)
		n = -n;
	if(over)
		if(neg)
			n = 2147483647;
		else
			n = int -2147483648;
	return (n, p);
}

hex(a: array of byte): int
{
	n := 0;
	for(i := 0; i < len a; i++){
		c := int a[i];
		if(c >= '0' && c <= '9')
			c -= '0';
		else
			c -= 'a' - 10;
		n = (n << 4) + (c & 15);
	}
	return n;
}
