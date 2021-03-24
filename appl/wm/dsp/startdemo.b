#
# Demo Sports Program: Get Executable And Run It
#
# SYNTAX:
#
# startdemo [ machD [ args ... ] ]
#
# where 'machD' is the name of the machine where executable
# is (e.g., tcp!mypc.lucent.com) and 'args' are arguments to
# pass to the executable module.  If arguments are missing,
# local machine is assumed.
#
# DESCRIPTION:
#
# This module start 'rundemo' program, taking it from the
# machine indicated on the argument line.  If no machine
# is specified, local machine is assumed.  
#
# NOTES:
#
# This module is typically invoked by 'slideshow' program.
#
implement StartDemo;
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
StartDemo:module {
  init: fn(c:ref Draw->Context, a:list of string);
};
#
# Information pop-up window.  Reports a status of how
# authentication/mount/binds are progressing.
#
rd_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.l -background #000077 -foreground #FF7777 -text {Authentication with remote host in progress.\n\n              Please stand by.}",
	"pack .f.l -side left",
	"pack .Wm_t .f -fill x",
	"update",
};
#
# Module definition.  Optional machine names are specified in args.
#
init(ctxt:ref Draw->Context, args:list of string) {
  em: string;		# Error message;

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
# machine name is defined here only as an example.  The actual
# value is redefined later.
    m_point := "mnt";				# Mount point
    r_machD := "tcp!kline";			# Remote machine D
    r_demod := m_point + "/demo/dsp";		# Remote demo directory
    l_demod := "/demo/dsp";			# Local demo directory
#   encralg := "rc4";				# Encryption algorithm
    encralg := "sha";				# Encryption algorithm

# Check if arguments are given.  If they are, the first one
# is the name of the machine where 'rundemo.dis' may be found.
# Otherwise, local machine is assumed. (Note: the rest of the
# arguments are passed unchanged to 'rundemo.dis')
    args = tl args;
    if (args != nil) {
	r_machD = hd args;
	args = tl args;
    } else {
	r_machD = "tcp!" + sysname();
    }

# Put information notice
    (px,py) := getpos(ctxt,400,100);
    ppos := sys->sprint(" -x %d -y %d ",px,py);
    t = tk->toplevel(ctxt.screen,ppos+" -borderwidth 2 - relief raised");
    m := wmlib->titlebar(t,"Distributed Sports Program",0);
    tklib->tkcmds(t,rd_config);

# Mount machine D
    em = "none";
    if (remote_mount(ctxt,r_machD,m_point,encralg)) {
	if (sys->bind(r_demod,l_demod,sys->MREPL) < 0) {
	    em = sys->sprint("Machine D: bind(%s,%s) from machine %s failed\n",
			     r_demod,l_demod,r_machD);
	}
	sys->unmount(nil,m_point);
    } else {
	em = sys->sprint("Machine D: Mount of %s failed\n",r_machD);
    }

# If error, - report it.  Otherwise, load application and run it
    if (em != "none") {
	put_error(ctxt,em);
    } else {
	appl := "rundemo.dis";
	dsappl := load Wm appl;
	spawn dsappl->init(ctxt,"rundemo" :: args);
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
sysname(): string {
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
