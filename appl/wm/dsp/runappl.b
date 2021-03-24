#
# Demo Sports Program: Application module
#
# SYNTAX:
#
# runappl
#
# DESCRIPTION:
#
# Ask user for player's name and display player, team player is
# on, player's statistics, and team's statistics
#
# This program assumes that the relevant files are located in the
# current directory as follows:
#
# dbA/dbA.txt - contains player's name and team name
# dbB/dbB.txt - contains player's statistics
# dbC/dbC.txt - contains team's statistics
#
# All files are simple ASCII files (can be edited via Inferno's notepad
# or your favorite editor) and layout is as follows:
#
# -FIELD1-CONTENTS11
# -FIELD2-CONTENTS12
# ...
# -end-
# -FIELD1-CONTENTS21
# -FIELD2-CONTENTS22
# ...
# -end-
# ...
#
# where FIELDx is the field name (e.g., - name) and CONTENTSyx is
# the actual contents of the field x for record y.  Field contents
# can have either one or multiple lines.  In the latter case, the
# field tag is repeated (e.g., - look at -display-).
#
# The displayable part of the record is contained in -display- fields
# and it contains Tk instructions that are passed to the Tk unchanged.
#
# NOTES:
#
# Typically, this program is invoked by rundemo.dis, a module that
# executes necessary mount/bind commands to ensure that all appropriate
# files are present.
#
implement RunAppl;
#
# Libraries used by the code
#
include "sys.m";
 sys:Sys;

include "draw.m";
 draw:Draw;

include "bufio.m";
bufio: Bufio;
Iobuf: import bufio;

include "tk.m";
 tk:Tk;
 Toplevel:import tk;

t: ref Toplevel;

include "tklib.m";
 tklib:Tklib;

include "wmlib.m";
 wmlib: Wmlib;
