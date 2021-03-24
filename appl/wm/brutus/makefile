!include ..\..\..\mkconfig.nmk
!include ..\..\..\$(SYSHOST)/mkhost

OBJ=\
	excerpt.dis\
	image.dis\
	table.dis\

all:	$(OBJ)

MODULE=\
	../../../module/brutus.m\
	../../../module/brutusext.m\
	../../../module/bufio.m\
	../../../module/draw.m\
	../../../module/html.m\
	../../../module/imagefile.m\
	../../../module/pipe.m\
	../../../module/pslib.m\
	../../../module/regex.m\
	../../../module/string.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\dis\wm\brutus

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\dis\wm\brutus\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\wm\brutus
	copy $(OBJ) $(PREFIX_PKG)\dis\wm\brutus

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl
 
.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I../../../module $*.b

.b.s:	
	limbo -w -G -S -I../../../module $*.b

$(PREFIX_PKG)\dis\wm\brutus:
	mkdir $(PREFIX_PKG)\dis\wm\brutus

