!include ..\..\..\mkconfig.nmk
!include ..\..\..\$(SYSHOST)\mkhost

OBJ=\
	irtest.dis\
	manufacture.dis\
	rcmd.dis\
	stack.dis\
	tail.dis\
	tclsh.dis\
	wish.dis\

all:	$(OBJ)

auhdr.dis: auplay.dis
	copy auplay.dis auhdr.dis

MODULE= ..\..\..\module\sys.m\
	..\..\..\module\draw.m\
	..\..\..\module\string.m\
	..\..\..\module\prefab.m\
	..\..\..\module\ir.m\
	..\..\..\module\srv.m\
	..\..\..\module\tk.m\
	..\..\..\module\daytime.m\
	..\..\..\module\keyring.m\
	..\..\..\module\security.m\
	..\..\..\module\bufio.m\
	..\..\..\module\readdir.m\
	..\..\..\module\regex.m\
	..\..\..\module\newns.m\
	..\..\..\module\sh.m\
	..\..\..\module\workdir.m\
	..\..\..\module\filepat.m\
	..\..\..\module\pipe.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\dis

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\dis\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis
	copy $(OBJ) $(PREFIX_PKG)\dis

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -I..\..\..\module -gw $*.b

.b.s:	
	limbo -w -G -S -I..\..\..\module $*.b

$(PREFIX_PKG)\dis:
	mkdir $(PREFIX_PKG)\dis
