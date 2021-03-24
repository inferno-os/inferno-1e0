!include ..\..\..\mkconfig.nmk
!include ..\..\..\$(SYSHOST)/mkhost

OBJ=\
	runappl.dis\
	rundemo.dis\
	runerr.dis\
	runprofile.dis\
	slideshow.dis\
	startdemo.dis\

all:	$(OBJ)

MODULE=\
	..\..\..\module\bufio.m\
	..\..\..\module\draw.m\
	..\..\..\module\keyring.m\
	..\..\..\module\security.m\
	..\..\..\module\string.m\
	..\..\..\module\sys.m\
	..\..\..\module\tklib.m\
	..\..\..\module\tk.m\
	..\..\..\module\wmlib.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\demo\dsp

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\demo\dsp\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\demo\dsp
	copy $(OBJ) $(PREFIX_PKG)\demo\dsp

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl
 
.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I../../../module $*.b

.b.s:	
	limbo -w -G -S -I../../../module $*.b

$(PREFIX_PKG)\demo\dsp:
	mkdir $(PREFIX_PKG)\demo\dsp

