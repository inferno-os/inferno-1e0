implement Sh;

include "sys.m";
	sys: Sys;
	FD: import Sys;

include "draw.m";
	Context: import Draw;

include "filepat.m";
	filepat: Filepat;

include "pipe.m";
	pipe: Pipe;

include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

stdin: ref FD;
stderr: ref FD;
waitfd: ref FD;

Quoted: con '\uFFF0';
stringQuoted: con "\uFFF0";

Sh: module
{
	init: fn(ctxt: ref Context, argv: list of string);
};

Command: adt
{
	args: list of string;
	inf, outf: string;
	append: int;
};

Async, Seq: con iota;

Pipeline: adt
{
	cmds: list of ref Command;
	term: int;
};

init(ctxt: ref Context, argv: list of string)
{
	n: int;
	arg: list of string;
	buf := array[1024] of byte;

	sys = load Sys Sys->PATH;

	stderr = sys->fildes(2);
	sys->pctl(sys->FORKNS, nil);

	waitfd = sys->open("#p/"+string sys->pctl(0, nil)+"/wait", sys->OREAD);
	if(waitfd == nil){
		sys->fprint(stderr, "sh: open wait: %r\n");
		return;
	}

	if(argv != nil){
		argv = tl argv;
		if(argv != nil){
			script(ctxt, hd argv);
			return;
		}
	}
	stdin = sys->fildes(0);

	prompt := sysname() + "$ ";
	for(;;){
		sys->print("%s", prompt);
		n = sys->read(stdin, buf, len buf);
		if(n <= 0)
			break;
		arg = tokenize(string buf[0:n]);
		if(arg != nil)
			runit(ctxt, parseit(arg));
	}
}

rev(arg: list of string): list of string
{
	ret: list of string;

	while(arg != nil){
		ret = hd arg :: ret;
		arg = tl arg;
	}
	return ret;
}

waitfor(pid: int)
{
	if(pid <= 0)
		return;
	buf := array[sys->WAITLEN] of byte;
	status := "";
	for(;;){
		n := sys->read(waitfd, buf, len buf);
		if(n < 0){
			sys->fprint(stderr, "sh: read wait: %r\n");
			return;
		}
		status = string buf[0:n];
		if(status[len status-1] != ':')
			sys->fprint(stderr, "%s\n", status);
		who := int status;
		if(who != 0){
			if(who == pid)
				return;
		}
	}
}

redir(path: string, fd: int, mode, append: int): int
{
	rfd: ref FD;

	if(path == nil)
		return 0;

	if(mode == sys->OREAD)
		rfd = sys->open(path, mode);
	else{
		if(append){
			rfd = sys->open(path, mode);
			if(rfd != nil)
				sys->seek(rfd, 0, sys->SEEKEND);
		}
		if(rfd == nil)
			rfd = sys->create(path, mode, 8r666);
		if(rfd == nil)	# try open; can't create on a file2chan (pipe)
			rfd = sys->open(path, mode);
	}

	if(rfd == nil){
		sys->fprint(stderr, "sh: can't open %s mode %d: %r\n", path, mode);
		return -1;
	}
	sys->dup(rfd.fd, fd);
	return 0;
}

mkprog(ctxt: ref Context, arg: list of string, si, so: string, append: int, waitpid: chan of int)
{
	pid := sys->pctl(sys->FORKFD, nil);
	waitpid <-= pid;
	if(pid < 0)
		return;

	if(redir(si, 0, sys->OREAD, 0) < 0)
		return;
	if(redir(so, 1, sys->OWRITE, append) < 0)
		return;

	if(arg == nil)
		return;
	exec(ctxt, arg);
}

exec(ctxt: ref Context, args: list of string)
{
	cmd := hd args;
	file := cmd;
	if(len file<4 || file[len file-4:]!=".dis")
		file += ".dis";

	c := load Sh file;
	if(c == nil) {
		err := sys->sprint("%r");
		if(err == "file does not exist" && file[0]!='/' && file[0:2]!="./"){
			c = load Sh "/dis/"+file;
			if(c == nil)
				err = sys->sprint("%r");
		}
		if(c == nil){
			sys->fprint(stderr, "%s: %s\n", cmd, err);
			return;
		}
	}

	c->init(ctxt, args);
}

script(ctxt: ref Context, src: string)
{
	bufio = load Bufio Bufio->PATH;
	if(bufio == nil){
		sys->fprint(stderr, "sh: load bufio: %r\n");
		return;
	}

	f := bufio->open(src, Bufio->OREAD);
	if(f == nil){
		sys->fprint(stderr, "sh: open %s: %r\n", src);
		return;
	}
	for(;;){
		s := f.gets('\n');
		if(s == nil)
			break;
		arg := tokenize(s);
		if(arg == nil)
			break;
		runit(ctxt, parseit(arg));
	}
}

sysname(): string
{
	fd := sys->open("#c/sysname", sys->OREAD);
	if(fd == nil)
		return "anon";
	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0) 
		return "anon";
	return string buf[0:n];
}

# Lexer.

