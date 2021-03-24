!include ..\..\..\..\mkconfig.nmk
!include ..\..\..\..\$(SYSHOST)\mkhost

OBJ=\
	cache.dis\
	content.dis\
	date.dis\
	echo.dis\
	httpd.dis\
	imagemap.dis\
	parse.dis\
	query.dis\
	redirect.dis\
	stats.dis\
	alarm.dis\

all:	$(OBJ)

MODULE=\
	cache.m\
	cgi.m\
	content.m\
	date.m\
	httpd.m\
	parser.m\
	query.m\
	redirect.m\
	alarm.m\

LOGS=\
        httpd.debug\
        httpd.log\
        httpd.rewrite\
        httpd.suff\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\..\dis\svc\httpd
	$(DEL) $(DELFLAGS) ..\..\..\..\services\httpd\httpd.*
	copy httpd.debug ..\..\..\..\services\httpd
	copy httpd.log ..\..\..\..\services\httpd
	copy httpd.rewrite ..\..\..\..\services\httpd
	copy httpd.suff ..\..\..\..\services\httpd

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\..\dis\svc\httpd\%%j
	@-for %%j in ( $(LOGS) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\..\services\httpd\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\svc\httpd
	copy $(OBJ) $(PREFIX_PKG)\dis\svc\httpd

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I..\..\..\..\module $*.b

.b.s:	
	limbo -w -G -S -I..\..\..\..\module $*.b

$(PREFIX_PKG)\dis\svc\httpd:
	mkdir $(PREFIX_PKG)\dis\svc\httpd
