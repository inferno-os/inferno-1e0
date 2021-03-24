implement Changelogin;

include "sys.m";
sys: Sys;

include "daytime.m";
daytime: Daytime;

include "draw.m";

include "keyring.m";
kr: Keyring;

include "security.m";
pass: Password;

Changelogin: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

stderr, stdin: ref Sys->FD;

init(nil: ref Draw->Context, args: list of string)
{
	ok: int;
	word: string;

	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;

	stdin = sys->fildes(0);
	stderr = sys->fildes(2);

	argv0 := hd args;
	args = tl args;

	if(args == nil){
		sys->fprint(stderr, "usage: %s userid\n", argv0);
		exit;
	}

	daytime = load Daytime Daytime->PATH;
	if(daytime == nil) {
		sys->fprint(stderr, "%s: load Daytime: %r\n", argv0);
		exit;
	}
	pass = load Password Password->PATH;
	if(pass == nil) {
		sys->fprint(stderr, "%s: load Password: %r\n", argv0);
		exit;
	}

	# get password
	id := hd(args);
	pw := pass->get(id);
	if(pw == nil)
		sys->print("new account\n");
	npw := ref Password->PW;
	npw.id = id;
	for(;;){
		if(pw != nil)
			sys->print("password [default = don't change]: ");
		else
			sys->print("password: ");
		(ok, word) = readline(stdin);
		if(!ok)
			exit;
		if(word == "" && pw != nil)
			break;
		if(len word >= 7)
			break;
		sys->print("!password must be at least 7 characters\n");
	}
	if(word == "")
		npw.pw = pw.pw;
	else {
		pwbuf := array of byte word;
		npw.pw = array[Keyring->SHAdlen] of byte;
		kr->sha(pwbuf, len pwbuf, npw.pw, nil);
	}

	# get expiration time (midnight of date specified)
	now := daytime->now();
	tm := daytime->local(now);
	tm.sec = 59;
	tm.min = 59;
	tm.hour = 24;
	if(pw == nil)
		expsecs := now + 365*24*60*60;
	else
		expsecs = pw.expire;
	for(;;){
		otm := daytime->local(expsecs);
		sys->print("expires [DDMMYYYY, return = %2.2d%2.2d%4.4d]: ",
				otm.mday, otm.mon, otm.year+1900);
		(ok, word) = readline(stdin);
		if(!ok)
			exit;
		if(word == "")
			break;
		if(len word != 8){
			sys->print("!bad date format %s\n", word);
			continue;
		}
		tm.mday = int word[0:2];
		if(tm.mday > 31 || tm.mday < 1){
			sys->print("!bad day of month %d\n", tm.mday);
			continue;
		}
		tm.mon = int word[2:4] - 1;
		if(tm.mon > 11 || tm.mday < 0){
			sys->print("!bad month %d\n", tm.mon + 1);
			continue;
		}
		tm.year = int word[4:8] - 1900;
		if(tm.year < 70){
			sys->print("!bad year %d\n", tm.year + 1900);
			continue;
		}
		tm.sec = 59;
		tm.min = 59;
		tm.hour = 23;
		expsecs = daytime->tm2epoch(tm);
		if(expsecs > now)
			break;
		sys->print("!expiration date must be in the future\n");
	}
	npw.expire = expsecs;

	# get the free form field
	if(pw != nil)
		npw.other = pw.other;
	else
		npw.other = "";
	sys->print("free form info [return = %s]: ", npw.other);
	(ok, word) = readline(stdin);
	if(!ok)
		exit;
	if(word != "")
		npw.other = word;

	if(pass->put(npw) < 0)
		sys->fprint(stderr, "%s: error writing entry: %r\n", argv0);
	else
		sys->print("change written\n");
}
 
readline(io: ref Sys->FD): (int, string)
{
        r : int;
        line : string;
        buf := array[8192] of byte;
 
        #
        # Read up to the CRLF
        #
        line = "";
        for(;;) {
                r = sys->read(io, buf, len buf);
                if(r <= 0)
                        return (0, nil);
 
                line += string buf[0:r];
                if ((len line >= 1) &&
                    (line[(len line)-1] == '\n'))
                        break;
        }
 
        # Total success!
        return (1, line[0:len line - 1]);
}
