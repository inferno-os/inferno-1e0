!include ..\..\mkconfig.nmk
!include ..\..\$(SYSHOST)\mkhost

MODULE=..\..\module

DIRS=\
	cmd\
	mux\
	svc\
	wm\

all \
install \
uninstall \
nuke \
clean \
package :
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

cdmk: 
	@echo cd $(TARGCD); $(MAKE) /NOLOGO $(TARGMK) 
	@cd $(TARGCD)
	@$(MAKE) /NOLOGO $(TARGMK)
