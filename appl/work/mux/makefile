!include ..\..\..\mkconfig.nmk
!include ..\..\..\$(SYSHOST)\mkhost

OBJ=\
	audioctl.dis\
	comics.dis\
	connect4.dis\
	email.dis\
	fnn.dis\
	gamed.dis\
	games.dis\
	movie.dis\
	mux.dis\
	news.dis\
	othello.dis\
	pizza.dis\
	readlnw.dis\
	readnews.dis\
	rec-pb.dis\
	register.dis\
	rmux.dis\
	rmuxslave.dis\
	tv.dis\
	tvlist.dis\
	web.dis\

all:	$(OBJ)

MODULE=\
	..\..\..\module\bufio.m\
	..\..\..\module\devpointer.m\
	..\..\..\module\draw.m\
	..\..\..\module\html.m\
	..\..\..\module\ir.m\
	..\..\..\module\keyring.m\
	..\..\..\module\gamer.m\
	..\..\..\module\mpeg.m\
	..\..\..\module\prefab.m\
	..\..\..\module\math.m\
	..\..\..\module\security.m\
	..\..\..\module\srv.m\
	..\..\..\module\string.m\
	..\..\..\module\sys.m\
	..\..\..\module\tk.m\
	..\..\..\module\url.m\
	..\..\..\module\webget.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\..\dis\mux

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\..\dis\mux\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\mux
	copy $(OBJ) $(PREFIX_PKG)\dis\mux

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I..\..\..\module $*.b

.b.s:	
	limbo -w -G -S -I..\..\..\module $*.b

$(PREFIX_PKG)\dis\mux:
	mkdir $(PREFIX_PKG)\dis\mux
