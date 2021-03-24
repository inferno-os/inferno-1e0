implement HTML;

include "sys.m";
include "html.m";

sys:	Sys;

Stringtab: adt
{
	name:	string;
	val:		int;
};

chartab:= array[] of { Stringtab
	("AElig", 'Æ'),
	("Aacute", 'Á'),
	("Acirc", 'Â'),
	("Agrave", 'À'),
	("Aring", 'Å'),
	("Atilde", 'Ã'),
	("Auml", 'Ä'),
	("Ccedil", 'Ç'),
	("ETH", 'Ð'),
	("Eacute", 'É'),
	("Ecirc", 'Ê'),
	("Egrave", 'È'),
	("Euml", 'Ë'),
	("Iacute", 'Í'),
	("Icirc", 'Î'),
	("Igrave", 'Ì'),
	("Iuml", 'Ï'),
	("Ntilde", 'Ñ'),
	("Oacute", 'Ó'),
	("Ocirc", 'Ô'),
	("Ograve", 'Ò'),
	("Oslash", 'Ø'),
	("Otilde", 'Õ'),
	("Ouml", 'Ö'),
	("THORN", 'Þ'),
	("Uacute", 'Ú'),
	("Ucirc", 'Û'),
	("Ugrave", 'Ù'),
	("Uuml", 'Ü'),
	("Yacute", 'Ý'),
	("aElig", 'æ'),
	("aacute", 'á'),
	("acirc", 'â'),
	("agrave", 'à'),
	("alpha", 'α'),
	("amp", '&'),
	("aring", 'å'),
	("atilde", 'ã'),
	("auml", 'ä'),
	("beta", 'β'),
	("ccedil", 'ç'),
	("cdots", '⋯'),
	("chi", 'χ'),
	("copy", '©'),
	("ddots", '⋱'),
	("delta", 'δ'),
	("eacute", 'é'),
	("ecirc", 'ê'),
	("egrave", 'è'),
	("emdash", '—'),
	("emsp", ' '),
	("endash", '–'),
	("ensp", ' '),
	("epsilon", 'ε'),
	("eta", 'η'),
	("eth", 'ð'),
	("euml", 'ë'),
	("gamma", 'γ'),
	("gt", '>'),
	("iacute", 'í'),
	("icirc", 'î'),
	("igrave", 'ì'),
	("iota", 'ι'),
	("iuml", 'ï'),
	("kappa", 'κ'),
	("lambda", 'λ'),
	("ldots", '…'),
	("lt", '<'),
	("mu", 'μ'),
	("nbsp", ' '),
	("ntilde", 'ñ'),
	("nu", 'ν'),
	("oacute", 'ó'),
	("ocirc", 'ô'),
	("ograve", 'ò'),
	("omega", 'ω'),
	("omicron", 'ο'),
	("oslash", 'ø'),
	("otilde", 'õ'),
	("ouml", 'ö'),
	("phi", 'φ'),
	("pi", 'π'),
	("psi", 'ψ'),
	("quad", ' '),
	("quot", '"'),
	("reg", '®'),
	("rho", 'ρ'),
	("shy", '­'),
	("sigma", 'σ'),
	("sp", ' '),
	("szlig", 'ß'),
	("tau", 'τ'),
	("theta", 'θ'),
	("thinsp", ' '),
	("thorn", 'þ'),
	("trade", '™'),
	("uacute", 'ú'),
	("ucirc", 'û'),
	("ugrave", 'ù'),
	("upsilon", 'υ'),
	("uuml", 'ü'),
	("varepsilon", '∈'),
	("varphi", 'ϕ'),
	("varpi", 'ϖ'),
	("varrho", 'ϱ'),
	("vdots", '⋮'),
	("vsigma", 'ς'),
	("vtheta", 'ϑ'), 
	("xi", 'ξ'),
	("yacute", 'ý'),
	("yuml", 'ÿ'),
	("zeta", 'ζ'),
};

