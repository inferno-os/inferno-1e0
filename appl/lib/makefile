!include ..\..\mkconfig.nmk
!include ..\..\$(SYSHOST)/mkhost

OBJ=\
	bufio.dis\
	cci.dis\
	countersigner.dis\
	createsignerkey.dis\
	cs.dis\
	db.dis\
	daytime.dis\
	debug.dis\
	devpointer.dis\
	filepat.dis\
	hash.dis\
	html.dis\
	imageremap.dis\
	ir.dis\
	irsage.dis\
	irsim.dis\
	gamer.dis\
	login.dis\
	logind.dis\
	mpeg.dis\
	newns.dis\
	password.dis\
	pipe.dis\
	quicktime.dis\
	rand.dis\
	random.dis\
	readdir.dis\
	readgif.dis\
	readjpg.dis\
	regex.dis\
	riff.dis\
	signer.dis\
	srv.dis\
	ssl.dis\
	string.dis\
	tcl_calc.dis\
	tcl_core.dis\
	tcl_inthash.dis\
	tcl_io.dis\
	tcl_list.dis\
	tcl_modhash.dis\
	tcl_stack.dis\
	tcl_strhash.dis\
	tcl_string.dis\
	tcl_symhash.dis\
	tcl_tk.dis\
	tcl_utils.dis\
	tklib.dis\
	url.dis\
	verify.dis\
	virgil.dis\
	virgild.dis\
	volume.dis\
	wmlib.dis\
	workdir.dis\

all:	$(OBJ)

MODULE= \
	../../module/bufio.m\
	../../module/cci.m\
	../../module/daytime.m\
	../../module/db.m\
	../../module/debug.m\
	../../module/devpointer.m\
	../../module/draw.m\
	../../module/filepat.m\
	../../module/hash.m\
	../../module/html.m\
	../../module/imagefile.m\
	../../module/ir.m\
	../../module/keyring.m\
	../../module/newns.m\
	../../module/mpeg.m\
	../../module/pipe.m\
	../../module/prefab.m\
	../../module/quicktime.m\
	../../module/readdir.m\
	../../module/regex.m\
	../../module/rand.m\
	../../module/riff.m\
	../../module/security.m\
	../../module/sh.m\
	../../module/srv.m\
	../../module/sys.m\
	../../module/tklib.m\
	../../module/url.m\
	../../module/volume.m\
	../../module/wmlib.m\

$(OBJ):	$(MODULE)

install: $(OBJ)
	copy *.dis ..\..\dis\lib

uninstall:
	@-for %%j in ( $(OBJ) ) \
	do $(DEL) $(DELFLAGS) ..\..\dis\lib\%%j

package:	$(OBJ)\
		$(PREFIX_PKG)\dis\lib
	copy $(OBJ) $(PREFIX_PKG)\dis\lib

clean nuke:
	-$(DEL) $(DELFLAGS) *.dis 
	-$(DEL) $(DELFLAGS) *.sbl

.SUFFIXES:	.b .dis .s

.b.dis:	
	limbo -gw -I../../module $*.b

.b.s:	
	limbo -w -G -S -I../../module $*.b

$(PREFIX_PKG)\dis\lib:
	mkdir $(PREFIX_PKG)\dis\lib