#
# Declaration of the module
#
RunAppl:module {
  init: fn(c:ref Draw->Context, a:list of string);
};
#
# Query window
#
ds_config := array[] of {
    "frame .f -background #000077 -foreground #FF7777",
    "label .f.c -bitmap @images/applogo.bit -background #000077 -foreground #FF7777",
    "label .f.l -background #000077 -foreground #FF7777 -text {Enter name:}",
    "entry .f.e -width 300 -background #000077 -foreground #FFFFFF",
    "text .f.t -width 12c -height 7c -background #000077 -foreground #FFFFFF",
    "pack .f.c .f.t -fill both -expand 1",
    "pack .f.l .f.e -side left",
    "label .f.n -background #000077 -foreground #FF7777 -text {names}",
    "pack .f.n -side right -fill x",
    "pack .Wm_t .f -fill x",
    "bind .f.e <Key-\n> {send cmd dial}",
    "update",
};
#
# Module definition
#
init(ctxt:ref Draw->Context, args:list of string) {

# Load libraries
    sys   = load Sys   Sys->PATH;	# System libraries
    draw  = load Draw  Draw->PATH;	# Screen I/O
    bufio = load Bufio Bufio->PATH;	# Buffered I/O
    tk    = load Tk    Tk->PATH;	# Tk toolkit
    tklib = load Tklib Tklib->PATH;	# Tk libraries
    wmlib = load Wmlib Wmlib->PATH;	# Window Manager libraries

# Initialize toolkit/wm
    tklib->init(ctxt);
    wmlib->init();

# Get query window close to the center of the screen
    (px,py) := getpos(ctxt,640,550);
    ppos := sys->sprint(" -x %d -y %d ",px,py);
    t = tk->toplevel(ctxt.screen,ppos+" -borderwidth 2 - relief raised -background #000077 -foreground #FF77777");
    m := wmlib->titlebar(t,"Distributed Sports Program",Wmlib->Appl);
    cmd := chan of string;
    tk->namechan(t,cmd,"cmd");
    tklib->tkcmds(t,ds_config);
    putnames("dbA/dbA.txt");

# Get query string
    for(;;) alt {
	menu := <- m => {		# Exit command hit?
	    if (menu[0] == 'e')
		return;
 	    wmlib->titlectl(t,menu);
	}
	<- cmd => {			# New query?
	    qs := tk->cmd(t,".f.e get");
	    qr := lookfor("name",qs,"dbA/dbA.txt");
	    if (qr != nil) {
		query_result(qr);
		tk->cmd(t,".f.e delete 0.0 end");
		tk->cmd(t,"update");
	    } else {
		tk->cmd(t,".f.t delete 1.0 end");
		tk->cmd(t,".f.t insert end 'Player '" + qs + "' not found\n");
		tk->cmd(t,"update");
	    }
	}
    }

# All done
    return;
}
#
# Display results of the query, extract and display player's and team's
# statistics.
#
query_result(qr:list of string) {
  ts: string;

# Get key information
    name := getfield("name",qr);
    team := getfield("team",qr);

# Print standard results
    tk->cmd(t,".f.t delete 1.0 end");
    qr = getlist("display",qr);
    n := len qr;
    while (qr != nil) {
	ts = hd qr;
	qr = tl qr;
	ts = ts + "\n";
	tk->cmd(t,ts);
    }

# Get individual statistics
    tk->cmd(t,".f.t insert end ' \nINDIVIDUAL STATISTICS:\n");
    qr = lookfor("name",name,"dbB/dbB.txt");
    if (qr == nil) {
	tk->cmd(t,".f.t insert end 'No individual statistics available\n");
    } else {
	qr = getlist("display",qr);
	while (qr != nil) {
	    ts = hd qr;
	    qr = tl qr;
	    ts = ts + "\n";
	    tk->cmd(t,ts);
	}
    }

# Get team statistics
    tk->cmd(t,".f.t insert end ' \nTEAM STATISTICS:\n");
    qr = lookfor("team",team,"dbC/dbC.txt");
    if (qr == nil) {
	tk->cmd(t,".f.t insert end 'No team statistics available\n");
    } else {
	qr = getlist("display",qr);
	while (qr != nil) {
	    ts = hd qr;
	    qr = tl qr;
	    ts = ts + "\n";
	    tk->cmd(t,ts);
	}
    }

# Flush all out
    tk->cmd(t,"update");
}
#
# Update list of possible players
#
putnames(db:string) {
  s: string;
  i: int;

    r := getnames(db);
    s = "";
    for (i = 0; (r != nil) && i < 5; i++) {
	s = (hd r) + " " + s;
	r = tl r;
    }
    tk->cmd(t,".f.n configure -text {Possible names:\n "+s+"}");
    tk->cmd(t,"update");
}
#
# Get a list of names (contents of -name- field)
#
getnames(db:string) : list of string {
  r: list of string;	# list of names
  s: string;		# line from file
  t: string;		# field tag

# Initialize list of names, try to open file
    r = nil;
    f := bufio->open(db,Bufio->OREAD);
    if (f == nil) {
	sys->print("Can not open %s\n",db);
	return(nil);
    }

# Read the file and collect names
    for (;;) {
	s = f.gets('\n');
	if (s == nil || (len s) < 6)
	    break;
	else
	    t = string s[0:6];
	if (t == "-name-")
	    r = s[6:] :: r;
    }

# Return list found
    return(r);
}
#
# Find a record in a file 'db' that has field 'key' value 'string'.
# Return all fields for this record as a list of strings or nil if
# not found.
#
lookfor(key:string,val:string,db:string) : list of string {
  f: ref Iobuf;
  r: list of string;
  s: string;

# Set initial list to nil and try to open file
    r = nil;
    f = bufio->open(db,Bufio->OREAD);
    if (f == nil) {
	sys->print("Can not open %s\n",db);
	return(r);
    }

# Generate the actual string that we're looking for from combination
# of the field name and field value
    pat := "-" + key + "-" + val;

# Until not found or EOF hit, look for the pattern
    for (;;) {
	s = f.gets('\n');
	if (s == nil)
	    return(r);
	else
	    s = string (s[0:(len s) - 1]);
	if (s == pat)
	    break;
    }

# Found something. Read all other fields until '-end-' string is found.
    r = s :: r;
    for (;;) {
	s = f.gets('\n');
	if (s == nil)
	    break;
	else
	    s = string (s[0:(len s) - 1]);
	if (s == "-end-")
	    break;
	else {
	    r = s :: r;
	}
    }

# Return result.
    return(r);
}
#
# Given a list of fields (l), get value of the field k and return
# it's contents as a string.
#
getfield(k:string, l:list of string) : string {
  s: string;
  n: int;

# This is the tag we're looking for
    k = "-" + k + "-";
    n = len k;

# Scan the list and try to find a match on the first n characters
# When found, return the rest of the string (after nth character)
    while (l != nil) {
	s = hd l;
	l = tl l;
	if (string (s[0:n]) == k) {
	    s = string s[n:];
	    return(s);
	}
    }

# Field not found!
    return(nil);
}
#
# Given a list of fields (l), get all fields k and return result as
# a list of strings. Note: fields are returned in REVERSED order
#
getlist(k:string, l:list of string) : list of string {
  r: list of string;
  s: string;
  n: int;

# Get the tag we're looking for and initialize result list to be empty
    k = "-" + k + "-";
    n = len k;
    r = nil;

# Scan all fields and build a list (in REVERSE order) when match is found
    while (l != nil) {
	s = hd l;
	l = tl l;
	if ((string (s[0:n])) == k) {
	    r = (string s[n:]) :: r;
	}
    }

# Return resulting list (possibly nil)
    return(r);
}
#
# Get coordinates of the window of width w and height h, such that
# it would appear at the center of window manager's work area.  Return
# these coordinates as (px,py) pair.
#
getpos(ctxt:ref Draw->Context,w,h:int) : (int,int) {

	r := ctxt.display.image.r;
	x := r.max.x - r.min.x;
	y := r.max.y - r.min.y;
	dx := (x - w) / 2; if (dx < 0) dx = 0;
	dy := (y - h) / 2; if (dy < 0) dy = 0;
	return(dx,dy);
}
