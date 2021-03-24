!include ..\..\..\mkconfig.nmk
!include ..\..\..\$(SYSHOST)\mkhost

OBJ=\
	readmail.dis\
	sendmail.dis\
	shortcut.dis\
	wish.dis\
	winctl.dis\

all:	$(OBJ)

MODULE=\
	..\..\..\module\bufio.m\
	..\..\..\module\cci.m\
	..\..\..\module\daytime.m\
	..\..\..\module\debug.m\
	..\..\..\module\draw.m\
	..\..\..\module\filepat.m\
	..\..\..\module\html.m\
	..\..\..\module\keyring.m\
	..\..\..\module\mpeg.m\
	..\..\..\module\newns.m\
	..\..\..\module\pipe.m\
	..\..\..\module\quicktime.m\
	..\..\..\module\rand.m\
	..\..\..\module\readdir.m\
	..\..\..\module\riff.m\
	..\..\..\module\security.m\
	..\..\..\module\sh.m\
	..\..\..\module\string.m\
	..\..\..\module\sys.m\
	..\..\..\module\tk.m\
	..\..\..\module\tklib.m\
	..\..\..\module\version.m\
	..\..\..\module\url.m\
	..\..\..\module\webget.m\
	..\..\..\module\wmlib.m\
	..\..\..\module\workdir.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\dis\wm

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\dis\wm\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\wm
	copy $(OBJ) $(PREFIX_PKG)\dis\wm

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I..\..\..\module $*.b

.b.s:	
	limbo -w -G -S -I..\..\..\module $*.b

$(PREFIX_PKG)\dis\wm:
	mkdir $(PREFIX_PKG)\dis\wm

#sam.dis samstub.dis samtk.dis: samstub.m samterm.m

cdmk: 
	@echo cd $(TARGCD); $(MAKE) /NOLOGO $(TARGMK) 
	@cd $(TARGCD)
	@$(MAKE) /NOLOGO $(TARGMK)
