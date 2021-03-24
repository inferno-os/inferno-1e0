implement echo;

include "sys.m";
	sys : Sys;

include "bufio.m";
	bufmod: Bufio;
Iobuf: 	import bufmod;

include "draw.m";
	draw: Draw;

include "content.m";
Content: import Cont;

include "cache.m";
	
include "httpd.m";
	g : ref Private_info;

include "parser.m";
	pars : Parser;

include "daytime.m";
	daytime : Daytime;

include "query.m";
	query : Que;

echo: module
{
	init: fn(g : ref Private_info, argv: list of string);
};


init(k : ref Private_info, argv: list of string) {	
	sys = load Sys "$Sys";
	draw = load Draw "$Draw";
	stderr := sys->fildes(2);	
	daytime = load Daytime Daytime->PATH;
	if(daytime == nil){
		sys->fprint(stderr,"Daytime module load: %r\n");
		return;
	}
	pars = load Parser Parser->PATH;
	if(pars == nil){
		sys->fprint(stderr,"echo pars module load: %r\n");
		return;
	}
	query = load Que Que->PATH;
	if(query == nil){
		sys->fprint(stderr,"echo query module load: %r\n");
		return;
	}
	meth := hd argv;
	vers := hd (tl argv);
	uri := hd(tl(tl argv));
	search := hd(tl(tl(tl argv)));
	g=k;
	bufmod=g.bufmod;
	send(meth, vers, uri, search);
	return;
}


send(meth, vers, uri, search : string) {
	c, lastnl : int;

	if(vers != ""){
		if (g.version==nil)
			sys->print("version is unknown.\n");
		if (g.bout==nil)
			sys->print("AHHHHHHHHH! g.bout is nil.\n");
		g.bout.puts(sys->sprint("%s 200 OK\r\n", g.version));
		g.bout.puts("Server: Charon\r\n");
		g.bout.puts("MIME-version: 1.0\r\n");
		g.bout.puts(sys->sprint("Date: %s\r\n", daytime->time()));
		g.bout.puts("Content-type: text/html\r\n");
		g.bout.puts("\r\n");
	}
	g.bout.puts("<head><title>Echo</title></head>\r\n");
	g.bout.puts("<body><h1>Echo</h1>\r\n");
	g.bout.puts(sys->sprint("You requested a %s on %s", meth, uri));
	if(search!=nil)
		g.bout.puts(sys->sprint(" with search string %s", search));
	g.bout.puts(".\n");

	g.bout.puts("Your client sent the following headers:<p><pre>");
	lastnl = 1;
	while((c = g.bin.getc()) != bufmod->EOF){
		if(c == '\r'){
			g.bout.putc(c);
			c = g.bin.getb();
			if(c == bufmod->EOF)
				break;
		}
		g.bout.putc(c);
		if(c == '\n'){
			if(lastnl)
				break;
			lastnl=1;
		}else
			lastnl = 0;
	}
	g.bout.puts("</pre>\n");	
	if (meth=="POST"){
		str:="";
		i:=0;
		while((c = g.bin.getc()) != '\n')
			str[len str]=c;
		query->init();
		q_list:=query->parsequery(str); 
		g.bout.puts("</pre>");
		g.bout.puts("Your client sent the following form data:<p>");
		g.bout.puts("<table>\n");
		while(q_list!=nil){
			g.bout.puts(sys->sprint("<tr><td>%d</td><td><I> ",i));
			g.bout.puts((hd q_list).tag);
			g.bout.puts("</I></td> ");
			g.bout.puts("<td><B> ");
			g.bout.puts((hd q_list).val);
			g.bout.puts("</B></td></tr>\n");
			g.bout.puts("\n");
			q_list = tl q_list;
			i++;
		}
		g.bout.puts("</table>\n");
	}	
	g.bout.puts("</body>\n");
	g.bout.flush();
	return;
}
