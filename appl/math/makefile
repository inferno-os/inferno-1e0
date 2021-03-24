!include ..\..\mkconfig.nmk
!include ..\..\$(SYSHOST)/mkhost

OBJ=\
	ffts.dis\
	graph0.dis\
	gr.dis\
	linalg.dis\
	linbench.dis\

all:	$(OBJ)

MODULE=\
	../../module/math.m\
	../../module/gr.m\
	../../module/linalg.m\
	../../module/draw.m\
	../../module/sys.m\
	../../module/tk.m\
	../../module/tklib.m\
	../../module/wmlib.m\
	../../module/draw.m\
	../../module/bufio.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\dis\math

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\dis\math\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\math
	copy $(OBJ) $(PREFIX_PKG)\dis\math

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I../../module $*.b

.b.s:	
	limbo -w -G -S -I../../module $*.b

$(PREFIX_PKG)\dis\math:
	mkdir $(PREFIX_PKG)\dis\math
