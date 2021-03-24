SYSTARG=Nt
OBJTYPE=386

A=		lib
O=		obj


AR=		lib
ARFLAGS=	

AS=		cl 
ASFLAGS=	-c $(AS_LOCAL)

CC=		cl 
CFLAGS=\
		-Zi -c -w -nologo\
		$(CC_LOCAL)\
                -I$(ROOT_DEVEL)\$(SYSTARG)\$(OBJTYPE)\include\
                -I$(ROOT_DEVEL)\include\

LD=		link
LDFLAGS=\
		$(LD_LOCAL)\

LIB=$(ROOT_DEVEL)\$(SYSTARG)\$(OBJTYPE)\lib;$(LIB)

		
LDSYSLIBS=	wsock32.lib\
		kernel32.lib\
		user32.lib\
		gdi32.lib\
		binmode.obj\
		advapi32.lib\

RC=		rc
RCFLAGS=

YACC=		yacc
YFLAGS=		-d

.SUFFIXES:	.b .dis .s .rc .res
.b.dis:
	limbo -gw -I..\module $*.b

.b.s:
	limbo -w -G -S -I..\module $*.b

.rc.res:
	$(RC) $(RCFLAGS) $*.rc
