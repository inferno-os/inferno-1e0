!include ..\..\mkconfig.nmk
!include ..\..\$(SYSHOST)/mkhost

DIRS=\
	brutus\
	dsp\

OBJ=\
	about.dis\
	avi.dis\
	brutus.dis\
	coffee.dis\
	date.dis\
	deb.dis\
	debdata.dis\
	debsrc.dis\
	dir.dis\
	edit.dis\
	charon.dis\
	license.dis\
	logon.dis\
	memory.dis\
	mpeg.dis\
	qt.dis\
#	readmail.dis\
	rmtdir.dis\
	rt.dis\
#	sam.dis\
#	samstub.dis\
#	samtk.dis\
#	sendmail.dis\
	sh.dis\
#	shortcut.dis\
	task.dis\
	telnet.dis\
	view.dis\
#	winctl.dis\
#	wish.dis\
	wm.dis\

all:	$(OBJ)
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

MODULE=\
	../../module/bufio.m\
	../../module/cci.m\
	../../module/daytime.m\
	../../module/debug.m\
	../../module/draw.m\
	../../module/filepat.m\
	../../module/html.m\
	../../module/keyring.m\
	../../module/mpeg.m\
	../../module/newns.m\
	../../module/pipe.m\
	../../module/quicktime.m\
	../../module/rand.m\
	../../module/readdir.m\
	../../module/riff.m\
	../../module/security.m\
	../../module/sh.m\
	../../module/string.m\
	../../module/sys.m\
	../../module/tk.m\
	../../module/tklib.m\
	../../module/version.m\
	../../module/url.m\
	../../module/webget.m\
	../../module/wmlib.m\
	../../module/workdir.m\
	wmdeb.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\dis\wm
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\dis\wm\%%j
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\wm
	copy $(OBJ) $(PREFIX_PKG)\dis\wm
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I../../module $*.b

.b.s:	
	limbo -w -G -S -I../../module $*.b

$(PREFIX_PKG)\dis\wm:
	mkdir $(PREFIX_PKG)\dis\wm

#sam.dis samstub.dis samtk.dis: samstub.m samterm.m

cdmk: 
	@echo cd $(TARGCD); $(MAKE) /NOLOGO $(TARGMK) 
	@cd $(TARGCD)
	@$(MAKE) /NOLOGO $(TARGMK)