htmlstringtab := array[] of { Stringtab
	("a", Ta),
	("address", Taddress),
	("applet", Tapplet),
	("area", Tarea),
	("att_footer", Tatt_footer),
	("b", Tb),
	("base", Tbase),
	("basefont", Tbasefont),
	("big", Tbig),
	("blink", Tblink),
	("blockquote", Tblockquote),
	("body", Tbody),
	("bq", Tbq),
	("br", Tbr),
	("caption", Tcaption),
	("center", Tcenter),
	("cite", Tcite),
	("code", Tcode),
	("col", Tcol),
	("colgroup", Tcolgroup),
	("dd", Tdd),
	("dfn", Tdfn),
	("dir", Tdir),
	("div", Tdiv),
	("dl", Tdl),
	("dt", Tdt),
	("em", Tem),
	("font", Tfont),
	("form", Tform),
	("h1", Th1),
	("h2", Th2),
	("h3", Th3),
	("h4", Th4),
	("h5", Th5),
	("h6", Th6),
	("head", Thead),
	("hr", Thr),
	("html", Thtml),
	("i", Ti),
	("img", Timg),
	("input", Tinput),
	("isindex", Tisindex),
	("item", Titem),
	("kbd", Tkbd),
	("li", Tli),
	("link", Tlink),
	("map", Tmap),
	("menu", Tmenu),
	("meta", Tmeta),
	("ol", Tol),
	("option", Toption),
	("p", Tp),
	("param", Tparam),
	("pre", Tpre),
	("q", Tq),
	("strike", Tstrike),
	("samp", Tsamp),
	("script", Tscript),
	("select", Tselect),
	("small", Tsmall),
	("strong", Tstrong),
	("style", Tstyle),
	("sub", Tsub),
	("sup", Tsup),
	("t", Tt),
	("table", Ttable),
	("tbody", Ttbody),
	("td", Ttd),
	("textarea", Ttextarea),
	("textflow", Ttextflow),
	("tfoot", Ttfoot),
	("th", Tth),
	("thead", Tthead),
	("title", Ttitle),
	("tr", Ttr),
	("tt", Ttt),
	("u", Tu),
	("ul", Tul),
	("var", Tvar)
};

lex(b: array of byte, keepwh: int): array of ref Lex
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	a: array of ref Lex;
	ai := 0;
	i := 0;
	for(;;){
		j := i;
    Whitespace:
		for(;;){
			# ignore nulls
			if(j<len b && (int b[j] == 0))
				j++;
			# skip white space
			if(!keepwh) {
				while(j<len b && (int b[j]==' ' || int b[j]=='\n'))
					j++;
			}
			# skip comments
			if(j<len b-4 && string b[j:j+4]=="<!--"){
				j += 4;
				while(j < len b-3){
					if(string b[j:j+3] == "-->"){
						j += 3;
						i = j;
						continue Whitespace;
					}
					j++;
				}
				continue Whitespace;
			}
			break;
		}
		if(j == len b)
			break;
		if(ai == len a){
			na := array[len a + 100] of ref Lex;
			if(a != nil)
				na[0:] = a;
			a = na;
		}
		s: string;
		if(int b[j] == '<'){
			(s, i) = gettag(b, j);
			rbra := 0;
			j = 1;
			# SGML parsing rule: record end immediately following start tag is ignored;
			#    record end immediately preceding end tag is ignored
			if(len s>1 && s[1]=='/'){
				rbra = RBRA;
				j = 2;
				if(ai > 0 && a[ai-1].tag == Data) {
					ps := a[ai-1].text;
					z := len ps - 1;
					if(z >= 0 && ps[z] == '\r') {
						a[ai-1].text = ps[0:z];
						z--;
					}
					if(z >= 0 && ps[z] == '\n')
						a[ai-1].text = ps[0:z];
				}
			}
			else {
				if(i < len b && int b[i] == '\r')
					i++;
				if(i < len b && int b[i] == '\n')
					i++;
			}
			for(k:=j; k<len s-1 && s[k]!=' ' && s[k]!='\n' && s[k]!='\t'; k++)
				;
			if(k == j)
				a[ai++] = ref Lex (Notfound, s, nil);
			else{
				tag := lookup(htmlstringtab, lowercase(s[j:k]));
				str := s[j:len s-1];
				a[ai++] = ref Lex (rbra+tag, str, attribute(str));
			}
		}else{
			(s, i) = getdata(b, i, keepwh);
			a[ai++] = ref Lex (Data, s, nil);
		}
	}
	return a[0:ai];
}

getdata(b: array of byte, i: int, keepnls: int): (string, int)	# assumes charset ISO-8859-1
{
	s:= "";
	j:= 0;
	c: int;

	while(i < len b){
		c = int b[i++];
		if(c == 0)
			continue;
		if(c == '<'){
			i--;
			break;
		}
		if(c == '&')
			(c, i) = ampersand(b, i);
		if(c == '\n' && !keepnls)
			c = ' ';
		if(c != '\r' && c != 16r1a)
			s[j++] = c;
	}
	return (s, i);
}

gettag(b: array of byte, i: int): (string, int)	# assumes charset ISO-8859-1
{
	s:= "";
	j:= 0;
	quote:=0;
	c: int;

	while(i < len b){
		c = int b[i++];
		if(c == '>' && quote == 0){
			s[j++] = '>';
			break;
		}
		if(c == '&')
			(c, i) = ampersand(b, i);
		if(quote) {
			if(quote == c)
				quote = 0;
		}
		else if(c == '"' || c == '\'')
			quote = c;
		s[j++] = c;
	}
	return (s, i);
}


