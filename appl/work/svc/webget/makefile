!include ..\..\..\..\mkconfig.nmk
!include ..\..\..\..\$(SYSHOST)\mkhost

OBJ=\
	date.dis\
	file.dis\
	http.dis\
	image2enc.dis\
	message.dis\
	webget.dis\
	wgutils.dis\

all:	$(OBJ)

MODULE=\
	date.m\
	image2enc.m\
	message.m\
	transport.m\
	wgutils.m\

LOGS=\
	webget.log\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\..\dis\svc\webget
	$(DEL) $(DELFLAGS) ..\..\..\..\services\webget\webget.*
	copy webget.log ..\..\..\..\services\webget

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\..\dis\svc\webget\%%j
	@-for %%j in ( $(LOGS) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\..\services\webget\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\svc\webget
	copy $(OBJ) $(PREFIX_PKG)\dis\svc\webget

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I..\..\..\..\module $*.b

.b.s:	
	limbo -w -G -S -I..\..\..\..\module $*.b

$(PREFIX_PKG)\dis\svc\webget:
	mkdir $(PREFIX_PKG)\dis\svc\webget