tokenize(s: string): list of string
{
	tok: list of string;
	token := "";
	instring := 0;

loop:
	for(i:=0; i<len s; i++) {
		if(instring) {
			if(s[i] != '\'')
				token = addchar(token, s[i]);
			else if(i == len s-1 || s[i+1] != '\'') {
				if(i == len s-1 || s[i+1] == ' ' || s[i+1] == '\t'){
					tok = token :: tok;
					token = "";
				}
				instring = 0;
			} else {
				token[len token] = '\'';
				i++;
			}
			continue;
		}
		case s[i] {
		' ' or '\t' or '\n'  or
		'#'  or '\'' or '|' or
		'&' or ';' or '>' or '<' =>
			if(token != "" && s[i]!='\''){
				tok = token :: tok;
				token = "";
			}
			case s[i] {
			'#' =>
				break loop;
			'\'' =>
				instring = 1;
			'>' =>
				ss := "";
				ss[0] = s[i];
				if(i<len s-1 && s[i+1]==s[i])
					ss[1] = s[i++];
				tok = ss :: tok;
			'|' or '&' or ';' or '<' =>
				ss := "";
				ss[0] = s[i];
				tok = ss :: tok;
			}
		* =>
			token[len token] = s[i];
		}
	}
	if(instring){
		sys->fprint(stderr, "sh: unmatched quote\n");
		return nil;
	}
	return rev(tok);
}

ismeta(char: int): int
{
	case char {
	'*'  or '[' or '?' or
	'#'  or '\'' or '|' or
	'&' or ';' or '>' or '<' =>
		return 1;
	}
	return 0;
}

addchar(token: string, char: int): string
{
	if(ismeta(char) && (len token==0 || token[0]!=Quoted))
		token = stringQuoted + token;
	token[len token] = char;
	return token;
}

# Parser.

getcommand(words: list of string): (ref Command, list of string)
{
	args: list of string;
	word: string;
	si, so: string;
	append := 0;

gather:
	do {
		word = hd words;

		case word {
		">" or ">>" =>
			if(so != nil)
				return (nil, nil);

			words = tl words;

			if(words == nil)
				return (nil, nil);

			so = hd words;
			if(len so>0 && so[0]==Quoted)
				so = so[1:];
			if(word == ">>")
				append = 1;
		"<" =>
			if(si != nil)
				return (nil, nil);

			words = tl words;

			if(words == nil)
				return (nil, nil);

			si = hd words;
			if(len si>0 && si[0]==Quoted)
				si = si[1:];
		"|" or ";" or "&" =>
			break gather;
		* =>
			files := doexpand(word);
			while(files != nil){
				args = hd files :: args;
				files = tl files;
			}
		}

		words = tl words;
	} while (words != nil);

	return (ref Command(rev(args), si, so, append), words);
}

doexpand(file: string): list of string
{
	if(len file>0 && file[0]==Quoted)
		return file[1:] :: nil;
	for(i:=0; i<len file; i++)
		if(file[i]=='*' || file[i]=='[' || file[i]=='?'){
			if(filepat == nil)
				filepat = load Filepat Filepat->PATH;
			files := filepat->expand(file);
			if(files != nil)
				return files;
			break;
		}
	return file :: nil;
}

revc(arg: list of ref Command): list of ref Command
{
	ret: list of ref Command;
	while(arg != nil) {
		ret = hd arg :: ret;
		arg = tl arg;
	}
	return ret;
}

getpipe(words: list of string): (ref Pipeline, list of string)
{
	cmds: list of ref Command;
	cur: ref Command;
	word: string;

	term := Seq;
gather:
	while(words != nil) {
		word = hd words;

		if(word == "|")
			return (nil, nil);

		(cur, words) = getcommand(words);

		if(cur == nil)
			return (nil, nil);

		cmds = cur :: cmds;

		if(words == nil)
			break gather;

		word = hd words;
		words = tl words;

		case word {
		";" =>
			break gather;
		"&" =>
			term = Async;
			break gather;
		"|" =>
			continue gather;
		}
		return (nil, nil);
	}

	if(word == "|")
		return (nil, nil);

	return (ref Pipeline(revc(cmds), term), words);
}

revp(arg: list of ref Pipeline): list of ref Pipeline
{
	ret: list of ref Pipeline;

	while(arg != nil) {
		ret = hd arg :: ret;
		arg = tl arg;
	}
	return ret;
}

parseit(words: list of string): list of ref Pipeline
{
	ret: list of ref Pipeline;
	cur: ref Pipeline;

	while(words != nil) {
		(cur, words) = getpipe(words);
		if(cur == nil){
			sys->fprint(stderr, "sh: syntax error\n");
			return nil;
		}
		ret = cur :: ret;
	}
	return revp(ret);
}

# Runner.

runpipeline(ctx: ref Context, pipeline: ref Pipeline)
{
	if(pipeline.term == Async)
		sys->pctl(sys->NEWPGRP, nil);

	pid := 0;
	cmds := pipeline.cmds;
	first := 1;
	inpipe := "";
	while(cmds != nil) {
		last := tl cmds == nil;
		cmd := hd cmds;

		inf := cmd.inf;
		if(first == 0)
			inf = inpipe;

		outpipe := "";
		outf := cmd.outf;
		append := cmd.append;
		if(last == 0) {
			if(pipe == nil)
				pipe = load Pipe pipe->PATH;
			(inpipe, outf) = pipe->files();
			if(outf == ""){
				sys->fprint(stderr, "sh: can't make pipe: %r\n");
				return;
			}
		}

		rpid := chan of int;
		spawn mkprog(ctx, cmd.args, inf, outf, append, rpid);
		pid = <-rpid;

		first = 0;
		cmds = tl cmds;
	}
	if(pipeline.term == Seq)
		waitfor(pid);
}

runit(ctx: ref Context, pipes: list of ref Pipeline)
{
	while(pipes != nil) {
		pipeline := hd pipes;
		pipes = tl pipes;
		if(pipeline.term == Seq)
			runpipeline(ctx, pipeline);
		else
			spawn runpipeline(ctx, pipeline);
	}
}
