#
# Demo Sports Program: Report error in a window
#
# SYNTAX:
#
# runerr 'error-message'
#
# DESCRIPTION:
#
# Create a small window closer to the top and center of the screen.
# Put there message passed as argument and wait for the user to hit
# exit button.
#
# This is a handy utility that allows program to report an error and
# keep running without checking for the window kill button.
#
implement RunErr;
#
# Libraries module needs
#
include	"sys.m";
 sys:Sys;

include	"draw.m";
 draw:Draw;
 Screen: import draw;

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
# Module declaration
#
RunErr:module {
  init: fn(c:ref Draw->Context, a:list of string);
};
#
# Error message window
#
err_msg_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.i -background #000077 -foreground #FF7777 -text {Configuration Error:}",
	"label .f.l -background #000077 -foreground #FF7777 -text {Warning:}",
	"pack .f.i .f.l -fill x",
	"frame .b -background #000077 -foreground #FF7777",
	"button .b.h -background #000077 -foreground #FF7777 -label HELP -command {send msg help}",
	"button .b.c -background #000077 -foreground #FF7777 -label EXIT -command {send msg exit}",
	"pack .b.h .b.c -padx 5 -pady 10 -side left -expand 1",
	"pack .Wm_t .f .b -fill x",
	"update",
};
#
# Help window
#
help_msg_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.a -background #000077 -foreground #FF7777 -text {Remote mounts have failed authentication.  The most likely\ncause of this failure is improper configuration due to:\n\n}",
	"pack .f.a -side top -anchor w",
	"frame .a -background #000077 -foreground #FF7777",
	"button .a.ba -background #000077 -foreground #FF7777 -text { An authentication signer has not been setup               } -command {send hmsg a}",
	"pack .a.ba -side left",
	"frame .b -background #000077 -foreground #FF7777",
	"button .b.bb -background #000077 -foreground #FF7777 -text { User does not have an account on the authentication signer} -command {send hmsg b}",
	"pack .b.bb -side left",
	"frame .c -background #000077 -foreground #FF7777",
	"button .c.bc -background #000077 -foreground #FF7777 -text { Inferno server is not running                             } -command {send hmsg c}",
	"pack .c.bc -side left",
	"frame .d -background #000077 -foreground #FF7777",
	"label .d.a -background #000077 -foreground #FF7777 -text {\n\nClick on one of the above to obtain more information\n }",
	"pack .d.a -anchor w",
	"pack .Wm_t .f .a .b .c .d -side top -anchor w -fill x",
	"update",
};
#
# Specific help 1
#
help_msg1_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.a1 -background #000077 -foreground #FF7777 -text {To setup authentication signer:}",
	"label .f.a2 -background #000077 -foreground #FF7777 -text {1) Quit the application}",
	"label .f.a3 -background #000077 -foreground #FF7777 -text {2) Quit EMU}",
	"label .f.a4 -background #000077 -foreground #FF7777 -text {3) Setup an Inferno server as specified in the\n   Inferno User's Guide, Chapter 2:\n   Installation and Setup, Setup Configuration.\n}",
	"pack .f.a1 .f.a2 .f.a3 .f.a4 -side top -anchor w",
	"pack .Wm_t .f -side top -anchor w -fill x",
	"update",
};
#
# Specific help 2
#
help_msg2_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.a1 -background #000077 -foreground #FF7777 -text {To setup user account on authentication server}",
	"label .f.a2 -background #000077 -foreground #FF7777 -text {1) Quit the application}",
	"label .f.a3 -background #000077 -foreground #FF7777 -text {2) Quit EMU}",
	"label .f.a4 -background #000077 -foreground #FF7777 -text {3) Setup a user account as specified in the\n   Inferno User's Guide, Chapter 2:\n   Installation and Setup, Setup Configuration.\n}",
	"pack .f.a1 .f.a2 .f.a3 .f.a4 -side top -anchor w",
	"pack .Wm_t .f -side top -anchor w -fill x",
	"update",
};
#
# Specific help 3
#
help_msg3_config := array[] of {
	"frame .f -background #000077 -foreground #FF7777",
	"label .f.a1 -background #000077 -foreground #FF7777 -text {To start server}",
	"label .f.a2 -background #000077 -foreground #FF7777 -text {1) Quit the application}",
	"label .f.a3 -background #000077 -foreground #FF7777 -text {2) In the emulator console window type\n\n      lib/srv\n\n}",
	"label .f.a4 -background #000077 -foreground #FF7777 -text {3) Restart application}",
	"pack .f.a1 .f.a2 .f.a3 .f.a4 -side top -anchor w",
	"pack .Wm_t .f -side top -anchor w -fill x",
	"update",
};
#
# Module specification
#
init(ctxt:ref Draw->Context, args:list of string) {

# Load libraries
    sys   = load Sys  Sys->PATH;
    draw  = load Draw Draw->PATH;
    tk    = load Tk Tk->PATH;
    tklib = load Tklib Tklib->PATH;
    wmlib = load Wmlib Wmlib->PATH;

# Initialize window manager stuff
    tklib->init(ctxt);
    wmlib->init();

# Put information notice
    (px,py) := getpos(ctxt,400,600);
    ppos := sys->sprint(" -x %d -y %d ",px,py);
    t = tk->toplevel(ctxt.screen,ppos+" -borderwidth 2 - relief raised");
    m := wmlib->titlebar(t,"Distributed Sports Program Configuration Error",Wmlib->Appl);
    msg := chan of string;
    tk->namechan(t,msg,"msg");
    tklib->tkcmds(t,err_msg_config);

# Get warning message up
    args = tl args;
    s := " ";
    while (args != nil) {
	s = sys->sprint("%s\n%s",s,(hd args));
	args = tl args;
    }
    tk->cmd(t,".f.l configure -text {"+s+"}");
    tk->cmd(t,"update");

# Wait until done
    for (;;) alt {
	menu := <- m => {
	    if (menu[0] == 'e')
		return;
	    wmlib->titlectl(t,menu);
	}
	btn := <- msg => {
	    if (btn == "help") {
#		sys->print("Help pressed\n");
		spawn show_help(ctxt.screen,20,py+20);
		return;
	    } else {
		return;
	    }
	}
    }
}
#
# Show help
#
show_help(screen: ref Screen, px,py: int) {

# Put help window
    ppos := sys->sprint(" -x %d -y %d ",px,py);
    tt := tk->toplevel(screen,ppos+" -borderwidth 2 - relief raised");
    m := wmlib->titlebar(tt,"Distributed Sports Program Help",Wmlib->Appl);
    hmsg := chan of string;
    tk->namechan(tt,hmsg,"hmsg");
    tklib->tkcmds(tt,help_msg_config);

# Wait until done or spawn a new type of specific help window
    for (;;) alt {
	menu := <- m => {
	    if (menu[0] == 'e')
		return;
	    wmlib->titlectl(tt,menu);
	}
	bbb := <- hmsg => {
	    spawn show_spec_help(screen,px+20,py+20,bbb);
	    px = px + 20;
	    py = py + 20;
	}
    }
}
#
# Show specific help
#
show_spec_help(screen: ref Screen, px,py: int, bbb: string) {

# Put help window
    ppos := sys->sprint(" -x %d -y %d ",px,py);
    tt := tk->toplevel(screen,ppos+" -borderwidth 2 - relief raised");
    m := wmlib->titlebar(tt,"Distributed Sports Program Help",Wmlib->Appl);
    if (bbb == "a") {
	tklib->tkcmds(tt,help_msg1_config);
    } else if (bbb == "b") {
	tklib->tkcmds(tt,help_msg2_config);
    } else if (bbb == "c") {
	tklib->tkcmds(tt,help_msg3_config);
    }

# Wait until done
    for (;;) {
	menu := <- m;
	if (menu[0] == 'e')
	    return;
	wmlib->titlectl(tt,menu);
    }
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
