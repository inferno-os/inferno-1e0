#
# Demo Sports Program: Run 'profile' in the current directory
#
# SYNTAX:
#
# runprofile
#
# DESCRIPTION:
#
# This module checks if there is a file called 'profile' in the current
# directory.  If there is none, it just executes 'slideshow'.  Otherwise,
# it runs 'profile' through 'sh.dis' interpreter.
#
# This program is handy when running the demo from the window manager
# menu, while the demo is located on the remote machine (it is impossible
# to pass arguments from 'wmsetup' call).  An example of a sample profile
# file may be found in 'sampleProfile' file in /demo/dsp directory.
#
implement RunProfile;
#
# Load all libraries
#
include	"sys.m";
 sys:Sys;

include	"draw.m";
 draw:Draw;
#
# Module declaration
#
RunProfile:module {
  init: fn(c:ref Draw->Context, a:list of string);
};
#
# Prototype of shell module
#
Wm: module {
  init: fn(c: ref Draw->Context, argv: list of string);
};
#
# Module specification
#
init(ctxt:ref Draw->Context, args:list of string) {

# Load libraries
    sys   = load Sys  Sys->PATH;
    draw  = load Draw Draw->PATH;

# Go to the demo directory
    sys->chdir("/demo/dsp");

# If there is a profile, - run it.  Otherwise, just jump to the slideshow
    if (sys->open("profile",sys->OREAD) != nil) {
	appl := "/dis/sh.dis";
	hand := load Wm appl;
	spawn hand->init(ctxt,"sh" :: "profile" :: nil);
    } else {
	appl := "slideshow.dis";
	hand := load Wm appl;
	spawn hand->init(ctxt,"slideshow" :: nil);
    }
}
