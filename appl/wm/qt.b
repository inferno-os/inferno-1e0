implement WmQt;

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;

include "tk.m";
	tk: Tk;
	Toplevel: import tk;

include "tklib.m";
	tklib: Tklib;

include	"wmlib.m";
	wmlib: Wmlib;
	ctxt: ref Draw->Context;
	ones: ref Draw->Image;

include "quicktime.m";
	qt: QuickTime;

WmQt: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

Stopped, Playing: con iota;

task_cfg := array[] of {
	"canvas .c",
	"frame .b",
	"button .b.File -text File -command {send cmd file}",
	"button .b.Stop -text Stop -command {send cmd stop}",
	"button .b.Pause -text Pause -command {send cmd pause}",
	"button .b.Play -text Play -command {send cmd play}",
	"frame .f",
	"label .f.file -text {File:}",
	"label .f.name",
	"pack .f.file .f.name -side left",
	"pack .b.File .b.Stop .b.Pause .b.Play -side left",
	"pack .Wm_t -fill x",
	"pack .f -fill x",
	"pack .b -anchor w",
	"pack .c -side bottom -fill both -expand 1",
	"pack propagate . 0",
};

init(xctxt: ref Draw->Context, argv: list of string)
{
	sys  = load Sys  Sys->PATH;
	draw = load Draw Draw->PATH;
	tk   = load Tk   Tk->PATH;
	wmlib= load Wmlib Wmlib->PATH;
	tklib= load Tklib Tklib->PATH;

	ctxt = xctxt;
	ones = ctxt.display.ones;

	tklib->init(ctxt);
	wmlib->init();

	tkargs := "";
	argv = tl argv;
	if(argv != nil) {
		tkargs = hd argv;
		argv = tl argv;
	}

	t := tk->toplevel(ctxt.screen, tkargs+" -borderwidth 2 -relief raised");

	menubut := wmlib->titlebar(t, "QuickTime Player", 0);

	cmd := chan of string;
	tk->namechan(t, cmd, "cmd");

	tklib->tkcmds(t, task_cfg);

	tk->cmd(t, "bind . <Configure> {send cmd resize}");
	tk->cmd(t, "update");

	qt = load QuickTime QuickTime->PATH;
	if(qt == nil) {
		tklib->notice(t, "Failed to load the QuickTime interface:\n"+
					sys->sprint("%r"));
		return;
	}
	qt->init();

	fname := "";
	ctl := chan of string;
	state := Stopped;

	for(;;) alt {
	menu := <-menubut =>
		if(menu[0] == 'e')
			return;
		wmlib->titlectl(t, menu);
	press := <-cmd =>
		case press {
		"file" =>
			fname = wmlib->getfilename(ctxt.screen, t, "QuickTime Movie", "*.mov", ".");
			if(fname != nil) {
				s := fname;
				if(len s > 25)
					s = "..."+fname[len s - 25:];
				tk->cmd(t, ".f.name configure -text {"+s+"}");
				tk->cmd(t, "update");
			}
		"play" =>
			if(fname != nil)
				spawn play(t, fname);
		}
	}
}

#
# Parse the atoms describing a movie
#
moov(t: ref Toplevel, q: ref QuickTime->QD)
{
	for(;;) {
		(h, l) := qt->q.atomhdr();
		if(l < 0)
			break;
		case h {
		* =>
			qt->q.skipatom(l);
		"mvhd" =>
			err := qt->q.mvhd(l);
			if(err == nil)
				break;
			tklib->notice(t, err);
			exit;
		"trak" =>
			err := qt->q.trak(l);
			if(err == nil)
				break;
			tklib->notice(t, err);
			exit;
		}
	}
}

play(t: ref Toplevel, file: string)
{
	(q, err) := qt->open(file);
	if(err != nil) {
		tklib->notice(t, err);
		return;
	}
	for(;;) {
		(h, l) := qt->q.atomhdr();
		if(l < 0)
			break;
		case h {
		* =>
			qt->q.skipatom(l);
		"moov" =>
			moov(t, q);
		}
	}
}