ampersand(b: array of byte, i: int): (int, int)
{
	starti := i;
	c := 0;
	if(i >= len b)
		return ('?', i);
	if(int b[i] == '#'){
		i++;
		while(i<len b && '0'<=int b[i] && int b[i]<='9'){
			c = c*10 + int b[i]-'0';
			i++;
		}
		if(0<c && c<256) {
			if(c==160)
				c = ' ';   # non-breaking space
			if(i<len b && int b[i]==';')
				return (c, i+1);
			return (c, i);
		}
		return ('&', starti+1);
	}
	s := "";
	k := 0;
	while(i<len b && int b[i]!=';'){
		if(int b[i] <'A' || int b[i]>'z') {
			if(k == 0)
				return ('&', starti+1);
			else
				break;
		}
		s[k++] = int b[i];
		i++;
	}
	char := lookup(chartab, s);
	if(char == Notfound)
		return ('&', starti+1);
	return (char, i+1);
}

lowercase(s: string): string
{
	l := "";

	for(i:=0; i<len s; i++)
		if('A'<=s[i] && s[i]<='Z')
			l[i] = s[i]-'A'+'a';
		else
			l[i] = s[i];
	return l;
}

uppercase(s: string): string
{
	l := "";

	for(i:=0; i<len s; i++)
		if('a'<=s[i] && s[i]<='z')
			l[i] = s[i]+'A'-'a';
		else
			l[i] = s[i];
	return l;
}

lookup(t: array of Stringtab, s: string): int
{
	min := 0;
	max := len t-1;
	while(min <= max){
		try := (min+max)/2;
		if(t[try].name == s)
			return t[try].val;
		if(t[try].name < s)
			min = try+1;
		else
			max = try-1;
	}
	return Notfound;
}

skipbl(str: string, i: int): int
{
	while(i<len str && (str[i]==' ' || str[i]=='\n' || str[i]=='\t'))
		i++;
	return i;
}

skipnonbl(str: string, i: int): int
{
	while(i<len str && (str[i]!=' ' && str[i]!='\n' && str[i]!='\t' && str[i]!='='))
		i++;
	return i;
}

attribute(str: string): list of Attr
{
	l: list of Attr;
	i := skipnonbl(str, 0);
	while(i < len str){
		i = skipbl(str, i);
		if(i == len str)
			break;
		j := skipnonbl(str, i);
		name := lowercase(str[i:j]);
		i = skipbl(str, j);
		if(i==len str || str[i]!='='){
			l = (name, "") :: l;
			continue;
		}
		i = skipbl(str, i+1);
		j = i;
		if(i == len str)
			value := "";
		else if(str[i]=='\'' || str[i]=='"'){
			quote := str[j++];
			while(j<len str && (str[j]!=quote))
				j++;
			value = str[i+1:j];
			j++;
		}else{
			j = skipnonbl(str, i);
			value = str[i:j];
		}
		i = j;
		l = (name, value) :: l;
	}
	return l;
}

attrvalue(attr: list of Attr, name: string): (int, string)
{
	while(attr != nil){
		a := hd attr;
		if(a.name == name)
			return (1, a.value); 
		attr = tl attr;
	}
	return (0, "");
}

globalattr(html: array of ref Lex, tag: int, attr: string): (int, string)
{
	for(i:=0; i<len html; i++)
		if(html[i].tag == tag)
			return attrvalue(html[i].attr, attr);
	return (0, "");
}

isbreak(h: array of ref Lex, i: int): int
{
	for(; i<len h; i++){
		case h[i].tag{
		Th1 or Th2 or Th3 or Th4 or Th5 or Th6 or
		Tbr or Tp or Tbody or Taddress or Tblockquote or
		Tul or Tdl or Tdir or Tmenu or Tol or Tpre or Thr or Tform =>
			return 1;
		Data =>
			return 0;
		}
	}
	return 0;
}

# for debugging
lex2string(l: ref Lex): string
{
	ans := "";
	tag := l.tag;
	if(tag == HTML->Data)
		ans = "'" + l.text + "'";
	else {
		ans = "<";
		if(tag >= RBRA) {
			tag -= RBRA;
			ans = ans + "/";
		}
		for(i := 0; i < len htmlstringtab; i++)
			if(tag == htmlstringtab[i].val) {
				ans = ans + uppercase(htmlstringtab[i].name);
				break;
			}
		for(al := l.attr; al != nil; al = tl al) {
			a := hd al;
			ans = ans + " " + a.name + "='" + a.value + "'";
		}
		ans = ans + ">";
	}
	return ans;
}
