#
# Demo Sports Program: Get Data Files Set and Run Application
#
# SYNTAX:
#
# rundemo [ machA [  machC ] ]
#
# DESCRIPTION:
#
# Bring data files into current environment and start application
# program.  Arguments specify on which machines data files exist
# (for example, tcp!mypc.lucent.com). If not specified, the local
# machine name is used.
#
# NOTES:
#
# Typically, this program is invoked by startdemo.dis, a module
# that finds rundemo.b on a remote machine and makes it visible
# locally by use of a bind command.
#
implement RunDemo;
#
# Libraries used by the code
#
include	"sys.m";
 sys:Sys;

include	"draw.m";
 draw:Draw;

include	"keyring.m";
include	"security.m";

include "tk.m";
 tk: Tk;
 Toplevel: import tk;

include "wmlib.m";
 wmlib: Wmlib;

include	"tklib.m";
 tklib: Tklib;

t: ref Toplevel;
#
# A madule prototype that will be loaded and executed
#
Wm: module {
  init: fn(c: ref Draw->Context, argv: list of string);
};
#
# Declaration of the module, optional arguments are passed in 'a'.
#
RunDemo:module {
  init: fn(c:ref Draw->Context, a:list of string);
};
#
# Information pop-up window.  Reports a status of how
# authentication/mount/binds are progressing.
#
rd_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.l -background #000077 -foreground #FF7777 -text {Authenticating.  Please stand by.}",
	"pack .f.l -side left",
	"pack .Wm_t .f -fill x",
	"update",
};
#
# Module definition.  Optional machine names are specified in args.
#
init(ctxt:ref Draw->Context, args:list of string) {
  em: string;		# Error message string

# Load libraries
    sys   = load Sys  Sys->PATH;
    draw  = load Draw Draw->PATH;
    tk    = load Tk Tk->PATH;
    tklib = load Tklib Tklib->PATH;
    wmlib = load Wmlib Wmlib->PATH;

# Initialize window manager stuff
    tklib->init(ctxt);
    wmlib->init();

# This is a map of mount points, machines, and files.  The actual
# machine names are defined here only as an example.  The actual
# values used are redefined later.
    demodir := "/demo/dsp";			# Demo directory
    m_point := "mnt";				# Mount point
    r_machA := "tcp!kline";			# Remote machine A
    r_fileA := m_point + demodir + "/rdbA";	# Remote database A
    l_fileA := "dbA";				# Local database A
    r_fileB := m_point + demodir + "/rdbB";	# Remote database B
    l_fileB := "dbB";				# Local database B
    r_machC := "tcp!kline";			# Remote machine C
    r_fileC := m_point + demodir + "/rdbC";	# Remote database C
    l_fileC := "dbC";				# Local database C
#   encralg := "rc4";				# Encryption to use
    encralg := "sha";				# Encryption to use

# Check if arguments are given.  If they are, - use these as the
# names of the machines where data files may be found.  For all
# missing arguments, use local machine name.
    args = tl args;
    if (args != nil) {
	r_machA = hd args;
	args = tl args;
	if (args != nil) {
	    r_machC = hd args;
	} else {
	    r_machC = r_machA;
	}
    } else {
	r_machA = "tcp!" + sysname();
	r_machC = r_machA;
    }

# Put information notice
    (px,py) := getpos(ctxt,400,100);
    ppos := sys->sprint(" -x %d -y %d ",px,py);
    t = tk->toplevel(ctxt.screen,ppos+" -borderwidth 2 - relief raised");
    m := wmlib->titlebar(t,"Distributed Sports Program",0);
    tklib->tkcmds(t,rd_config);
    tk->cmd(t,".f.l configure -text {\n\nAuthenticating with host A.  Please stand by.}");
    tk->cmd(t,"update");

# Mount machine A (and B, implicitely)
    em = "none";
    if (remote_mount(ctxt,r_machA,m_point,encralg)) {
	tk->cmd(t,".f.l configure -text {Authentication with host A successful.\n\nAuthenticating with host C.  Please stand by.}");
	tk->cmd(t,"update");
	if (sys->bind(r_fileA,l_fileA,sys->MREPL) < 0) {
	    em = em + "\n" +
		sys->sprint("Machine A: bind(%s,%s) from machine %s failed\n",
			    r_fileA,l_fileA,r_machA);
	}
	if (sys->bind(r_fileB,l_fileB,sys->MREPL) < 0) {
	    em = em + "\n" +
		sys->sprint("Machine A: bind(%s,%s) from machine %s failed\n",
			    r_fileB,l_fileB,r_machA);
	}
	sys->unmount(nil,m_point);
    } else {
	em = em + "\n" + sys->sprint("Machine A: Mount of %s failed\n",r_machA);
    }

# Mount machine C
    if (remote_mount(ctxt,r_machC,m_point,encralg)) {
	tk->cmd(t,".f.l configure -text {Authentication with host C successful.\n\n}");
	tk->cmd(t,"update");
	if (sys->bind(r_fileC,l_fileC,sys->MREPL) < 0) {
	    em = em + "\n" +
		sys->sprint("Machine C: bind(%s,%s) from machine %s failed\n",
			    r_fileC,l_fileC,r_machC);
	}
	sys->unmount(nil,m_point);
    } else {
	em = em + "\n" + sys->sprint("Machine C: Mount of %s failed\n",r_machC);
    }

# Load application and run it
    if (em != "none") {
	em = string em[4:];
	put_error(ctxt,em);
    } else {
	appl := "runappl.dis";
	dsappl := load Wm appl;
	spawn dsappl->init(ctxt,"runappl" :: nil);
    }
    return;
}
#
# Mount a remote machine 'addr' at mount point 'place'.  Use
# algorithm 'alg' for encryption (e.g., "sha" or "rc4").  Return
# zero on failure, one on success.
#
remote_mount(ctxt: ref Draw->Context, addr,place,alg: string) : int {

# Connect to remote
    sel := addr+"!styx";
    (ok,c) := sys->dial(sel,nil);
    if (ok < 0) {
	sys->print("dial(%s,nil) failed\n",sel);
	return(0);
    }

# Authenticate
    fd := auth(ctxt,addr,alg,c.dfd);		# Note: c is from dial above
    if (fd == nil) {
	sys->print("auth(%s,%s) failed\n",addr,alg);
	return(0);
    }

# Mount
    sys->pctl(sys->FORKNS,nil);
    n := sys->mount(fd,place,sys->MREPL,"");
    if (n < 0) {
	sys->print("%r. failed\n");
	return(0);
    }

# All done
    return(1);
}
#
# Authenticate connection 'dfd', for machine 'keyname'.  Use
# encryption algorithm 'alg' (e.g., "sha" or "rc4").  Return connection
# on success, nil on failure.
#
auth(ctxt: ref Draw->Context,
     keyname, alg: string, dfd: ref Sys->FD): ref Sys->FD {
  c: ref Sys->Connection;

    kr := load Keyring Keyring->PATH;
    if (kr == nil) {
	sys->print("Can't load module Keyring: %r. ");
	return nil;
    }

    login := load Login Login->PATH;
    if (login == nil) {
	sys->print("Can't load module Login: %r. ");
	return nil;
    }

    ai := login->getauthinfo(ctxt, keyname, nil);
    if (ai == nil) {
	sys->print("warning: can't get key: %r. ");
    }

    (id_or_err, secret) := kr->auth(dfd, ai, 0);
    if (secret == nil) {
	sys->print("authentication failed: %s. ",id_or_err);
	return nil;
    } else {
	if(id_or_err != "xyzzy") {
	    sys->print("\nAuthentication succeeded but remote id\n");
	    sys->print("is '%s' instead of the normal\n",id_or_err);
	    sys->print("service id.  This may be unsafe.\n");
	}
    }

    algbuf := array of byte alg;
    kr->sendmsg(dfd, algbuf, len algbuf);
    if(alg == "none")
	return dfd;

# push ssl and turn on algorithm
    ssl := load SSL SSL->PATH;
    if (ssl == nil) {
	sys->print("Can't load module SSL: %r. ");
	return nil;
    }

    if (sys->bind("#D", "/n/ssl", Sys->MREPL) < 0) {
	sys->print("cannot bind #D: %r. ");
	return nil;
    }

    (id_or_err, c) = ssl->connect(dfd);
    if (c == nil) {
	sys->print("Can't push SSL: %s. ",id_or_err);
	return nil;
    }

    id_or_err = ssl->secret(c, secret, secret);
    if (id_or_err != nil) {
	sys->print("Can't write secret: %s. ",id_or_err);
	return nil;
    }

    if(sys->fprint(c.cfd, "alg %s", alg) < 0){
	sys->print("Can't start %s: %r", alg);
	return nil;
    }

    return c.dfd;
}
#
# Get the name of the local machine
#
sysname(): string
{
	fd := sys->open("#c/sysname", sys->OREAD);
	if(fd == nil)
		return "Anon";
	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0) 
		return "Anon";
	return string buf[0:n];
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
#
# Spawn an error reporting program, passing it the error message 's'.
# This allows current program to continue, while error is displayed.
#
put_error(ctxt:ref Draw->Context,s:string) {

    en := "runerr.dis";
    eh := load Wm en;
    spawn eh->init(ctxt,"runerr" :: s :: nil);
}
