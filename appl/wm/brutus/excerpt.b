implement Brutusext;

# <Extension excerpt file [start [end]]>

Name:	con "Brutus entry";

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Context: import draw;

include	"bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include	"regex.m";
	regex: Regex;

include "tk.m";
	tk: Tk;

include	"tklib.m";
	tklib: Tklib;

include	"brutus.m";
include	"brutusext.m";

init(s: Sys, d: Draw, b: Bufio, t: Tk, tkl: Tklib)
{
	sys = s;
	draw = d;
	bufio = b;
	tk = t;
	tklib = tkl;
	regex = load Regex Regex->PATH;
}

create(t: ref Tk->Toplevel, name, args: string): string
{
	(text, err) := gather(args);
	if(err != nil)
		return err;
	err = tk->cmd(t, "text "+name+" -tabs {1c} -wrap none");
	if(tklib->is_err(err))
		return err;
	n := nlines(text);
	tk->cmd(t, name+" configure -height "+string n+"h");
	return tk->cmd(t, name+" insert end '"+text);
}

gather(args: string): (string, string)
{
	(nargs, argl) := sys->tokenize(args, " ");
	if(nargs == 0)
		return (nil, "usage: excerpt [start] [end] file");
	file := hd argl;
	argl = tl argl;
	b := bufio->open(file, Bufio->OREAD);
	if(b == nil)
		return (nil, sys->sprint("can't open %s: %r", file));
	start := "";
	end := "";
	if(argl != nil){
		start = hd argl;
		if(tl argl != nil)
			end = hd tl argl;
	}
	(text, err) := readall(b, start, end);
	return (text, err);
}

readall(b: ref Iobuf, start, end: string): (string, string)
{
	s := "";
	appending := 0;
	lineno := 0;
	for(;;){
		line := b.gets('\n');
		if(line == nil)
			return (s, "");
		lineno++;
		if(!appending){
			m := match(start, line, lineno);
			if(m < 0)
				return (nil, "error in pattern");
			if(m)
				appending = 1;
		}
		if(appending){
			s += line;
			if(start != ""){
				m := match(end, line, lineno);
				if(m < 0)
					return (nil, "error in pattern");
				if(m)
					break;
			}
		}
	}
	return (s, "");
}

nlines(s: string): int
{
	n := 0;
	for(i:=0; i<len s; i++)
		if(s[i] == '\n')
			n++;
	if(len s>0 && s[len s-1]!='\n')
		n++;
	return n;
}

match(pat, line: string, lineno: int): int
{
	if(pat == "")
		return 1;
	case pat[0] {
	'0' to '9' =>
		return int pat <= lineno;
	'/' =>
		if(len pat < 3 || pat[len pat-1]!='/')
			return -1;
		re := compile(pat[1:len pat-1]);
		if(re == nil)
			return -1;
		(beg, end) := regex->execute(re, line);
		return beg >= 0;
	}
	return -1;
}

pats: list of (string, Regex->Re);

compile(pat: string): Regex->Re
{
	l := pats;
	while(l != nil){
		(p, r) := hd l;
		if(p == pat)
			return r;
		l = tl l;
	}
	re := regex->compile(pat);
	pats = (pat, re) :: pats;
	return re;
}

cook(nil: int, args: string): (ref Brutusext->Celem, string)
{
	(text, err) := gather(args);
	if(err != nil)
		return (nil, err);
	el1 := ref Brutusext->Celem(Brutusext->Text, text, nil, nil, nil, nil);
	el2 := ref Brutusext->Celem(Brutus->Type*Brutus->NSIZE+Brutus->Size10, text, el1, nil, nil, nil);
	el1.parent = el2;
	ans := ref Brutusext->Celem(Brutus->Example, "", el2, nil, nil, nil);
	el2.parent = ans;
	return (ans, "");
}
